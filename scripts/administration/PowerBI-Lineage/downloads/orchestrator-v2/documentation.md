# PowerBI-Lineage.Orchestrator.V2.ps1: detailed documentation

The script runs inside Orchestrator's own PowerShell host, which may be 32-bit Windows PowerShell (Orchestrator
2019) or a .NET 8 PowerShell (Orchestrator 2022 and 2025). It does not run the tool there. It checks the settings,
saves the tool's 8 files, which it carries as plain text, and starts 64-bit Windows PowerShell on
`Invoke-LineageRun.ps1`, passing the settings as environment variables. `PowerBI-Lineage.Orchestrator.ps1` (V1) is
the same script with the files compressed.

## Flow

1. Read the nine settings; take any that are empty or start with `Required-` from their environment variables.
2. Check each setting against its pattern; require `$ClientSecret` or `$CertificateThumbprint`.
3. Default `$Mode` to `Admin` and the timeout to 180 minutes.
4. Work out the output file: a `.csv` path means CSV only; a folder gets `PowerBI-Lineage_<ddMMyyHHmm>.xlsx` (or `.csv`).
5. Build `$files`, an ordered table of the 8 files, from 8 here-strings. Join each path and its text with CRLF; the version is the first 6 bytes of the SHA-256 of that text (UTF-8), as 12 hex characters.
6. If `<installRoot>\<version>\.complete` is missing, write each file (turning `#~'@` lines back into `'@`, line endings CRLF), write `.complete`, and delete older 12-hex version folders.
7. Start `cmd.exe` (from `Sysnative` if it exists, else `System32`), which runs `System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File Invoke-LineageRun.ps1` with output redirected to two temp files and input from `NUL`.
8. Wait up to the timeout; if it passes, stop the process tree with `taskkill.exe /T /F`.
9. Read and delete the two temp files, and write their text to the run log next to the output.
10. Throw on timeout or a non-zero exit code; otherwise return the run's console output.

## Structure

| Part | Starts at | What it does |
|---|---|---|
| Banner | Line 1 | How to paste and fill in the script. |
| Settings | `$TenantId = ` | Nine lines `$Name = '...'`. The first four hold `Required-...` placeholders; the rest are empty. |
| Header note | `# Nothing below needs changing.` | Lists the 8 files with their line counts, where they are saved, and which modules are used. |
| Checks | `$ErrorActionPreference = 'Stop'` | `Get-Setting` and `Assert-Setting` calls (steps 1 to 4). |
| The tool's files | `# ---- The tool's files, in full` | `$files = [ordered]@{}`, then one block per file under a heading such as `# ==== File 3 of 8: src\modules\MQueryLineage.psm1 (712 lines)`. |
| Save step | `# ---- Save the tool once per version` | Steps 5 and 6. |
| Run | `# ---- Run in 64-bit Windows PowerShell` | Steps 7 to 10. |

Each file block has this form:

```powershell
$files['src\modules\RunProgress.psm1'] = @'
...file text...
'@
```

A single-quoted here-string ends at the first line that starts with `'@`. Two source lines start that way (line 29
of `MQueryLineage.psm1` and line 122 of `LauncherArguments.psm1`). They are embedded as `#~'@` and restored when
saved.

## The launcher

V2 is about 142 KB. Pasted into a Run .NET Script activity, it fails with "Error initializing extension" before any
of it runs, as any pasted script of that size does. So V2 is copied to the runbook server as a file, and
`PowerBI-Lineage.Orchestrator.V2.Launcher.ps1` (about 5 KB) is pasted into the activity instead.

### Launcher flow

1. Read `$ScriptPath`; if it is empty or a `Required-...` placeholder, read `LINEAGE_SCRIPT_PATH`. Throw if neither is set.
2. Throw if no file exists at that path.
3. Read the file's bytes. If `$ScriptSha256` is set, check it is 64 hex characters and that the file's SHA-256 matches it (either case).
4. Decode the bytes as UTF-8 (dropping a byte order mark). Throw unless the text contains `POWER BI REPORT LINEAGE` and a line `$files = [ordered]@{}`, so only V2 is run.
5. For each of the nine settings with a value (not empty, not a `Required-...` placeholder), set its environment variable in the activity's process, remembering the previous value.
6. Run V2's text with `& ([scriptblock]::Create($text))`: the same as if V2 had been pasted. V2 reads its settings from those variables, because the settings inside the file are still placeholders.
7. Restore every environment variable to its previous value, whether the run succeeded or failed. V2's output, or its error, becomes the activity's result.

### Launcher settings

