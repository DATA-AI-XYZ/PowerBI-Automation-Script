# Power BI Automation Scripts

Ready-to-run PowerShell tools for **Power BI administrators**. Each tool is a single file you download and run: on your
desktop, on a schedule, or in System Center Orchestrator. There's nothing to install first, and it runs on the PowerShell
built into Windows.

---

## Tools

| Tool | Answers | Download |
|---|---|---|
| [**Power BI Report Lineage**](scripts/administration/PowerBI-Lineage/) | Which database, schema and table feeds every Power BI report, through which semantic model, table and gateway. Produces an Excel workbook with a sheet per workspace. | Desktop or scheduled: [`PowerBI-Lineage.cmd`](scripts/administration/PowerBI-Lineage/PowerBI-Lineage.cmd)<br>System Center Orchestrator: [`PowerBI-Lineage.Orchestrator.ps1`](scripts/administration/PowerBI-Lineage/PowerBI-Lineage.Orchestrator.ps1) |

---

## How to use a tool

1. Open the tool's folder above. Its README starts with **Pick your file**: which download to use on your desktop, on a
   schedule, or in System Center Orchestrator, and what the tool needs in Power BI.
2. Open that file on GitHub and choose **Download raw file**.
3. Follow the matching steps in the README. On a desktop that means: double-click the `.cmd` and answer its questions.

Every script inside a `.cmd` is stored as plain text, so you can open it in Notepad and read exactly what it does
before running it.

---

## About this repository

This repository publishes the downloads only, and it is updated when a new version of a tool is released. It
does not accept contributions.

---

## Licence

MIT. See [LICENSE](LICENSE).
