# Power BI Report Lineage: which database, schema and table feeds every report

Find out where the data in your Power BI reports comes from. For every report in your tenant, or in the workspaces
you can reach, this tool lists:

```
Report ─► Semantic model (dataset) ─► Table ─► Server / Database / Schema / Source table or view ─► Gateway
```

It answers questions like:

- Which SQL Server, database, schema and table populates this report?
- Which reports break if we change or drop `dbo.FactSales`?
- Which gateway does each report depend on?

The result is an **Excel workbook** (with a sheet per workspace) and a **JSON** file with the complete data. The
tool only reads from Power BI; it changes nothing there.

---

## Pick your file

Each file is self-contained: download just the one you need.

| I want to | Download | Instructions |
|---|---|---|
| Run it on my computer | [`PowerBI-Lineage.cmd`](PowerBI-Lineage.cmd) | [1. Run it on your desktop](#1-run-it-on-your-desktop) |
| Send it to someone by email | [`PowerBI-Lineage.zip`](PowerBI-Lineage.zip) (the same `.cmd`, zipped) | [1. Run it on your desktop](#1-run-it-on-your-desktop) |
| Run it on a schedule, e.g. Task Scheduler, SQL Server Agent, UiPath or Control-M | [`PowerBI-Lineage.cmd`](PowerBI-Lineage.cmd) | [2. Run it unattended](#2-run-it-unattended) |
| Run it in a System Center Orchestrator runbook | [`PowerBI-Lineage.Orchestrator.ps1`](PowerBI-Lineage.Orchestrator.ps1) (paste into one activity) | [3. Run it in System Center Orchestrator](#3-run-it-in-system-center-orchestrator) |

To download a file on GitHub, open it and choose **Download raw file**.

---

## Before you start: Power BI permissions

The tool can cover the whole tenant, or only the workspaces the signed-in account belongs to.

| Scope | Needs |
|---|---|
| **Whole tenant** (Admin mode) | A **Fabric / Power BI Administrator** account, or a service principal allowed to use read-only admin APIs (below). A Power BI admin must also enable the tenant settings **Enhance admin APIs responses with detailed metadata** and **Enhance admin APIs responses with DAX and mashup expressions**. |
| **Only my workspaces** (User mode) | **Contributor** or higher on each workspace that holds a semantic model, and the tenant setting **Dataset Execute Queries REST API** enabled. |

**Signing in:** on your desktop you can sign in with your own account or a service principal. Unattended and
Orchestrator runs always use a **service principal**: an app registration with a client secret or a certificate.

**Service principal for the whole tenant:** add the app to a security group allowed by the tenant setting
**Service principals can access read-only admin APIs**. The app registration must **not** have any Power BI API
permissions that need admin consent.

---

## 1. Run it on your desktop

1. Download [`PowerBI-Lineage.cmd`](PowerBI-Lineage.cmd).
2. Double-click it. If Windows warns about a downloaded file, choose **More info > Run anyway**.
3. Answer three questions:
   - **How to sign in:** your own account (a sign-in window opens), or a service principal with a client secret
     or certificate.
   - **Which reports:** every workspace in the tenant, or only workspaces you are a member of.
   - **Where to save the workbook:** press Enter for `Documents\Power BI Lineage`, or type a folder or a `.xlsx` file. In a folder the workbook is named `PowerBI-Lineage_DDMMYYHHMM.xlsx`, after the date and time of the run.
4. Watch the eight numbered steps complete, then open the workbook when asked.

```
  [1/8] Checking prerequisites ............... done
  [2/8] Signing in ........................... done, User peter@contoso.com
  ...
  [8/8] Saving results ....................... done, JSON, CSV and Excel
```

Nothing needs installing first:

- It runs on the Windows PowerShell built into Windows 10 and 11 (or PowerShell 7 if you have it).
- On the first run it installs two PowerShell modules, `MicrosoftPowerBIMgmt.Profile` and `ImportExcel`, for your
  user account only. No administrator rights are needed, but the computer must be able to reach
  powershellgallery.com.
- Microsoft Excel is not needed to create the workbook.

The tool's scripts are stored as plain text inside the `.cmd`: open it in Notepad to read exactly what it does.

**Sending it to someone:** share `PowerBI-Lineage.cmd` through Teams, OneDrive or SharePoint. Email usually blocks
`.cmd` files, so email [`PowerBI-Lineage.zip`](PowerBI-Lineage.zip) instead; the file inside can be double-clicked
without extracting it.

---

## 2. Run it unattended

For Windows Task Scheduler, SQL Server Agent, UiPath Orchestrator, Control-M, or anything else that runs a command
on a Windows machine.

Run `PowerBI-Lineage.cmd` **with arguments** and it runs unattended: no questions, no pause, plain log output, and
exit code `0` on success or `1` on failure, with the reason on the error output.

**With a certificate** (installed for the account the job runs as):

```bat
PowerBI-Lineage.cmd -Mode Admin -TenantId contoso.onmicrosoft.com -ClientId <app-id> -CertificateThumbprint <thumbprint> -ExcelPath "\\fileserver\bi"
```

**With a client secret:** the secret is never accepted on the command line, where job logs and process lists could
show it. Have the scheduler set the `PBI_CLIENT_SECRET` environment variable from its credential store:

```bat
set PBI_CLIENT_SECRET=<secret>
PowerBI-Lineage.cmd -Mode Admin -TenantId contoso.onmicrosoft.com -ClientId <app-id> -ExcelPath "\\fileserver\bi"
```

`-ExcelPath` takes a folder or a file:

- **A folder**, e.g. `"\\fileserver\bi"`: each run writes a new workbook named after its local date and time,
  `PowerBI-Lineage_DDMMYYHHMM.xlsx` (a run at 15:45 on 17 September 2026 writes `PowerBI-Lineage_1709261545.xlsx`).
  Earlier runs are kept.
- **A `.xlsx` file**, e.g. `"\\fileserver\bi\PowerBI-Lineage.xlsx"`: the same file is replaced on every run.
- **A `.csv` file**, e.g. `"\\fileserver\bi\PowerBI-Lineage.csv"`: **CSV only**, no workbook, replaced on every run.
  The `ImportExcel` module is not needed.

The CSV is named after the workbook, and the JSON is saved in a `report-lineage-<date>` folder next to it. `PowerBI-Lineage.cmd /?` lists every
option, including
`-WorkspaceId <id>,<id>` to limit the run and `-SkipExcel` for JSON and CSV only.

On the machine that runs the job:

- If it cannot reach powershellgallery.com, install the modules first:
  `Install-Module MicrosoftPowerBIMgmt.Profile, ImportExcel -Scope AllUsers`.
- The job's account needs write access to `%LOCALAPPDATA%` (where the tool unpacks) and to the output folder.

---

## 3. Run it in System Center Orchestrator

Use [`PowerBI-Lineage.Orchestrator.ps1`](PowerBI-Lineage.Orchestrator.ps1): **one file, pasted into one activity**.
Nothing is copied to the runbook server. The whole tool is inside the file as compressed text (the long block of
letters and digits at the bottom); it unpacks itself on the first run.

### Add it to a runbook

1. In **Runbook Designer**, create a runbook inside a folder.
2. Drag a **new Run .NET Script** activity from **Activities > System** onto the runbook. Use a new activity rather
   than one from an imported runbook or a copy of another activity.
3. On its **Details** tab, set **Type** to **PowerShell**.
4. Open `PowerBI-Lineage.Orchestrator.ps1` in Notepad, select all (**Ctrl+A**), copy, and paste it into the
   **Script** box, replacing anything already there.
5. Fill in the settings at the top. Required settings start with placeholder text such as `'Required-TenantId'`:
   replace each placeholder with your value. Optional settings start empty.

   ```powershell
   $TenantId = 'contoso.onmicrosoft.com'                # tenant ID or domain
   $AppId = '00000000-0000-0000-0000-000000000000'      # the service principal's application (client) ID
   $ClientSecret = 'Required-ClientSecret-or-CertificateThumbprint'  # see "Keep the client secret safe" below
   $ExcelPath = '\\fileserver\bi'                        # folder: PowerBI-Lineage_DDMMYYHHMM.xlsx each run; or a .xlsx/.csv file
   $OutputFormat = ''                                    # optional: Excel (default: workbook + CSV) or CSV (CSV only)
   $Mode = ''                                            # optional: Admin (default, whole tenant) or User
   $WorkspaceIds = ''                                    # optional: comma-separated workspace IDs
   $CertificateThumbprint = ''                           # optional: use a certificate instead of a secret
   $TimeoutMinutes = ''                                  # optional: default 180
   ```

   Values go between the single quotes and must not contain a single quote. Instead of typing a value you can
   subscribe to one: select the text between the quotes, right-click, and choose **Subscribe > Published Data**
   (for example an Initialize Data parameter).
6. Select **Finish**, check the runbook in, and run it.

To update the tool later, paste the new file over the whole script and fill in the settings again.

The activity **succeeds** when the run succeeds. In the `$ExcelPath` folder you then find the workbook, a run log
and CSV named after it (for example `PowerBI-Lineage_1709261545.xlsx`, `.log` and `.csv`), and a
`report-lineage-<date>` folder with the JSON. `$ExcelPath` works as for [unattended runs](#2-run-it-unattended): a folder
gets a new dated workbook each run, and a `.xlsx` file is replaced each run.
The activity **fails**, with the reason in its error summary, when the run fails; the full detail is in the run log.

**CSV only:** set `$OutputFormat = 'CSV'` (or give `$ExcelPath` a `.csv` file). Each run then writes
`PowerBI-Lineage_DDMMYYHHMM.csv` and its `.log`, with no workbook, and the server doesn't need the `ImportExcel` module.

### Keep the client secret safe

A secret typed into the script is stored in the Orchestrator database in plain text. Instead:

1. Create a **Variable** in Runbook Designer, tick **Encrypted variable**, and enter the secret.
2. In the pasted script, select the placeholder text between the quotes of `$ClientSecret`, right-click, choose
   **Subscribe > Variable**, and pick it.
3. Keep activity-specific logging off for this runbook.

Or leave `$ClientSecret` as its placeholder and use a certificate: install it with its private key in **LocalMachine\My** on the
runbook server, give the Orchestrator Runbook Service account read access to the private key, and set
`$CertificateThumbprint`.

The secret is passed to the tool through an environment variable, never on a command line.

### Runbook server requirements

- **Modules:** `MicrosoftPowerBIMgmt.Profile` (part of `MicrosoftPowerBIMgmt`) and `ImportExcel` (not needed for CSV only). Modules already
  installed for 32-bit or 64-bit Windows PowerShell are used as they are; only a missing one is installed. If the
  server cannot reach powershellgallery.com, install them first in an elevated PowerShell:
  `Install-Module MicrosoftPowerBIMgmt.Profile, ImportExcel -Scope AllUsers`.
- **Access:** the **Orchestrator Runbook Service** account needs write access to the `$ExcelPath` folder.
- **Disk:** the tool unpacks itself to `%ProgramData%\PowerBI-Lineage` on first run. Windows lets every account
  create folders under `%ProgramData%` by default.

To test outside Orchestrator, fill in the settings in a copy of `PowerBI-Lineage.Orchestrator.ps1` and run it with
Windows PowerShell; delete the copy afterwards so the secret isn't left on disk.

### Alternative: import a ready-made runbook

[`PowerBI-Lineage.ois_export`](PowerBI-Lineage.ois_export) contains the same script in a runbook, with each setting
subscribed to an **Initialize Data** parameter (Tenant ID, App ID, Client secret, Excel path, Output format, and the
other optional ones):

1. In Runbook Designer, right-click a folder and choose **Import**, then select the file.
2. Clear **Import Orchestrator encrypted data** (the file contains none).
3. Open the **Power BI** folder and run **Power BI Report Lineage**.

This file was generated to match the Runbook Designer export format but has not been import-tested on an
Orchestrator server. If it fails to import, or its activity fails with "Error initializing extension", delete the
imported runbook and use [Add it to a runbook](#add-it-to-a-runbook) instead. A client secret entered as an Initialize
Data parameter also appears in the job's run history, so subscribe an encrypted variable instead for production.

---

## What you get

| File | Contents |
|---|---|
| `*.xlsx` | The workbook (sheets below). |
| `report-lineage.json` | Everything collected, untruncated, in a `report-lineage-<date>` folder next to the workbook. |
| `*.csv` | The All Lineage rows as CSV, named after the workbook and saved next to it. Nothing is cut short, and it opens directly in Excel. For the CSV alone, give a `.csv` path (or `$OutputFormat = 'CSV'` in Orchestrator). |
| `*.log` | Orchestrator runs only: the run's output, named after the workbook. |

| Sheet | Contents |
|---|---|
| **Summary** | When and how the run was made, totals, and links to every sheet. |
| **All Lineage** | One row per report, model table and source object. |
| **Source Objects** | Each database table, view, file or feed, with the gateways, reports and model tables that use it. Use it for impact analysis. |
| **Issues** | Anything that could not be read, such as a semantic model without permission or gateway names that need gateway admin rights. |
| One sheet per workspace | The rows for the reports in that workspace. |

Main columns: `WorkspaceName`, `ReportName`, `DatasetName` (the semantic model), `TableName`, `SourceType`,
`Server`, `Database`, `Schema`, `SourceObject`, `Location` (files and URLs), `NativeQuery`, `GatewayName`,
`ConnectionDetails`, `IsSnowflakeConnection` (`Y` when the source type, server or connection details mention Snowflake, including ODBC connections to it), `ObjectOrigin`, `Notes` and `SourceExpression` (the Power Query code the source was read from).
IDs sit next to each name.

Excel holds at most 32,767 characters per cell. A longer query is cut in the workbook, marked, and counted on the
Summary sheet; the JSON keeps the full text.

---

## How the source table is found

Power BI does not store "this table is loaded from `dbo.FactSales`" as a field. The tool reads each model table's
Power Query (M) code:

- **Connections** give the server and database: `Sql.Database`, `Oracle.Database`, `Snowflake.Databases`,
  `Databricks.Catalogs`, `PostgreSQL.Database`, `Web.Contents`, `SharePoint.Files`, Fabric lakehouses, dataflows
  and more.
- **Navigation steps** give the schema and table: `Source{[Schema="dbo",Item="FactSales"]}[Data]`.
- **Native SQL** (`[Query="..."]`, `Value.NativeQuery`) is scanned for the tables after `FROM`, `JOIN` and `EXEC`.
- **Parameters and shared queries** are followed, so `Sql.Database(ServerName, DatabaseName)` resolves to their values.

It reads the code without running it, so check the `ObjectOrigin` column:

| `ObjectOrigin` | Meaning |
|---|---|
| `Navigation` | Table picked directly in Power Query. Reliable. |
| `Native query` | Table named in SQL. A view or procedure may read further tables. |
| `Connection only` | Server and database known, table not: chosen dynamically, or a whole file or feed. |
| *(no source)* | Calculated table, calculation group, or no Power Query code returned. |

Paginated reports stop at the connection, because their queries live inside the report file. Reports published
through an app are listed once, under their workspace.

---

## Troubleshooting

Problems that don't stop a run are counted in its summary ("3 issues need attention") and listed on the **Issues**
sheet.

| Message or symptom | What to do |
|---|---|
| "Could not install the ... module automatically" | The network blocks the PowerShell Gallery. Ask IT to allow `powershellgallery.com`, or install `MicrosoftPowerBIMgmt.Profile` and `ImportExcel` with `-Scope AllUsers`. |
| "This account is not a Power BI / Fabric administrator" | Choose **Only workspaces I am a member of** (or `-Mode User` / `$Mode = 'User'`), or ask for the admin role. |
| "This service principal cannot use the Power BI admin APIs" | See [Service principal for the whole tenant](#before-you-start-power-bi-permissions), or use User mode. |
| Rows noting "No table metadata returned" | A Power BI admin needs to enable the two **Enhance admin APIs responses** tenant settings. |
| "Unattended runs sign in as a service principal" | Pass `-TenantId` and `-ClientId` with `-CertificateThumbprint`, or set `PBI_CLIENT_SECRET`. |
| "Error initializing extension" in Orchestrator | Orchestrator could not start the activity, before any of the script ran. Drag a **new** Run .NET Script activity from **Activities > System** (not one from an imported runbook or a copied activity), set **Type** to **PowerShell**, and paste the whole of `PowerBI-Lineage.Orchestrator.ps1` ([section 3](#3-run-it-in-system-center-orchestrator)). |
| "The setting ... is required" or "has an invalid value" | Orchestrator: check the settings at the top of the activity script, and replace every `Required-...` placeholder. `$AppId` must be a GUID and `$ExcelPath` must be a folder or end in `.xlsx`. |
| The window closes at once, or scripts are blocked | Group Policy or AppLocker blocks PowerShell scripts. Ask IT. |

