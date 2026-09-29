# MQueryLineage.psm1: detailed documentation

## Flow

Import:

1. The module builds its script-level state: the token regex, the M escape evaluator, the keyword set, the connector catalogue and the non-source namespace set (see [Script state](#script-state)).
2. It exports `Get-MQuerySource`, `Get-NativeQuerySource` and `Get-SqlReferencedObject`.

`Get-MQuerySource`:

1. Returns nothing if `Expression` is empty or white space.
2. `Get-MSharedContext` builds, or reuses from cache, the context that holds the shared expressions.
3. `Get-MToken` splits the expression into tokens, dropping white space and comments; `ConvertFrom-MStringLiteral` decodes string literals.
4. `Resolve-MExpressionSource` calls `Split-MLetExpression` to split `let ... in` into named steps and picks the final step.
5. `Resolve-MStepSource` scans the final step for connector calls (`Get-MConnectorDefinition`, `New-MSourceFromCall`) and `Value.NativeQuery` calls.
6. `Get-MReference` finds the local steps and shared queries the step refers to; each is resolved recursively (`Resolve-MStepSource` or `Resolve-MSharedSource`).
7. `Get-MNavigationRecord` finds `{[...]}` navigation records; `Set-MNavigation` applies them to the sources found.
8. Text values (server, database, record fields) come from `Resolve-MValue`, which follows parameters, text steps and `&` concatenation.
9. `ConvertTo-MSourceObject` expands native SQL into one entry per table (`Get-SqlReferencedObject`), sets `ObjectOrigin`, refines `SourceType` (`Get-MRefinedSourceType`), removes duplicates and returns the objects.

`Get-NativeQuerySource`:

1. `New-MSource` creates a source from the given connection values and query.
2. `ConvertTo-MSourceObject` expands and returns it.

## Functions

### ConvertFrom-MStringLiteral

Removes the quotes from an M string literal, turns `""` into `"` and decodes `#(...)` escapes.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Literal` | string | Yes | Literal including its surrounding quotes. |

**Returns:** the decoded string.
**Calls:** `$script:MEscapeEvaluator` through `[regex]::Replace`.
**Errors:** None raised. An escape with an unknown code (not `cr`, `lf`, `tab`, `#`, or 4 or 8 hex digits) is left as written.

### Get-MToken

Tokenises an M expression with `$script:TokenPattern`.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Expression` | string | Yes | M text. Empty string allowed. |

**Returns:** a `List[object]` of tokens, each with `Type` (`String`, `Identifier`, `Number`, `Symbol`), `Value` and `Quoted` (`$true` for `#"..."` identifiers). White space and `//` or `/* */` comments are dropped.
**Calls:** `ConvertFrom-MStringLiteral`.
**Errors:** None.

### Test-MSymbol

Tests whether a token is a symbol with one of the given values.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Token` | object | Yes | Token, may be `$null`. |
| `Value` | string[] | Yes | Symbols to match. |

**Returns:** `$true` or `$false`.
**Calls:** None.
**Errors:** None.

### Test-MKeyword

Tests whether a token is an unquoted identifier equal to a keyword (case-sensitive).

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Token` | object | Yes | Token, may be `$null`. |
| `Keyword` | string | Yes | Keyword, for example `let`. |

**Returns:** `$true` or `$false`.
**Calls:** None.
**Errors:** None.

### Get-MTokenRange

Returns a slice of a token list.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Tokens` | List[object] | Yes | Token list. |
| `From` | int | Yes | First index. |
| `To` | int | Yes | Last index (inclusive). |

**Returns:** a `List[object]`; empty when `To` is less than `From`.
**Calls:** None.
**Errors:** None handled; an index outside the list throws from `GetRange`.

### Split-MLetExpression

Splits a `let ... in ...` expression into named steps and the result expression. Commas and `in` inside brackets or nested `let` blocks are ignored.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Tokens` | List[object] | Yes | Token list. |

**Returns:** an object with `Steps` (list of `Name`, `Body`) and `Result` (tokens after the matching `in`). If the first token is not `let`, `Steps` is empty and `Result` is all tokens. If no matching `in` is found, the last segment becomes a step and `Result` is empty.
**Calls:** `Test-MKeyword`, `Test-MSymbol`, nested `$addStep`.
**Errors:** None.

### $addStep (nested in Split-MLetExpression)

Script block that adds a token segment as a step if it has the form `Identifier = body` (at least three tokens).

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `From` | int | Yes | First index of the segment. |
| `To` | int | Yes | Last index of the segment. |

**Returns:** nothing; adds to the enclosing `$steps` list.
**Calls:** `Get-MTokenRange`, `Test-MSymbol`.
**Errors:** None.

### Get-MCallArgument

Splits the bracketed group that starts at an opening `(`, `[` or `{` into its comma-separated top-level arguments.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Tokens` | List[object] | Yes | Token list. |
| `OpenIndex` | int | Yes | Index of the opening bracket. |

**Returns:** a `List[object]` of token lists, one per argument.
**Calls:** `Test-MSymbol`.
**Errors:** None.

### ConvertFrom-MRecord

Reads a record literal `[Field = value, ...]` into a hashtable of field name to resolved text.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Tokens` | List[object] | Yes | Token list. |
| `OpenIndex` | int | Yes | Index of the `[`. |
| `Scope` | object | Yes | Current let-scope. |
| `Context` | object | Yes | Shared context. |

**Returns:** a hashtable (case-insensitive keys). A value that cannot be resolved is `$null`.
**Calls:** `Get-MCallArgument`, `Get-MTokenRange`, `Test-MSymbol`, `Resolve-MValue`.
**Errors:** None.

### Get-MNavigationRecord

Finds indexer navigation `<expression>{[...]}` in a step. The token before `{` must be `]`, `)`, `}` or a non-keyword identifier, so a list of records such as `({[Name="x"]})` is not treated as navigation.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Tokens` | List[object] | Yes | Tokens of one step. |
| `Scope` | object | Yes | Current let-scope. |
| `Context` | object | Yes | Shared context. |

**Returns:** one hashtable per non-empty navigation record, in token order.
**Calls:** `Test-MSymbol`, `ConvertFrom-MRecord`.
**Errors:** None.

### Test-MParameter

Tests whether a shared expression is a parameter: its text matches `IsParameterQuery\s*=\s*true`.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | string | Yes | Shared expression name. |
| `Context` | object | Yes | Shared context. |

**Returns:** `$true` or `$false`; `$false` if the name is not a shared expression.
**Calls:** None.
**Errors:** None.

### Get-MSharedToken

Returns the tokens of a shared expression, tokenising it once and caching the result in `Context.SharedTokens`.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | string | Yes | Shared expression name. |
| `Context` | object | Yes | Shared context. |

**Returns:** a `List[object]` of tokens.
**Calls:** `Get-MToken`.
**Errors:** None handled.

### Resolve-MValue

Resolves a text-valued expression: string and number literals, `"value" meta [...]` parameter values, references to local steps or shared expressions, and `&` concatenation.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Tokens` | List[object] | Yes | Tokens of the value. |
| `Scope` | object | Yes | Current let-scope, or `$null` inside a shared expression. |
| `Context` | object | Yes | Shared context. |
| `Depth` | int | No | Recursion depth. Default `0`. |

**Returns:** the text, or `$null` when the value is computed (any concatenation part longer than one token, other than a `meta` value), is `null`, or `Depth` exceeds 10. An identifier that cannot be resolved is written as `{Name}`.
**Calls:** `Test-MSymbol`, `Test-MKeyword`, `Get-MSharedToken`, itself.
**Errors:** None.

### Get-MReference

Lists the local steps and shared queries a step refers to. Parameters, keywords, record field names (`Name =`) and column accessors (`[Column]`) are skipped.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Tokens` | List[object] | Yes | Tokens of one step. |
| `Scope` | object | Yes | Current let-scope. |
| `Context` | object | Yes | Shared context. |

**Returns:** distinct names, in order of first use.
**Calls:** `Test-MSymbol`, `Test-MParameter`.
**Errors:** None.

### New-MSource

Creates an empty source hashtable.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Connector` | string | Yes | Connector function name. |
| `SourceType` | string | Yes | Source type. |

**Returns:** a hashtable with `Connector`, `SourceType`, `Server`, `Database`, `Schema`, `Object`, `ObjectKind`, `ObjectOrigin`, `Location`, `NativeQuery` (all `''`) and `Options` (`@{}`).
**Calls:** None.
**Errors:** None.

### Copy-MSource

Copies a source hashtable, including its `Options` hashtable.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Source` | hashtable | Yes | Source to copy. |

**Returns:** the copy.
**Calls:** None.
**Errors:** None.

### Get-MConnectorDefinition

Looks up a function name in `$script:ConnectorCatalog`. If absent, a name matching `Namespace.Database|Databases|Contents|Feed|DataSource|Catalogs|Tables|Files|Data|Query` (case-sensitive) whose namespace is not in `$script:NonSourceNamespaces` is treated as a generic connector.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | string | Yes | Function name, for example `Sql.Database`. |

**Returns:** a hashtable with `SourceType` and `Arguments`, or nothing. For a generic connector, `SourceType` is the namespace and `Arguments` is `@('Server')`.
**Calls:** None.
**Errors:** None.

### New-MSourceFromCall

Builds a source from a connector call. Positional arguments are mapped to roles from the definition. The roles `Server`, `Database`, `Object`, `Location` and `NativeQuery` set output fields; any other role is stored in `Options`. A record argument with a `Query` field sets `NativeQuery`.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | string | Yes | Connector name. |
| `Definition` | hashtable | Yes | Result of `Get-MConnectorDefinition`. |
| `Arguments` | object | Yes | Result of `Get-MCallArgument`. |
| `Scope` | object | Yes | Current let-scope. |
| `Context` | object | Yes | Shared context. |

**Returns:** a source hashtable. Arguments that resolve to `$null` are skipped.
**Calls:** `New-MSource`, `Resolve-MValue`, `Test-MSymbol`, `ConvertFrom-MRecord`.
**Errors:** None.

### Set-MNavigation

Applies one navigation record to a source. Does nothing if the source already has an `Object`. See [Navigation fields](#navigation-fields).

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Source` | hashtable | Yes | Source to update. |
| `Fields` | hashtable | Yes | Navigation record. |

**Returns:** nothing; updates `Source` in place.
**Calls:** None.
**Errors:** None.

### Resolve-MStepSource

Finds the sources behind one let-step: connector calls, `Value.NativeQuery` calls, referenced steps and shared queries, then navigation. Results are cached per scope.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | string | Yes | Step name. |
| `Scope` | object | Yes | Let-scope with `Steps`, `Cache`, `Resolving`. |
| `Context` | object | Yes | Shared context. |

**Returns:** a `List[hashtable]` of copies of the cached sources. Empty when the step is already being resolved (cycle).
**Calls:** `Test-MSymbol`, `Get-MCallArgument`, `Resolve-MValue`, `Get-MConnectorDefinition`, `New-MSourceFromCall`, `Get-MReference`, itself, `Resolve-MSharedSource`, `Get-MNavigationRecord`, `Set-MNavigation`, `Copy-MSource`.
**Errors:** None.

### Resolve-MSharedSource

Finds the sources behind a shared query. Results are cached in `Context.SharedCache`.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | string | Yes | Shared expression name. |
| `Context` | object | Yes | Shared context. |

**Returns:** a `List[hashtable]` of copies. Empty when `Context.Depth` is 30 or more, or when the name is already being resolved (cycle).
**Calls:** `Resolve-MExpressionSource`, `Get-MSharedToken`, `Copy-MSource`.
**Errors:** `Depth` and `Resolving` are restored in a `finally` block.

### Resolve-MExpressionSource

Builds a let-scope for an expression and resolves its final step. The final step is the step named after `in`; otherwise the `in` expression as a step called `__result`; otherwise the last step.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Tokens` | List[object] | Yes | Tokens of the whole expression. |
| `Context` | object | Yes | Shared context. |

**Returns:** a `List[hashtable]`; empty if there are no steps and no result.
**Calls:** `Split-MLetExpression`, `Resolve-MStepSource`.
**Errors:** None.

### Get-MSharedContext

Returns the context for a shared expressions dictionary. Reuses `$script:SharedContextCache` when the same dictionary instance is passed and its `Count` has not changed. `$null` values are skipped.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `SharedExpression` | IDictionary | Yes | Name to M text. |

**Returns:** an object with `Shared`, `SharedTokens`, `SharedCache`, `Resolving` and `Depth`.
**Calls:** None.
**Errors:** None.

### Get-MRefinedSourceType

Replaces the source type based on the server name.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `SourceType` | string | Yes | Source type from the connector. |
| `Server` | string | Yes | Server value. |

**Returns:** the refined type (first match wins), otherwise `SourceType`.

| Server matches | Returned type |
|---|---|
| `.datawarehouse.fabric.microsoft.com` or `.datawarehouse.pbidedicated.windows.net` | `Fabric SQL analytics endpoint / Warehouse` |
| `.database.fabric.microsoft.com` | `Fabric SQL database` |
| `.sql.azuresynapse.net` | `Azure Synapse Analytics` |
| `.database.windows.net` | `Azure SQL Database` |
| starts with `powerbi://` | `Power BI semantic model` |
| starts with `asazure://` | `Azure Analysis Services` |

**Calls:** None.
**Errors:** None.

### ConvertTo-MSourceObject

Sets `ObjectOrigin`, expands native SQL into one entry per referenced table, removes duplicates and builds the output objects.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Sources` | List[hashtable] | Yes | Sources to convert. |

**Returns:** `[pscustomobject]` items with `SourceType`, `Connector`, `Server`, `Database`, `Schema`, `Object`, `ObjectKind`, `ObjectOrigin`, `Location`, `Options`, `NativeQuery`. `Options` is `key=value` pairs sorted by key and joined with `; `. Duplicates are detected on `Connector`, `Server`, `Database`, `Schema`, `Object`, `Location` and `NativeQuery`, case-insensitive.
**Calls:** `Get-SqlReferencedObject`, `Copy-MSource`, `Get-MRefinedSourceType`.
**Errors:** None.

### Get-MQuerySource

Returns the upstream sources behind an M expression.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Expression` | string | Yes | M expression. Pipeline input. Empty string allowed. |
| `SharedExpression` | IDictionary | No | Shared queries and parameters, name to M text. Default `@{}`. |

**Returns:** zero or more source objects (see `ConvertTo-MSourceObject`). Nothing for empty or white-space input, or when no connector is found (for example a DAX expression).
**Calls:** `Get-MSharedContext`, `Get-MToken`, `Resolve-MExpressionSource`, `ConvertTo-MSourceObject`.
**Errors:** None raised by the module's own code.

```powershell
Get-MQuerySource -Expression 'let Source = Sql.Database(ServerName, "db"), T = Source{[Schema="dbo",Item="X"]}[Data] in T'
# Server = {ServerName}, Database = db, Schema = dbo, Object = X
```

### Get-NativeQuerySource

Builds source objects for a SQL query bound to a known connection, for example a legacy query partition.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Query` | string | Yes | SQL text. |
| `SourceType` | string | No | Default `''`. |
| `Connector` | string | No | Default `''`. |
| `Server` | string | No | Default `''`. |
| `Database` | string | No | Default `''`. |

**Returns:** one object per table found in `Query`, or one object with `ObjectOrigin` `Native query (no tables parsed)`.
**Calls:** `New-MSource`, `ConvertTo-MSourceObject`.
**Errors:** None.

```powershell
Get-NativeQuerySource -Query 'SELECT * FROM dbo.Budget' -SourceType 'Sql' -Server 'sql02' -Database 'Plan'
# Server = sql02, Database = Plan, Schema = dbo, Object = Budget
```

### Get-SqlReferencedObject

Lists the tables, views and procedures named after `FROM`, `JOIN`, `EXEC` or `EXECUTE` in SQL text. A pattern match, not a SQL parser.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Query` | string | Yes | SQL text. Pipeline input. Empty string allowed. |

**Returns:** `[pscustomobject]` items with `Server`, `Database`, `Schema`, `Object`, taken right to left from a name of up to four parts. Names may be bare, `[bracketed]`, `"quoted"` or `` `backticked` ``. Each qualified name is returned once (case-insensitive).
Skipped:

- `--` and `/* */` comments, and the content of `'...'` string literals.
- Names starting with `#` or `@` (temp tables, table variables).
- `select`, `lateral`, `unnest`, `values`, `dual`, `openjson`, `openquery`, `openrowset`, `string_split`.
- Single-part names that match a CTE name.
- `FROM` preceded by `year`, `month`, `day`, `hour`, `minute`, `second`, `epoch`, `quarter`, `week`, `leading`, `trailing` or `both` (for example `EXTRACT(YEAR FROM x)`).

**Calls:** None.
**Errors:** None.

```powershell
Get-SqlReferencedObject -Query 'EXEC [rpt].[usp_GetSales] @Year = 2024'
# Schema = rpt, Object = usp_GetSales
```

## Recognised sources

Connector functions in `$script:ConnectorCatalog`. Arguments are positional. `Server`, `Database`, `Object`, `Location` and `NativeQuery` fill the output field of that name; other roles go to `Options`.

| M function | SourceType | Argument 1 | Argument 2 | Argument 3 |
|---|---|---|---|---|
| `Sql.Database` | SQL Server | Server | Database | |
| `Sql.Databases` | SQL Server | Server | | |
| `Oracle.Database` | Oracle | Server | | |
| `PostgreSQL.Database` | PostgreSQL | Server | Database | |
| `MySQL.Database` | MySQL | Server | Database | |
| `AmazonRedshift.Database` | Amazon Redshift | Server | Database | |
| `Snowflake.Databases` | Snowflake | Server | Option `Warehouse` | |
| `GoogleBigQuery.Database` | Google BigQuery | | | |
| `Databricks.Catalogs` | Databricks | Server | Option `HttpPath` | |
| `Databricks.Contents` | Databricks | Server | Option `HttpPath` | |
| `DatabricksMultiCloud.Catalogs` | Databricks | Server | Option `HttpPath` | |
| `Teradata.Database` | Teradata | Server | | |
| `DB2.Database` | IBM Db2 | Server | Database | |
| `SapHana.Database` | SAP HANA | Server | | |
| `SapBusinessWarehouse.Cubes` | SAP BW | Server | | |
| `Sybase.Database` | Sybase | Server | Database | |
| `Informix.Database` | Informix | Server | Database | |
| `AnalysisServices.Database` | Analysis Services | Server | Database | |
| `AnalysisServices.Databases` | Analysis Services | Server | | |
| `AzureDataExplorer.Contents` | Azure Data Explorer | Server | Database | Object |
| `Kusto.Contents` | Azure Data Explorer | Server | Database | Object |
| `Odbc.DataSource` | ODBC | Server | | |
| `Odbc.Query` | ODBC | Server | NativeQuery | |
| `OleDb.DataSource` | OLE DB | Server | | |
| `OleDb.Query` | OLE DB | Server | NativeQuery | |
| `OData.Feed` | OData | Location | | |
| `Web.Contents` | Web | Location | | |
| `SharePoint.Files` | SharePoint | Location | | |
| `SharePoint.Contents` | SharePoint | Location | | |
| `SharePoint.Tables` | SharePoint list | Location | | |
| `File.Contents` | File | Location | | |
| `Folder.Files` | Folder | Location | | |
| `Folder.Contents` | Folder | Location | | |
| `AzureStorage.Blobs` | Azure Blob Storage | Location | | |
| `AzureStorage.DataLake` | Azure Data Lake Storage | Location | | |
| `AzureStorage.Tables` | Azure Table Storage | Location | | |
| `Lakehouse.Contents` | Fabric Lakehouse | | | |
| `Fabric.Warehouse` | Fabric Warehouse | | | |
| `PowerPlatform.Dataflows` | Dataflow | | | |
| `PowerBI.Dataflows` | Dataflow | | | |
| `CommonDataService.Database` | Dataverse | Server | | |
| `Dataverse.Contents` | Dataverse | | | |
| `Salesforce.Data` | Salesforce | Location | | |

Other sources of data:

| Construct | What it yields |
|---|---|
| Any other `Namespace.Suffix(...)` with suffix `Database`, `Databases`, `Contents`, `Feed`, `DataSource`, `Catalogs`, `Tables`, `Files`, `Data` or `Query`, and a namespace not in `$script:NonSourceNamespaces` | `SourceType` = namespace; argument 1 = `Server` |
| A record argument with `Query`, for example `Sql.Database("s", "d", [Query="SELECT ..."])` | `NativeQuery` |
| `Value.NativeQuery(source, "SQL", ...)` | Argument 2 becomes `NativeQuery` of each source in the step that has neither `NativeQuery` nor `Object` |
| `{[...]}` navigation after an expression | `Server`, `Database`, `Schema`, `Object`, `ObjectKind` (see below) |
| Reference to a local step or a shared query (not a parameter) | The sources of that step or query |

### Navigation fields

Applied by `Set-MNavigation` only while the source has no `Object`. Field names are matched case-insensitively.

| Record field | Sets |
|---|---|
| `workspaceId` | `Server`, if empty |
| `lakehouseId`, `warehouseId`, `dataflowId`, `datasetId`, `databaseId` | `Database` (the last one present wins) |
| `entity` | `Object`; `ObjectKind` = `Entity` |
| `Schema` | `Schema` |
| `Item` | `Object`; `ObjectKind` = `Kind` or `ItemKind` |
| `Name` with `Kind` `Database` or `Catalog` | `Database` |
| `Name` with `Kind` `Schema` | `Schema` |
| `Name` with no kind | `Database` if the connector ends in `.Databases` or `.Catalogs` and `Database` is empty; otherwise `Object` |
| `Name` with any other kind | `Object`; `ObjectKind` = kind |
| `Id` with `Kind` or `ItemKind` `Lakehouse`, `Warehouse` or `Database` | `Database` |
| `Id` with any other kind | `Object`; `ObjectKind` = kind |

`Item` takes precedence over `Name`, and `Name` over `Id`.

## ObjectOrigin values

Set by `ConvertTo-MSourceObject`:

| Value | When |
|---|---|
| `Navigation` | The source has an `Object` (from navigation, the `Object` argument of `AzureDataExplorer.Contents` or `Kusto.Contents`, or `entity`). |
| `Native query` | No `Object`; `NativeQuery` named one or more tables. One output per table; `ObjectKind` = `Referenced in native query`. A `Database` from a three- or four-part name replaces the connection's database. |
| `Native query (no tables parsed)` | No `Object`; `NativeQuery` is set but no table was found. |
| `Connection only` | No `Object` and no `NativeQuery`. |

`Get-PbiReportLineage.ps1` sets one further value, `Direct Lake entity (name assumed from table)`, outside this module.

## Script state

| Name | Type | Purpose |
|---|---|---|
| `$script:TokenPattern` | compiled regex | Token rules: white space, comments, `#"..."` identifiers, strings, numbers, dotted identifiers (optionally `#`-prefixed), symbols (`=>`, `<>`, `<=`, `>=`, `..`, `...`, single characters). |
| `$script:MEscapeEvaluator` | `MatchEvaluator` | Decodes `#(cr)`, `#(lf)`, `#(tab)`, `#(#)` and 4 or 8 hex digit escapes; comma-separated codes allowed. |
| `$script:Keywords` | `HashSet[string]` (ordinal) | M keywords: `let`, `in`, `each`, `if`, `then`, `else`, `and`, `or`, `not`, `true`, `false`, `null`, `meta`, `type`, `as`, `is`, `otherwise`, `try`, `error`, `section`, `shared`. |
| `$script:ConnectorCatalog` | hashtable | Known connectors, their `SourceType` and argument roles (see [Recognised sources](#recognised-sources)). |
| `$script:NonSourceNamespaces` | `HashSet[string]` (case-insensitive) | Namespaces never treated as generic connectors: `Table`, `List`, `Record`, `Text`, `Number`, `Date`, `DateTime`, `DateTimeZone`, `Duration`, `Time`, `Binary`, `BinaryFormat`, `Value`, `Expression`, `Function`, `Type`, `Json`, `Csv`, `Excel`, `Xml`, `Lines`, `Splitter`, `Combiner`, `Replacer`, `Comparer`, `Cube`, `Uri`, `Html`, `Pdf`, `Parquet`, `Access`, `Character`, `Logical`, `Diagnostics`, `Error`, `Variable`, `Embedded`, `Action`, `Culture`. |
| `$script:SharedContextCache` | object or `$null` | Last shared context, with the dictionary it was built from and its `Count`. Initially `$null`. |

## Error handling

- The module does not throw its own errors and does not write warnings.
- Values that cannot be resolved become `{Name}` or are left empty; they are not guessed.
- Cycles between steps or shared queries return no sources for the repeated name instead of recursing.
- Recursion limits: `Resolve-MValue` stops beyond depth 10; `Resolve-MSharedSource` stops at depth 30.
- Unexpected .NET or regex exceptions are not caught and reach the caller.

## Limits and notes

- Static analysis only. Function results, dynamic navigation and text built from computed values are not resolved.
- A parameter is recognised only by `IsParameterQuery = true` in its text. Only a text literal before `meta` is read as its value; a number parameter shows as `{Name}`.
- A reference to a shared function is followed like a query. Its arguments are not bound, so values that depend on them appear as `{Name}`.
- Navigation records in a step are applied to every source in that step, not only the one being navigated.
- Once a source has an `Object`, later navigation is ignored.
- `Value.NativeQuery` reads only its second argument, and only fills sources without `NativeQuery` or `Object`.
- `Odbc.*` and `OleDb.*` map their first argument, usually a connection string, to `Server`.
- `Get-MRefinedSourceType` looks only at `Server`, for any connector.
- `Get-SqlReferencedObject` sees names after `FROM`, `JOIN` and `EXEC` only. Dynamic SQL and objects used inside views or functions are not visible. Its `Server` part is not copied into the output of `ConvertTo-MSourceObject`.
- The CTE pattern also matches `, name AS (`, so a single-part table of that name is skipped.
- The shared context cache holds one dictionary at a time and is keyed on instance and `Count`. Changing a value without changing the count reuses stale parsing.
- The default `SharedExpression` is a new `@{}` on every call, so the cache is not reused when it is omitted.
