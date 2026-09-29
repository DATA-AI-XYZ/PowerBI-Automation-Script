# Prerequisites.psm1

A PowerShell module that makes sure a required PowerShell module is present and imports it. A module that is already installed is used as it is; only a module found nowhere is installed from the PowerShell Gallery, for the current user.

| | |
|---|---|
| Type | Module |
| Used by | `Get-PbiReportLineage.ps1` (`MicrosoftPowerBIMgmt.Profile`, and `ImportExcel` unless no workbook is built); `Export-PbiLineageWorkbook.ps1` (`ImportExcel`) |
| Uses | `Get-Module`, `Import-Module`; `Get-PackageProvider`, `Install-PackageProvider` and `Install-Module` only when installing |
| Runs in | Windows PowerShell 5.1 or PowerShell 7 (`#Requires -Version 5.1`) |
| Reads | `$env:PSModulePath`; the Windows PowerShell and PowerShell module folders under Program Files, the Windows folder and Documents |
| Writes | `$env:PSModulePath` for the current process, when a module is not found at first; the current user's module folder and the NuGet provider, when installing |

## Use

```powershell
Import-Module .\src\modules\Prerequisites.psm1
Initialize-RequiredModule -Name ImportExcel -InformationAction Continue
```

Exported functions: `Find-RequiredModule`, `Initialize-RequiredModule`.

## Inputs

Both functions take the same parameters.

| Name | Required | Default | Description |
|---|---|---|---|
| `Name` | Yes | None | Module name, for example `ImportExcel`. |
| `MinimumVersion` | No | None | Lowest acceptable version. An older installed copy counts as missing. |

## Outputs

- `Find-RequiredModule` returns the newest installed copy of the module (a `PSModuleInfo`), or nothing.
- `Initialize-RequiredModule` imports the module and returns nothing. If it had to install and the install failed, it throws a message naming the computer, the account and the command to install the module for all users.

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../README.md)
- [Get-PbiReportLineage.ps1](../Get-PbiReportLineage.ps1/README.md)
- [Export-PbiLineageWorkbook.ps1](../Export-PbiLineageWorkbook.ps1/README.md)
