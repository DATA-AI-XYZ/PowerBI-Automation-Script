# PowerBI-Lineage.Orchestrator.ps1: detailed documentation

The script runs inside Orchestrator's own PowerShell host, which may be 32-bit Windows PowerShell (Orchestrator
2019) or a .NET 8 PowerShell (Orchestrator 2022 and 2025). It does not run the tool there. It checks the settings,
unpacks the tool, and starts 64-bit Windows PowerShell on `Invoke-LineageRun.ps1`, passing the settings as
environment variables.

## Flow

1. Read the nine settings; take any that are empty or start with `Required-` from their environment variables.
2. Check each setting against its pattern; require `$ClientSecret` or `$CertificateThumbprint`.
3. Default `$Mode` to `Admin` and the timeout to 180 minutes.
4. Work out the output file: a `.csv` path means CSV only; a folder gets `PowerBI-Lineage_<ddMMyyHHmm>.xlsx` (or `.csv`).
5. Decode the base64 payload; the version is the first 6 bytes of the SHA-256 of the compressed bytes, as 12 hex characters.
6. If `<installRoot>\<version>\.complete` is missing, decompress, write the 8 files, write `.complete`, and delete older 12-hex version folders.
7. Start `cmd.exe` (from `Sysnative` if it exists, else `System32`), which runs `System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File Invoke-LineageRun.ps1` with output redirected to two temp files and input from `NUL`.
8. Wait up to the timeout; if it passes, stop the process tree with `taskkill.exe /T /F`.
9. Read and delete the two temp files, and write their text to the run log next to the output.
10. Throw on timeout or a non-zero exit code; otherwise return the run's console output.

## Structure

| Part | What it does |
|---|---|
| Banner | How to paste and fill in the script. |
| Settings | Nine lines `$Name = '...'`. The first four hold `Required-...` placeholders; the rest are empty. |
| `# Nothing below needs changing.` header | Says the tool is compressed, where it unpacks, and which modules it uses. |
| Checks | `Get-Setting` and `Assert-Setting` calls (steps 1 to 4). |
| `# ---- Unpack the tool once per version` | `$payload` here-string of base64 in lines of 100 characters, then step 5 and 6. |
| `# ---- Run in 64-bit Windows PowerShell` | Steps 7 to 10. |

The payload holds these files, each after a line `=====LINEAGE-FILE: <path>=====`:

| Unpacked path | Documentation |
|---|---|
| `src\modules\Prerequisites.psm1` | [Prerequisites.psm1](../../docs/Prerequisites.psm1/README.md) |
| `src\modules\PowerBIRest.psm1` | [PowerBIRest.psm1](../../docs/PowerBIRest.psm1/README.md) |
| `src\modules\MQueryLineage.psm1` | [MQueryLineage.psm1](../../docs/MQueryLineage.psm1/README.md) |
| `src\modules\RunProgress.psm1` | [RunProgress.psm1](../../docs/RunProgress.psm1/README.md) |
| `src\modules\LauncherArguments.psm1` | [LauncherArguments.psm1](../../docs/LauncherArguments.psm1/README.md) |
| `src\Get-PbiReportLineage.ps1` | [Get-PbiReportLineage.ps1](../../docs/Get-PbiReportLineage.ps1/README.md) |
| `src\Export-PbiLineageWorkbook.ps1` | [Export-PbiLineageWorkbook.ps1](../../docs/Export-PbiLineageWorkbook.ps1/README.md) |
| `Invoke-LineageRun.ps1` | [Invoke-LineageRun.ps1](../../docs/Invoke-LineageRun.ps1/README.md) |

### Get-Setting

Returns a setting's value, falling back to an environment variable.

| Parameter | Type | Description |
|---|---|---|
| `Typed` | string | The value in the script. |
| `EnvironmentName` | string | The environment variable to read if `Typed` is empty or a placeholder. |

**Returns:** the trimmed value, or an empty string. A value matching `^Required-.*$` counts as empty, from either
source.
**Errors:** none.

### Assert-Setting

Checks one setting.

| Parameter | Type | Description |
|---|---|---|
| `Name` | string | Setting name used in messages. |
| `Value` | string | The value. |
| `Pattern` | string | Regular expression the value must match. |
| `Optional` | bool | If `$true`, an empty value passes. |

**Returns:** nothing.
**Errors:** `The setting <Name> is required: replace its Required-... placeholder with a value.` when a required
value is empty; `The setting <Name> has an invalid value: <Value>` when it does not match.

Patterns used:

| Setting | Pattern | Optional |
|---|---|---|
| `TenantId` | `^[A-Za-z0-9.-]+$` | No |
| `AppId` | GUID, `8-4-4-4-12` hex | No |
| `ExcelPath` | `^[^"<>\|*?]+$` | No |
| `OutputFormat` | `^(Excel\|CSV)$` | Yes |
| `Mode` | `^(Admin\|User\|Auto)$` | Yes |
| `WorkspaceIds` | 36 characters of hex or `-`, comma-separated | Yes |
| `CertificateThumbprint` | `^[0-9A-Fa-f]{40}$` | Yes |
| `TimeoutMinutes` | `^[0-9]{1,4}$` | Yes |

### Environment passed to the child process

