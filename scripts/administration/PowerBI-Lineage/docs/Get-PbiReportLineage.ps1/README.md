# Get-PbiReportLineage.ps1

The main script of the tool. It traces every Power BI report the caller can reach to its semantic model, the model's tables, the source server, database, schema and table or view behind each table, and the gateway. It writes the result as JSON, CSV and (optionally) an Excel workbook.

| | |
|---|---|
| Type | Script |
| Used by | `PowerBI-Lineage.cmd` (desktop and unattended runs), `Invoke-LineageRun.ps1` (Orchestrator runs), or run directly |
| Uses | `Prerequisites.psm1`, `PowerBIRest.psm1`, `MQueryLineage.psm1`, `RunProgress.psm1`; `Export-PbiLineageWorkbook.ps1`; PowerShell modules `MicrosoftPowerBIMgmt.Profile` and `ImportExcel` (installed for the current user if missing) |
| Runs in | Windows PowerShell 5.1 or PowerShell 7 |
| Reads | Power BI REST API (read-only calls, plus `POST` for the admin scanner and `executeQueries`); `-ConfigPath` file; `PBI_CLIENT_SECRET` or the environment variable named in the config |
| Writes | A `report-lineage-<yyyyMMdd-HHmmss>` run folder with `report-lineage.json` (and `raw/` with `-SaveRawResponses`); a CSV; an `.xlsx` workbook unless skipped |

## Use

```powershell
./Get-PbiReportLineage.ps1 -Mode Admin -TenantId <tenant> -ClientId <app-id> `
    -CertificateThumbprint <thumbprint> -ExcelPath '\\share\bi\PowerBI-Lineage.xlsx'
```

With no sign-in parameters it reuses the current Power BI session or opens a browser sign-in. `-Interactive` asks the questions instead (used by `PowerBI-Lineage.cmd` when double-clicked).

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `-Mode` | No | `Auto` | `Auto`, `Admin` or `User`. `Auto` uses Admin when a test call to `admin/groups` succeeds, and User when it returns 401 or 403. |
| `-WorkspaceId` | No | All accessible workspaces | Limit the run to these workspace IDs. |
| `-OutputPath` | No | `output` folder next to `src` | Folder for the timestamped run folder holding the JSON. |
| `-ExcelPath` | No | `report-lineage.xlsx` in the run folder | A folder (writes `PowerBI-Lineage_<ddMMyyHHmm>.xlsx`), a `.xlsx` file (replaced each run) or a `.csv` file (CSV only, no workbook). Any other file extension is rejected. |
| `-SkipExcel` | No | Off | Write JSON and CSV only; `ImportExcel` is not loaded. |
| `-TenantId` | With `-ClientId` | None | Tenant ID or domain. |
| `-ClientId` | No | None | Service principal application ID. Selects service principal sign-in. |
| `-ClientSecret` | No | None | Client secret as a `SecureString`. |
| `-CertificateThumbprint` | No | None | Certificate thumbprint for the service principal. |
| `-ConfigPath` | No | None | `config.json` describing a service principal; used only when `-ClientId` is not given. |
| `-IncludePersonalWorkspaces` | No | Off | Admin: include personal workspaces in the scan. User: include the caller's My workspace (ignored for a service principal). |
| `-IncludeAutoDateTables` | No | Off | Keep `LocalDateTable_*` and `DateTableTemplate_*` tables in the lineage rows. |
| `-SkipGatewayLookup` | No | Off | Do not call the gateway APIs to resolve names. |
| `-SaveRawResponses` | No | Off | Save raw scanner results (Admin) or INFO query results (User) to `raw/`. |
| `-ScanBatchSize` | No | `100` | Workspaces per admin scan request, 1-100. |
| `-PassThru` | No | Off | Also return the lineage rows to the pipeline. |
| `-Interactive` | No | Off | Ask for sign-in, scope and save location. Cannot be combined with `-Unattended`. |
| `-Unattended` | No | Off | Never prompt; refuse browser sign-in. Without `-OutputPath`, the JSON goes next to `-ExcelPath`, or to `Documents\Power BI Lineage`. |
| `PBI_CLIENT_SECRET` | No | None | Environment variable used as the secret when `-ClientId` is given without `-ClientSecret` or `-CertificateThumbprint`. |

## Outputs

| Output | Where |
|---|---|
| `report-lineage.json` | `<OutputPath>\report-lineage-<yyyyMMdd-HHmmss>\`. Complete, untruncated record of the run (`schemaVersion` 1). Written first. |
| CSV | Same name and folder as the workbook, with a `.csv` extension. UTF-8 with a byte order mark. One line per lineage row. |
| Excel workbook | `-ExcelPath`, built by `Export-PbiLineageWorkbook.ps1`. Not written with `-SkipExcel` or a `.csv` `-ExcelPath`. |
| `raw\scan-<n>.json` or `raw\dataset-<id>.json` | Only with `-SaveRawResponses`. |
| Pipeline | The lineage rows, only with `-PassThru`. |

A console summary lists step results, totals, the number of issues and the output paths. The script sets no exit code; a failure is a terminating error. `Invoke-LineageRun.ps1` and `PowerBI-Lineage.cmd` turn that into exit code `1`.

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../README.md)
- [Export-PbiLineageWorkbook.ps1](../Export-PbiLineageWorkbook.ps1/README.md)
- [MQueryLineage.psm1](../MQueryLineage.psm1/README.md)
- [PowerBIRest.psm1](../PowerBIRest.psm1/README.md)
- [Prerequisites.psm1](../Prerequisites.psm1/README.md)
- [RunProgress.psm1](../RunProgress.psm1/README.md)
- [Invoke-LineageRun.ps1](../Invoke-LineageRun.ps1/README.md)
- [LauncherArguments.psm1](../LauncherArguments.psm1/README.md)
