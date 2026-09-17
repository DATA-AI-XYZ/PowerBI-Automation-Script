# Power BI Report Lineage: paste this into a System Center Orchestrator "Run .NET Script" activity (PowerShell).
#
# Before you run it, copy PowerBI-Lineage.Orchestrator.ps1 to the runbook server and set ScriptPath to it.
# Fill in the settings, or replace a value between its quotes with a subscription (right-click > Subscribe), for
# example to an Initialize Data parameter, or to an encrypted variable for the client secret. Values must not contain
# a single quote.

# Where PowerBI-Lineage.Orchestrator.ps1 is on the runbook server
$ScriptPath = 'C:\Tools\PowerBI-Lineage\PowerBI-Lineage.Orchestrator.ps1'

# Tenant ID or domain, e.g. contoso.onmicrosoft.com
$TenantId = ''

# The service principal's application (client) ID
$AppId = ''

# The service principal's client secret. Leave empty to sign in with CertificateThumbprint instead.
$ClientSecret = ''

# Workbook to write, e.g. \\fileserver\bi\PowerBI-Lineage.xlsx. The JSON and run log are saved alongside it.
$ExcelPath = ''

# Admin = every workspace in the tenant (the default when empty); User = only workspaces the app belongs to
$Mode = ''

# Optional: comma-separated workspace IDs to limit the run
$WorkspaceIds = ''

# Optional: thumbprint of a certificate in LocalMachine\My, to use instead of ClientSecret
$CertificateThumbprint = ''

# Optional: stop the run after this many minutes (default 180)
$TimeoutMinutes = ''

# ---- Nothing below needs changing. Kept to basic PowerShell so Orchestrator's script host can always load it. ----

$ErrorActionPreference = 'Stop'

$ScriptPath = "$ScriptPath".Trim()
if (-not $ScriptPath) { throw 'Set ScriptPath to where PowerBI-Lineage.Orchestrator.ps1 is on the runbook server.' }
if ($ScriptPath -match '["<>|&^%*?]' -or $ScriptPath -notmatch '\.ps1$') { throw "ScriptPath is not a valid .ps1 path: $ScriptPath" }
if (-not (Test-Path -LiteralPath $ScriptPath)) { throw "PowerBI-Lineage.Orchestrator.ps1 was not found at $ScriptPath on runbook server $env:COMPUTERNAME." }

$waitMinutes = 185
if ("$TimeoutMinutes".Trim() -match '^[0-9]{1,4}$') { $waitMinutes = [int]"$TimeoutMinutes".Trim() + 5 }

$runId = [guid]::NewGuid().ToString('N')
$stdoutFile = Join-Path ([IO.Path]::GetTempPath()) ('PowerBI-Lineage-activity-' + $runId + '.out.txt')
$stderrFile = Join-Path ([IO.Path]::GetTempPath()) ('PowerBI-Lineage-activity-' + $runId + '.err.txt')

# This activity runs in a 32-bit process: start the 64-bit command processor through Sysnative, which then runs
# 64-bit Windows PowerShell from System32. Settings go through environment variables, never the command line.
$system = Join-Path $env:SystemRoot 'Sysnative'
if (-not (Test-Path -LiteralPath $system)) { $system = Join-Path $env:SystemRoot 'System32' }
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = Join-Path $system 'cmd.exe'
$startInfo.Arguments = '/d /c ""' + $powershell + '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $ScriptPath + '" > "' + $stdoutFile + '" 2> "' + $stderrFile + '" < NUL"'
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.EnvironmentVariables['LINEAGE_TENANT_ID'] = "$TenantId".Trim()
$startInfo.EnvironmentVariables['LINEAGE_CLIENT_ID'] = "$AppId".Trim()
$startInfo.EnvironmentVariables['PBI_CLIENT_SECRET'] = "$ClientSecret".Trim()
$startInfo.EnvironmentVariables['LINEAGE_EXCEL_PATH'] = "$ExcelPath".Trim()
$startInfo.EnvironmentVariables['LINEAGE_MODE'] = "$Mode".Trim()
$startInfo.EnvironmentVariables['LINEAGE_WORKSPACE_IDS'] = "$WorkspaceIds".Trim()
$startInfo.EnvironmentVariables['LINEAGE_CERTIFICATE_THUMBPRINT'] = "$CertificateThumbprint".Trim()
$startInfo.EnvironmentVariables['LINEAGE_TIMEOUT_MINUTES'] = "$TimeoutMinutes".Trim()

$process = [System.Diagnostics.Process]::Start($startInfo)
$finished = $process.WaitForExit($waitMinutes * 60 * 1000)
if (-not $finished) { & taskkill.exe /PID $process.Id /T /F | Out-Null }

$output = ''
$errorText = ''
if (Test-Path -LiteralPath $stdoutFile) { $output = [IO.File]::ReadAllText($stdoutFile); Remove-Item -LiteralPath $stdoutFile -Force }
if (Test-Path -LiteralPath $stderrFile) { $errorText = [IO.File]::ReadAllText($stderrFile); Remove-Item -LiteralPath $stderrFile -Force }

if (-not $finished) { throw "Power BI lineage run did not finish within $waitMinutes minutes and was stopped." }
if ($process.ExitCode -ne 0) {
    $reason = ($errorText -replace '\s+', ' ').Trim() -replace '^ERROR:\s*', ''
    if (-not $reason) { $reason = "exit code $($process.ExitCode)" }
    throw "Power BI lineage run failed: $reason"
}

$output
