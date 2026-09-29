# Get-PbiReportLineage.ps1: detailed documentation

## Flow

1. Set `$ErrorActionPreference = 'Stop'` and `$ProgressPreference = 'SilentlyContinue'`. In Windows PowerShell 5.1, remove the `System.Array` type data so arrays serialise to JSON as plain arrays.
2. Import `Prerequisites.psm1`, `PowerBIRest.psm1`, `MQueryLineage.psm1` and `RunProgress.psm1` from `src/modules`.
3. Initialise script state (see [Script state](#script-state)) and define the functions.
4. Throw if `-Interactive` and `-Unattended` are both set.
5. Normalise `-ExcelPath` with `Resolve-ExcelPath`.
6. With `-Unattended` and no `-OutputPath`, set `$OutputPath` to the folder of `-ExcelPath`, or to `Documents\Power BI Lineage` (or `Power BI Lineage` under the current location when there is no Documents folder).
7. With `-Interactive`, call `Read-InteractiveOption`.
8. If `-ExcelPath` ends in `.csv`, turn on `-SkipExcel`; otherwise print the `Power BI report lineage` banner.
9. `Start-RunProgress -TotalSteps 8`, then run the eight steps:
   1. **Checking prerequisites**: `Find-RequiredModule` and `Initialize-RequiredModule` for `MicrosoftPowerBIMgmt.Profile`, and `ImportExcel` unless `-SkipExcel`.
   2. **Signing in**: `Connect-LineageSession`.
   3. **Checking access**: `Resolve-CollectionMode` picks Admin or User. The run folder `report-lineage-<yyyyMMdd-HHmmss>` (and `raw/` with `-SaveRawResponses`) is then created under `$OutputPath`.
   4. **Listing workspaces**: Admin: `Get-AdminWorkspaceId`. User: `Get-UserWorkspaceTarget`.
   5. Admin: **Scanning workspaces** with `Get-AdminLineageModel`. User: **Reading reports** with `Read-UserReport`.
   6. **Reading tables and data sources**: Admin: records issues for models without tables from the scan. User: `Read-UserDataset`.
   7. **Tracing lineage**: `Get-LineageRow`; adds a `Gateway` issue if any gateway name was not found.
   8. **Saving results**: `New-LineageDocument` to `report-lineage.json`; the rows to CSV; the workbook via `Export-PbiLineageWorkbook.ps1 -Force` unless `-SkipExcel`.
10. On any error in the steps, `Stop-RunStep` marks the step failed and the error is re-thrown.
11. Print the summary with `Write-RunMessage`: elapsed time, counts, issue count, workbook sheet list and output paths.
12. With `-Interactive` and a workbook, ask `Open the workbook now? [Y/n]`; any answer not starting with `n` opens it with `Invoke-Item`.
13. With `-PassThru`, return the lineage rows.

## Functions

All functions are defined in the script and are private to it. They appear here in file order.

### Add-Issue

Records a problem that does not stop the run. Issues are counted in the summary and saved to the JSON `issues` array (and the workbook's Issues sheet).

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Area` | string | No | Category, e.g. `Workspace`, `Semantic model`, `Report`, `Gateway`, `Tenant settings`. |
| `Item` | string | No | Name or ID of the affected item. |
| `Message` | string | No | Explanation. |

**Returns:** Nothing. Adds `{ Area; Item; Message }` to `$script:Issues`.
**Calls:** `Write-Verbose`.
**Errors:** None.

### Get-StatusCode

Reads the HTTP status that `Invoke-PbiRestMethod` stores on its exceptions.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `ErrorRecord` | ErrorRecord | No | The caught error. |

**Returns:** `$ErrorRecord.Exception.Data['StatusCode']`, or `$null`.
**Calls:** None.
**Errors:** None.

### Save-Raw

Saves a raw response as JSON in the `raw/` folder when `-SaveRawResponses` is on.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | string | No | File name inside `raw/`. |
| `Content` | object | No | Object to serialise. |

**Returns:** Nothing. Does nothing when `$script:RawFolder` is not set.
**Calls:** `ConvertTo-Json -Depth 50`, `Set-Content -Encoding utf8`.
**Errors:** Write failures propagate.

### Get-WorkspacePath

Builds the REST path prefix for a workspace.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Id` | string | No | Workspace ID, or `me` for the caller's My workspace. |

**Returns:** `''` for `me`, otherwise `groups/<Id>/`.
**Calls:** None.
**Errors:** None.

### Resolve-ConfigSecret

Turns a config file's `servicePrincipal.secretFrom` value into a `SecureString`.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `SecretFrom` | string | No | `env:<NAME>` or `keyvault:<vault>/<secret>`. |

**Returns:** A `SecureString`.
**Calls:** `[Environment]::GetEnvironmentVariable`, `ConvertTo-SecureString`, `Get-AzKeyVaultSecret`.
**Errors:** Throws `Environment variable '<NAME>' named in the config is not set.`; throws `Unsupported secretFrom '<value>'. Use env:<NAME> or keyvault:<vault>/<secret>.`; Key Vault errors propagate.

### Read-MenuChoice

Shows a numbered menu and reads a choice.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Question` | string | No | Text shown above the options. |
| `Options` | string[] | No | Menu entries. |

**Returns:** The chosen number (1-based). An empty answer returns `1`. Repeats until the answer is a valid number.
**Calls:** `Write-Host`, `Read-Host` (prompt `Choose 1-<n> (Enter = 1)`).
**Errors:** None.

### Read-RequiredValue

Reads a value that must not be empty.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Prompt` | string | No | Prompt text. |

**Returns:** The trimmed value. Repeats with `A value is required.` until one is given.
**Calls:** `Read-Host`, `Write-Host`.
**Errors:** None.

### Read-InteractiveOption

Fills the script parameters from questions, for `-Interactive` runs.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | |

**Returns:** Nothing. Sets `$script:TenantId`, `$script:ClientId`, `$script:ClientSecret` or `$script:CertificateThumbprint` (service principal choices only), `$script:Mode` (`Admin` for "Every workspace in the tenant", `User` otherwise), `$script:ExcelPath` and `$script:OutputPath` (the workbook's folder).
**Calls:** `Read-MenuChoice`, `Read-RequiredValue`, `Read-Host`, `Resolve-ExcelPath`. The default save location is `Resolve-ExcelPath` of `Documents\Power BI Lineage`.
**Errors:** `Resolve-ExcelPath` errors propagate.

### Connect-ServicePrincipal

Signs in as a service principal with a certificate or a secret.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Tenant` | string | Yes | Tenant ID or domain. |
| `AppId` | string | Yes | Application (client) ID. |
| `Secret` | securestring | No | Client secret, used when no thumbprint is given. |
| `Thumbprint` | string | No | Certificate thumbprint; takes precedence over `Secret`. |

**Returns:** Nothing. Sets `$script:IsServicePrincipal = $true` and `$script:SignedInAs = 'Service principal <AppId>'`.
**Calls:** `Connect-PowerBIServiceAccount -ServicePrincipal` (with `-CertificateThumbprint`, or `-Credential`).
**Errors:** Sign-in errors propagate.

### Connect-LineageSession

Chooses and performs the sign-in.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | Reads the script parameters. |

Order of precedence:

1. `-ClientId`: service principal with `-ClientSecret`, `-CertificateThumbprint`, or `PBI_CLIENT_SECRET`.
2. `-ConfigPath`: service principal from `tenantId`, `servicePrincipal.appId`, and `servicePrincipal.certificateThumbprint` or `servicePrincipal.secretFrom`.
3. An existing Power BI session (`Get-PowerBIAccessToken` succeeds): reused; `SignedInAs` is `Existing Power BI session`.
4. Otherwise, unless `-Unattended`, an interactive `Connect-PowerBIServiceAccount`; `SignedInAs` is `User <UserName>` or `User account`.

**Returns:** Nothing.
**Calls:** `Connect-ServicePrincipal`, `Resolve-ConfigSecret`, `Get-PowerBIAccessToken`, `Connect-PowerBIServiceAccount`, `Update-RunStep`.
**Errors:** Throws `-TenantId is required with -ClientId.`; `Service principal sign-in needs -ClientSecret, -CertificateThumbprint or the PBI_CLIENT_SECRET environment variable.`; and, with `-Unattended` and no session, `Unattended runs sign in as a service principal: pass -TenantId and -ClientId with -CertificateThumbprint (or set PBI_CLIENT_SECRET), or pass -ConfigPath.`

### Resolve-CollectionMode

Decides between Admin and User collection.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | Reads `-Mode`. |

**Returns:** `User` when `-Mode User` (no call is made). Otherwise `Admin` if `GET admin/groups?$top=1` succeeds; `User` if it fails with 401 or 403 and `-Mode` is `Auto`.
**Calls:** `Invoke-PbiRestMethod`, `Get-StatusCode`.
**Errors:** Re-throws any other status. With `-Mode Admin` and 401/403, throws either `This service principal cannot use the Power BI admin APIs. ...` or `This account is not a Power BI / Fabric administrator.`, each followed by ` To cover only the workspaces this identity is a member of, use -Mode User (or choose that option when asked).`

### New-LineageModel

Creates the empty in-memory model that the collection functions fill.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | |

**Returns:** An object with `Workspaces` (hashtable by ID), `Reports` (list), `Datasets` (hashtable by ID), `DatasetErrors` (hashtable by ID) and `DatasetIndex` (hashtable by ID).
**Calls:** None.
**Errors:** None.

### New-ReportEntry

Converts a report from the API into the model's report shape.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Report` | object | No | Report from the scanner or `reports` endpoint. |
| `WorkspaceId` | string | No | Workspace the report was listed in. |

**Returns:** `Id`, `Name`, `ReportType` (defaults to `PowerBIReport`), `WorkspaceId`, `DatasetId`, `DatasetWorkspaceId` (defaults to the report's workspace).
**Calls:** None.
**Errors:** None.

### Get-AdminWorkspaceId

Lists the workspace IDs to scan in Admin mode.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | Reads `-WorkspaceId` and `-IncludePersonalWorkspaces`. |

**Returns:** `-WorkspaceId` as given, if set. Otherwise the IDs from `GET admin/workspaces/modified?excludePersonalWorkspaces=<true|false>&excludeInActiveWorkspaces=true`.
**Calls:** `Invoke-PbiRestMethod`.
**Errors:** REST errors propagate.

### Get-AdminLineageModel

Runs the admin scanner and builds the model from its results.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Ids` | string[] | No | Workspace IDs to scan. |

For each scan result: indexes `datasourceInstances` and `misconfiguredDatasourceInstances` by `datasourceId`; adds each workspace; adds each report that has no `appId`; and adds each dataset with its tables (`Expressions` from `table.source[].expression`), shared expressions, the data sources matched through `datasourceUsages` and `misconfiguredDatasourceUsages`, `StorageMode` (`ContentProviderType`, else `targetStorageMode`) and `MetadataError` (`schemaRetrievalError`). Table `StorageMode` and `PartitionTypes` are left empty.

**Returns:** The model. Returns an empty model when `Ids` is empty.
**Calls:** `New-LineageModel`, `Invoke-PbiWorkspaceScan` (with `-BatchSize $ScanBatchSize` and an `-OnProgress` script block that calls `Update-RunStep`), `Save-Raw` (`scan-<n>.json`), `New-ReportEntry`, `Update-RunStep`.
**Errors:** Scanner errors propagate and stop the run.

### Invoke-DaxQuery

Runs one DAX query against a semantic model.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `DatasetPath` | string | No | `[groups/<id>/]datasets/<id>`. |
| `Query` | string | No | DAX query text. |

**Returns:** One object per row of the first result table, with the column names' `[...]` brackets and table prefix removed.
**Calls:** `Invoke-PbiRestMethod -Method Post` to `<DatasetPath>/executeQueries` with `serializerSettings.includeNulls = true`.
**Errors:** Throws `DAX query failed: <error JSON>` when the result carries an error; REST errors propagate.

### Get-UserDatasetDetail

Reads a model's data sources, tables, partitions and shared expressions in User mode.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Dataset` | object | No | Dataset from the `datasets` endpoint. |
| `WorkspaceId` | string | No | The dataset's workspace ID, or `me`. |

Runs `INFO.TABLES()`, `INFO.PARTITIONS()` and `INFO.EXPRESSIONS()`, and `INFO.REFRESHPOLICIES()` when any partition has `Type` 6. For each table it collects the distinct partition `QueryDefinition` values and the refresh policy `SourceExpression`, maps partition `Mode` and `Type` codes to names (see [Script state](#script-state)), and records the shared expression named by an entity partition (`Type` 5) with an `ExpressionSourceID`.

**Returns:** A dataset object: `Id`, `Name`, `WorkspaceId`, `StorageMode` (`targetStorageMode`), `Tables`, `SharedExpressions`, `Datasources`, `MetadataError`.
**Calls:** `Get-WorkspacePath`, `Invoke-PbiRestMethod` (`GET <datasetPath>/datasources`), `Invoke-DaxQuery`, `Save-Raw` (`dataset-<id>.json`), `Add-Issue`.
**Errors:** A data source failure adds issue `Data sources could not be read. ...`. A failure in the INFO queries sets `MetadataError` and adds issue `Tables could not be read (needs Contributor or above on its workspace). ...`. A refresh policy failure is written to verbose only. Nothing is thrown.

### Get-UserWorkspaceTarget

Lists the caller's workspaces, records them on the model, and returns the IDs to read.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Model` | object | No | The lineage model. |

**Returns:** An array of workspace IDs, filtered by `-WorkspaceId` if set, with `me` first when `-IncludePersonalWorkspaces` is set for a user account. Always adds `me` (`My workspace`) to `Model.Workspaces`.
**Calls:** `Get-PbiPagedValue -Path 'groups'`, `Add-Issue`.
**Errors:** Adds issue `Not visible to this account, so it was skipped.` for each requested ID not found, and `A service principal has no My workspace; -IncludePersonalWorkspaces was ignored.` for a service principal. Errors from `groups` propagate.

### Read-UserReport

Lists reports, and the datasets of workspaces that have reports, in User mode.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Model` | object | No | The lineage model. |
| `Targets` | string[] | No | Workspace IDs. |

**Returns:** Nothing. Adds reports to `Model.Reports` and datasets to `Model.DatasetIndex`.
**Calls:** `Update-RunStep`, `Get-WorkspacePath`, `Invoke-PbiRestMethod` (`GET <prefix>reports`, `GET <prefix>datasets`), `New-ReportEntry`.
**Errors:** A failure for one workspace adds issue `Skipped: reports could not be listed. ...` and the loop continues.

### Read-UserDataset

Reads each semantic model that a report references, in User mode.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Model` | object | No | The lineage model. |

For each distinct `DatasetId`, uses the dataset from `DatasetIndex`, or fetches it with `GET <workspace path>datasets/<id>` using the first report's `DatasetWorkspaceId`.

**Returns:** Nothing. Fills `Model.Datasets`.
**Calls:** `Update-RunStep`, `Invoke-PbiRestMethod`, `Get-WorkspacePath`, `Get-UserDatasetDetail`, `Add-Issue`.
**Errors:** An unreadable dataset sets `Model.DatasetErrors[<id>]` and adds issue `Semantic model not accessible to this account. ...`; the loop continues.

### Format-Endpoint

Normalises a server name or URL for comparison.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Value` | string | No | Server, URL or path. |

**Returns:** The value trimmed and lower-cased, without a leading `tcp:`, a trailing `,<port>` or trailing `/`. `''` for empty input.
**Calls:** None.
**Errors:** None.

### Test-Unresolved

Tests whether a value is empty or still holds an unresolved `{Parameter}` placeholder.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Value` | string | No | Value to test. |

**Returns:** `$true` if empty or matching `\{[^}]+\}`.
**Calls:** None.
**Errors:** None.

### Find-BoundDatasource

Matches a parsed source to one of the model's bound data sources (which carry the gateway binding).

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Source` | object | No | Source from `MQueryLineage.psm1`. |
| `Datasources` | object[] | No | The model's data sources. |

Scoring: same server scores 2, or 3 when the databases also match, or 0 when both have a database and they differ. Without a server match, a location that is a prefix of the data source's `url` or `path` (or the reverse) scores 2. The highest score wins. If the source has no usable server or location and the model has exactly one data source, that one is used.

**Returns:** The matching data source, or nothing.
**Calls:** `Test-Unresolved`, `Format-Endpoint`.
**Errors:** None.

### Get-GatewayName

Resolves a gateway ID to its name.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `GatewayId` | string | No | Gateway ID. |

**Returns:** The name, or `''`. Returns `''` at once for an empty ID or with `-SkipGatewayLookup`.
**Calls:** `Invoke-PbiRestMethod` (`GET gateways`, once per run; cached in `$script:GatewayNames`).
**Errors:** A failed gateway list is written to verbose only. Unfound IDs are added to `$script:UnnamedGateways`.

### Get-GatewayDatasourceName

Resolves a gateway data source ID to its name.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `GatewayId` | string | No | Gateway ID. |
| `DatasourceId` | string | No | Gateway data source ID. |

**Returns:** `datasourceName`, or `''`. Returns `''` at once if either ID is empty or with `-SkipGatewayLookup`.
**Calls:** `Invoke-PbiRestMethod` (`GET gateways/<GatewayId>/datasources/<DatasourceId>`), cached per pair in `$script:GatewayDatasourceNames`.
**Errors:** Failures are written to verbose and cached as `''`.

### Get-TableSource

Finds the upstream sources of one model table.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Dataset` | object | No | The model. |
| `Table` | object | No | The table. |

For each table expression: if it starts with `select` or `with`, it is treated as a legacy query partition and passed to `Get-NativeQuerySource` with connector `Query partition` and the model's data source when it has exactly one. Otherwise it goes to `Get-MQuerySource` with the model's shared expressions. If no source is found and the table has an `EntityExpression`, that shared expression is parsed; a source without an object gets the table's name and `ObjectOrigin` `Direct Lake entity (name assumed from table)`.

**Returns:** A list of source objects (may be empty). Cached per `<datasetId>|<tableName>`.
**Calls:** `Get-NativeQuerySource`, `Get-MQuerySource`.
**Errors:** Parser errors propagate.

### Select-Value

Picks a parsed value, falling back to the data source value when the parsed one is unresolved.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Preferred` | string | No | Value from the M code. |
| `Fallback` | string | No | Value from the bound data source. |

**Returns:** `Preferred` if resolved; else `Fallback` if set; else `Preferred`.
**Calls:** `Test-Unresolved`.
**Errors:** None.

### New-LineageRow

Builds one lineage row.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Base` | IDictionary | No | Report and model columns. |
| `Table` | object | No | Model table, if any. |
| `Source` | object | No | Parsed source, if any. |
| `Datasource` | object | No | Bound data source, if any. |
| `Notes` | string | No | Text for the `Notes` column. Default `''`. |

Server, database and location use `Select-Value` with the data source's `server`, `database`, and `url` (else `path`). An all-zero gateway GUID is treated as no gateway. `IsSnowflakeConnection` is `Y` when `SourceType`, `Connector`, `Server`, `DatasourceType` or `ConnectionDetails` contains `snowflake`, else `N`. `SourceExpression` joins the table's expressions with a `----` line.

**Returns:** A row with these columns, in order: `WorkspaceName`, `WorkspaceId`, `ReportName`, `ReportId`, `ReportType`, `DatasetName`, `DatasetId`, `DatasetWorkspaceName`, `DatasetWorkspaceId`, `DatasetStorageMode`, `TableName`, `TableIsHidden`, `TableStorageMode`, `SourceType`, `Connector`, `Server`, `Database`, `Schema`, `SourceObject`, `SourceObjectKind`, `ObjectOrigin`, `Location`, `ConnectorOptions`, `NativeQuery`, `DatasourceType`, `GatewayId`, `GatewayName`, `GatewayDatasourceId`, `GatewayDatasourceName`, `ConnectionDetails`, `IsSnowflakeConnection`, `Notes`, `SourceExpression`.
**Calls:** `Select-Value`, `Get-GatewayName`, `Get-GatewayDatasourceName`, `ConvertTo-Json`.
**Errors:** None of its own.

### Get-SourceNote

Builds the `Notes` text for a row that has a source.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Source` | object | No | Parsed source. |
| `Datasource` | object | No | Bound data source, if any. |

**Returns:** Zero or more of these sentences, joined by spaces: for `ObjectOrigin` `Connection only`, that the source object was not identified; for `Native query*`, that views or procedures may hide further tables; for an unresolved server parameter with no bound data source, that the server could not be resolved statically.
**Calls:** `Test-Unresolved`.
**Errors:** None.

### Get-TableNote

Builds the `Notes` text for a table with no recognised source.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Table` | object | No | Model table. |

**Returns:** `Calculation group; no external source.`, `Calculated table (DAX); built from other model tables.`, `No source expression returned for this table.`, or a general "no external source recognised" note, in that order of checks.
**Calls:** None.
**Errors:** None.

### Get-LineageRow

Turns the model into lineage rows, one per report x table x source object.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Model` | object | No | The filled lineage model. |

Per report:

| Case | Rows |
|---|---|
| No `DatasetId` (paginated or unbound report) | One row per data source from `GET <workspace path>reports/<id>/datasources`, or one row with no source. Note explains paginated or unbound. |
| Model not in `Model.Datasets` | One row; note from `DatasetErrors`, else `Semantic model is outside the scanned workspaces or not accessible.` |
| Model with no tables (after removing auto date tables unless `-IncludeAutoDateTables`) | One row per model data source, or one row; note is `No table metadata: <error>` or `$script:NoMetadataHint`. |
| Table with no sources | One row with `Get-TableNote`. |
| Table with sources | One row per source, matched with `Find-BoundDatasource`, noted with `Get-SourceNote`. |

**Returns:** Lineage rows on the pipeline.
**Calls:** `Update-RunStep`, `Invoke-PbiRestMethod`, `Get-WorkspacePath`, `New-LineageRow`, `Get-TableSource`, `Find-BoundDatasource`, `Get-SourceNote`, `Get-TableNote`, `Add-Issue`.
**Errors:** A failed report data source call is added to the note and as issue `Data sources of this paginated report could not be read. ...`.

### Get-SourceObjectSummary

Groups rows by source object for the `sourceObjects` section.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Rows` | object[] | No | Lineage rows. |

Uses rows with a `SourceObject`, `Server` or `Location`, grouped by `SourceType`, `Server`, `Database`, `Schema`, `SourceObject`, `Location`.

**Returns:** One object per group with those six fields plus `Gateways`, `ReportCount`, `ModelCount`, `Reports` (`<workspace> / <report>`), `ModelTables` (`<model>[<table>]`), sorted by `SourceType`, `Server`, `Database`, `Schema`, `SourceObject`. Lists are joined with `; `.
**Calls:** `Group-Object`, `Sort-Object`.
**Errors:** None.

### New-LineageDocument

Builds the JSON document for the run. The workbook is built from this document alone.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Rows` | object[] | No | Lineage rows. |
| `Model` | object | No | The lineage model. |
| `CollectionMode` | string | No | `Admin` or `User`. |

**Returns:** An ordered dictionary with `schemaVersion` (1), `generatedAtUtc`, `collectionMode`, `signedInAs`, `workspaceScope` (the IDs, or `All accessible workspaces`), `summary`, `issues`, `workspaces`, `lineage`, `sourceObjects` and `semanticModels` (each with `sharedExpressions`, `datasources` and `tables` with `expressions`).

`summary` fields: `workspaces` and `reports` (distinct IDs in the rows), `semanticModels`, `tables` (all tables in all models, auto date tables included), `lineageRows`, `tracedToObject` (rows with a `SourceObject`), `connectionOnly` (no object but a server or location), `noExternalSource` (the rest), `issues`.
**Calls:** `Get-SourceObjectSummary`.
**Errors:** None.

### Format-Count

Formats a count with a singular or plural noun.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Count` | int | No | The number. |
| `Singular` | string | No | Noun for 1. |
| `Plural` | string | No | Noun otherwise. Default `<Singular>s`. |

**Returns:** For example `1 report` or `1,234 tables`.
**Calls:** None.
**Errors:** None.

### Resolve-ExcelPath

Turns an `-ExcelPath` value into a file path.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Path` | string | No | Folder, `.xlsx` file or `.csv` file. Surrounding spaces and quotes are removed. |

**Returns:** The path as given if it ends in `.xlsx` or `.csv`; otherwise `<Path>\PowerBI-Lineage_<ddMMyyHHmm>.xlsx` using the local time.
**Calls:** `Split-Path`, `Join-Path`, `Get-Date`.
**Errors:** Throws `ExcelPath must be a folder, a .xlsx file or a .csv file: <path>` when the last path segment ends in a 2-5 letter extension other than `.xlsx` or `.csv`.

## Script state

| Variable | Purpose |
|---|---|
| `$script:StorageModeNames` | Partition `Mode` codes: 0 `Import`, 1 `DirectQuery`, 2 `Default`, 3 `Push`, 4 `Dual`, 5 `Direct Lake`. |
| `$script:PartitionTypeNames` | Partition `Type` codes: 1 `Query`, 2 `Calculated`, 3 `None`, 4 `M`, 5 `Entity`, 6 `PolicyRange`, 7 `CalculationGroup`, 8 `Inferred`. |
| `$script:AutoDateTablePattern` | `^(LocalDateTable_\|DateTableTemplate_)`. |
| `$script:NoMetadataHint` | Note used when a model returns no tables and no error. |
| `$script:GatewayNames` | Gateway ID to name; `$null` until first used. |
| `$script:GatewayDatasourceNames` | `<gatewayId>/<datasourceId>` to name. |
| `$script:TableSourceCache` | `<datasetId>\|<tableName>` to parsed sources. |
| `$script:RawFolder` | `raw/` folder with `-SaveRawResponses`, else `$null`. |
| `$script:IsServicePrincipal` | Set by `Connect-ServicePrincipal`. |
| `$script:SignedInAs` | Sign-in description saved in the JSON. |
| `$script:Issues` | List of `{ Area; Item; Message }`. |
| `$script:UnnamedGateways` | Gateway IDs with no name found. |
| `$script:ScanTotal`, `$script:ScanDone` | Admin scan progress counters. |

## Error handling

- `$ErrorActionPreference` is `Stop`. Failures in sign-in, access checks, the admin scan, the workspace list, file writes and the workbook build stop the run.
- Inside the eight steps, a failure calls `Stop-RunStep` (the step shows `failed`) and the error is re-thrown to the caller. The script sets no exit code.
- Problems with single items (an unreadable workspace, model or report data source, missing gateway names, missing tenant settings) are recorded with `Add-Issue` and the run continues. The summary line says how many issues need attention and points to the Issues sheet, or to the JSON `issues` section with `-SkipExcel`.
- REST calls go through `Invoke-PbiRestMethod`, which retries 429 and 5xx responses and puts the HTTP status in `Exception.Data['StatusCode']`.

## Limits and notes

- Source objects come from reading M code with `MQueryLineage.psm1`, not from running it. Dynamic navigation or function results give a connection without an object.
- Admin mode skips reports that have an `appId` (app copies).
- Admin mode always excludes inactive workspaces (`excludeInActiveWorkspaces=true`). `-IncludePersonalWorkspaces` has no effect when `-WorkspaceId` is given.
- Admin mode fills no table `StorageMode`, `PartitionTypes` or `EntityExpression`. So `TableStorageMode` is empty, calculated tables and calculation groups get the general "no external source" note rather than the specific one, and the Direct Lake entity fallback applies only in User mode.
- Admin mode's `DatasetStorageMode` is the scanner's `ContentProviderType` when present (for example `PbixInCompositeMode`), else `targetStorageMode`.
- In Admin mode, a report whose model sits in a workspace outside the scan gets the note `Semantic model is outside the scanned workspaces or not accessible.` In User mode such a model is fetched by ID.
- The `Tenant settings` issue is added only when every model in the scan returned no tables and no error.
- `summary.tables` counts auto date tables even though the rows exclude them by default.
- In User mode, `workspaces` in the JSON always includes `My workspace`.
- `Resolve-ConfigSecret` calls `Get-AzKeyVaultSecret` for `keyvault:` secrets; the script does not install or import the Az module or sign in to Azure.
- When both `-ClientId` and `-ConfigPath` are given, `-ClientId` is used and the config file is ignored.
- `-Interactive` sets `$OutputPath` to the workbook's folder, replacing any `-OutputPath`.
- A folder `-ExcelPath` whose last segment ends in a 2-5 letter extension (for example `reports.old`) is rejected as a file.
