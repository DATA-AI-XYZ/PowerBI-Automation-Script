# RunProgress.psm1: detailed documentation

## Flow

1. On import the module sets `$script:State` to `$null` and `$script:LabelWidth` to `46`.
2. `Start-RunProgress` resolves the style (`Console` or `Plain`) and creates `$script:State` with a run timer.
3. `Start-RunStep` completes any open step (`Complete-RunStep`), moves to the next step number and draws it (`Show-RunStep -Force`).
4. `Update-RunStep` redraws the open step with a live status through `Show-RunStep`, in `Console` style only.
5. `Complete-RunStep` writes the step's result, adding the step's duration when it took 2 seconds or more (`Format-RunDuration`).
6. `Stop-RunStep` completes an open step as `failed` with outcome `Failure`, so a following error message starts on its own line.
7. `Write-RunMessage` writes summary lines in the run's style; `Get-RunElapsed` returns the run's duration.

`Get-PbiReportLineage.ps1` calls `Start-RunProgress -TotalSteps 8` with the default style, then calls `Stop-RunStep` in its `catch` block before re-throwing.

## Functions

### Format-RunDuration

Formats a time span as `7s`, `2m 05s` or `1h 02m`.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Duration` | `TimeSpan` | Yes | The time span to format. |

**Returns:** `[string]`. Under 60 seconds: whole seconds, rounded down, never below `0` (`{0}s`). Under 60 minutes: `{0}m {1:00}s`. Otherwise: `{0}h {1:00}m`.
**Calls:** None.
**Errors:** None of its own.

### Format-RunStepLine

Builds one step line: `  [i/n] Name ` padded with dots to 46 characters, then a space and the status.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Index` | `int` | No | Step number. |
| `Total` | `int` | No | Number of steps. |
| `Name` | `string` | No | Step name. |
| `Status` | `string` | No | Text after the dots. Left out when empty. |
| `Width` | `int` | No | Maximum line length. Default `0` (no limit). Applied only when greater than 10. |

**Returns:** `[string]`. When `Width` is over 10 and the line is longer, it is cut to `Width - 3` characters plus `...`. A label already 46 characters or longer gets no dots.
**Calls:** None.
**Errors:** None of its own.

### Get-ConsoleWidth

Returns the usable console width.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | |

**Returns:** `[Console]::WindowWidth - 1`, at least `40`. Returns `119` when the width cannot be read.
**Calls:** None.
**Errors:** Caught; falls back to `119`.

### Start-RunProgress

Begins a run and sets the output style.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `TotalSteps` | `int` | Yes | Number of steps in the run. |
| `Style` | `string` | No | `Auto` (default), `Console` or `Plain`. |

**Returns:** Nothing. Replaces `$script:State` with a new object (see Script state).
**Calls:** `Write-Verbose` when the console cannot be queried.
**Errors:** For `Auto`, a failure reading `[Console]::IsOutputRedirected` is caught and the style stays `Plain`, with the verbose message `No console attached; using plain progress lines.`

`Auto` resolves as follows:

| Condition | Style |
|---|---|
| `$Host.Name` is `ConsoleHost` and `[Console]::IsOutputRedirected` is false | `Console` |
| Anything else | `Plain` |

### Show-RunStep

Draws the open step on the current console line.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Status` | `string` | No | Live status after the dots. |
| `Force` | `switch` | No | Draw even if the last draw was under 150 ms ago. |

**Returns:** Nothing. In `Console` style writes `` `r `` plus the line padded to the console width, with no newline, then restarts the draw timer. Does nothing in `Plain` style.
**Calls:** `Get-ConsoleWidth`, `Format-RunStepLine`, `Write-Host`.
**Errors:** None of its own.

### Start-RunStep