| Variable | Value |
|---|---|
| `LINEAGE_TENANT_ID`, `LINEAGE_CLIENT_ID`, `LINEAGE_EXCEL_PATH`, `LINEAGE_MODE`, `LINEAGE_WORKSPACE_IDS`, `LINEAGE_CERTIFICATE_THUMBPRINT`, `PBI_CLIENT_SECRET` | The checked settings. An empty setting is removed from the child's environment rather than inherited. |
| `PSModulePath` | The host's value without entries containing `\PowerShell\` (PowerShell 7 folders). |
| `LOCALAPPDATA` | Set to `<installRoot>\LocalAppData` only if the host has none. |

`$OutputFormat` and `$TimeoutMinutes` are not passed on: the format is carried by the `.xlsx` or `.csv` extension
of `LINEAGE_EXCEL_PATH`, and the timeout is applied by this script.

## What it writes

| Location | What | Lifetime |
|---|---|---|
| `%ProgramData%\PowerBI-Lineage\<version>\` | The 8 files (UTF-8 with byte order mark) and `.complete`. Falls back to `PowerBI-Lineage` under the temp folder if `%ProgramData%\PowerBI-Lineage` cannot be created. | Until a different version runs. Only 12-hex folder names are deleted. |
| `<temp>\PowerBI-Lineage-<run id>.out.txt`, `.err.txt` | The child's standard output and error. | Deleted after the run. |
| `$ExcelPath` with extension `.log` | Standard output followed by standard error. | Replaced when the name repeats. |
| `$ExcelPath` | Workbook (`.xlsx`) or CSV. | A folder path gets a new dated name each run. |
| `$ExcelPath` with extension `.csv` | The CSV, written by the tool. | As above. |
| `report-lineage-yyyyMMdd-HHmmss\` in the `$ExcelPath` folder | `report-lineage.json`. | Kept. |
| The run account's PowerShell module folder | `MicrosoftPowerBIMgmt.Profile`, and `ImportExcel` unless CSV only, only if found in no module folder. | Permanent. |

## Error handling

| Case | Message or result |
|---|---|
| A setting missing or malformed | Thrown before anything is unpacked (see `Assert-Setting`). |
| No secret and no certificate | `Set ClientSecret or CertificateThumbprint.` |
| `$ExcelPath` ends in another extension of 2 to 5 letters | `The setting ExcelPath must be a folder, a .xlsx file or a .csv file: <path>` |
| Tool exits non-zero | `Power BI lineage run failed: <reason> Log: <log path>`. The reason is standard error with `ERROR:` removed, or the last 5 non-empty output lines. |
| Timeout | Process tree stopped; `Power BI lineage run did not finish within <n> minutes and was stopped. Log: <log path>` |
| Log cannot be written | The log path in the message becomes `(log not written: <reason>)`. |

`$ErrorActionPreference` is `Stop`, so any other error also fails the activity.

## How it is built

`build/New-OrchestratorRunbook.ps1` fills the template `orchestrator/OrchestratorTool.ps1`:

- It joins the 8 files (LF line endings, trailing line breaks trimmed) after `=====LINEAGE-FILE:` lines, gzip-compresses them at `Optimal`, base64-encodes the result and puts it in `{{PAYLOAD}}` in lines of 100.
- It replaces the nine `{{<parameter>}}` placeholders: `Required-TenantId`, `Required-AppId`, `Required-ClientSecret-or-CertificateThumbprint`, `Required-ExcelPath`, and empty strings for the rest.
- It converts line endings to CRLF and writes UTF-8 without a byte order mark.

The build throws if a source contains the file marker, a placeholder is missing or unmatched, the script does not
parse, or it contains a non-ASCII character or a backtick.

`tests/OrchestratorRunbook.Tests.ps1` checks that:

- the file matches a fresh build, comparing the payload after decompression;
- it is plain ASCII with no byte order mark and no backticks, and under 64 KB;
- the first nine settings and their placeholders are as listed above;
- in 32-bit and 64-bit Windows PowerShell and PowerShell 7 hosts, the tool runs in 64-bit Windows PowerShell and receives tenant, app ID and secret (a stand-in Power BI module stops at sign-in);
- five of the unpacked files match their sources exactly;
- the run log is written next to the workbook, and named `PowerBI-Lineage_<10 digits>.log` for a folder path;
- CSV only runs without `ImportExcel`;
- a certificate is used when the secret is left as its placeholder;
- placeholder settings are read from `LINEAGE_*` and `PBI_CLIENT_SECRET`;
- eight kinds of bad setting are refused before anything is unpacked.

## Limits and notes

- A value must not contain a single quote: it would end the string.
- A folder whose name ends in `.` and 2 to 5 letters, such as `bi.data`, is read as a file and refused.
- `$TimeoutMinutes = '0'` passes the check and stops the run at once.
- The version is a hash of the compressed bytes. Windows PowerShell and PowerShell 7 compress the same text to different bytes, so the same sources built on different hosts unpack to different folders.
- A run of a new version deletes older version folders without checking whether another run is using one.
- The log is written only after the child process ends; there is no log while it runs.
- A secret typed into the script is stored in the Orchestrator database as plain text. Subscribe to an encrypted variable, or use a certificate.
