# LauncherArguments.psm1: detailed documentation

## Flow

1. On import the module sets `$script:AllowedParameters` to the 15 accepted parameter names.
2. The launcher calls `ConvertFrom-LauncherArgument $env:LINEAGE_ARGS`.
3. Empty text returns an empty hashtable; a help token returns `@{ Help = $true }`.
4. Otherwise the text is parsed as the arguments of a dummy command, `Invoke-Lineage <text>`, with `[Parser]::ParseInput`. Nothing is run.
5. The parse must give one statement holding one command. Each element after the command name is read in turn.
6. A parameter name is checked against `$script:AllowedParameters`. A value is read with `Get-LiteralArgumentValue`, which accepts constants only.
7. The launcher splats the hashtable into `Get-PbiReportLineage.ps1` with `-Unattended`, or calls `Get-LauncherUsage` when the key `Help` is present.

## Functions

### Get-LiteralArgumentValue

Returns the value of one parsed argument, if it is a literal.

Private.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Ast` | `System.Management.Automation.Language.Ast` | No | The parsed argument. |

**Returns:**

| Parsed as | Returns |
|---|---|
| `StringConstantExpressionAst` (bare word, quoted text) | The text. |
| `ConstantExpressionAst` (number) | The number. |
| `ExpandableStringExpressionAst` with no nested expressions | The text. |
| `ArrayLiteralAst` (`a,b`) | An array, each element read by this function. |
| `VariableExpressionAst` `$true` / `$false` | `$true` / `$false`. |

**Calls:** Itself, for array elements.
**Errors:** Throws `Arguments must be plain values; '<text>' contains an expression.` for double-quoted text with `$(...)` or a variable. Throws `Arguments must be plain values; '<text>' is not.` for anything else, including other variables such as `$env:TEMP`.

### ConvertFrom-LauncherArgument

Converts a command line such as `-Mode Admin -WorkspaceId a,b -SkipExcel` into a parameter hashtable.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `CommandLine` | `string` | No | The argument text. Empty text is allowed. |

**Returns:** `[hashtable]`.

| Input | Result |
|---|---|
| Empty or only spaces | `@{}` |
| Exactly one of `/?`, `-?`, `-h`, `/h`, `-help`, `/help`, `--help` (any case) | `@{ Help = $true }` |
| `-Name value` | `Name = value` |
| `-Name:value` | `Name = value` |
| `-Name` with no value | `Name = $true` |
| Same name twice | The last value wins. |

**Calls:** `[System.Management.Automation.Language.Parser]::ParseInput`, `Get-LiteralArgumentValue`.
**Errors:** Throws, with these messages:

| Case | Message |
|---|---|
| Parse error | `Could not read the arguments: <parser message>` |
| More than one statement, a pipeline, or not a command | `Arguments must be parameter names and values only, for example: -Mode Admin -TenantId <tenant>.` |
| `-ClientSecret` | `Do not put the client secret on the command line, where job logs and process lists can show it. Set the PBI_CLIENT_SECRET environment variable instead, or use -CertificateThumbprint or -ConfigPath.` |
| Other unknown name | `Unknown parameter -<name>. Valid parameters: -Mode, -WorkspaceId, ...` (lists all 15) |
| Value with no name before it | `Unexpected value '<text>'. Put a parameter name such as -ExcelPath before it.` |
| Value that is not a literal | See `Get-LiteralArgumentValue`. |

### Get-LauncherUsage

Returns the help text for `PowerBI-Lineage.cmd`.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| None. | | | |

**Returns:** `[string]`. It covers double-click use, unattended use (no questions, no pause, exit code `0` on success and `1` on failure, service principal sign-in), two examples (certificate, and `PBI_CLIENT_SECRET`), and a one-line description of each accepted parameter.
**Calls:** None.
**Errors:** None.

## Script state

| Name | Value |
|---|---|
| `$script:AllowedParameters` | `Mode`, `WorkspaceId`, `OutputPath`, `ExcelPath`, `SkipExcel`, `TenantId`, `ClientId`, `CertificateThumbprint`, `ConfigPath`, `IncludePersonalWorkspaces`, `IncludeAutoDateTables`, `SkipGatewayLookup`, `SaveRawResponses`, `ScanBatchSize`, `Verbose` |

## Error handling

`ConvertFrom-LauncherArgument` throws a terminating error with a plain message for every rejected input. It never runs the text. In `PowerBI-Lineage.cmd` the call sits in a `try` block: the `catch` writes `ERROR: <message>` to standard error and exits with code `1`.

## Limits and notes

- The whole text is parsed by the PowerShell parser, so PowerShell quoting applies. In double-quoted text a backtick is an escape character. Text inside single quotes is taken as written.
- `$(...)`, variables other than `$true` and `$false`, `;`, `|` and other expressions are rejected, not run.
- A parameter given without a value becomes `$true`, and a value after any name is assigned to it. The module does not know which parameters are switches, so `-Mode` alone becomes `Mode = $true`. `Get-PbiReportLineage.ps1` then rejects it.
- Help is recognised only when the help token is the whole text. `-Help` with other arguments is an unknown parameter.
- Unattended runs through the launcher always add `-Unattended`, so they need service principal sign-in.
- The text reaches the module through the batch variable `LINEAGE_ARGS` (set from `%*`), so batch handling of characters such as `%` and `^` applies before the module sees it.
