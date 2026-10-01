# Set up V2 in System Center Orchestrator

| File | Goes where |
|---|---|
| `PowerBI-Lineage.Orchestrator.V2.ps1` | Copied to a folder on the **runbook server**. Not pasted, not edited. |
| `PowerBI-Lineage.Orchestrator.V2.Launcher.ps1` | Pasted into the Run .NET Script activity. Your settings go here. |

To get every file at once, download `PowerBI-Lineage.Orchestrator.V2.zip` from this folder.

V2 is too large to paste (Orchestrator fails with "Error initializing extension"). The launcher reads V2 from the file
and runs it.

## Before you start

- The runbook server is listed under **Runbook Servers** in Runbook Designer.
- The Orchestrator Runbook Service account needs read access to the V2 folder and write access to the output folder.
- Create an encrypted variable for the client secret.
- Optional, so nothing is installed at run time: `Install-Module MicrosoftPowerBIMgmt.Profile, ImportExcel -Scope AllUsers`
  (as administrator, on the runbook server).

## Steps

1. Copy `PowerBI-Lineage.Orchestrator.V2.ps1` to `<V2 folder>` on the runbook server. If it arrived as `.txt`, rename
   it to exactly `PowerBI-Lineage.Orchestrator.V2.ps1` (show file name extensions to be sure).
2. In Runbook Designer, check out the runbook and add a **Run .NET Script** activity from **Activities > System**.
   Set **Type** to **PowerShell**.
3. Paste the whole launcher into the **Script** box.
4. Fill in the settings at the top:
   ```powershell
   $ScriptPath   = '<V2 folder>\PowerBI-Lineage.Orchestrator.V2.ps1'
   $TenantId     = '<tenant ID or domain>'
   $AppId        = '<service principal application ID>'
   $ClientSecret = '<subscribe to your encrypted variable>'
   $ExcelPath    = '<output folder>'
   ```
   For `$ClientSecret`, select the text between the quotes, right-click, **Subscribe > Variable**. Do not type the
   variable's name: typed text is sent as the secret and sign-in fails.
5. **Finish**, check in, and run.

## Result

`<output folder>` gets `PowerBI-Lineage_DDMMYYHHMM.xlsx`, `.csv` and `.log`. If the activity fails, its error summary
gives the reason and the `.log` gives the detail.

| Error | Fix |
|---|---|
| "Error initializing extension" | V2 was pasted instead of the launcher, or the activity is a copy. Use a new activity and paste the launcher. |
| "...V2.ps1 was not found at ..." | Wrong path, a `.txt` name, the file is not on the runbook server, or no read access. |
| `[2/8] Signing in ... failed` | Secret typed instead of subscribed, or a wrong or expired secret, app ID or tenant ID. |
