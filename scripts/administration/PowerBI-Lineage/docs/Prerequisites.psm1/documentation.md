# Prerequisites.psm1: detailed documentation

## Flow

On import the module only defines its functions and exports `Find-RequiredModule` and `Initialize-RequiredModule`.

When `Initialize-RequiredModule -Name <module>` runs:

1. `Find-RequiredModule` looks for the module in the folders on `$env:PSModulePath`.
2. If it is not there, `Add-OtherModuleFolder` appends the other PowerShell module folders (from `Get-OtherModuleFolder`) to `$env:PSModulePath`, and `Find-RequiredModule` looks once more.
3. If the module is still not found, it is installed from the PowerShell Gallery for the current user.
4. The module is imported with `Import-Module`.

## Module search order

`Find-RequiredModule` uses `Get-Module -ListAvailable -Name <Name>`, drops copies older than `MinimumVersion`, and takes the highest version.

| Pass | Folders searched |
|---|---|
| 1 | The folders already on `$env:PSModulePath` |
| 2 | Only when pass 1 finds nothing and `Add-OtherModuleFolder` adds at least one folder: the same folders plus the folders below, appended in this order |

Folders appended for pass 2, each only if it exists and is not already on the path, duplicates removed:

| Order | Folder |
|---|---|
| 1 | `%ProgramW6432%\WindowsPowerShell\Modules` |
| 2 | `%ProgramFiles%\WindowsPowerShell\Modules` |
| 3 | `%ProgramFiles(x86)%\WindowsPowerShell\Modules` |
| 4 | `%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules` |
| 5 | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\Modules` |
| 6 | `%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\Modules` |
| 7 | `<Documents>\WindowsPowerShell\Modules` |
| 8 | `%ProgramW6432%\PowerShell\Modules` |
| 9 | `%ProgramFiles%\PowerShell\Modules` |
| 10 | `%ProgramFiles(x86)%\PowerShell\Modules` |
| 11 | `<Documents>\PowerShell\Modules` |

`<Documents>` is `[Environment]::GetFolderPath('MyDocuments')`. Unset Program Files variables are skipped. PowerShell 7's own built-in module folder is not added. This lets a module installed for the 64-bit Windows PowerShell be found from the 32-bit one, and the other way round.

## Install behaviour

Only when both passes find nothing, `Initialize-RequiredModule`:

1. Writes the information message `Installing the <Name> PowerShell module for your user account (first run only)...` (shown when the caller's `InformationAction` is `Continue`).
2. Sets `$ProgressPreference` to `SilentlyContinue`.
3. Adds TLS 1.2 to `[Net.ServicePointManager]::SecurityProtocol`.
4. Checks `Get-PackageProvider -ListAvailable` for `NuGet` version `2.8.5.201` or later. If missing, runs `Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force`.
5. Runs `Install-Module -Name <Name> -Scope CurrentUser -Repository PSGallery -Force`, adding `-MinimumVersion` when given.

No administrator rights are needed. If a step fails, it throws:

```text
The <Name> module is not installed on <COMPUTERNAME> for <DOMAIN\user>, and installing it from the PowerShell Gallery failed: <error> Install it once for all users in an elevated Windows PowerShell: Install-Module <Name> -Scope AllUsers (or ask IT to allow powershellgallery.com, or to install it).
```

After a successful find or install, the module is imported with `Import-Module -Name <Name> -ErrorAction Stop -WarningAction SilentlyContinue`, adding `-MinimumVersion` when given.

## Functions

### Get-OtherModuleFolder

Lists the Windows PowerShell and PowerShell module folders that exist on this computer, in the order in [Module search order](#module-search-order).

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | |

**Returns:** folder paths, unique. Nothing when `$env:SystemRoot` is not set (not Windows).

**Calls:** `Join-Path`, `Test-Path -LiteralPath`, `[Environment]::GetFolderPath('MyDocuments')`.

**Errors:** none raised.

### Add-OtherModuleFolder

Appends the folders from `Get-OtherModuleFolder` that are not already on `$env:PSModulePath`, for the current process only.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | |

**Returns:** `$true` if any folder was added, otherwise `$false`.

**Calls:** `Get-OtherModuleFolder`.

**Errors:** none raised.

Paths are split on `;` and compared without a trailing `\`, ignoring case. When folders are added, `$env:PSModulePath` is rewritten as the existing entries followed by the new ones. Existing entries keep their order but lose any trailing `\`, and empty entries are dropped. Example: `C:\First;C:\Second\` plus `C:\Second`, `C:\Third` becomes `C:\First;C:\Second;C:\Third`.

### Find-RequiredModule

Returns the newest installed copy of a module at or above `MinimumVersion`, or nothing if it is not installed.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | `string` | Yes | Module name. |
| `MinimumVersion` | `version` | No | Lowest acceptable version. |

**Returns:** one `PSModuleInfo`, or nothing.

**Calls:** `Get-Module -ListAvailable`; `Add-OtherModuleFolder` when the first search finds nothing.

**Errors:** none raised.

`Get-PbiReportLineage.ps1` calls it before `Initialize-RequiredModule` to show the step text `installing <name> (first run only)` when a module is missing.

### Initialize-RequiredModule

Imports a module, installing it for the current user first only if it is not installed.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | `string` | Yes | Module name. |
| `MinimumVersion` | `version` | No | Lowest acceptable version; passed to `Install-Module` and `Import-Module`. |

**Returns:** nothing.

**Calls:** `Find-RequiredModule`; when installing, `Get-PackageProvider`, `Install-PackageProvider`, `Install-Module`; then `Import-Module`.

**Errors:** the install failure message above. `Import-Module` errors are not caught (`-ErrorAction Stop`).

## Script state

The module has no `$script:` variables or constants. It changes process-wide state:

| Item | When |
|---|---|
| `$env:PSModulePath` | A module is not found on the existing path and other module folders exist |
| `[Net.ServicePointManager]::SecurityProtocol` (adds `Tls12`) | A module is installed |

## Error handling

- `Find-RequiredModule` never throws for a missing module; it returns nothing.
- Any failure while installing (NuGet provider or `Install-Module`) is caught and rethrown as one message that names the module, `$env:COMPUTERNAME`, the Windows account, the original error, and the `Install-Module <Name> -Scope AllUsers` command.
- `Import-Module` failures surface unchanged.

## Limits and notes

- The folder search and `$env:PSModulePath` handling use Windows paths and the `;` separator. On other systems only pass 1 runs.
- The account name in the install error comes from `[Security.Principal.WindowsIdentity]::GetCurrent()`, which exists on Windows only.
- An installed copy older than `MinimumVersion` counts as missing, so a newer copy is installed.
- `Import-Module` loads the module by name. It is not given the path of the copy `Find-RequiredModule` found.
- The module is not checked again after `Install-Module`; `Import-Module` fails if it is still not available.
- The `$env:PSModulePath` change lasts for the current process only.
