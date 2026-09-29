# PowerBIRest.psm1: detailed documentation

## Flow

On import:

1. Adds TLS 1.2 to `[Net.ServicePointManager]::SecurityProtocol` (Windows PowerShell 5.1 otherwise defaults to TLS 1.0/1.1).
2. Sets `$script:ApiBaseUrl` to `https://api.powerbi.com/v1.0/myorg`.
3. Exports `Set-PbiApiBaseUrl`, `Invoke-PbiRestMethod`, `Get-PbiPagedValue` and `Invoke-PbiWorkspaceScan`.

On each call:

1. `Invoke-PbiRestMethod` builds the URI, gets a token with `Get-PowerBIAccessToken -AsString` and calls `Invoke-RestMethod`.
2. On HTTP 429 or 5xx it waits and tries again; on any other failure, or when retries run out, it throws.
3. `Get-PbiPagedValue` and `Invoke-PbiWorkspaceScan` make all their requests through `Invoke-PbiRestMethod`, so every request gets the same retry behaviour.

## Functions

### Set-PbiApiBaseUrl

Changes the API root, for sovereign clouds (for example `https://api.powerbigov.us/v1.0/myorg`).

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Url` | `string` | Yes | New API root. Trailing `/` characters are removed. |

**Returns:** nothing.

**Calls:** none.

**Errors:** none raised.

### Invoke-PbiRestMethod

Calls a Power BI REST endpoint, retrying on HTTP 429 and 5xx.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Path` | `string` | Yes | Path relative to `$script:ApiBaseUrl` (a leading `/` is removed), or an absolute URL matching `^https?://`, used as it is. |
| `Method` | `string` | No | `Get` (default) or `Post`. |
| `Body` | `object` | No | Converted with `ConvertTo-Json -Depth 20 -Compress`, sent as UTF-8 bytes with content type `application/json; charset=utf-8`. |
| `MaxRetries` | `int` | No | Retries after the first attempt. Default `6`. |

**Returns:** the output of `Invoke-RestMethod` (parsed JSON).

**Calls:** `Get-PowerBIAccessToken -AsString` (on every attempt, for the `Authorization` header), `Invoke-RestMethod` with `-UseBasicParsing`, `Start-Sleep`. `$ProgressPreference` is set to `SilentlyContinue` inside the function.

