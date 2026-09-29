# PowerBI-Lineage.Orchestrator.V2.ps1: detailed documentation

V2 is [`PowerBI-Lineage.Orchestrator.ps1`](../orchestrator-v1/PowerBI-Lineage.Orchestrator.ps1) (V1) with the 8
files of the tool written out as plain text instead of a compressed payload. The settings, the checks and the run
section are the same text as V1. This page covers what differs; for the shared parts see
[V1 detailed documentation](../orchestrator-v1/documentation.md).

## Flow

1. Read the nine settings; take any that are empty or start with `Required-` from their environment variables.
2. Check each setting; require `$ClientSecret` or `$CertificateThumbprint`.
3. Default `$Mode` to `Admin` and the timeout to 180 minutes; work out the output file name.
4. Build `$files`, an ordered table of the 8 files, from 8 here-strings.
5. Join each path and its text with CRLF; the version is the first 6 bytes of the SHA-256 of that text (UTF-8), as 12 hex characters.
6. If `<installRoot>\<version>\.complete` is missing, write each file (turning `#~'@` lines back into `'@`, line endings CRLF), write `.complete`, and delete older 12-hex version folders.
7. Start 64-bit Windows PowerShell on `Invoke-LineageRun.ps1` through `cmd.exe`, with the settings as environment variables.
8. Wait up to the timeout, stopping the process tree if it passes.
9. Write the run log next to the output; throw on timeout or failure, otherwise return the run's console output.

Steps 1 to 3 and 7 to 9 are identical to V1.

## Structure

| Part | Starts at | What it does |
|---|---|---|
| Banner and settings | Line 1 | Same as V1. |
| Header note | `# Nothing below needs changing.` | Lists the 8 files with their line counts. |
| Checks | `$ErrorActionPreference = 'Stop'` | Same as V1: `Get-Setting`, `Assert-Setting`, output path. |
| The tool's files | `# ---- The tool's files, in full` | `$files = [ordered]@{}`, then one block per file under a heading such as `# ==== File 3 of 8: src\modules\MQueryLineage.psm1 (712 lines)`. |
| Save step | `# ---- Save the tool once per version` | Steps 5 and 6. |
| Run | `# ---- Run in 64-bit Windows PowerShell` | Same as V1. |

Each file block has this form:

```powershell
$files['src\modules\RunProgress.psm1'] = @'
...file text...
'@
```

A single-quoted here-string ends at the first line that starts with `'@`. Two source lines start that way (line 29
of `MQueryLineage.psm1` and line 122 of `LauncherArguments.psm1`). They are embedded as `#~'@` and restored when
saved.

The files, in order:

| Key in `$files` | Lines | Documentation |
|---|---|---|
| `src\modules\Prerequisites.psm1` | 105 | [Prerequisites.psm1](../../docs/Prerequisites.psm1/README.md) |
| `src\modules\PowerBIRest.psm1` | 173 | [PowerBIRest.psm1](../../docs/PowerBIRest.psm1/README.md) |
| `src\modules\MQueryLineage.psm1` | 712 | [MQueryLineage.psm1](../../docs/MQueryLineage.psm1/README.md) |
| `src\modules\RunProgress.psm1` | 177 | [RunProgress.psm1](../../docs/RunProgress.psm1/README.md) |
| `src\modules\LauncherArguments.psm1` | 125 | [LauncherArguments.psm1](../../docs/LauncherArguments.psm1/README.md) |
| `src\Get-PbiReportLineage.ps1` | 1154 | [Get-PbiReportLineage.ps1](../../docs/Get-PbiReportLineage.ps1/README.md) |
| `src\Export-PbiLineageWorkbook.ps1` | 305 | [Export-PbiLineageWorkbook.ps1](../../docs/Export-PbiLineageWorkbook.ps1/README.md) |
| `Invoke-LineageRun.ps1` | 29 | [Invoke-LineageRun.ps1](../../docs/Invoke-LineageRun.ps1/README.md) |

### Get-Setting

Same as in V1: returns the typed value, or the environment variable's value, trimmed, with `Required-...`
treated as empty. See [V1: Get-Setting](../orchestrator-v1/documentation.md#get-setting).

### Assert-Setting

Same as in V1: throws `The setting <Name> is required: ...` or `The setting <Name> has an invalid value: <Value>`.
See [V1: Assert-Setting](../orchestrator-v1/documentation.md#assert-setting).

No other functions are defined directly in the file. The functions inside the 8 embedded files are documented on
their own pages.

## What it writes

As V1, with one difference in the unpacked files:

| Location | What | Lifetime |
|---|---|---|
| `%ProgramData%\PowerBI-Lineage\<version>\` (or `PowerBI-Lineage` under the temp folder) | The 8 files, CRLF line endings, UTF-8 with byte order mark, each ending in a line break; and `.complete`. | Until a different version runs. Only 12-hex folder names are deleted. |
| `<temp>\PowerBI-Lineage-<run id>.out.txt`, `.err.txt` | Captured output. | Deleted after the run. |
| `$ExcelPath` and the same name with `.csv` and `.log` | Workbook (unless CSV only), CSV and run log. | A folder path gets a new dated name each run. |
| `report-lineage-yyyyMMdd-HHmmss\report-lineage.json` in the output folder | The JSON. | Kept. |

## Error handling

Identical to V1: setting errors are thrown before anything is saved; a failed run throws
`Power BI lineage run failed: <reason> Log: <log path>`; a timeout throws
`Power BI lineage run did not finish within <n> minutes and was stopped. Log: <log path>`.

## How it is built

`build/New-OrchestratorRunbook.ps1` builds V2 in the same run as V1, from the same template
(`orchestrator/OrchestratorTool.ps1`) and the same 8 files:

- It replaces V1's header note with a list of the files and their line counts.
- It replaces everything from `# ---- Unpack the tool once per version` up to `# ---- Run in 64-bit Windows PowerShell` with the file blocks and the save step.
- It fills the settings with the same placeholders as V1, converts line endings to CRLF and writes UTF-8 without a byte order mark.

The build throws if the template's header note or unpack section has changed, a source has a line starting with
`#~'@`, a source contains Orchestrator's published-data marker, the result does not parse, or it contains a
non-ASCII character. Unlike V1, backticks are allowed.

`tests/OrchestratorRunbook.Tests.ps1` checks that:

- V2 is byte for byte the same as a fresh build;
- it has no `$payload`;
- its file blocks are the 8 files in order, each equal to its source once `#~'@` is turned back into `'@`;
- the text before `# Nothing below needs changing.` and from `# ---- Run in 64-bit Windows PowerShell` onwards is identical to V1.

The tests that run the script in 32-bit and 64-bit hosts use V1 only.

## Limits and notes

- The file is about 142 KB and 3,021 lines. It contains 16 backticks on 12 lines, all in the embedded tool code.
- V2's version is a hash of the file text; V1's is a hash of the compressed bytes. The same sources therefore unpack to different folders from V1 and V2, and running one deletes the other's folder.
- All the limits of V1 apply: no single quotes in values, folder names ending in `.` and 2 to 5 letters are refused, `$TimeoutMinutes = '0'` stops the run at once, and a typed secret is stored in plain text in the Orchestrator database.
- No test runs V2 in an Orchestrator-like host.
