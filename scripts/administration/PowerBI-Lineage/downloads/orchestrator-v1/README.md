# PowerBI-Lineage.Orchestrator.ps1 (V1)

A System Center Orchestrator script that lists, for every Power BI report, the semantic model, tables, and the
server, database, schema and table behind them, with the gateway. It only reads from Power BI and changes nothing
there. Paste the whole file into one Run .NET Script activity.

The tool's code is compressed inside this script so the paste stays small (57 KB). `PowerBI-Lineage.Orchestrator.V2.ps1` is the same script with the code as readable plain text; use V2 when someone needs to review what runs.

## How it works

It is one self-contained script. Nothing is downloaded except, if missing, the two PowerShell modules below.

1. **Settings.** It reads the settings at the top (or their environment variables) and checks them.
2. **Save the tool's files.** The tool's 8 files are inside this script, gzip-compressed and base64-encoded (the long block of letters and digits). On the first run of this
   version it writes them to `%ProgramData%\PowerBI-Lineage\<version>\` (`<version>` is a 12-character hash of
   the files) and leaves a `.complete` marker. Later runs of the same version find the marker and reuse the files. A
   new version deletes the older version folders.
   ```
   %ProgramData%\PowerBI-Lineage\<version>\
     Invoke-LineageRun.ps1
     src\Get-PbiReportLineage.ps1
     src\Export-PbiLineageWorkbook.ps1
     src\modules\Prerequisites.psm1, PowerBIRest.psm1, MQueryLineage.psm1, RunProgress.psm1, LauncherArguments.psm1
   ```
   These files are **saved, not installed**: they are not registered with PowerShell and nothing else on the server
   uses them.
3. **Run them.** It starts 64-bit Windows PowerShell on the saved `Invoke-LineageRun.ps1`, passing the settings as
   environment variables (never on a command line). That runs `Get-PbiReportLineage.ps1`, which loads its four
   modules from the saved `src\modules` folder with `Import-Module <path>` and does the work.
4. **Outside modules.** `Prerequisites.psm1` looks for `MicrosoftPowerBIMgmt.Profile` (Microsoft) and `ImportExcel`
   (community). Only if one is missing does it install it from the PowerShell Gallery for the service account. These
   two are the only things ever installed.
5. **Finish.** It waits for the run (180 minutes by default), writes a `.log` next to the output, and fails the
   activity with the reason if the run failed.

Why files at all: `Import-Module` loads modules from files, and the work must run in a separate 64-bit PowerShell,
because Orchestrator's own PowerShell is 32-bit (or PowerShell 7 in Orchestrator 2022 and 2025).

## Run it

1. In **Runbook Designer**, drag a **new Run .NET Script** activity from **Activities > System** onto a runbook.
   Set **Type** to **PowerShell**.
2. Open the script in Notepad, select all, copy, and paste it into the **Script** box.
3. Replace each `Required-...` placeholder at the top (see **Settings**).
4. Check the runbook in and run it.

It works with Orchestrator 2019, 2022 and 2025. To update, paste the new file over the whole script and fill in the
settings again.

## Settings

Fill these in at the top of the script. Values go between the single quotes and must not contain a single quote. A
setting left empty, or left as its `Required-...` placeholder, is read from the environment variable shown.

| Setting | Required | Default | Environment variable | Value |
|---|---|---|---|---|
| `$TenantId` | Yes | | `LINEAGE_TENANT_ID` | Tenant ID or domain, e.g. `contoso.onmicrosoft.com`. |
| `$AppId` | Yes | | `LINEAGE_CLIENT_ID` | The service principal's application (client) ID. |
| `$ClientSecret` | This or `$CertificateThumbprint` | | `PBI_CLIENT_SECRET` | The client secret. See **Keep the secret safe**. |
| `$ExcelPath` | Yes | | `LINEAGE_EXCEL_PATH` | A folder, a `.xlsx` file or a `.csv` file (CSV only). |
| `$OutputFormat` | No | `Excel` | `LINEAGE_OUTPUT_FORMAT` | `Excel` (workbook and CSV) or `CSV`. |
| `$Mode` | No | `Admin` | `LINEAGE_MODE` | `Admin` (whole tenant), `User` (workspaces the app belongs to) or `Auto`. |
| `$WorkspaceIds` | No | All | `LINEAGE_WORKSPACE_IDS` | Comma-separated workspace IDs. |
| `$CertificateThumbprint` | This or `$ClientSecret` | | `LINEAGE_CERTIFICATE_THUMBPRINT` | A certificate in `LocalMachine\My`, instead of a secret. |
| `$TimeoutMinutes` | No | `180` | `LINEAGE_TIMEOUT_MINUTES` | Stop the run after this many minutes. |

## Keep the secret safe

Orchestrator stores activity scripts in its database in plain text. Instead of typing the secret:

- create an **encrypted variable** in Runbook Designer, then select the text between the quotes of `$ClientSecret`,
  right-click, and choose **Subscribe > Variable**; or
- leave `$ClientSecret` as its placeholder and use a certificate (`$CertificateThumbprint`), installed with its private
  key in `LocalMachine\My`, readable by the Orchestrator Runbook Service account.

Keep activity-specific logging off for this runbook. The secret is passed to the run as an environment variable,
never on a command line, and the tool does not write it to any file or log.

## Permissions it needs

| Scope | Needs |
|---|---|
| Whole tenant (`Admin` mode) | A service principal in a security group allowed by the tenant setting **Service principals can access read-only admin APIs**, with no Power BI API permissions that need admin consent. The tenant settings **Enhance admin APIs responses with detailed metadata** and **Enhance admin APIs responses with DAX and mashup expressions** turned on. |
| Only its own workspaces (`User` mode) | **Contributor** or higher on each workspace, and the tenant setting **Dataset Execute Queries REST API** turned on. |

## Runbook server requirements

- **Modules:** to avoid any download, install them once in an elevated PowerShell:
  `Install-Module MicrosoftPowerBIMgmt.Profile, ImportExcel -Scope AllUsers` (`ImportExcel` is not needed for CSV only).
- **Access:** the Orchestrator Runbook Service account needs write access to the `$ExcelPath` folder.
- **Disk:** `%ProgramData%\PowerBI-Lineage` (falls back to `%TEMP%\PowerBI-Lineage` if it cannot be written).

## What it connects to

| Address | Why | When |
|---|---|---|
| `login.microsoftonline.com` | Sign-in | Every run |
| `api.powerbi.com` | Read Power BI metadata (read-only) | Every run |
| `www.powershellgallery.com` | Install `MicrosoftPowerBIMgmt.Profile` (Microsoft) or `ImportExcel` (community) | Only if the module is not already installed. Pre-install both and this is never contacted. |

It never contacts GitHub or any other source of code. It never reads report data, only metadata and Power Query code.

## What you get

| File | Contents |
|---|---|
| `PowerBI-Lineage_DDMMYYHHMM.xlsx` | Workbook: **Summary**, **All Lineage** (one row per report, table and source), **Source Objects** (each database object and the reports that use it), **Issues**, and one sheet per workspace. |
| `PowerBI-Lineage_DDMMYYHHMM.csv` | The All Lineage rows, in full. |
| `report-lineage-<date>\report-lineage.json` | Everything collected, untruncated. |

Main columns: `WorkspaceName`, `ReportName`, `DatasetName`, `TableName`, `SourceType`, `Server`, `Database`,
`Schema`, `SourceObject`, `GatewayName`, `IsSnowflakeConnection`, `ObjectOrigin`, `Notes`, `SourceExpression`.

File names above are for a folder as the output path, which gets new dated files each run. A `.xlsx` or `.csv` file path is replaced each run; a
`.csv` path writes the CSV only (no workbook, and `ImportExcel` is not needed).

Orchestrator runs also write `PowerBI-Lineage_DDMMYYHHMM.log` next to the output, because Orchestrator does not keep
the activity's console output.

## What it leaves on the server

| Location | What | Kept |
|---|---|---|
| `%ProgramData%\PowerBI-Lineage\<version>\` | The tool's 8 files and `.complete` | Until a different version runs |
| `%TEMP%\PowerBI-Lineage-<run id>.out.txt`, `.err.txt` | The run's output while it runs | Deleted at the end of the run |
| The `$ExcelPath` folder | The output files and a `.log` | Yours to manage |
| PowerShell module folders | `MicrosoftPowerBIMgmt.Profile`, `ImportExcel`, only if they were missing | Until removed |

## Troubleshooting

| Message or symptom | What to do |
|---|---|
| "Error initializing extension" | Drag a **new** Run .NET Script activity from **Activities > System**, set **Type** to **PowerShell** and paste again. |
| "The setting ... is required" or "has an invalid value" | Replace every `Required-...` placeholder. `$AppId` must be a GUID; `$ExcelPath` a folder, `.xlsx` or `.csv`. |
| "Could not install the ... module automatically" | The server cannot reach the PowerShell Gallery. Install the modules as in **Runbook server requirements**. |
| "This service principal cannot use the Power BI admin APIs" | Check **Permissions it needs**, or set `$Mode = 'User'`. |
| Rows noting "No table metadata returned" | Turn on the two **Enhance admin APIs responses** tenant settings. |
| The run fails | The reason is in the activity's error summary; the detail is in the `.log` next to the output. |

## Files in this folder

| File | What it is |
|---|---|
| `PowerBI-Lineage.Orchestrator.ps1` | The script to paste. |
| `README.md` | This page. |
| [`documentation.md`](documentation.md) | The detail: the script section by section, its functions, the files inside and their functions, how it is built. |
