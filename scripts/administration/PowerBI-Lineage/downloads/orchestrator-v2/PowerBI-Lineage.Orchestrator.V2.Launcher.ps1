###############################################################################################################
# POWER BI REPORT LINEAGE - System Center Orchestrator launcher for V2
#
# Orchestrator cannot load a pasted script as large as PowerBI-Lineage.Orchestrator.V2.ps1 (about 140 KB): the
# activity fails with "Error initializing extension". So V2 is copied to the runbook server as a file, and this
# short script is pasted into the Run .NET Script activity (Type: PowerShell) instead. It reads V2 from that file
# and runs it here, exactly as if V2 had been pasted. Nothing is downloaded.
#
# Replace each Required-... placeholder below with a value. Optional settings can stay empty. Instead of typing
# a value you can subscribe to one (right-click between the quotes > Subscribe), e.g. an encrypted variable for
# the client secret. Values must not contain a single quote. Leave the settings inside the V2 file as they are.
###############################################################################################################

# Full path of PowerBI-Lineage.Orchestrator.V2.ps1 on the runbook server, e.g. D:\Tools\PowerBI-Lineage\PowerBI-Lineage.Orchestrator.V2.ps1
$ScriptPath = 'Required-ScriptPath'

# Optional: the SHA-256 hash of that file (Get-FileHash <file>). If set, the run stops when the file has changed.
$ScriptSha256 = ''

# Tenant ID or domain, e.g. contoso.onmicrosoft.com
$TenantId = 'Required-TenantId'

# The service principal's application (client) ID
$AppId = 'Required-AppId'

# The service principal's client secret. Or leave the placeholder and set CertificateThumbprint instead.
$ClientSecret = 'Required-ClientSecret-or-CertificateThumbprint'

# Folder for the output, e.g. \\fileserver\bi : each run writes PowerBI-Lineage_DDMMYYHHMM.xlsx (and .csv, .log).
# Or a file replaced on every run: \\fileserver\bi\PowerBI-Lineage.xlsx, or PowerBI-Lineage.csv for CSV only.
$ExcelPath = 'Required-ExcelPath'

# Optional: Excel = workbook and CSV (the default); CSV = CSV only, no workbook (ImportExcel module not needed)
$OutputFormat = ''

# Optional: Admin = every workspace in the tenant (the default); User = only workspaces the app belongs to
$Mode = ''

# Optional: comma-separated workspace IDs to limit the run
$WorkspaceIds = ''

# Optional: thumbprint of a certificate in LocalMachine\My, to use instead of ClientSecret
$CertificateThumbprint = ''

# Optional: stop the run after this many minutes (default 180)
$TimeoutMinutes = ''

###############################################################################################################
# Nothing below needs changing.
###############################################################################################################

$ErrorActionPreference = 'Stop'

# ---- Find and check the V2 file ------------------------------------------------------------------------------

$path = "$ScriptPath".Trim() -replace '^Required-.*$', ''
if (-not $path) { $path = "$([Environment]::GetEnvironmentVariable('LINEAGE_SCRIPT_PATH'))".Trim() -replace '^Required-.*$', '' }
if (-not $path) { throw 'The setting ScriptPath is required: the full path of PowerBI-Lineage.Orchestrator.V2.ps1 on this server.' }
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "PowerBI-Lineage.Orchestrator.V2.ps1 was not found at $path. Copy it to the runbook server and check ScriptPath."
}

$bytes = [IO.File]::ReadAllBytes($path)
$expected = ("$ScriptSha256".Trim() -replace '\s', '').ToLowerInvariant()
if ($expected) {
    if ($expected -notmatch '^[0-9a-f]{64}$') { throw "The setting ScriptSha256 has an invalid value: $ScriptSha256" }
    $sha = [Security.Cryptography.SHA256]::Create()
    $actual = -join (@($sha.ComputeHash($bytes)) | ForEach-Object { $_.ToString('x2') })
    if ($actual -ne $expected) { throw "$path has changed: its SHA-256 is $actual, not $expected. Check the file before running it." }
}
$text = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
if ($text -notmatch 'POWER BI REPORT LINEAGE' -or $text -notmatch '(?m)^\$files = \[ordered\]@\{\}') {
    throw "$path is not PowerBI-Lineage.Orchestrator.V2.ps1."
}

# ---- Hand the settings to V2 ---------------------------------------------------------------------------------
# V2 reads a setting from its environment variable when the setting in the file is empty or a Required-...
# placeholder, so the settings above are set as environment variables of this process for the run, then restored.

$settings = @(
    @('LINEAGE_TENANT_ID', $TenantId),
    @('LINEAGE_CLIENT_ID', $AppId),
    @('PBI_CLIENT_SECRET', $ClientSecret),
    @('LINEAGE_EXCEL_PATH', $ExcelPath),
    @('LINEAGE_OUTPUT_FORMAT', $OutputFormat),
    @('LINEAGE_MODE', $Mode),
    @('LINEAGE_WORKSPACE_IDS', $WorkspaceIds),
    @('LINEAGE_CERTIFICATE_THUMBPRINT', $CertificateThumbprint),
    @('LINEAGE_TIMEOUT_MINUTES', $TimeoutMinutes)
)
$previous = @{}
foreach ($setting in $settings) {
    $previous[$setting[0]] = [Environment]::GetEnvironmentVariable($setting[0])
    $value = "$($setting[1])".Trim() -replace '^Required-.*$', ''
    if ($value) { [Environment]::SetEnvironmentVariable($setting[0], $value) }
}

# ---- Run V2 --------------------------------------------------------------------------------------------------

try {
    & ([scriptblock]::Create($text))
}
finally {
    foreach ($setting in $settings) { [Environment]::SetEnvironmentVariable($setting[0], $previous[$setting[0]]) }
}