| Setting | Environment variable set for V2 | Required |
|---|---|---|
| `$ScriptPath` | none (read from `LINEAGE_SCRIPT_PATH` when empty) | Yes |
| `$ScriptSha256` | none | No |
| `$TenantId` | `LINEAGE_TENANT_ID` | Yes |
| `$AppId` | `LINEAGE_CLIENT_ID` | Yes |
| `$ClientSecret` | `PBI_CLIENT_SECRET` | This or `$CertificateThumbprint` |
| `$ExcelPath` | `LINEAGE_EXCEL_PATH` | Yes |
| `$OutputFormat` | `LINEAGE_OUTPUT_FORMAT` | No |
| `$Mode` | `LINEAGE_MODE` | No |
| `$WorkspaceIds` | `LINEAGE_WORKSPACE_IDS` | No |
| `$CertificateThumbprint` | `LINEAGE_CERTIFICATE_THUMBPRINT` | No |
| `$TimeoutMinutes` | `LINEAGE_TIMEOUT_MINUTES` | No |

A setting left empty in the launcher leaves any variable already set in the activity's environment in place. V2 then
checks every setting as described in **Script functions**.

### Launcher errors

| Case | Message |
|---|---|
| No path | `The setting ScriptPath is required: the full path of PowerBI-Lineage.Orchestrator.V2.ps1 on this server.` |
| No file | `PowerBI-Lineage.Orchestrator.V2.ps1 was not found at <path>. Copy it to the runbook server and check ScriptPath.` |
| Bad hash setting | `The setting ScriptSha256 has an invalid value: <value>` |
| File changed | `<path> has changed: its SHA-256 is <actual>, not <expected>. Check the file before running it.` |
| Another file | `<path> is not PowerBI-Lineage.Orchestrator.V2.ps1.` |
| V2 fails | V2's own error, unchanged (see **Script errors**). |

### Launcher limits

- The launcher trusts the file at `$ScriptPath`. Set `$ScriptSha256`, and allow only administrators to change the folder.
- Settings are passed as environment variables of the activity's process for the length of the run, as V2 passes them to its own 64-bit process.
- The launcher is plain ASCII with no backticks, like V1, and is well under the size Orchestrator accepts.

<!-- shared:script -->
## Script functions

The Orchestrator script defines two functions of its own. Everything else it runs is in **The files inside**.

### Get-Setting

Returns a setting's value, falling back to an environment variable.

| Parameter | Type | Description |
|---|---|---|
| `Typed` | string | The value in the script. |
| `EnvironmentName` | string | The environment variable to read if `Typed` is empty or a placeholder. |

**Returns:** the trimmed value, or an empty string. A value matching `^Required-.*$` counts as empty, from either
source.
**Errors:** none.

### Assert-Setting

Checks one setting.

| Parameter | Type | Description |
|---|---|---|
| `Name` | string | Setting name used in messages. |
| `Value` | string | The value. |
| `Pattern` | string | Regular expression the value must match. |
| `Optional` | bool | If `$true`, an empty value passes. |

**Returns:** nothing.
**Errors:** `The setting <Name> is required: replace its Required-... placeholder with a value.` when a required
value is empty; `The setting <Name> has an invalid value: <Value>` when it does not match.

Patterns used:

| Setting | Pattern | Optional |
|---|---|---|
| `TenantId` | `^[A-Za-z0-9.-]+$` | No |
| `AppId` | GUID, `8-4-4-4-12` hex | No |
| `ExcelPath` | `^[^"<>\|*?]+$` | No |
| `OutputFormat` | `^(Excel\|CSV)$` | Yes |
| `Mode` | `^(Admin\|User\|Auto)$` | Yes |
| `WorkspaceIds` | 36 characters of hex or `-`, comma-separated | Yes |
| `CertificateThumbprint` | `^[0-9A-Fa-f]{40}$` | Yes |
| `TimeoutMinutes` | `^[0-9]{1,4}$` | Yes |

### Environment passed to the run

| Variable | Value |
|---|---|
| `LINEAGE_TENANT_ID`, `LINEAGE_CLIENT_ID`, `LINEAGE_EXCEL_PATH`, `LINEAGE_MODE`, `LINEAGE_WORKSPACE_IDS`, `LINEAGE_CERTIFICATE_THUMBPRINT`, `PBI_CLIENT_SECRET` | The checked settings. An empty setting is removed from the child's environment rather than inherited. |
| `PSModulePath` | The host's value without entries containing `\PowerShell\` (PowerShell 7 folders). |
| `LOCALAPPDATA` | Set to `<installRoot>\LocalAppData` only if the host has none. |

`$OutputFormat` and `$TimeoutMinutes` are not passed on: the format is carried by the `.xlsx` or `.csv` extension
of `LINEAGE_EXCEL_PATH`, and the timeout is applied by this script.

## Script errors

| Case | Message or result |
|---|---|
| A setting missing or malformed | Thrown before anything is unpacked (see `Assert-Setting`). |
| No secret and no certificate | `Set ClientSecret or CertificateThumbprint.` |
| `$ExcelPath` ends in another extension of 2 to 5 letters | `The setting ExcelPath must be a folder, a .xlsx file or a .csv file: <path>` |
| Tool exits non-zero | `Power BI lineage run failed: <reason> Log: <log path>`. The reason is standard error with `ERROR:` removed, or the last 5 non-empty output lines. |
| Timeout | Process tree stopped; `Power BI lineage run did not finish within <n> minutes and was stopped. Log: <log path>` |
| Log cannot be written | The log path in the message becomes `(log not written: <reason>)`. |

