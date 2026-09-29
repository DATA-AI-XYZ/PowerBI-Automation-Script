# Export-PbiLineageWorkbook.ps1: detailed documentation

## Flow

1. Sets `$ErrorActionPreference = 'Stop'`.
2. Imports `modules/Prerequisites.psm1` and calls `Initialize-RequiredModule -Name ImportExcel -InformationAction Continue`, then loads the `System.Drawing` assembly.
3. Throws if `-JsonPath` does not exist.
4. If `-ExcelPath` exists: throws without `-Force`, otherwise deletes it.
5. Creates the folder of `-ExcelPath` if it is missing.
6. Reads the JSON as UTF-8 and parses it with `ConvertFrom-Json` (with `-Depth 100` in PowerShell 7). Throws unless `schemaVersion` is `1`.
7. Builds three data tables with `ConvertTo-DataTable`: `lineage`, `sourceObjects` and `issues`. Null entries are dropped first.
8. Reserves the four standard sheet names, groups the lineage rows by `WorkspaceId`, sorts the groups by name then ID, and names each workspace sheet with `Get-SheetName`.
9. Creates the package with `Open-ExcelPackage -Create`, then adds `Summary` (`Add-SummarySheet`), `All Lineage`, `Source Objects` and `Issues` (`Add-DataSheet`).
10. For each workspace, filters the `All Lineage` table with a `DataView` on `WorkspaceId` and adds the result with `Add-DataSheet`, showing `Write-Progress` ("Building workspace sheets").
11. On any error, closes the package with `Close-ExcelPackage -NoSave` and rethrows. Otherwise saves it with `Close-ExcelPackage`.
12. Writes a verbose message and returns the result object (`Path`, `Sheets`, `WorkspaceSheets`, `TruncatedCells`).

## Functions

All functions are defined in the script and are not exported.

### ConvertTo-CellText

Turns a value into the text written to a cell, and cuts text over the Excel cell limit.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Value` | any | No | The value to convert. |

**Returns:** a string. A string is kept as it is. A `DateTime` is written as `yyyy-MM-ddTHH:mm:ss.FFFFFFFK`, so ISO dates that `ConvertFrom-Json` turned into dates return to their original text. Other value types are cast to `[string]`. Anything else (arrays, objects, `$null`) is written as compressed JSON (`-Depth 10`). Text longer than 32,767 characters is cut so that, with the marker ` ...[truncated in Excel; full text in the JSON]` appended, it is exactly 32,767 characters, and `$script:TruncatedCells` is increased by one.

**Calls:** `ConvertTo-Json`.

**Errors:** none raised.

### ConvertTo-DataTable

Builds a `System.Data.DataTable` from rows of objects.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Rows` | `object[]` | No | The rows. |
| `DefaultColumns` | `string[]` | No | Column names used when `Rows` is empty. |
| `TableName` | `string` | No | Name of the data table. |

**Returns:** the data table, as a single object. Columns are the property names of the first row, or `DefaultColumns` when there are no rows. Columns listed in `$script:ColumnTypes` get that type; all others are `string`. `$null` values are left empty. String-typed columns are filled through `ConvertTo-CellText`. Typed columns get the value as it is, except that an empty string is left empty.

**Calls:** `ConvertTo-CellText`.

**Errors:** none raised; a value that cannot be stored in a typed column throws from `System.Data`.

### Get-SheetName

Makes a valid, unique Excel sheet name from a workspace name.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | `string` | No | The workspace name. |
| `Used` | `HashSet[string]` | No | Names already taken. The new name is added to it. |

**Returns:** the sheet name. Rules, in order:

1. Each of `[ ] : * ? / \` becomes `-`.
2. Spaces and single quotes are trimmed from both ends.
3. An empty result becomes `Workspace`.
4. The name is cut to 31 characters.
5. If the name is already in `Used` (the set in the script ignores case) or equals `History`, a suffix ` (2)`, ` (3)` and so on is added, shortening the name so the total stays at 31 characters.

Example: `Finance: Actuals [2026] / Budget and Forecast Reporting` becomes `Finance- Actuals -2026- - Budge`.

**Calls:** none.

**Errors:** none raised.

### Add-DataSheet

Adds a worksheet and loads a data table into it.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Package` | ExcelPackage | No | The open package. |
| `SheetName` | `string` | No | Name of the new sheet. |
| `Table` | `System.Data.DataTable` | No | The data to write. |

**Returns:** the worksheet (callers discard it).

Behaviour:

- With rows: loads the table at `A1` with headers as an Excel table in style `Medium2`.
- Without rows: loads the headers only and makes row 1 bold.
- Column widths come from `$script:ColumnWidths`; otherwise 38 for a name ending in `Id`, otherwise 18.
- Freezes the header row (`FreezePanes(2, 1)`).

