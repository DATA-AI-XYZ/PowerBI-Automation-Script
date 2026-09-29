# PowerBI-Lineage.cmd

A single Windows file that runs the Power BI report lineage tool. Double-click it to answer questions, or run it
with arguments for an unattended job. `PowerBI-Lineage.zip` holds the same file, for email systems that block
`.cmd` attachments.

| | |
|---|---|
| **Type** | Download: [`PowerBI-Lineage.cmd`](PowerBI-Lineage.cmd) (about 132 KB, plain ASCII) and [`PowerBI-Lineage.zip`](PowerBI-Lineage.zip) (the `.cmd` only) |
| **Runs in** | `cmd.exe`, which starts PowerShell 7 (`pwsh`) if installed, otherwise Windows PowerShell |
| **Used by** | People at their desktop; schedulers that run a command, such as Task Scheduler or SQL Server Agent |
| **Contains** | A batch launcher, a PowerShell loader, and the 7 files of `src/` as plain text |
| **Reads** | Its own text, its arguments, `PBI_CLIENT_SECRET`, `LOCALAPPDATA`, and Power BI REST API metadata |
| **Writes** | The unpacked scripts to `%LOCALAPPDATA%\PowerBI-Lineage\<version>`, and the JSON, CSV and workbook of each run |

## Use

Desktop:

1. Double-click `PowerBI-Lineage.cmd` (or the copy inside the `.zip`).
2. Answer the three questions: how to sign in, which reports, where to save the workbook.
3. When it ends, choose whether to open the workbook, then press a key to close the window.

Unattended: run it with arguments. It asks nothing, does not pause, and signs in as a service principal.

```bat
set PBI_CLIENT_SECRET=<secret>
PowerBI-Lineage.cmd -Mode Admin -TenantId contoso.onmicrosoft.com -ClientId <app-id> -ExcelPath "\\fileserver\bi"
```

`PowerBI-Lineage.cmd /?` prints the list of arguments.

## Inputs

Arguments apply to unattended runs only. They are read as literal values; an expression is refused, not run.

| Name | Required | Default | Description |
|---|---|---|---|
| `-Mode` | No | `Auto` | `Admin` (whole tenant), `User` (workspaces the identity belongs to) or `Auto` (Admin if the caller is a tenant admin, otherwise User). |
| `-TenantId` | Yes, with `-ClientId` | | Tenant ID or domain. |
| `-ClientId` | Yes, unless `-ConfigPath` | | Service principal application (client) ID. |
| `-CertificateThumbprint` | One of this, `PBI_CLIENT_SECRET` or `-ConfigPath` | | Certificate in the CurrentUser or LocalMachine personal store. |
| `PBI_CLIENT_SECRET` (environment variable) | One of this, `-CertificateThumbprint` or `-ConfigPath` | | Client secret. `-ClientSecret` on the command line is refused. |
| `-ConfigPath` | No | | `config.json` with `tenantId` and `servicePrincipal` settings. |
| `-ExcelPath` | No | `report-lineage.xlsx` in the run's JSON folder | A folder (writes `PowerBI-Lineage_DDMMYYHHMM.xlsx`), a `.xlsx` file, or a `.csv` file (CSV only). |
| `-OutputPath` | No | The `-ExcelPath` folder, otherwise `Documents\Power BI Lineage` | Folder for the JSON run folder. |
| `-WorkspaceId` | No | All workspaces | Comma-separated workspace IDs. |
| `-SkipExcel` | No | Off | JSON and CSV only. |
| `-IncludePersonalWorkspaces`, `-IncludeAutoDateTables`, `-SkipGatewayLookup`, `-SaveRawResponses`, `-Verbose` | No | Off | Switches passed to `Get-PbiReportLineage.ps1`. |
| `-ScanBatchSize` | No | `100` | Workspaces per admin scan request, 1 to 100. |
| `LOCALAPPDATA` (environment variable) | No | The account's local application data folder, then `%TEMP%\LocalAppData` | Where the scripts are unpacked. |

## Outputs

| Output | Location |
|---|---|
| Unpacked scripts | `%LOCALAPPDATA%\PowerBI-Lineage\<version>\src\...`, with a `.complete` marker |
| JSON | `report-lineage-yyyyMMdd-HHmmss\report-lineage.json` under the output folder |
| CSV | Named after the workbook, next to it |
| Workbook | `-ExcelPath`, unless `-SkipExcel` or a `.csv` path |

| Exit code | Meaning |
|---|---|
| `0` | Unattended run finished, or help was printed. |
| `1` | The run failed. Unattended runs write `ERROR: <message>` to standard error. |

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../../docs/README.md)
- [Tool overview](../../README.md)
- [Get-PbiReportLineage.ps1](../../docs/Get-PbiReportLineage.ps1/README.md), the script the launcher runs
- [LauncherArguments.psm1](../../docs/LauncherArguments.psm1/README.md), how arguments are read
- [Orchestrator script (V1)](../orchestrator-v1/README.md), for System Center Orchestrator
