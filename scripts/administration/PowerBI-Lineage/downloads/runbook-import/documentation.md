# PowerBI-Lineage.ois_export: detailed documentation

The file is XML in the layout of a Runbook Designer export. It defines one runbook with two activities and a link.
The script activity holds the V1 Orchestrator script, with every setting replaced by a subscription to an Initialize
Data parameter. It has not been import-tested on an Orchestrator server.

## Flow

When the imported runbook runs:

1. `Initialize Data` starts the runbook and takes the nine parameter values.
2. `Link` passes control to the script activity. It has no conditions.
3. Orchestrator replaces each subscription in the script with the parameter's value.
4. `Run Power BI Lineage` runs the V1 script: checks the settings, unpacks the tool, runs it in 64-bit Windows PowerShell, writes the run log. See [V1 flow](../orchestrator-v1/documentation.md#flow).

## Structure

```
ExportData
  EncryptionSalt
  Policies
    Folder                "Power BI"
      Policy              "Power BI Report Lineage" (the runbook)
        38 runbook fields
        Object            "Initialize Data"       (Custom Start)
          CUSTOM_START_PARAMETERS / 9 x Entry
        Object            "Run Power BI Lineage"  (Run .Net Script)
        Object            "Link"                  (Link)
```

The file is one line of XML apart from line breaks inside the script text. Every field element has a `datatype`
attribute: `string`, `int`, `bool`, `date` or `null`. In text, `&`, `<` and `>` are escaped and carriage returns are
written as `&#xD;`.

### ExportData

| Element | Value |
|---|---|
| `EncryptionSalt` | 22 base64 characters: the MD5 of `PowerBI-Lineage/orchestrator/salt`, `=` padding removed. |
| `Folder/UniqueID` | Stable GUID (see IDs below). |
| `Folder/Name` | `Power BI` |

### Policy (the runbook)

Fields in this order: `UniqueID`, `Name`, `ParentID`, `CreationTime`, `CreatedBy`, `LastModified`,
`LastModifiedBy`, `Enabled`, `Flags`, `ASC_UseServiceSecurity`, `ASC_ThisAccount`, `ASC_Username`, `ASC_Password`,
`HasExtenders`, `Type`, `CheckOutUser`, `CheckOutTime`, `CheckOutLocation`, `Schedule`, `Deleted`, `Priority`,
`CostDollar`, `SavingsDollar`, `CostTime`, `SavingsTime`, `Published`, `PublishingTime`, `ActionServer`,
`UsePreferredServers`, `LogCommonData`, `LogSpecificData`, `Description`, `PolicyTimeout`, `NotifyOnFail`,
`MaxParallelRequests`, `RunInPipelineMode`, `ReturnDataDefinition`, `PreferredServers`. Then the three objects.

Values set:

| Field | Value |
|---|---|
| `Name` | `Power BI Report Lineage` |
| `ParentID` | The folder's ID. |
| `CreationTime`, `LastModified` | `134340768000000000`: 17 September 2026 00:00 UTC as a Windows FILETIME. |
| `CreatedBy`, `LastModifiedBy`, `PreferredServers` | Empty string. |
| `Enabled`, `Deleted`, `Published`, `LogCommonData`, `LogSpecificData`, `NotifyOnFail` | `FALSE` |
| `MaxParallelRequests` | `1` |
| `RunInPipelineMode` | `TRUE` |
| `Description` | `Traces every Power BI report to its semantic model, tables, and the database objects and gateways behind them. Writes an Excel workbook, JSON and a run log. Signs in as a service principal.` |
| All others | `null` |

### Common object fields

Each `Object` starts with these 32 fields: `UniqueID`, `ParentID`, `Name`, `Description`, `PositionX`, `PositionY`,
`ObjectType`, `SubType`, `Enabled`, `Flags`, `ASC_UseServiceSecurity`, `ASC_ThisAccount`, `ASC_Username`,
`ASC_Password`, `HasExtenders`, `CreationTime`, `CreatedBy`, `LastModified`, `LastModifiedBy`, `Deleted`, `Cost`,
`Savings`, `Number`, `AlternateDisplayData`, `ASW_ObjectTimeout`, `ASW_NotifyOnFail`, `Flatten`, `FlatUseLineBreak`,
`FlatUseCSV`, `FlatUseCustomSep`, `FlatCustomSep`, `ObjectTypeName`.

`ParentID` is the runbook's ID for all three. `Enabled` is `TRUE`, `Deleted` is `FALSE`, `Number` is `0`.

| Object | `ObjectType` | `ObjectTypeName` | Position | Description |
|---|---|---|---|---|
| `Initialize Data` | `{6C576F3D-E927-417A-B145-5D3EFF9C995F}` | `Custom Start` | 100, 200 | `null` |
| `Run Power BI Lineage` | `{ED7F2A41-107A-4B74-BAFE-ADAE63632B79}` | `Run .Net Script` | 300, 200 | `Runs the Power BI lineage tool (embedded in this script) in 64-bit Windows PowerShell. Fails with the tool's message if the run fails; the run log is saved next to the Excel file.` |
| `Link` | `{7A65BD17-9532-4D07-A6DA-E0F89FA0203E}` | `Link` | `null` | `null` |

The two activities have `ASW_NotifyOnFail` `FALSE`, `Flatten` `FALSE`, `FlatUseCustomSep` `TRUE` and
`FlatCustomSep` `,`. The link has these as `null`.

### Initialize Data parameters

`CUSTOM_START_PARAMETERS` holds one `Entry` per parameter, with `UniqueID`, `ParentID` (the Initialize Data ID),
`Value` (the name), `Type` (`String`), `ParameterDescription` (`null`) and `GroupID` (`null`).

| Parameter | Script setting |
|---|---|
| `Tenant ID` | `$TenantId` |
| `App ID` | `$AppId` |
| `Client secret` | `$ClientSecret` |
| `Excel path` | `$ExcelPath` |
| `Output format` | `$OutputFormat` |
| `Mode` | `$Mode` |
| `Workspace IDs` | `$WorkspaceIds` |
| `Certificate thumbprint` | `$CertificateThumbprint` |
| `Timeout minutes` | `$TimeoutMinutes` |

### Run Power BI Lineage

After the common fields: `ScriptType` (`PowerShell`), `ScriptBody`, then `Dependencies`, `Namespaces`,
`ExecutionData` and `PublishedData`, all `null`. The activity publishes no data.

`ScriptBody` is the V1 script with each setting line written as a published-data subscription:

```powershell
$TenantId = '\`d.T.~Ed/<Initialize Data ID>.<parameter ID>\`d.T.~Ed/'
```

Each ID includes its braces, for example `{D52B175F-ED7D-15D3-EFE3-D77206D79816}` for Initialize Data.

Everything else in the script, including the compressed payload, is the same as
[`PowerBI-Lineage.Orchestrator.ps1`](../orchestrator-v1/PowerBI-Lineage.Orchestrator.ps1). Its functions,
`Get-Setting` and `Assert-Setting`, are documented in the [V1 detailed documentation](../orchestrator-v1/documentation.md#get-setting).

### Link

After the common fields: `SourceObject` (Initialize Data ID), `TargetObject` (script activity ID), `Color` `0`,
`WaitDelay` `0`, `SubPoints` `null`, `And` `null`, `Label` `null`, `Width` `0`. No conditions: the build script
describes this as "continue when Initialize Data succeeds".

### IDs

Every ID is a GUID made from the MD5 of `PowerBI-Lineage/orchestrator/<key>`, in upper case with braces:

| Key | Used for |
|---|---|
| `folder` | Folder |
| `runbook` | Policy |
| `activity/initialize-data` | Initialize Data |
| `activity/run-lineage` | Run Power BI Lineage |
| `link/initialize-to-run` | Link |
| `parameter/<name>` | Each Initialize Data parameter |

The same IDs come out of every build.

## What it writes

The file writes nothing itself. Import creates the folder, runbook and activities in Orchestrator. When the runbook
runs, the script writes what the V1 script writes: see [V1: What it writes](../orchestrator-v1/documentation.md#what-it-writes).

## Error handling

- The XML is checked for well-formedness (`[xml]`) before it is written.
- At run time, errors are those of the V1 script: bad settings are refused before unpacking, and a failed or timed-out run fails the activity with `Power BI lineage run failed: ...` or `Power BI lineage run did not finish within ...`.
- An import that fails has no handling in the file. Use the V1 script in a new activity instead.

## How it is built

`build/New-OrchestratorRunbook.ps1` writes this file in the same run as V1 and V2. It fills the template
`orchestrator/OrchestratorTool.ps1` a second time, with each `{{<parameter>}}` placeholder replaced by
`` \`d.T.~Ed/<Initialize Data ID>.<parameter ID>\`d.T.~Ed/ ``, then builds the XML described above and writes it as
UTF-8 without a byte order mark.

`tests/OrchestratorRunbook.Tests.ps1` checks that:

- the file matches a fresh build, comparing the payload after decompression;
- it starts `<ExportData><EncryptionSalt>` with a 22-character salt, one folder named `Power BI` and one `Policy` whose `ParentID` is the folder;
- the runbook fields and the first 32 fields of each object are in the order listed above, followed by the script and link fields;
- `ScriptType` is `PowerShell`;
- all objects have the runbook as parent, and the link goes from Initialize Data to the script activity;
- the Initialize Data parameters are exactly the nine names, and `ScriptBody` equals the V1 script with each setting replaced by its subscription.

## Limits and notes

- Not import-tested on an Orchestrator server. The format follows the build script's reading of Runbook Designer exports.
- The build script states that, because IDs are fixed, re-importing replaces the runbook rather than duplicating it. This has not been tested.
- The runbook is exported with `Enabled` and `Published` set to `FALSE`.
- `Client secret` is a plain `String` parameter. A value entered when the runbook starts is not protected by an encrypted variable.
- The runbook description mentions an Excel workbook, JSON and a run log, but not the CSV that is also written.
- All limits of the [V1 script](../orchestrator-v1/documentation.md#limits-and-notes) apply.
