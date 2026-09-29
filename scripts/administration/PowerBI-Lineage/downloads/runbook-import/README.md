# PowerBI-Lineage.ois_export

A System Center Orchestrator runbook to import with Runbook Designer. It holds the V1 Orchestrator script in a
Run .NET Script activity, with each setting subscribed to an **Initialize Data** parameter, so the settings are
entered when the runbook starts.

| | |
|---|---|
| **Type** | Download: [`PowerBI-Lineage.ois_export`](PowerBI-Lineage.ois_export) (about 73 KB, Runbook Designer export XML) |
| **Used by** | Runbook Designer, **Import** |
| **Runs in** | Orchestrator, as the runbook `Power BI Report Lineage` in the folder `Power BI` |
| **Contains** | One folder, one runbook, and three objects: `Initialize Data` -> `Link` -> `Run Power BI Lineage` |
| **Reads** | Nine Initialize Data parameters; the script then reads Power BI REST API metadata |
| **Writes** | As the [V1 script](../orchestrator-v1/README.md): the tool under `%ProgramData%\PowerBI-Lineage`, and the output, JSON and run log at `Excel path` |

This file was generated to match the Runbook Designer export format. It has **not** been import-tested on an
Orchestrator server.

## Use

1. In Runbook Designer, right-click a folder and choose **Import**, then select the file.
2. Clear **Import Orchestrator encrypted data** (the file contains none).
3. Open the **Power BI** folder and run **Power BI Report Lineage**, entering the parameters.

If the import fails, or the activity fails with "Error initializing extension", delete the imported runbook and paste
the [V1 script](../orchestrator-v1/README.md) into a new Run .NET Script activity instead.

## Inputs

Initialize Data parameters, all of type `String`. Each is subscribed to the script setting shown. An empty value
falls back to the setting's environment variable, as in V1.

| Name | Required | Default | Description |
|---|---|---|---|
| `Tenant ID` | Yes | | `$TenantId`: tenant ID or domain. |
| `App ID` | Yes | | `$AppId`: application (client) ID, a GUID. |
| `Client secret` | This or `Certificate thumbprint` | | `$ClientSecret`. |
| `Excel path` | Yes | | `$ExcelPath`: a folder, a `.xlsx` file or a `.csv` file. |
| `Output format` | No | `Excel` | `$OutputFormat`: `Excel` or `CSV`. |
| `Mode` | No | `Admin` | `$Mode`: `Admin` or `User` (`Auto` is also accepted). |
| `Workspace IDs` | No | All workspaces | `$WorkspaceIds`: comma-separated workspace IDs. |
| `Certificate thumbprint` | This or `Client secret` | | `$CertificateThumbprint`: 40 hex characters, certificate in `LocalMachine\My`. |
| `Timeout minutes` | No | `180` | `$TimeoutMinutes`. |

`Client secret` is a plain parameter. For production, edit the activity and subscribe `$ClientSecret` to an
encrypted variable instead.

## Outputs

The same as the [V1 script](../orchestrator-v1/README.md#outputs): the workbook or CSV, a `.log` and a `.csv` named
after it, and a `report-lineage-<date>` folder with the JSON. The activity fails with the tool's message when the run
fails.

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../../docs/README.md)
- [Tool overview](../../README.md)
- [V1 script](../orchestrator-v1/README.md) and its [detailed documentation](../orchestrator-v1/documentation.md)
- [V2 script](../orchestrator-v2/README.md), the same script as plain text
- [Invoke-LineageRun.ps1](../../docs/Invoke-LineageRun.ps1/README.md)
