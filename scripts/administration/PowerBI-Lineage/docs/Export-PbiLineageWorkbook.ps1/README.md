# Export-PbiLineageWorkbook.ps1

A script that builds the Excel lineage workbook from the `report-lineage.json` file written by `Get-PbiReportLineage.ps1`. It needs only the JSON, so a workbook can be rebuilt later without calling Power BI.

| | |
|---|---|
| Type | Script |
| Used by | `Get-PbiReportLineage.ps1` (unless `-SkipExcel` or a `.csv` `-ExcelPath` is given), or run directly |
| Uses | `Prerequisites.psm1` (`Initialize-RequiredModule`); PowerShell module `ImportExcel` (installed for the current user if missing); .NET `System.Drawing` and `System.Data` |
| Runs in | Windows PowerShell 5.1 or PowerShell 7 (`#Requires -Version 5.1`) |
| Reads | The JSON file given in `-JsonPath` (UTF-8, `schemaVersion` 1) |
| Writes | The `.xlsx` file given in `-ExcelPath`, creating its folder if needed |

## Use

```powershell
./Export-PbiLineageWorkbook.ps1 -JsonPath ./output/report-lineage-20260916-090000/report-lineage.json `
    -ExcelPath 'C:\Reports\PowerBI-Lineage.xlsx' -Force
```

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `-JsonPath` | Yes | None | `report-lineage.json` from a `Get-PbiReportLineage.ps1` run. |
| `-ExcelPath` | Yes | None | Path of the `.xlsx` file to create. |
| `-Force` | No | Off | Replace the workbook if it already exists. Without it, an existing file stops the script. |

## Outputs

Writes one workbook with these sheets, in this order:

| Sheet | Contents |
|---|---|
| `Summary` | Run details, totals and links to every sheet |
| `All Lineage` | Every report, semantic model, table and the source it reads from |
| `Source Objects` | Each database object and the reports that depend on it |
| `Issues` | Anything that could not be read during the run |
| One per workspace | The `All Lineage` rows of the reports in that workspace |

Values longer than 32,767 characters are cut in the workbook and marked; the JSON keeps the full text. See [Workbook layout](documentation.md#workbook-layout) for every column.

Returns one object:

| Property | Description |
|---|---|
| `Path` | Full path of the workbook. |
| `Sheets` | The four standard sheets, each with `Name` and `Description`. |
| `WorkspaceSheets` | Names of the workspace sheets, in workbook order. |
| `TruncatedCells` | Number of cell values that were cut. |

The script does not write the CSV; `Get-PbiReportLineage.ps1` does.

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../README.md)
- [Get-PbiReportLineage.ps1](../Get-PbiReportLineage.ps1/README.md)
- [Prerequisites.psm1](../Prerequisites.psm1/README.md)