**Errors:** see [Error handling](#error-handling).

#### Retry and throttling

| Item | Behaviour |
|---|---|
| Retried | HTTP 429 and any status of 500 or above |
| Not retried | Any other status (for example 400, 401, 403, 404), and any failure without an HTTP response (the original error is rethrown at once) |
| Attempts | Up to `MaxRetries + 1` requests. With the default, 7 requests and 6 waits |
| Wait without `Retry-After` | `min(60, 2^(attempt + 1))` seconds, where the first attempt is 0: 2, 4, 8, 16, 32, 60, then 60 for any further retries |
| `Retry-After` | Used instead of the calculated wait when it converts to a non-zero integer. Not capped at 60 seconds |
| `Retry-After` source | Windows PowerShell 5.1: the `Retry-After` header value. PowerShell 7: `Headers.RetryAfter.Delta` in seconds; the date form is not read |
| Log | `Write-Verbose "HTTP <status> from <uri>; retrying in <n> s (attempt <attempt + 1> of <MaxRetries>)."` |

With the default settings and no `Retry-After` header, the waits add up to 122 seconds before the last attempt.

### Get-PbiPagedValue

Returns every item from an endpoint that pages with `$top`/`$skip` and wraps results in `value`.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `Path` | `string` | Yes | Endpoint path. May already contain a query string. |
| `PageSize` | `int` | No | Items per request (`$top`). Default `5000`. |

**Returns:** the non-null items of each page, emitted as they arrive.

**Calls:** `Invoke-PbiRestMethod` with `GET <Path>?$top=<PageSize>&$skip=<n>` (`&` instead of `?` when `Path` already has a query string). `$skip` starts at 0 and grows by `PageSize`. Paging stops when a page returns fewer than `PageSize` non-null items.

**Errors:** those of `Invoke-PbiRestMethod`.

### Invoke-PbiWorkspaceScan

Runs the admin scanner (WorkspaceInfo) over workspaces in batches and emits one scan result per batch.

Exported.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `WorkspaceId` | `string[]` | Yes | Workspace IDs to scan. |
| `BatchSize` | `int` | No | Workspaces per scan, 1 to 100 (`ValidateRange`). Default `100`. |
| `PollSeconds` | `int` | No | Seconds to wait before each status check. Default `5`. |
| `TimeoutMinutes` | `int` | No | Time allowed per batch. Default `30`. |
| `OnProgress` | `scriptblock` | No | Called with one status string. |

**Returns:** one scan result object per batch, in batch order.

**Calls**, per batch, in order:

| Step | Request | Progress text |
|---|---|---|
| 1 | | `batch <i> of <n>, starting` |
| 2 | `POST admin/workspaces/getInfo?lineage=True&datasourceDetails=True&datasetSchema=True&datasetExpressions=True&getArtifactUsers=False` with body `{ "workspaces": [ ... ] }` | |
| 3 | Wait `PollSeconds`, then `GET admin/workspaces/scanStatus/<scan id>`; repeat while the status is `NotStarted` or `Running` | `batch <i> of <n>, <status in lower case>` after each check |
| 4 | | `batch <i> of <n>, downloading` |
| 5 | `GET admin/workspaces/scanResult/<scan id>` | |

Batches run one after the other. Table and expression metadata are only returned when the tenant settings "Enhance admin APIs responses with detailed metadata" and "Enhance admin APIs responses with DAX and mashup expressions" are on.

**Errors:**

| Condition | Message |
|---|---|
| Timeout reached after a status check | `Scan <id> did not finish within <TimeoutMinutes> minutes.` |
| Final status not `Succeeded` | `Scan <id> ended with status '<status>'.` |
| Any request fails | The error from `Invoke-PbiRestMethod` |

## Script state

| Name | Value | Use |
|---|---|---|
| `$script:ApiBaseUrl` | `https://api.powerbi.com/v1.0/myorg` | Root for relative paths; changed by `Set-PbiApiBaseUrl` |
| `[Net.ServicePointManager]::SecurityProtocol` | Existing value plus `Tls12` | Set once on import, for the whole process |

## Error handling

When `Invoke-PbiRestMethod` gives up, it throws a `System.InvalidOperationException`:

- Message: `HTTP <status> from <METHOD> <path>: <detail>`. `<METHOD>` is upper case. `<path>` is relative to the API root when the URI starts with it, otherwise the full URI.
- `Exception.Data['StatusCode']` holds the HTTP status as an integer. `Get-PbiReportLineage.ps1` reads it to tell 401 and 403 apart from other failures.

`<detail>` is taken from the error body, first match wins:

1. `error.message`
2. `error.pbi.error.details[]`: each `detail.value`, or `message`, joined with spaces (returned by `executeQueries`)
3. `error.code`
4. `Message`
5. The raw body, when it is not JSON or none of the above is set
6. The response's `ReasonPhrase` (PowerShell 7) or `StatusDescription` (Windows PowerShell 5.1), when none of the above gives a detail

The detail is cut to 1,000 characters. In Windows PowerShell 5.1, when `ErrorDetails` is empty, the body is read from the response stream.

A failure with no HTTP response (for example a name resolution or connection error) is rethrown unchanged, without `Data['StatusCode']`.

## Limits and notes

- Only `Get` and `Post` are allowed (`ValidateSet`).
- A new token is requested with `Get-PowerBIAccessToken` on every attempt, including retries.
- `Retry-After` values are not capped; a long value makes the call wait that long.
- `Get-PbiPagedValue` stops at the first page shorter than `PageSize`. An endpoint that returns fewer items per page than asked for is read only in part.
- The scan timeout is checked after each status request, so a batch can run up to one `PollSeconds` interval (plus the request time) past `TimeoutMinutes`. A status of `Succeeded` returned after the deadline still throws the timeout error.
- `WorkspaceId` is mandatory and does not allow an empty array; `Get-PbiReportLineage.ps1` skips the call when there are no IDs.
- `Set-PbiApiBaseUrl` is exported but no script in the tool calls it.
- The module does not sign in or load `MicrosoftPowerBIMgmt.Profile`; the caller does both first.
