# RunProgress.psm1

A PowerShell module that shows the progress of a run made of numbered steps. Each step is one line that ends with its result. In a console window the line is redrawn in place with a live status; when output is redirected, each finished step is written once as a plain line.

| | |
|---|---|
| Type | module |
| Used by | `Get-PbiReportLineage.ps1` (its eight steps and the closing summary); bundled into `PowerBI-Lineage.cmd` by `build/New-LineageBundle.ps1` and into the Orchestrator scripts by `build/New-OrchestratorRunbook.ps1` |
| Uses | Nothing outside the module |
| Runs in | PowerShell 5.1 or later (`#Requires -Version 5.1`), in the caller's session |
| Reads | `$Host.Name`, `[Console]::IsOutputRedirected`, `[Console]::WindowWidth` |
| Writes | The console (`Write-Host`) or the information stream (`Write-Information`) |

## Use

```powershell
Import-Module ./src/modules/RunProgress.psm1
Start-RunProgress -TotalSteps 2
Start-RunStep 'Listing workspaces'
Update-RunStep '3/10 workspaces'
Complete-RunStep 'done, 10 workspaces'
Start-RunStep 'Saving results'
Complete-RunStep
Write-RunMessage "Done in $(Get-RunElapsed)." -Color Green
```

A finished step looks like this:

```
  [4/8] Listing workspaces ...................... done, 212 workspaces
```

## Inputs

`Start-RunProgress` sets the output style for the whole run.

| Name | Required | Default | Description |
|---|---|---|---|
| `-TotalSteps` | Yes | None | Number of steps, shown as the `/n` in `[i/n]`. |
| `-Style` | No | `Auto` | `Auto`, `Console` or `Plain`. `Auto` picks `Console` when the host is `ConsoleHost` and standard output is not redirected, otherwise `Plain`. |

### Interactive and unattended output

The style depends on where output goes, not on whether the run is interactive or unattended.

| | `Console` style | `Plain` style |
|---|---|---|
| When (`Auto`) | Console window, output not redirected | Output redirected (log file, Orchestrator run, test), or a host other than `ConsoleHost` |
| Live status (`Update-RunStep`) | Redrawn on the same line, at most every 150 ms unless `-Force` | Not shown |
| Finished step | Redrawn once more with the result, in green, yellow or red | One line to the information stream |
| Long lines | Cut to the console width, ending in `...` | Not cut |
| `Write-RunMessage` | `Write-Host`, with the given colour | Information stream, colour ignored |

## Outputs

Nothing is returned to the pipeline except by the two formatting functions and `Get-RunElapsed`, which return strings. Output goes to the host or to the information stream (stream 6). With `-InformationAction Continue` set on each call, plain lines are shown even when `$InformationPreference` is `SilentlyContinue`.

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../README.md)
- [Get-PbiReportLineage.ps1](../Get-PbiReportLineage.ps1/README.md)
- [Invoke-LineageRun.ps1](../Invoke-LineageRun.ps1/README.md)
- [PowerBI-Lineage.cmd](../../downloads/cmd/README.md)
