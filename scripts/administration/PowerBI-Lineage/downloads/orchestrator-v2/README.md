# PowerBI-Lineage.Orchestrator.V2.ps1

A System Center Orchestrator runbook script that traces every Power BI report to the database, schema and table
behind it:

```
Report ─► Semantic model ─► Table ─► Server / Database / Schema / Source table or view ─► Gateway
```

It writes the result to an Excel workbook, a CSV, a JSON file and a run log. It only reads from Power BI and changes
nothing there.

V2 is the version to review. It does exactly what
[`PowerBI-Lineage.Orchestrator.ps1`](../orchestrator-v1/PowerBI-Lineage.Orchestrator.ps1) (V1) does, but every line
of code is in the file as plain text. V1 carries the same code gzip-compressed and base64-encoded so the pasted
script stays small. V2 has nothing compressed or encoded, so what you read is what runs.

| | |
|---|---|
| **Type** | Download: [`PowerBI-Lineage.Orchestrator.V2.ps1`](PowerBI-Lineage.Orchestrator.V2.ps1) (about 142 KB, 3,021 lines, plain ASCII) |
| **Runs in** | System Center Orchestrator 2019, 2022 and 2025, in a Run .NET Script activity (Type: PowerShell) |
| **Signs in as** | A service principal (app registration) with a client secret or a certificate |
| **Contains** | Nine settings, checks, the 8 files of the tool as plain text, and the run section |
| **Reads** | Its settings (or `LINEAGE_*` and `PBI_CLIENT_SECRET` environment variables), and Power BI REST API metadata: workspaces, reports, semantic models, their Power Query code, and gateways |
| **Writes** | Files to the output location you choose, and the tool's scripts to `%ProgramData%\PowerBI-Lineage` |
| **Source** | MIT licence. Built from the same source as V1; see [Checking V2 against V1](#checking-v2-against-v1) |

---

## Use

1. In **Runbook Designer**, drag a **new Run .NET Script** activity from **Activities > System** onto a runbook, and
   set **Type** to **PowerShell**.
2. Open `PowerBI-Lineage.Orchestrator.V2.ps1` in Notepad, select all, copy, and paste it into the **Script** box.
3. Replace each `Required-...` placeholder at the top:

   ```powershell
   $TenantId = 'contoso.onmicrosoft.com'
   $AppId = '00000000-0000-0000-0000-000000000000'
   $ClientSecret = 'Required-ClientSecret-or-CertificateThumbprint'   # subscribe to an encrypted variable
   $ExcelPath = '\\fileserver\bi'                                     # a folder, or a .xlsx or .csv file
   ```

4. Check the runbook in and run it.

The activity succeeds when the run succeeds, and fails with the reason in its error summary when it does not. The
full detail is in the `.log` next to the output.

For the output columns, troubleshooting and the other ways to run the tool (desktop, Task Scheduler), see the
[tool overview](../../README.md).

## Inputs

The settings are the same as V1. A setting left empty, or still starting with `Required-`, is read from the
environment variable in brackets.

| Name | Required | Default | Description |
|---|---|---|---|
| `$TenantId` (`LINEAGE_TENANT_ID`) | Yes | | Tenant ID or domain. |
| `$AppId` (`LINEAGE_CLIENT_ID`) | Yes | | Application (client) ID, a GUID. |
| `$ClientSecret` (`PBI_CLIENT_SECRET`) | This or `$CertificateThumbprint` | | Client secret. |
| `$ExcelPath` (`LINEAGE_EXCEL_PATH`) | Yes | | A folder (writes `PowerBI-Lineage_DDMMYYHHMM.xlsx`), a `.xlsx` file, or a `.csv` file (CSV only). |
| `$OutputFormat` (`LINEAGE_OUTPUT_FORMAT`) | No | `Excel` | `Excel` or `CSV`. |
| `$Mode` (`LINEAGE_MODE`) | No | `Admin` | `Admin` or `User`. `Auto` is also accepted. |
| `$WorkspaceIds` (`LINEAGE_WORKSPACE_IDS`) | No | All workspaces | Comma-separated workspace IDs. |
| `$CertificateThumbprint` (`LINEAGE_CERTIFICATE_THUMBPRINT`) | This or `$ClientSecret` | | 40 hex characters. |
| `$TimeoutMinutes` (`LINEAGE_TIMEOUT_MINUTES`) | No | `180` | Stop the run after this many minutes. |

## Outputs

`PowerBI-Lineage_DDMMYYHHMM.xlsx`, `.csv` and `.log` (or the names you give), and a `report-lineage-<date>` folder
with the JSON. See [What it writes on the runbook server](#what-it-writes-on-the-runbook-server).

---

## How the file is laid out

Read it top to bottom. It runs in the same order.

| Part | What it does |
|---|---|
| **Settings** (top) | Nine settings you fill in: tenant, app ID, secret or certificate, output path, and five optional ones. Nothing else in the file needs editing. |
| **Checks** | Reads each setting (or its environment variable if left blank), rejects missing or malformed values, and works out the output file name. |
| **The tool's files** | The 8 files of the tool, each written out in full under a heading such as `# ==== File 3 of 8: src\modules\MQueryLineage.psm1 (712 lines)`. The header at the top of the script lists all eight. |
| **Save the tool** | Saves the 8 files to `%ProgramData%\PowerBI-Lineage\<version>` the first time this version runs, and removes older versions. |
| **Run** | Starts 64-bit Windows PowerShell on `Invoke-LineageRun.ps1`, waits for it, saves the run log next to the output, and fails the activity with the reason if the run failed. |

The eight files it carries:

| File | Purpose |
|---|---|
| `Invoke-LineageRun.ps1` | Entry point. Reads the settings from environment variables and calls the main script. |
| `src\Get-PbiReportLineage.ps1` | Main script: signs in, lists workspaces and reports, collects each model's tables and Power Query code, resolves gateways. |
| `src\modules\MQueryLineage.psm1` | Reads Power Query (M) code as text to find the server, database, schema and table. It parses the code and never runs it. |
| `src\modules\PowerBIRest.psm1` | Calls the Power BI REST API, with retry on HTTP 429 (throttling) and 5xx responses. |
| `src\Export-PbiLineageWorkbook.ps1` | Writes the Excel workbook. |
| `src\modules\Prerequisites.psm1` | Finds the two PowerShell modules the tool needs, and installs them only if they are missing. |
| `src\modules\RunProgress.psm1` | Progress and log output. |
| `src\modules\LauncherArguments.psm1` | Argument handling for the desktop launcher (not used by Orchestrator runs, carried so the tool is complete). |

The CSV is written by `src\Get-PbiReportLineage.ps1`.

### The one change to the embedded code

Each file sits inside a PowerShell here-string, which ends at the first line that starts with `'@`. Two lines in the
tool start that way: line 29 of `MQueryLineage.psm1` and line 122 of `LauncherArguments.psm1`. They end here-strings
of their own. In V2 those two lines are shown as `#~'@`, and the save step turns them back into `'@`:

```powershell
$content = ($files[$name] -replace "(?m)^#~'@", "'@") -replace '\r?\n', $newLine
```

No other character of any file is changed.

---

## What it connects to

Every call is an HTTPS request from the runbook server. Nothing is sent anywhere other than the endpoints below.

| Endpoint | Why |
|---|---|
| `login.microsoftonline.com` | Service principal sign-in, through the `MicrosoftPowerBIMgmt.Profile` module. |
| `api.powerbi.com` | Power BI REST API, read-only metadata (below). |
| `www.powershellgallery.com` | **Only if** `MicrosoftPowerBIMgmt.Profile` or `ImportExcel` is not already installed on the server. Before installing, the tool also installs the NuGet package provider if version 2.8.5.201 or later is missing. Install the modules beforehand and neither happens. |

### Power BI API calls

**Admin mode** (the default: every workspace in the tenant) uses the read-only admin scanner APIs:

| Call | Purpose |
|---|---|
| `GET admin/groups?$top=1` | Checks the service principal can use the admin APIs. |
| `GET admin/workspaces/modified` | Lists workspace IDs (personal and inactive workspaces excluded). Skipped when `$WorkspaceIds` is set. |
| `POST admin/workspaces/getInfo` | Starts a metadata scan of up to 100 workspaces at a time: lineage, data source details, model schema and Power Query expressions. User lists are not requested (`getArtifactUsers=False`). |
| `GET admin/workspaces/scanStatus/{id}` | Waits for the scan to finish. |
| `GET admin/workspaces/scanResult/{id}` | Downloads the scan result. |

The `POST` call starts a scan and returns a scan ID. It creates nothing in the tenant.

**User mode** (`$Mode = 'User'`: only workspaces the app is a member of) uses the workspace APIs instead: `GET groups`,
`GET groups/{id}/reports`, `GET groups/{id}/datasets`, `GET .../datasets/{id}` and `GET .../datasets/{id}/datasources`,
and `POST datasets/{id}/executeQueries` running only these read-only DAX queries against each model:
`INFO.TABLES()`, `INFO.PARTITIONS()`, `INFO.EXPRESSIONS()` and, for models with refresh-policy partitions,
`INFO.REFRESHPOLICIES()`. They return the model's structure, not its data.

**Both modes** also call:

| Call | Purpose |
|---|---|
| `GET gateways`, `GET gateways/{id}/datasources/{id}` | Resolves gateway names, where the service principal has gateway rights. |
| `GET .../reports/{id}/datasources` | Connections of paginated reports and other reports not bound to a semantic model. |

**The tool never reads report data or row-level data.** It reads metadata and Power Query code only.

---

## Permissions it needs

| Scope | Needs |
|---|---|
| **Whole tenant** (Admin mode) | The service principal in a security group allowed by the tenant setting **Service principals can access read-only admin APIs**, and the tenant settings **Enhance admin APIs responses with detailed metadata** and **Enhance admin APIs responses with DAX and mashup expressions** enabled. The app registration must have **no** Power BI API permissions that need admin consent. |
| **Only its workspaces** (User mode) | **Contributor** or higher on each workspace, and the tenant setting **Dataset Execute Queries REST API** enabled. |
| **Runbook server** | The Orchestrator Runbook Service account needs write access to the output folder. |

---

## What it writes on the runbook server

| Location | What | Kept |
|---|---|---|
| `%ProgramData%\PowerBI-Lineage\<version>\` | The 8 files, exactly as embedded. `<version>` is the first 12 hex characters of a SHA-256 hash of their text, so a changed script saves to a new folder. | Until a different version runs, which deletes older version folders. |
| `%TEMP%\PowerBI-Lineage-<run id>.out.txt` / `.err.txt` | The run's console output, captured while it runs. | Deleted at the end of the run. |
| The output folder (`$ExcelPath`) | `PowerBI-Lineage_DDMMYYHHMM.xlsx`, `.csv` and `.log`, plus a `report-lineage-<date>` folder with the JSON. | Yours to manage. |
| The run account's PowerShell module folder | `MicrosoftPowerBIMgmt.Profile` and `ImportExcel`, only if not found in any module folder. | Permanent. |

If `%ProgramData%\PowerBI-Lineage` cannot be created, it falls back to `%TEMP%\PowerBI-Lineage`.

The output contains workspace, report and model names, server and database names, and the Power Query code of each
table, which can include native SQL. The JSON records the sign-in as `Service principal <app ID>`. It contains no
secret and no report data. Store it with the same care as other data-platform documentation.

---

## How it handles the secret

- **Never on a command line.** The settings, including the secret, are passed to the child PowerShell process as
  environment variables on that process only (`PBI_CLIENT_SECRET`, `LINEAGE_*`), so they do not show in process
  lists or command-line audit logs.
- **Not written to a file** by the script or the tool. The run log holds the child process's console output.
- **Stored by Orchestrator** if typed into the script: Orchestrator keeps activity scripts in its database in plain
  text. Avoid this by subscribing `$ClientSecret` to an **encrypted variable** (select the text between the quotes,
  right-click, **Subscribe > Variable**), or by leaving it as its placeholder and using a certificate in
  `LocalMachine\My` with `$CertificateThumbprint`.
- Keep activity-specific logging off for this runbook.

---

## Things a reviewer will notice

| What | Why |
|---|---|
| `-ExecutionPolicy Bypass` when starting PowerShell | The tool's `.ps1` files are saved at run time and are not signed. Bypass applies to that one process only and changes no machine or user policy. |
| It starts a second PowerShell process | Orchestrator's script host is 32-bit (or PowerShell 7 on .NET 8 in Orchestrator 2022/2025). The Power BI and Excel modules need 64-bit Windows PowerShell, so the script starts `System32\WindowsPowerShell\v1.0\powershell.exe` through `cmd.exe` from `Sysnative` (or `System32` when `Sysnative` does not exist). |
| `Install-Module` | Only for a module that is missing. It installs from PSGallery for the current account (`-Scope CurrentUser`). Pre-install both modules with `-Scope AllUsers` to rule this out. |
| `taskkill /T /F` | Stops the run, and anything it started, if it passes `$TimeoutMinutes` (default 180). |
| `PSModulePath` is rewritten for the child process | PowerShell 7 module folders are removed so Windows PowerShell does not load incompatible built-in modules. Nothing outside the run is affected. |
| Backticks in the embedded code | 16, on 12 lines, all in the tool's own code (escape characters such as `` "`r`n" `` and line continuations in help examples). V1 contains none because its code is encoded. |

---

## Checking V2 against V1

V1 and V2 are generated from the same source by `build/New-OrchestratorRunbook.ps1`. You can confirm the code is the
same yourself:

1. **The settings and the run section are identical.** Compare the two files: they differ only in the header note
   and the part between `# ---- Unpack the tool` (V1) or `# ---- The tool's files` (V2) and
   `# ---- Run in 64-bit Windows PowerShell`.
2. **The embedded files are identical.** From this folder, decode V1's payload and compare it with V2's files:

   ```powershell
   $v1 = Get-Content ..\orchestrator-v1\PowerBI-Lineage.Orchestrator.ps1 -Raw
   $b64 = [regex]::Match($v1, "(?s)\`$payload = @'(.*?)'@").Groups[1].Value -replace '\s', ''
   $gzip = New-Object IO.Compression.GZipStream ([IO.MemoryStream][Convert]::FromBase64String($b64)), ([IO.Compression.CompressionMode]::Decompress)
   (New-Object IO.StreamReader $gzip).ReadToEnd() | Set-Content .\v1-decoded.txt
   ```

   `v1-decoded.txt` holds the same 8 files, each after a line `=====LINEAGE-FILE: <path>=====`.

The tests in `tests/OrchestratorRunbook.Tests.ps1` check both: V2 must match what the build script produces byte for
byte, each embedded file must match its source, and everything around the files must match V1.

---

## Status

V2 was added on 28 September 2026. It has been checked on macOS PowerShell 7: it parses, and the 8 files it saves
are identical to the source. It has **not yet been run inside Orchestrator**. The first run should be in a test
runbook.

---

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../../docs/README.md)
- [Tool overview](../../README.md)
- [V1 README](../orchestrator-v1/README.md) and [V1 detailed documentation](../orchestrator-v1/documentation.md)
- [Runbook import](../runbook-import/README.md)
- Source pages: [Invoke-LineageRun.ps1](../../docs/Invoke-LineageRun.ps1/README.md),
  [Get-PbiReportLineage.ps1](../../docs/Get-PbiReportLineage.ps1/README.md),
  [Export-PbiLineageWorkbook.ps1](../../docs/Export-PbiLineageWorkbook.ps1/README.md),
  [MQueryLineage.psm1](../../docs/MQueryLineage.psm1/README.md),
  [PowerBIRest.psm1](../../docs/PowerBIRest.psm1/README.md),
  [Prerequisites.psm1](../../docs/Prerequisites.psm1/README.md),
  [RunProgress.psm1](../../docs/RunProgress.psm1/README.md),
  [LauncherArguments.psm1](../../docs/LauncherArguments.psm1/README.md)
