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
| Run it in a System Center Orchestrator runbook | [`PowerBI-Lineage.Orchestrator.ps1`](PowerBI-Lineage.Orchestrator.ps1) | [3. Run it in System Center Orchestrator](#3-run-it-in-system-center-orchestrator) |

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
   - **Where to save the workbook:** press Enter for `Documents\Power BI Lineage`, or type a path.
4. Watch the eight numbered steps complete, then open the workbook when asked.

```
  [1/8] Checking prerequisites ............... done
  [2/8] Signing in ........................... done, User peter@contoso.com
  ...
  [8/8] Saving results ....................... done, JSON and Excel
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
PowerBI-Lineage.cmd -Mode Admin -TenantId contoso.onmicrosoft.com -ClientId <app-id> -CertificateThumbprint <thumbprint> -ExcelPath "\\fileserver\bi\PowerBI-Lineage.xlsx"
```

**With a client secret:** the secret is never accepted on the command line, where job logs and process lists could
show it. Have the scheduler set the `PBI_CLIENT_SECRET` environment variable from its credential store:

```bat
set PBI_CLIENT_SECRET=<secret>
PowerBI-Lineage.cmd -Mode Admin -TenantId contoso.onmicrosoft.com -ClientId <app-id> -ExcelPath "\\fileserver\bi\PowerBI-Lineage.xlsx"
```

The JSON is saved in a `report-lineage-<date>` folder next to the workbook. `PowerBI-Lineage.cmd /?` lists every
option, including
`-WorkspaceId <id>,<id>` to limit the run and `-SkipExcel` for JSON only.

On the machine that runs the job:

- If it cannot reach powershellgallery.com, install the modules first:
  `Install-Module MicrosoftPowerBIMgmt.Profile, ImportExcel -Scope AllUsers`.
- The job's account needs write access to `%LOCALAPPDATA%` (where the tool unpacks) and to the output folder.

---

## 3. Run it in System Center Orchestrator

Use [`PowerBI-Lineage.Orchestrator.ps1`](PowerBI-Lineage.Orchestrator.ps1). It is one script with the whole tool
embedded, so nothing else needs copying to the runbook server.

### Add it to a runbook

1. In **Runbook Designer**, create a runbook inside a folder.
2. Add a **Run .NET Script** activity (in **System**).
3. On its **Details** tab, set the language to **PowerShell**.
4. Open `PowerBI-Lineage.Orchestrator.ps1`, copy **all** of it, and paste it into the **Script** box.
5. Fill in the settings at the top of the script:

   ```powershell
   $TenantId = 'contoso.onmicrosoft.com'                # tenant ID or domain
   $AppId = '00000000-0000-0000-0000-000000000000'      # the service principal's application (client) ID
   $ClientSecret = ''                                    # see "Keep the client secret safe" below
   $ExcelPath = '\\fileserver\bi\PowerBI-Lineage.xlsx'  # the JSON and a run log are saved alongside
   $Mode = ''                                            # optional: Admin (default, whole tenant) or User
   $WorkspaceIds = ''                                    # optional: comma-separated workspace IDs
   $CertificateThumbprint = ''                           # optional: use a certificate instead of a secret
   $TimeoutMinutes = ''                                  # optional: default 180
   ```

   Instead of typing a value you can subscribe to one: delete the text between the quotes, right-click there, and
   choose **Subscribe > Published Data** (for example an Initialize Data parameter).
6. Select **Finish**, check the runbook in, and run it.

The activity **succeeds** when the run succeeds. In the `$ExcelPath` folder you then find the workbook, a run log
named after it (`PowerBI-Lineage.log` for `PowerBI-Lineage.xlsx`), and a `report-lineage-<date>` folder with the JSON.
The activity **fails**, with the reason in its error summary, when the run fails; the full detail is in the run log.

### Keep the client secret safe

A secret typed into the script is stored in the Orchestrator database in plain text. Instead:

1. Create a **Variable** in Runbook Designer, tick **Encrypted variable**, and enter the secret.
2. In the pasted script, click between the quotes of `$ClientSecret = ''`, right-click, choose
   **Subscribe > Variable**, and pick it.
3. Keep activity-specific logging off for this runbook.

Or leave `$ClientSecret` empty and use a certificate: install it with its private key in **LocalMachine\My** on the
runbook server, give the Orchestrator Runbook Service account read access to the private key, and set
`$CertificateThumbprint`.

The secret is passed to the tool through an environment variable, never on a command line.

### Runbook server requirements

- **Modules:** if the server cannot reach powershellgallery.com, install them first in an elevated PowerShell:
  `Install-Module MicrosoftPowerBIMgmt.Profile, ImportExcel -Scope AllUsers`.
- **Access:** the **Orchestrator Runbook Service** account needs write access to the `$ExcelPath` folder.
- **Disk:** the tool unpacks itself to `%ProgramData%\PowerBI-Lineage` on first run. Windows lets every account
  create folders under `%ProgramData%` by default.

### Alternative: import a ready-made runbook

[`PowerBI-Lineage.ois_export`](PowerBI-Lineage.ois_export) contains the same script in a runbook, with each setting
subscribed to an **Initialize Data** parameter (Tenant ID, App ID, Client secret, Excel path, and the optional ones):

1. In Runbook Designer, right-click a folder and choose **Import**, then select the file.
2. Clear **Import Orchestrator encrypted data** (the file contains none).
3. Open the **Power BI** folder and run **Power BI Report Lineage**.

This file was generated to match the Runbook Designer export format but has not been import-tested on an
Orchestrator server. If an activity shows as unknown after import, use the steps in
[Add it to a runbook](#add-it-to-a-runbook). A client secret entered as an Initialize Data parameter also appears in
the job's run history, so subscribe an encrypted variable instead for production.

---

## What you get

| File | Contents |
|---|---|
| `*.xlsx` | The workbook (sheets below). |
| `report-lineage.json` | Everything collected, untruncated, in a `report-lineage-<date>` folder next to the workbook. |
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
`ConnectionDetails`, `ObjectOrigin`, `Notes` and `SourceExpression` (the Power Query code the source was read from).
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
| "The setting ... is required" or "has an invalid value" | Orchestrator script: check the settings at the top. `$AppId` must be a GUID and `$ExcelPath` must end in `.xlsx`. |
| The window closes at once, or scripts are blocked | Group Policy or AppLocker blocks PowerShell scripts. Ask IT. |