Starts the next step.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Name` | `string` | Yes | Step name. |

**Returns:** Nothing. Increments the step number, marks the step open and starts its timer.
**Calls:** `Complete-RunStep` (if a step is still open, with the default result `done`), `Show-RunStep -Force`.
**Errors:** Does not check that `Start-RunProgress` was called; with no state the property updates fail.

### Update-RunStep

Shows a live status for the open step, for example `37/120 semantic models`.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Status` | `string` | No | Live status text. |
| `Force` | `switch` | No | Redraw even within 150 ms of the last draw. |

**Returns:** Nothing.
**Calls:** `Show-RunStep`.
**Errors:** None. Does nothing when there is no run or no open step.

### Complete-RunStep

Ends the open step and writes its result.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Result` | `string` | No | Result text. Default `done`. |
| `Outcome` | `string` | No | `Success` (default), `Warning` or `Failure`. Sets the colour in `Console` style: green, yellow, red. |

**Returns:** Nothing. Marks the step closed.
**Calls:** `Format-RunDuration` (step took 2 seconds or more: appends ` (<duration>)`), `Get-ConsoleWidth`, `Format-RunStepLine`, `Write-Host` (`Console`) or `Write-Information -InformationAction Continue` (`Plain`).
**Errors:** None. Does nothing when there is no run or no open step.

In `Console` style the result is cut to the room left after the label, ending in `...`, and padded to that room so it overwrites any longer live status.

### Stop-RunStep

Marks the open step as failed.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | |

**Returns:** Nothing.
**Calls:** `Complete-RunStep -Result 'failed' -Outcome Failure`, only when a step is open.
**Errors:** None.

### Get-RunElapsed

Returns the time since `Start-RunProgress`.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | |

**Returns:** `[string]` from `Format-RunDuration`, or `0s` when no run has started.
**Calls:** `Format-RunDuration`.
**Errors:** None.

### Write-RunMessage

Writes a summary line in the run's style.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Text` | `string` | No | Text to write. Default empty (a blank line). |
| `Color` | `string` | No | `''` (default), `Green`, `Yellow`, `Red`, `Cyan` or `Gray`. Used in `Console` style only. |

**Returns:** Nothing.
**Calls:** `Write-Host` when the run's style is `Console`; otherwise `Write-Information -InformationAction Continue`.
**Errors:** None.

## Script state

| Name | Value | Description |
|---|---|---|
| `$script:LabelWidth` | `46` | Width the step label is padded to with dots. |
| `$script:State` | `$null` until `Start-RunProgress` | Run state object with the properties below. |
| `State.Style` | `Console` or `Plain` | Resolved output style. |
| `State.Total` | `int` | Number of steps. |
| `State.Index` | `int`, starts at `0` | Current step number. |
| `State.Name` | `string` | Current step name. |
| `State.Open` | `bool` | Whether a step is in progress. |
| `State.StepTimer` | `Stopwatch` | Started by `Start-RunStep`. |
| `State.LastDraw` | `Stopwatch` | Time since the last redraw; limits redraws to one per 150 ms. |
| `State.RunTimer` | `Stopwatch` | Started by `Start-RunProgress`; read by `Get-RunElapsed`. |

## Error handling

The module throws no errors of its own. Failures reading the console are caught (`Start-RunProgress`, `Get-ConsoleWidth`). Calls to `Update-RunStep`, `Complete-RunStep` and `Stop-RunStep` with no open step do nothing. The caller reports a failure by calling `Stop-RunStep` and then re-throwing.

## Limits and notes

- The style follows standard output, not the caller's mode. An unattended run started from a console with output not redirected still uses `Console` style. An Orchestrator run redirects output to a file, so it uses `Plain` style.
- In `Plain` style live status is dropped; only finished steps and messages are written.
- `Write-RunMessage` called before `Start-RunProgress` has no state and always writes to the information stream, uncoloured. `Get-PbiReportLineage.ps1` writes its heading this way, and re-imports the module with `-Force`, which resets the state.
- The module holds one run at a time. A second `Start-RunProgress` replaces the state.
- `Start-RunStep` does not stop at `TotalSteps`; the step number keeps counting.
- The line width in `Console` style is read on every draw, so resizing the window takes effect on the next draw.
