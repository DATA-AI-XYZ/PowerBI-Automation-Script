# MQueryLineage.psm1

A PowerShell module that reads a Power Query (M) expression and returns the upstream server, database, schema and table or view that a Power BI model table reads from. It analyses the text only; it never runs the query or connects to a source.

| | |
|---|---|
| Type | module |
| Used by | `Get-PbiReportLineage.ps1` (function `Get-TableSource`); bundled into the runbook by `build/New-OrchestratorRunbook.ps1` |
| Uses | Nothing outside the module |
| Runs in | PowerShell 5.1 or later (`#Requires -Version 5.1`), in the caller's session |
| Reads | The M or SQL text passed in, and the model's shared expressions dictionary |
| Writes | Nothing. It returns objects to the pipeline |

## Use

```powershell
Import-Module .\src\modules\MQueryLineage.psm1
Get-MQuerySource -Expression 'let Source = Sql.Database("sql01", "DW"), T = Source{[Schema="dbo",Item="Sales"]}[Data] in T'
```

The module exports three functions: `Get-MQuerySource`, `Get-NativeQuerySource` and `Get-SqlReferencedObject`.

## Inputs

`Get-MQuerySource`

| Name | Required | Default | Description |
|---|---|---|---|
| `Expression` | Yes | | M expression of a partition, refresh policy or shared query. Accepts pipeline input. Empty or white space returns nothing. |
| `SharedExpression` | No | `@{}` | Model's shared expressions (queries and parameters) as name to M text. Pass the same dictionary instance for every table of a model so parsing is reused. |

`Get-NativeQuerySource`

| Name | Required | Default | Description |
|---|---|---|---|
| `Query` | Yes | | SQL text, for example a legacy query partition. |
| `SourceType` | No | `''` | Source type to report. |
| `Connector` | No | `''` | Connector name to report. |
| `Server` | No | `''` | Server of the bound connection. |
| `Database` | No | `''` | Database of the bound connection. |

`Get-SqlReferencedObject`

| Name | Required | Default | Description |
|---|---|---|---|
| `Query` | Yes | | SQL text. Accepts pipeline input. Empty string allowed. |

## Outputs

`Get-MQuerySource` and `Get-NativeQuerySource` return one object per distinct source with these properties: `SourceType`, `Connector`, `Server`, `Database`, `Schema`, `Object`, `ObjectKind`, `ObjectOrigin`, `Location`, `Options`, `NativeQuery`.

Example for `Sql.Database("sql01.contoso.com", "SalesDW")` navigated to `[Schema="dbo",Item="FactSales"]`:

| Property | Value |
|---|---|
| `SourceType` | `SQL Server` |
| `Server` | `sql01.contoso.com` |
| `Database` | `SalesDW` |
| `Schema` | `dbo` |
| `Object` | `FactSales` |
| `ObjectOrigin` | `Navigation` |

A parameter that cannot be resolved appears as `{ParameterName}`, for example `{ServerName}`.

`Get-SqlReferencedObject` returns one object per table, view or procedure named after `FROM`, `JOIN` or `EXEC`, with `Server`, `Database`, `Schema` and `Object`.

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../README.md)
- [Get-PbiReportLineage.ps1](../Get-PbiReportLineage.ps1/README.md)
- [Export-PbiLineageWorkbook.ps1](../Export-PbiLineageWorkbook.ps1/README.md)