`$ErrorActionPreference` is `Stop`, so any other error also fails the activity.

## Script limits

- A value must not contain a single quote: it would end the string.
- A folder whose name ends in `.` and 2 to 5 letters, such as `bi.data`, is read as a file and refused.
- `$TimeoutMinutes = '0'` passes the check and stops the run at once.
- A run of a new version deletes older version folders without checking whether another run is using one.
- The log is written only after the child process ends; there is no log while it runs.
- A secret typed into the script is stored in the Orchestrator database as plain text. Subscribe to an encrypted variable, or use a certificate.
<!-- /shared:script -->

## What it writes

| Location | What | Lifetime |
|---|---|---|
| `%ProgramData%\PowerBI-Lineage\<version>\` | The 8 files (UTF-8 with byte order mark, CRLF line endings) and `.complete`. Falls back to `PowerBI-Lineage` under the temp folder if `%ProgramData%\PowerBI-Lineage` cannot be created. | Until a different version runs. Only 12-hex folder names are deleted. |
| `<temp>\PowerBI-Lineage-<run id>.out.txt`, `.err.txt` | The child's standard output and error. | Deleted after the run. |
| `$ExcelPath` with extension `.log` | Standard output followed by standard error. | Replaced when the name repeats. |
| `$ExcelPath` | Workbook (`.xlsx`) or CSV. | A folder path gets a new dated name each run. |
| `$ExcelPath` with extension `.csv` | The CSV, written by the tool. | As above. |
| `report-lineage-yyyyMMdd-HHmmss\` in the `$ExcelPath` folder | `report-lineage.json`. | Kept. |
| The run account's PowerShell module folder | `MicrosoftPowerBIMgmt.Profile`, and `ImportExcel` unless CSV only, only if found in no module folder. | Permanent. |

## How it is built

The launcher is `orchestrator/OrchestratorLauncherV2.ps1`, copied by `build/New-OrchestratorRunbook.ps1` with CRLF
line endings after checking that it parses, is plain ASCII and has no backticks. The tests run it in a 32-bit host
against a copy of V2, and check that a changed hash and a missing file are refused.

`build/New-OrchestratorRunbook.ps1` builds V2 in the same run as V1, from the same template
(`orchestrator/OrchestratorTool.ps1`) and the same 8 files:

- It replaces V1's header note with a list of the files and their line counts.
- It replaces everything from `# ---- Unpack the tool once per version` up to `# ---- Run in 64-bit Windows PowerShell` with the file blocks and the save step.
- It fills the settings with the same placeholders as V1, converts line endings to CRLF and writes UTF-8 without a byte order mark.

The build throws if the template's header note or unpack section has changed, a source has a line starting with
`#~'@`, a source contains Orchestrator's published-data marker, the result does not parse, or it contains a
non-ASCII character. Unlike V1, backticks are allowed.

`tests/OrchestratorRunbook.Tests.ps1` checks that:

- V2 is byte for byte the same as a fresh build;
- it has no `$payload`;
- its file blocks are the 8 files in order, each equal to its source once `#~'@` is turned back into `'@`;
- the text before `# Nothing below needs changing.` and from `# ---- Run in 64-bit Windows PowerShell` onwards is identical to V1.

The tests that run the script in 32-bit and 64-bit hosts use V1 only.

## Limits of V2

- The file is about 142 KB and 3,021 lines. It contains 16 backticks on 12 lines, all in the embedded tool code.
- V2's version is a hash of the file text; V1's is a hash of the compressed bytes. The same sources therefore unpack to different folders from V1 and V2, and running one deletes the other's folder.
- V2 cannot be pasted into an activity: it is too large. Use the launcher.

## Reading V1's compressed block

V1 carries the same files as V2, gzip-compressed and base64-encoded. To read them, save V1 as
`PowerBI-Lineage.Orchestrator.ps1` and run:

```powershell
$v1 = Get-Content .\PowerBI-Lineage.Orchestrator.ps1 -Raw
$b64 = [regex]::Match($v1, "(?s)\`$payload = @'(.*?)'@").Groups[1].Value -replace '\s', ''
$gzip = New-Object IO.Compression.GZipStream ([IO.MemoryStream][Convert]::FromBase64String($b64)), ([IO.Compression.CompressionMode]::Decompress)
(New-Object IO.StreamReader $gzip).ReadToEnd() | Set-Content .\v1-decoded.txt
```

`v1-decoded.txt` holds the 8 files, each after a line `=====LINEAGE-FILE: <path>=====`. They match V2's blocks
exactly. Outside the files, V1 and V2 differ only in the header note and the section that holds and saves them.

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
