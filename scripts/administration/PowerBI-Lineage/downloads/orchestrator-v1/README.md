# PowerBI-Lineage.Orchestrator.ps1

A PowerShell script to paste into one System Center Orchestrator **Run .NET Script** activity. It carries the whole
lineage tool as compressed text, unpacks it on the runbook server, and runs it in 64-bit Windows PowerShell as a
service principal.

| | |
|---|---|
| **Type** | Download: [`PowerBI-Lineage.Orchestrator.ps1`](PowerBI-Lineage.Orchestrator.ps1) (about 57 KB, plain ASCII, no backticks, no byte order mark) |
| **Runs in** | A Run .NET Script activity, Type **PowerShell**, in Orchestrator 2019, 2022 or 2025 |
| **Contains** | Nine settings, checks, and the 8 files of the tool as gzip-compressed base64 |
| **Reads** | Its settings, or `LINEAGE_*` and `PBI_CLIENT_SECRET` environment variables for settings left empty or as placeholders |
| **Writes** | The tool to `%ProgramData%\PowerBI-Lineage\<version>`, and the workbook or CSV, JSON and run log to the `$ExcelPath` location |

## Use

1. In Runbook Designer, drag a new **Run .NET Script** activity from **Activities > System** onto a runbook.
2. On **Details**, set **Type** to **PowerShell**.
3. Paste the whole file into **Script**.
4. Replace each `Required-...` placeholder. Subscribe `$ClientSecret` to an encrypted variable rather than typing it.
5. Check the runbook in and run it.

```powershell
$TenantId = 'contoso.onmicrosoft.com'
$AppId = '00000000-0000-0000-0000-000000000000'
$ClientSecret = 'Required-ClientSecret-or-CertificateThumbprint'   # subscribe to an encrypted variable
$ExcelPath = '\\fileserver\bi'
```

## Inputs

Each setting is a line `$Name = '...'` at the top. A setting left empty, or still starting with `Required-`, is read
from its environment variable.

| Name | Required | Default | Description |
|---|---|---|---|
| `$TenantId` (`LINEAGE_TENANT_ID`) | Yes | | Tenant ID or domain. Letters, digits, `.` and `-`. |
| `$AppId` (`LINEAGE_CLIENT_ID`) | Yes | | Application (client) ID. Must be a GUID. |
| `$ClientSecret` (`PBI_CLIENT_SECRET`) | This or `$CertificateThumbprint` | | Client secret. |
| `$ExcelPath` (`LINEAGE_EXCEL_PATH`) | Yes | | A folder (writes `PowerBI-Lineage_DDMMYYHHMM.xlsx`), a `.xlsx` file, or a `.csv` file (CSV only). |
| `$OutputFormat` (`LINEAGE_OUTPUT_FORMAT`) | No | `Excel` | `Excel` (workbook and CSV) or `CSV` (CSV only). |
| `$Mode` (`LINEAGE_MODE`) | No | `Admin` | `Admin` (whole tenant) or `User` (workspaces the app belongs to). `Auto` is also accepted. |
| `$WorkspaceIds` (`LINEAGE_WORKSPACE_IDS`) | No | All workspaces | Comma-separated workspace IDs. Spaces are removed. |
| `$CertificateThumbprint` (`LINEAGE_CERTIFICATE_THUMBPRINT`) | This or `$ClientSecret` | | 40 hex characters. Spaces are removed. |
| `$TimeoutMinutes` (`LINEAGE_TIMEOUT_MINUTES`) | No | `180` | Stop the run after this many minutes. 1 to 4 digits. |

## Outputs

| Output | Location |
|---|---|
| Workbook | `$ExcelPath` (`.xlsx`), unless CSV only |
| CSV | Same name as the workbook, `.csv` |
| Run log | Same name as the workbook, `.log` |
| JSON | `report-lineage-yyyyMMdd-HHmmss\report-lineage.json` in the same folder |
| Tool files | `%ProgramData%\PowerBI-Lineage\<version>\` |

The activity succeeds when the run succeeds; its output is the run summary. It fails with
`Power BI lineage run failed: <reason> Log: <log path>` or, after a timeout,
`Power BI lineage run did not finish within <n> minutes and was stopped. Log: <log path>`.

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../../docs/README.md)
- [Tool overview](../../README.md)
- [V2 README](../orchestrator-v2/README.md): the same script with the tool as plain text, for review
- [Runbook import](../runbook-import/README.md): the same script in an importable runbook
- [Get-PbiReportLineage.ps1](../../docs/Get-PbiReportLineage.ps1/README.md)
- [Invoke-LineageRun.ps1](../../docs/Invoke-LineageRun.ps1/README.md)
