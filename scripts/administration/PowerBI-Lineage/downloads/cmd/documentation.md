# PowerBI-Lineage.cmd: detailed documentation

`PowerBI-Lineage.cmd` is a batch/PowerShell polyglot. `cmd.exe` runs the batch block at the top. PowerShell reads
the same block as a `<# ... #>` comment and runs the loader below it. The loader unpacks the scripts stored at the
bottom of the file and runs `Get-PbiReportLineage.ps1`. `PowerBI-Lineage.zip` holds this file with `README.md` and `documentation.md`.

## Flow

1. `cmd.exe` sets `LINEAGE_BUNDLE` (the file's full path) and `LINEAGE_ARGS` (all arguments), inside `setlocal`.
2. It picks PowerShell: `pwsh` if `where pwsh` finds it, else `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe` if that exists, else `powershell`.
3. It starts that PowerShell with `-NoProfile -ExecutionPolicy Bypass` (plus `-NonInteractive` when there are arguments).
4. PowerShell reads the file and runs the text before the `#==== FILES ====` marker with `Invoke-Expression`.
5. The loader hashes the text from the marker to the end; the first 6 bytes of the SHA-256, as 12 hex characters, are the version.
6. If `%LOCALAPPDATA%\PowerBI-Lineage\<version>\.complete` is missing, it writes each embedded file there, writes `.complete`, and deletes every other folder under `%LOCALAPPDATA%\PowerBI-Lineage`.
7. With arguments: it reads them with `ConvertFrom-LauncherArgument`, prints help and exits `0` if help was asked for, otherwise runs `Get-PbiReportLineage.ps1 -Unattended` with them and exits `0`.
8. Without arguments: it runs `Get-PbiReportLineage.ps1 -Interactive`.
9. Back in `cmd.exe`: an unattended run exits with PowerShell's exit code. An interactive run prints `Finished.` or `The run did not finish. The message above explains why.`, then pauses.

## Structure

| Part | Lines | What it does |
|---|---|---|
| Batch launcher | From `<# : batch launcher` to `#>` | Steps 1 to 3 and 9. Ends at `exit /b`, so `cmd.exe` never reads further. |
| Header comment | After `#>` | What the file is, where it unpacks, and that it is generated. |
| Loader | Up to `return` | Steps 5 to 8. |
| `#==== FILES ==== (generated; do not edit)` | One line | Start of the payload. The launcher builds the marker from two strings (`'#====' + ' FILES ===='`) so a search for it never matches the launcher itself. |
| Embedded files | Rest of the file | Each file after a line `#==== FILE: <path> ====`, as plain text. |

The embedded files, in order:

| Path | Documentation |
|---|---|
| `src/modules/Prerequisites.psm1` | Prerequisites.psm1 |
| `src/modules/PowerBIRest.psm1` | PowerBIRest.psm1 |
| `src/modules/MQueryLineage.psm1` | MQueryLineage.psm1 |
| `src/modules/RunProgress.psm1` | RunProgress.psm1 |
| `src/modules/LauncherArguments.psm1` | LauncherArguments.psm1 |
| `src/Get-PbiReportLineage.ps1` | Get-PbiReportLineage.ps1 |
| `src/Export-PbiLineageWorkbook.ps1` | Export-PbiLineageWorkbook.ps1 |

`orchestrator/Invoke-LineageRun.ps1` is not in this file.

### Functions

The launcher and loader define no functions. The functions they call come from the embedded files:
`ConvertFrom-LauncherArgument` and `Get-LauncherUsage` from `LauncherArguments.psm1`, and everything else from
`Get-PbiReportLineage.ps1` and the modules it imports.

### Variables the loader sets

| Name | Value |
|---|---|
| `$payload` | The file text from the `#==== FILES ====` marker to the end. |
| `$version` | First 6 bytes of the SHA-256 of `$payload` (UTF-8), as 12 lower-case hex characters. |
| `$localAppData` | `$env:LOCALAPPDATA`, else `[Environment]::GetFolderPath('LocalApplicationData')`, else `LocalAppData` under the temp folder. |
| `$target` | `<localAppData>\PowerBI-Lineage\<version>`. |
| `$lineageScript` | `<target>\src\Get-PbiReportLineage.ps1`. |

## What it writes

| Location | What | Lifetime |
|---|---|---|
| `%LOCALAPPDATA%\PowerBI-Lineage\<version>\` | The 7 embedded files (UTF-8 with byte order mark) and `.complete` holding the version. | Until a run of a different version deletes it. |
| The current user's PowerShell module folder | `MicrosoftPowerBIMgmt.Profile` and `ImportExcel`, only if not already installed (installed by `Prerequisites.psm1`, `-Scope CurrentUser`). `ImportExcel` is not needed for CSV only or `-SkipExcel`. | Permanent. |
| Output folder | `report-lineage-yyyyMMdd-HHmmss\report-lineage.json` (and `raw\` with `-SaveRawResponses`). | Kept; each run makes a new folder. |
| Next to the workbook | The CSV, named after the workbook. | Replaced when the name repeats. |
| `-ExcelPath` | The workbook. | A folder gets a new dated file each run; a file path is replaced. |

Output folder defaults: interactive runs use the folder of the chosen workbook. Unattended runs use the `-ExcelPath`
folder, else `Documents\Power BI Lineage`. Without `-ExcelPath` the workbook is `report-lineage.xlsx` in the JSON
run folder.

## Error handling

| Case | Result |
|---|---|
| Unattended, any error (including a refused argument) | `ERROR: <message>` on standard error, exit code `1`. |
| `-ClientSecret` given | Refused: `Do not put the client secret on the command line, where job logs and process lists can show it. ...` |
| Unknown parameter | Refused: `Unknown parameter -<name>. Valid parameters: ...` |
| An argument that is not a plain value, e.g. `$(...)` | Refused: `Arguments must be plain values; '<text>' ...` |
| Unattended without service principal details | `Unattended runs sign in as a service principal: pass -TenantId and -ClientId with -CertificateThumbprint (or set PBI_CLIENT_SECRET), or pass -ConfigPath.` |
| Interactive, any error | The message in red, PowerShell exit code `1`, then `The run did not finish. The message above explains why.` and a pause. |
| Unpack interrupted | No `.complete` is written, so the next run unpacks again. |
| Old version folders cannot be deleted | Ignored (`-ErrorAction SilentlyContinue`). |

## How it is built

`build/New-LineageBundle.ps1` writes `PowerBI-Lineage.cmd` from the 7 files in `src/` listed above. By default it
writes it to `downloads\cmd`; `-OutputFolder` writes it elsewhere. `build/New-DownloadZips.ps1` then zips the folder
into `PowerBI-Lineage.zip`.

The build:

- throws if a source file has a line starting with `#==== FILE`;
- adds a final line break to any file without one;
- converts every line ending to CRLF, which batch files need;
- throws if the result contains a non-ASCII character (`The bundle contains non-ASCII characters, which Windows PowerShell 5.1 and cmd may misread.`);
- writes the `.cmd` as ASCII and zips it with `Compress-Archive`.

`tests/Bundle.Tests.ps1` checks that:

- the published `.cmd` equals a fresh build;
- every `.ps1` and `.psm1` under `src/` is in the bundle, unchanged apart from line endings;
- the file is ASCII, starts with `<# : batch launcher` and has no bare LF;
- `/?` exits `0` with the usage text, and `-ClientSecret abc` exits `1` with its `ERROR:` message, neither pausing (input redirected from `NUL`);
- the zip holds only `PowerBI-Lineage.cmd`.

## Limits and notes

- Windows only: it is a batch file and uses `cmd.exe`.
- The version covers the payload only. A change to the launcher alone does not change the version folder.
- Step 6 deletes every other folder under `%LOCALAPPDATA%\PowerBI-Lineage`, not only version folders, and does not check whether another run is using one.
- Two runs of a new version started at the same moment both unpack into the same folder.
- `PowerBI-Lineage.cmd` must stay ASCII with CRLF line endings. Editing it by hand breaks the up-to-date test; edit `src/` and rebuild.
- `-PassThru` and `-ClientSecret` are not accepted as arguments. Unattended runs never open a browser sign-in.
- `-ConfigPath` with `keyvault:<vault>/<secret>` calls `Get-AzKeyVaultSecret`; the launcher does not install the Az module for it.

<!-- shared:inside -->
## The files inside

The three Orchestrator downloads carry the 8 files below, word for word. `PowerBI-Lineage.cmd` carries 7 of them: all
but `Invoke-LineageRun.ps1`. They are the tool's own code. They are **not** downloaded from anywhere: the download
writes them to a local folder and runs them from there (see **How it works** in the README). They are not registered
with PowerShell, so nothing else on the machine sees them.

| File | What it does |
|---|---|
| `Invoke-LineageRun.ps1` | Orchestrator entry point. Reads the settings from environment variables, runs `Get-PbiReportLineage.ps1`, exits `0` on success or `1` with `ERROR: <message>`. Not in the `.cmd`. |
| `src\Get-PbiReportLineage.ps1` | Main script. Signs in, lists workspaces and reports, reads each semantic model's tables and Power Query code, finds sources and gateways, writes the JSON and CSV, then runs `Export-PbiLineageWorkbook.ps1`. |
| `src\Export-PbiLineageWorkbook.ps1` | Builds the Excel workbook from the JSON. |
| `src\modules\Prerequisites.psm1` | Finds `MicrosoftPowerBIMgmt.Profile` and `ImportExcel`. Installs a missing one for the current user from the PowerShell Gallery (and the NuGet provider first, if missing). |
| `src\modules\PowerBIRest.psm1` | Calls the Power BI REST API. Retries on HTTP 429 and 5xx. |
| `src\modules\MQueryLineage.psm1` | Reads Power Query (M) code as text to find the server, database, schema and table. It parses the code; it never runs it. |
| `src\modules\RunProgress.psm1` | The numbered steps and progress lines. |
| `src\modules\LauncherArguments.psm1` | Reads the `.cmd` command line as literal values, never as code. Used only by the `.cmd`. |

`Get-PbiReportLineage.ps1` loads the four modules with `Import-Module <path>` from the folder next to it.

### Functions

**`src\Get-PbiReportLineage.ps1`**

| Function | Purpose |
|---|---|
| `Add-Issue` | Records a problem that does not stop the run (Issues sheet). |
| `Get-StatusCode` | Reads the HTTP status from a failed call. |
| `Save-Raw` | Saves a raw API response with `-SaveRawResponses`. |
| `Get-WorkspacePath` | Builds the REST path for a workspace. |
| `Resolve-ConfigSecret` | Reads the secret named in a config file (environment variable or Key Vault). |
| `Read-MenuChoice`, `Read-RequiredValue`, `Read-InteractiveOption` | Ask the questions of an interactive run. |
| `Connect-ServicePrincipal` | Signs in with a certificate or secret. |
| `Connect-LineageSession` | Chooses and performs the sign-in. |
| `Resolve-CollectionMode` | Chooses `Admin` or `User` (a test call to `admin/groups` when `Auto`). |
| `New-LineageModel`, `New-ReportEntry` | Create the in-memory model and its report entries. |
| `Get-AdminWorkspaceId` | Lists workspaces to scan (`GET admin/workspaces/modified`). |
| `Get-AdminLineageModel` | Runs the admin scanner and builds the model. |
| `Invoke-DaxQuery` | Runs one read-only `INFO.*` DAX query (`User` mode). |
| `Get-UserDatasetDetail`, `Get-UserWorkspaceTarget`, `Read-UserReport`, `Read-UserDataset` | Collect workspaces, reports and models in `User` mode. |
| `Format-Endpoint`, `Test-Unresolved`, `Select-Value` | Compare and pick server and database values. |
| `Find-BoundDatasource` | Matches a parsed source to the model's data source and gateway. |
| `Get-GatewayName`, `Get-GatewayDatasourceName` | Resolve gateway names. |
| `Get-TableSource` | Finds the sources of one model table. |
| `New-LineageRow`, `Get-LineageRow` | Build the lineage rows. |
| `Get-SourceNote`, `Get-TableNote` | Build the `Notes` text. |
| `Get-SourceObjectSummary` | Groups rows by source object. |
| `New-LineageDocument` | Builds the JSON document. |
| `Format-Count` | Singular or plural counts in messages. |
| `Resolve-ExcelPath` | Turns the output path into a file name. |

**`src\Export-PbiLineageWorkbook.ps1`**

| Function | Purpose |
|---|---|
| `ConvertTo-CellText` | Converts a value to cell text; cuts text over Excel's 32,767-character limit. |
| `ConvertTo-DataTable` | Builds a table from rows. |
| `Get-SheetName` | Makes a valid, unique sheet name. |
| `Add-DataSheet` | Adds a sheet and loads its rows. |
| `Set-SheetLink` | Links a cell to another sheet. |
| `Add-SummarySheet` | Writes the Summary sheet. |

**`src\modules\Prerequisites.psm1`**

| Function | Purpose |
|---|---|
| `Get-OtherModuleFolder`, `Add-OtherModuleFolder` | Also search the 32-bit and 64-bit Windows PowerShell module folders. |
| `Find-RequiredModule` | Finds an installed module. |
| `Initialize-RequiredModule` | Imports a module, installing it first only if it is missing. |

**`src\modules\PowerBIRest.psm1`**

| Function | Purpose |
|---|---|
| `Set-PbiApiBaseUrl` | Changes the API root (sovereign clouds). Not used by default. |
| `Invoke-PbiRestMethod` | Calls one endpoint, with retries. |
| `Get-PbiPagedValue` | Reads every page of a paged endpoint. |
| `Invoke-PbiWorkspaceScan` | Runs the admin scanner in batches (`POST admin/workspaces/getInfo`, then `scanStatus`, `scanResult`). |

**`src\modules\MQueryLineage.psm1`**

| Function | Purpose |
|---|---|
| `Get-MQuerySource` | Entry point: the sources behind one Power Query expression. |
| `Get-NativeQuerySource` | The sources behind a SQL query on a known connection. |
| `Get-SqlReferencedObject` | Tables after `FROM`, `JOIN`, `EXEC` in SQL (a pattern match, not a SQL parser). |
| `Get-MToken`, `Test-MSymbol`, `Test-MKeyword`, `Get-MTokenRange` | Split M code into tokens. |
| `Split-MLetExpression` | Splits `let ... in ...` into steps. |
| `Get-MCallArgument`, `ConvertFrom-MRecord`, `ConvertFrom-MStringLiteral` | Read arguments, records and text. |
| `Get-MNavigationRecord`, `Set-MNavigation` | Read navigation such as `{[Schema="dbo",Item="Sales"]}`. |
| `Test-MParameter`, `Resolve-MValue`, `Get-MReference` | Resolve parameters and references. |
| `Get-MConnectorDefinition`, `New-MSourceFromCall` | Recognise a connector (`Sql.Database`, `Snowflake.Databases` and 41 more). |
| `New-MSource`, `Copy-MSource` | Create source records. |
| `Resolve-MStepSource`, `Resolve-MSharedSource`, `Resolve-MExpressionSource`, `Get-MSharedToken`, `Get-MSharedContext` | Follow steps and shared queries. |
| `Get-MRefinedSourceType` | Refines the source type from the server name. |
| `ConvertTo-MSourceObject` | Builds the output and sets `ObjectOrigin`. |

**`src\modules\RunProgress.psm1`**

| Function | Purpose |
|---|---|
| `Start-RunProgress` | Starts a run and picks console or plain output. |
| `Start-RunStep`, `Update-RunStep`, `Complete-RunStep`, `Stop-RunStep`, `Show-RunStep` | Show one numbered step. |
| `Write-RunMessage` | Writes a summary line. |
| `Format-RunDuration`, `Format-RunStepLine`, `Get-ConsoleWidth`, `Get-RunElapsed` | Formatting and timing. |

**`src\modules\LauncherArguments.psm1`**

| Function | Purpose |
|---|---|
| `ConvertFrom-LauncherArgument` | Turns the command line into parameters; refuses anything that is not a literal value. |
| `Get-LiteralArgumentValue` | Reads one literal value. |
| `Get-LauncherUsage` | The `/?` help text. |

`Invoke-LineageRun.ps1` has no functions.
<!-- /shared:inside -->
