# LauncherArguments.psm1

A PowerShell module that turns the arguments given to `PowerBI-Lineage.cmd` into parameters for `Get-PbiReportLineage.ps1`. It accepts literal values only, so nothing in the arguments is ever run as code. It also holds the launcher's help text.

| | |
|---|---|
| Type | module |
| Used by | The unattended branch of `PowerBI-Lineage.cmd` (launcher code in `build/New-LineageBundle.ps1`). Carried in the Orchestrator scripts but not used there |
| Uses | The PowerShell parser (`System.Management.Automation.Language.Parser`) |
| Runs in | PowerShell 5.1 or later (`#Requires -Version 5.1`), in the caller's session |
| Reads | The command-line text passed in (the launcher passes `LINEAGE_ARGS`, set from `%*`) |
| Writes | Nothing. It returns a hashtable or a string |

## Use

```powershell
Import-Module ./src/modules/LauncherArguments.psm1
$parameters = ConvertFrom-LauncherArgument '-Mode Admin -WorkspaceId aaa,bbb -SkipExcel'
if ($parameters.ContainsKey('Help')) { Get-LauncherUsage } else { & ./src/Get-PbiReportLineage.ps1 @parameters -Unattended }
```

From the launcher:

```
PowerBI-Lineage.cmd -Mode Admin -TenantId <tenant> -ClientId <app-id> -CertificateThumbprint <thumbprint> -ExcelPath "\\share\bi\PowerBI-Lineage.xlsx"
```

## Inputs

Accepted arguments. Names match without regard to case and are returned in the casing below. Abbreviations are not accepted. Values are passed on as they are; `Get-PbiReportLineage.ps1` checks them.

| Name | Required | Default | Description |
|---|---|---|---|
| `-Mode` | No | `Auto` (script default) | `Admin`, `User` or `Auto`. |
| `-WorkspaceId` | No | None | One ID, or a comma-separated list (`aaa,bbb`). |
| `-OutputPath` | No | See script | Folder for the JSON. |
| `-ExcelPath` | No | None | Folder, `.xlsx` file or `.csv` file. |
| `-SkipExcel` | No | Off | Switch. JSON and CSV only. |
| `-TenantId` | No | None | Tenant ID or domain. |
| `-ClientId` | No | None | Service principal application ID. |
| `-CertificateThumbprint` | No | None | Certificate thumbprint for the service principal. |
| `-ConfigPath` | No | None | `config.json` with the service principal settings. |
| `-IncludePersonalWorkspaces` | No | Off | Switch. |
| `-IncludeAutoDateTables` | No | Off | Switch. |
| `-SkipGatewayLookup` | No | Off | Switch. |
| `-SaveRawResponses` | No | Off | Switch. |
| `-ScanBatchSize` | No | `100` (script default) | Number, 1-100. |
| `-Verbose` | No | Off | Switch. |
| `/?`, `-?`, `-h`, `/h`, `-help`, `/help`, `--help` | No | None | Only as the whole argument text. Returns `@{ Help = $true }`. |

Refused: `-ClientSecret` (use the `PBI_CLIENT_SECRET` environment variable, `-CertificateThumbprint` or `-ConfigPath`), and any other name, including `-Interactive`, `-Unattended` and `-PassThru`.

Accepted value forms: bare words, single- or double-quoted text without `$(...)` or variables, numbers, comma-separated lists, `$true`, `$false`, and `-Name:value`.

## Outputs

| Function | Returns |
|---|---|
| `ConvertFrom-LauncherArgument` | `[hashtable]` to splat into `Get-PbiReportLineage.ps1`. Empty for empty text. `@{ Help = $true }` for a help request. |
| `Get-LauncherUsage` | `[string]` help text. The launcher prints it and exits with code `0`. |

Invalid arguments throw. The launcher writes `ERROR: <message>` to standard error and exits with code `1`.

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../README.md)
- [PowerBI-Lineage.cmd](../../downloads/cmd/README.md)
- [Get-PbiReportLineage.ps1](../Get-PbiReportLineage.ps1/README.md)
- [RunProgress.psm1](../RunProgress.psm1/README.md)
