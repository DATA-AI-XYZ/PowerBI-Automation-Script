# Invoke-LineageRun.ps1

The entry point for Orchestrator runs. It runs `Get-PbiReportLineage.ps1` unattended with settings read from `LINEAGE_*` environment variables, so no setting is placed on a command line, and turns the result into exit code `0` or `1`.

| | |
|---|---|
| Type | script |
| Used by | The Orchestrator scripts (`PowerBI-Lineage.Orchestrator.ps1`, `PowerBI-Lineage.Orchestrator.V2.ps1`), which start it in 64-bit Windows PowerShell with `-File` |
| Uses | `src\Get-PbiReportLineage.ps1`, relative to its own folder |
| Runs in | Windows PowerShell 5.1 or later (`#Requires -Version 5.1`), as its own process |
| Reads | `LINEAGE_MODE`, `LINEAGE_TENANT_ID`, `LINEAGE_CLIENT_ID`, `LINEAGE_EXCEL_PATH`, `LINEAGE_CERTIFICATE_THUMBPRINT`, `LINEAGE_WORKSPACE_IDS`; `PBI_CLIENT_SECRET` is read by the main script |
| Writes | Whatever `Get-PbiReportLineage.ps1` writes; `ERROR: <message>` to standard error on failure |

In the source tree the file is `orchestrator/Invoke-LineageRun.ps1`. `build/New-OrchestratorRunbook.ps1` packs it at the root of the tool folder, next to `src\`, which is where it expects to run.

## Use

The Orchestrator scripts set the environment variables on the child process only, then start:

```
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "<tool folder>\Invoke-LineageRun.ps1"
```

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `LINEAGE_MODE` | Yes | None | Passed as `-Mode`: `Admin`, `User` or `Auto`. Unset or empty fails the run. The Orchestrator scripts set `Admin` when the setting is empty. |
| `LINEAGE_TENANT_ID` | Yes | None | Passed as `-TenantId`. |
| `LINEAGE_CLIENT_ID` | Yes | None | Passed as `-ClientId`. |
| `LINEAGE_EXCEL_PATH` | Yes | None | Passed as `-ExcelPath`: a folder, a `.xlsx` file or a `.csv` file. |
| `LINEAGE_CERTIFICATE_THUMBPRINT` | No | None | Passed as `-CertificateThumbprint` when set. |
| `LINEAGE_WORKSPACE_IDS` | No | All workspaces | Split on `,` and passed as `-WorkspaceId` when set. |
| `PBI_CLIENT_SECRET` | When no certificate | None | Not read here. `Get-PbiReportLineage.ps1` reads it when no certificate thumbprint is given. |

`-Unattended` is always passed. `LINEAGE_OUTPUT_FORMAT` and `LINEAGE_TIMEOUT_MINUTES` are used by the Orchestrator scripts only, not by this script.

## Outputs

| Exit code | Meaning |
|---|---|
| `0` | `Get-PbiReportLineage.ps1` finished without a terminating error. |
| `1` | Any terminating error. `ERROR: <message>` is written to standard error. |

The main script's output goes to standard output. Its files (JSON, CSV, workbook) go where `LINEAGE_EXCEL_PATH` points; with no `-OutputPath`, an unattended run puts the JSON run folder next to the Excel file. The Orchestrator scripts redirect standard output and standard error to temporary files and save them as the run log next to the output.

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../README.md)
- [Get-PbiReportLineage.ps1](../Get-PbiReportLineage.ps1/README.md)
- [RunProgress.psm1](../RunProgress.psm1/README.md)
- [Orchestrator script](../../downloads/orchestrator-v1/README.md)
- [Orchestrator script, uncompressed](../../downloads/orchestrator-v2/README.md)
- [Runbook import](../../downloads/runbook-import/README.md)