**Calls:** EPPlus `Worksheets.Add`, `LoadFromDataTable`.

**Errors:** none raised.

### Set-SheetLink

Turns a cell into a link to another sheet.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Cell` | Excel range | No | The cell to change. |
| `SheetName` | `string` | No | The target sheet. |

**Returns:** nothing. Sets a hyperlink to `'<sheet>'!A1` (single quotes in the name doubled), writes the sheet name as the cell value, and styles it underlined in RGB (5, 99, 193).

**Calls:** `OfficeOpenXml.ExcelHyperLink`, `System.Drawing.Color`.

**Errors:** none raised.

### Add-SummarySheet

Writes the `Summary` sheet.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Package` | ExcelPackage | No | The open package. |
| `Document` | object | No | The parsed JSON document. |
| `WorkspaceSheets` | `object[]` | No | Workspace entries with `Name`, `Sheet`, `Reports`, `Models`, `Rows`, `Traced`. |

**Returns:** nothing. Layout is in [Workbook layout](#workbook-layout).

**Calls:** `ConvertTo-CellText`, `Set-SheetLink`, `Resolve-Path` (on the script's `$JsonPath`).

**Errors:** none raised.

## Workbook layout

Sheet order: `Summary`, `All Lineage`, `Source Objects`, `Issues`, then one sheet per workspace, sorted by workspace name and then ID.

### Summary

| Row | Column A | Column B |
|---|---|---|
| 1 | `Power BI report lineage` (bold, size 14) | |
| 3 | `Generated (UTC)` | `generatedAtUtc`, through `ConvertTo-CellText` |
| 4 | `Collection mode` | `collectionMode` |
| 5 | `Signed in as` | `signedInAs` |
| 6 | `Workspace scope` | `workspaceScope`; a list is joined with `, ` |
| 7 | `Workspaces with reports` | `summary.workspaces` |
| 8 | `Reports` | `summary.reports` |
| 9 | `Semantic models` | `summary.semanticModels` |
| 10 | `Lineage rows` | `summary.lineageRows` |
| 11 | `Traced to a source object` | `summary.tracedToObject` |
| 12 | `Traced to a connection only` | `summary.connectionOnly` |
| 13 | `No external source` | `summary.noExternalSource` |
| 14 | `Issues` | Count of non-null entries in `issues` |
| 15 | `Source JSON` | Full path of `-JsonPath` |
| 16 | `Truncated cells` | Only when values were cut: `<n> value(s) exceeded Excel's 32,767-character cell limit and are cut here; the JSON has the full text.` |

Column A labels are bold. After one empty row come two blocks, separated by one empty row:

1. Sheet list: header `Sheet` | `Contents` (bold), then one row per standard sheet. Column A links to the sheet; column B holds its description from `$script:SheetCatalog`.
2. Workspace list: header `Workspace` | `Sheet` | `Reports` | `Semantic models` | `Lineage rows` | `Traced to a source object` (bold), then one row per workspace sheet. `Sheet` links to that sheet. The header is written even when there are no workspaces.

Workspace list values, per `WorkspaceId` group of lineage rows:

| Column | Value |
|---|---|
| `Workspace` | First non-empty `WorkspaceName` in the group, otherwise the `WorkspaceId` |
| `Sheet` | Name from `Get-SheetName` |
| `Reports` | Distinct `ReportId` values |
| `Semantic models` | Distinct non-empty `DatasetId` values |
| `Lineage rows` | Rows in the group |
| `Traced to a source object` | Rows with a non-empty `SourceObject` |

Column widths: A 30, B 34, C to F 18.

### All Lineage and workspace sheets

Row 1 holds the headers; data starts at row 2. Columns are the properties of the first lineage row in the JSON. When there are no rows, the columns below are used. Workspace sheets have the same columns, holding only the rows whose `WorkspaceId` matches.

| Column | Type | Width |
|---|---|---|
| `WorkspaceName` | text | 24 |
| `WorkspaceId` | text | 38 |
| `ReportName` | text | 30 |
| `ReportId` | text | 38 |
| `ReportType` | text | 18 |
| `DatasetName` | text | 28 |
| `DatasetId` | text | 38 |
| `DatasetWorkspaceName` | text | 24 |
| `DatasetWorkspaceId` | text | 38 |
| `DatasetStorageMode` | text | 18 |
| `TableName` | text | 26 |
| `TableIsHidden` | Boolean | 18 |
| `TableStorageMode` | text | 18 |
| `SourceType` | text | 22 |
| `Connector` | text | 20 |
| `Server` | text | 34 |
| `Database` | text | 24 |
| `Schema` | text | 14 |
| `SourceObject` | text | 30 |
| `SourceObjectKind` | text | 18 |
| `ObjectOrigin` | text | 18 |
| `Location` | text | 40 |
| `ConnectorOptions` | text | 18 |
| `NativeQuery` | text | 50 |
| `DatasourceType` | text | 18 |
| `GatewayId` | text | 38 |
| `GatewayName` | text | 24 |
| `GatewayDatasourceId` | text | 38 |
| `GatewayDatasourceName` | text | 24 |
| `ConnectionDetails` | text | 40 |
| `IsSnowflakeConnection` | text | 22 |
| `Notes` | text | 60 |
| `SourceExpression` | text | 60 |

### Source Objects

One row per entry in the JSON `sourceObjects` array.

| Column | Type | Width |
|---|---|---|
| `SourceType` | text | 22 |
| `Server` | text | 34 |
| `Database` | text | 24 |
| `Schema` | text | 14 |
| `SourceObject` | text | 30 |
| `Location` | text | 40 |
| `Gateways` | text | 24 |
| `ReportCount` | integer | 18 |
| `ModelCount` | integer | 18 |
| `Reports` | text | 60 |
| `ModelTables` | text | 60 |

### Issues

One row per entry in the JSON `issues` array.

| Column | Type | Width |
|---|---|---|
| `Area` | text | 18 |
| `Item` | text | 36 |
| `Message` | text | 100 |

### Formatting of data sheets

- A sheet with rows is an Excel table in style `Medium2`; a sheet without rows has a bold header row only.
- The header row is frozen.
- Text columns are written as text, so a value starting with `=` is not a formula and `0012` keeps its leading zeros.

### CSV

This script does not write a CSV. `Get-PbiReportLineage.ps1` writes it before calling this script:

| Item | Value |
|---|---|
| Path | `-ExcelPath` with the extension changed to `.csv`; without `-ExcelPath`, `report-lineage.csv` in the run folder |
| Rows | The lineage rows, the same as `All Lineage`, not truncated |
| Columns | The lineage row properties, in the order above |
| Format | `Export-Csv -NoTypeInformation`, UTF-8 with a byte order mark (`utf8BOM` in PowerShell 6 and later, `UTF8` in 5.1) |
| No rows | One object with no properties is exported instead |

## Script state

| Name | Value | Use |
|---|---|---|
| `$script:SheetCatalog` | `Summary`, `All Lineage`, `Source Objects`, `Issues`, each with a `Description` | Sheet order, the Summary sheet list, reserved names, the returned `Sheets` |
| `$script:MaxCellLength` | `32767` | Excel cell limit |
| `$script:TruncationMarker` | ` ...[truncated in Excel; full text in the JSON]` | Appended to cut values |
| `$script:TruncatedCells` | `0` at start | Count of cut values |
| `$script:ColumnTypes` | `TableIsHidden` = `[bool]`, `ReportCount` = `[int]`, `ModelCount` = `[int]` | Non-text columns |
| `$script:ColumnWidths` | Width per column name | `Add-DataSheet` |
| `$script:DefaultLineageColumns` | 33 lineage column names | Headers when there are no lineage rows |
| `$script:DefaultSourceObjectColumns` | 11 source object column names | Headers when there are no source objects |
| `$script:DefaultIssueColumns` | `Area`, `Item`, `Message` | Headers when there are no issues |

## Error handling

`$ErrorActionPreference` is `Stop`, so any failure ends the script. It throws these messages itself:

| Condition | Message |
|---|---|
| JSON file missing | `JSON file not found: <JsonPath>` |
| Workbook exists, no `-Force` | `<ExcelPath> already exists. Use -Force to replace it.` |
| Wrong schema | `Unsupported lineage JSON schemaVersion '<value>'.` |

If `ImportExcel` is missing and cannot be installed, the error from `Initialize-RequiredModule` stops the script. An error while the workbook is built closes the package without saving and is rethrown.

## Limits and notes

- With `-Force`, the existing workbook is deleted before the JSON is read and checked. An unsupported `schemaVersion` or a build error then leaves no workbook.
- Columns come from the first row of each array. Properties that only later rows have are not written.
- Cell values are cut at 32,767 characters. The JSON and the CSV keep the full text.
- Workspace sheets are built from the already converted `All Lineage` table, so a cut value is counted once in `TruncatedCells`.
- A sheet cannot be named `History`; a workspace with that name gets `History (2)`.
- The Summary `Issues` count comes from the `issues` array, not from `summary.issues`. `summary.tables` is not shown.
- When `generatedAtUtc` is missing, `ConvertTo-CellText` receives `$null` and writes the JSON text `null`.
- `Add-SummarySheet` reads `$JsonPath` from the script scope, and uses `Resolve-Path` without `-LiteralPath`.
