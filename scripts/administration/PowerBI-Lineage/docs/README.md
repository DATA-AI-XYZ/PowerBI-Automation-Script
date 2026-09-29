# Power BI Report Lineage: documentation

Every file of the tool has two pages:

- **README**: what the file is, how it is used, its inputs and outputs.
- **Detailed documentation**: what happens when it runs, step by step, and a reference entry for every function.

For how to run the tool, start with the [tool overview](../README.md).

## Downloads

What people download and run. Each download has its own folder.

| File | What it is | Pages |
|---|---|---|
| `PowerBI-Lineage.cmd`, `PowerBI-Lineage.zip` | Desktop and unattended runs: a launcher with every script embedded as plain text. The `.zip` holds the same `.cmd` for email. | [README](../downloads/cmd/README.md) · [Detail](../downloads/cmd/documentation.md) |
| `PowerBI-Lineage.Orchestrator.ps1` | System Center Orchestrator, V1: one script pasted into a Run .NET Script activity, with the tool embedded as compressed text. | [README](../downloads/orchestrator-v1/README.md) · [Detail](../downloads/orchestrator-v1/documentation.md) |
| `PowerBI-Lineage.Orchestrator.V2.ps1` | System Center Orchestrator, V2: the same script with the tool as plain text, for review. | [README](../downloads/orchestrator-v2/README.md) · [Detail](../downloads/orchestrator-v2/documentation.md) |
| `PowerBI-Lineage.ois_export` | The Orchestrator script in a runbook to import with Runbook Designer. | [README](../downloads/runbook-import/README.md) · [Detail](../downloads/runbook-import/documentation.md) |

## Source files

The code inside every download. Listed in the order a run uses them.

| File | What it does | Pages |
|---|---|---|
| `Invoke-LineageRun.ps1` | Entry point for Orchestrator runs: reads the settings from environment variables and starts the main script. | [README](Invoke-LineageRun.ps1/README.md) · [Detail](Invoke-LineageRun.ps1/documentation.md) |
| `LauncherArguments.psm1` | Reads the arguments given to the desktop `.cmd` launcher. | [README](LauncherArguments.psm1/README.md) · [Detail](LauncherArguments.psm1/documentation.md) |
| `Get-PbiReportLineage.ps1` | Main script: signs in, collects reports, semantic models, tables and sources, and writes the JSON and CSV. | [README](Get-PbiReportLineage.ps1/README.md) · [Detail](Get-PbiReportLineage.ps1/documentation.md) |
| `Prerequisites.psm1` | Finds the PowerShell modules the tool needs, and installs a missing one. | [README](Prerequisites.psm1/README.md) · [Detail](Prerequisites.psm1/documentation.md) |
| `PowerBIRest.psm1` | Calls the Power BI REST API, including the admin scanner APIs. | [README](PowerBIRest.psm1/README.md) · [Detail](PowerBIRest.psm1/documentation.md) |
| `MQueryLineage.psm1` | Reads Power Query (M) code to find the server, database, schema and table behind each model table. | [README](MQueryLineage.psm1/README.md) · [Detail](MQueryLineage.psm1/documentation.md) |
| `RunProgress.psm1` | Shows the numbered steps and progress of a run. | [README](RunProgress.psm1/README.md) · [Detail](RunProgress.psm1/documentation.md) |
| `Export-PbiLineageWorkbook.ps1` | Builds the Excel workbook from the JSON. (The CSV is written by `Get-PbiReportLineage.ps1`.) | [README](Export-PbiLineageWorkbook.ps1/README.md) · [Detail](Export-PbiLineageWorkbook.ps1/documentation.md) |

## How the files fit together

```
PowerBI-Lineage.cmd ──► LauncherArguments.psm1 ──┐
                                                  ├──► Get-PbiReportLineage.ps1 ──► Export-PbiLineageWorkbook.ps1
Orchestrator script ──► Invoke-LineageRun.ps1 ───┘         │
(V1, V2, .ois_export)                                      ├── Prerequisites.psm1
                                                           ├── PowerBIRest.psm1
                                                           ├── MQueryLineage.psm1
                                                           └── RunProgress.psm1
```
