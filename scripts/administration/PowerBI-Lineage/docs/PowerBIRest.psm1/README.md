# PowerBIRest.psm1

A PowerShell module that calls the Power BI REST API with the token of the current Power BI session. It retries throttled and failed calls, follows `$top`/`$skip` paging, and runs the admin scanner (WorkspaceInfo) in batches.

| | |
|---|---|
| Type | Module |
| Used by | `Get-PbiReportLineage.ps1` |
| Uses | `Get-PowerBIAccessToken` from `MicrosoftPowerBIMgmt.Profile` (loaded by the caller); `Invoke-RestMethod` |
| Runs in | Windows PowerShell 5.1 or PowerShell 7 (`#Requires -Version 5.1`) |
| Reads | Power BI REST API, default root `https://api.powerbi.com/v1.0/myorg` |
| Writes | Nothing. Importing it adds TLS 1.2 to the process's allowed protocols |

## Use

Sign in first with `Connect-PowerBIServiceAccount`, then:

```powershell
Import-Module .\src\modules\PowerBIRest.psm1
$workspaces = Get-PbiPagedValue -Path 'groups'
$reports = (Invoke-PbiRestMethod -Path "groups/$($workspaces[0].id)/reports").value
```

Exported functions: `Set-PbiApiBaseUrl`, `Invoke-PbiRestMethod`, `Get-PbiPagedValue`, `Invoke-PbiWorkspaceScan`.

## Inputs

`Invoke-PbiRestMethod`

| Name | Required | Default | Description |
|---|---|---|---|
| `Path` | Yes | None | Path relative to the API root (for example `groups`), or an absolute `http`/`https` URL. |
| `Method` | No | `Get` | `Get` or `Post`. |
| `Body` | No | None | Object sent as compressed JSON (UTF-8). |
| `MaxRetries` | No | `6` | Retries after the first attempt, for HTTP 429 and 5xx. |

`Get-PbiPagedValue`

| Name | Required | Default | Description |
|---|---|---|---|
| `Path` | Yes | None | Endpoint that wraps results in `value`. |
| `PageSize` | No | `5000` | `$top` per request. |

`Invoke-PbiWorkspaceScan`

| Name | Required | Default | Description |
|---|---|---|---|
| `WorkspaceId` | Yes | None | Workspace IDs to scan. |
| `BatchSize` | No | `100` | Workspaces per scan request, 1 to 100. |
| `PollSeconds` | No | `5` | Wait between status checks. |
| `TimeoutMinutes` | No | `30` | Time allowed for each batch. |
| `OnProgress` | No | None | Script block called with a status text such as `batch 2 of 5, running`. |

`Set-PbiApiBaseUrl`

| Name | Required | Default | Description |
|---|---|---|---|
| `Url` | Yes | None | New API root, for sovereign clouds. A trailing `/` is removed. |

## Outputs

- `Invoke-PbiRestMethod` returns the parsed response of `Invoke-RestMethod`.
- `Get-PbiPagedValue` emits every item of every page.
- `Invoke-PbiWorkspaceScan` emits one scan result per batch.
- A failed call throws `System.InvalidOperationException` with the message `HTTP <status> from <METHOD> <path>: <detail>` and the status in `Exception.Data['StatusCode']`.

## See also

- [Detailed documentation](documentation.md)
- [All documentation](../README.md)
- [Get-PbiReportLineage.ps1](../Get-PbiReportLineage.ps1/README.md)
- [Prerequisites.psm1](../Prerequisites.psm1/README.md)
