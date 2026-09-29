# Invoke-LineageRun.ps1: detailed documentation

## Flow

1. Sets `$ErrorActionPreference = 'Stop'`.
2. Inside `try`, builds a parameter hashtable: `Unattended = $true`, and `Mode`, `TenantId`, `ClientId` and `ExcelPath` from `LINEAGE_MODE`, `LINEAGE_TENANT_ID`, `LINEAGE_CLIENT_ID` and `LINEAGE_EXCEL_PATH`.
3. Adds `CertificateThumbprint` when `LINEAGE_CERTIFICATE_THUMBPRINT` is not empty.
4. Adds `WorkspaceId` when `LINEAGE_WORKSPACE_IDS` is not empty, as `@($env:LINEAGE_WORKSPACE_IDS -split ',')`.
5. Runs `& (Join-Path $PSScriptRoot 'src\Get-PbiReportLineage.ps1') @parameters`.
6. On return, `exit 0`.
7. In `catch`, writes `ERROR: <exception message>` with `[Console]::Error.WriteLine` and `exit 1`.

## Functions

The script defines no functions. Its steps are listed under Flow.

### Environment variables

| Variable | Parameter | When passed |
|---|---|---|
| `LINEAGE_MODE` | `-Mode` | Always, even when unset (as an empty value). |
| `LINEAGE_TENANT_ID` | `-TenantId` | Always, even when unset. |
| `LINEAGE_CLIENT_ID` | `-ClientId` | Always, even when unset. |
| `LINEAGE_EXCEL_PATH` | `-ExcelPath` | Always, even when unset. |
| `LINEAGE_CERTIFICATE_THUMBPRINT` | `-CertificateThumbprint` | Only when not empty. |
| `LINEAGE_WORKSPACE_IDS` | `-WorkspaceId` | Only when not empty; split on `,`. |
| None | `-Unattended` | Always. |

`PBI_CLIENT_SECRET` is not read here. `Get-PbiReportLineage.ps1` reads it when `-ClientId` is given without `-ClientSecret` or `-CertificateThumbprint`.

### Exit codes

| Code | When |
|---|---|
| `0` | `Get-PbiReportLineage.ps1` returned without a terminating error. |
| `1` | Any terminating error in the `try` block, including parameter validation by `Get-PbiReportLineage.ps1`. |

## Script state

| Name | Value |
|---|---|
| `$ErrorActionPreference` | `Stop` |
| `$parameters` | The hashtable splatted into `Get-PbiReportLineage.ps1`. |

## Error handling

Every error that reaches the `catch` block is reduced to one line on standard error, `ERROR: <message>`, and exit code `1`. The Orchestrator scripts read that line, strip the `ERROR:` prefix, and fail the activity with `Power BI lineage run failed: <reason> Log: <log path>`. When standard error is empty they use the last five non-empty lines of standard output instead.

Examples of errors from `Get-PbiReportLineage.ps1` that end here:

| Cause | Message |
|---|---|
| `LINEAGE_MODE` unset or not `Admin`, `User` or `Auto` | Parameter validation error for `Mode`. |
| `LINEAGE_CLIENT_ID` set, `LINEAGE_TENANT_ID` empty | `-TenantId is required with -ClientId.` |
| No certificate and no `PBI_CLIENT_SECRET` | `Service principal sign-in needs -ClientSecret, -CertificateThumbprint or the PBI_CLIENT_SECRET environment variable.` |
| `LINEAGE_EXCEL_PATH` has another file extension | `ExcelPath must be a folder, a .xlsx file or a .csv file: <path>` |

## Limits and notes

- The script expects `src\Get-PbiReportLineage.ps1` under its own folder. That holds in the folder unpacked by the Orchestrator scripts, not in the source tree, where the file sits in `orchestrator\`.
- The path uses a backslash, so the script is written for Windows.
- Values are passed as read. The script does not trim them, and does not trim the workspace IDs after splitting. The Orchestrator scripts check each setting and remove white space from `LINEAGE_WORKSPACE_IDS` and `LINEAGE_CERTIFICATE_THUMBPRINT` before setting them.
- `-OutputPath` is never passed. As an unattended run, `Get-PbiReportLineage.ps1` then writes the JSON run folder next to `LINEAGE_EXCEL_PATH`.
- `-PassThru` is not passed, so no lineage rows are written to standard output; standard output holds the progress lines and summary.
- Output is redirected by the Orchestrator scripts, so `RunProgress.psm1` uses its `Plain` style: one line per finished step, no live status.
- The script has no time limit. The Orchestrator scripts stop the process after their `TimeoutMinutes` setting (or `LINEAGE_TIMEOUT_MINUTES`), default 180 minutes.
