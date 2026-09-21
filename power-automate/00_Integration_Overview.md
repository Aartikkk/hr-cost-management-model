# Integration Overview: Ara, Power Automate, and SQL Server

How the pieces connect, plus the one-time setup (gateway and SQL connection) that every flow depends on. Run all four scripts in `sql/` first; everything below calls the views and procedures they create.

## How the pieces fit together

Ara never touches SQL Server directly. Every action Ara takes is a Power Automate flow running in between:

```
Ara (Copilot Studio) -> Power Automate flow -> On-premises data gateway -> SQL Server (Team2 schema)
```

The file intake pipeline uses the same path, but it is triggered by a file landing in OneDrive instead of by chat. Power BI connects to SQL Server through the same gateway for its dataset.

| Component | Trigger | Calls | Build guide |
|---|---|---|---|
| HRD - Get Budget | Ara (chat) | `Team2.usp_GetBudget` | Step 2 below |
| HRD - Upsert Budget Entry | Ara (chat, after confirmation) | `Team2.usp_UpsertBudgetEntry` | `Upsert_Flow_Agent0.md` |
| HRD - Forecast Budget | Ara (chat) | `Team2.usp_ForecastBudget` | `Forecast_Flow_Agent0.md` |
| HRD - Auto Intake Pipeline | Excel file dropped in OneDrive | `usp_StageBudgetRow`, `usp_ProcessStagingBatch` | `Auto_Intake_Pipeline_Flow.md` |

Ara's full instructions and parameter descriptions are in `copilot-studio/`.

---

## Step 0: Check for an on-premises data gateway

1. Go to **make.powerautomate.com** (or **Power Platform admin center** > your environment > **Gateways**).
2. If a gateway is listed and its status is "online", skip to Step 1.
3. If nothing is listed, one needs to be installed:
   - Download the installer from the same Gateways page ("Install gateway").
   - Install it on a machine that is on the same network as SQL Server and always on. This is often the SQL Server machine itself or a dedicated always-on PC.
   - During setup, sign in with your work Microsoft 365 account and register the gateway to your Power Platform environment.
   - This usually needs IT involvement (firewall rules, service account permissions), so flag it early if you don't have local admin rights on the target machine.

## Step 1: Register the SQL Server connection

Do this once; every flow reuses it.

1. In Power Automate, go to **Data > Connections > New connection**.
2. Search for **SQL Server** and choose the **SQL Server (on-premises data gateway)** variant.
3. Fill in: server `<SQL_SERVER>`, database `COSTANALYSER`, authentication type (Windows authentication is typical on-prem), credentials, and the gateway from Step 0.
4. Test and save.

## Step 2: Build the Get Budget flow

1. Open Ara > **Tools** > **+ Add a tool** > **Flow** > **Create a new flow**. This opens the designer with "When an agent calls the flow" and "Respond to the agent" already placed.
2. Name it `HRD - Get Budget`.
3. Add optional text inputs: `BusinessUnitCode`, `CostCenterName`, `GLDescription`, `FiscalYear`, `ValueType`. Use the parameter descriptions in `copilot-studio/Ara_GetBudget_Parameter_Descriptions.md`.
4. Add **SQL Server > Execute stored procedure (V2)** with the connection from Step 1, procedure `Team2.usp_GetBudget`, and map each input to the matching parameter.
5. In "Respond to the agent", add a text output set to the procedure's result sets (use `string(outputs('Execute_stored_procedure_(V2)')?['body/ResultSets'])` if you get a type warning).
6. Save and publish.

The Upsert and Forecast flows follow the same pattern; see their guides.

---

## Guardrails

- `usp_UpsertBudgetEntry` only writes to cost center and GL combinations that already exist. A misheard or vague request can't silently create bad dimensions.
- There is no delete path anywhere in the agent layer.
- Every write is logged in `Team2.FactBudget_AuditLog` (old value, new value, who, when, which flow). Check it regularly, especially while testing.
- Give the Power Automate SQL connection its own login scoped to `EXECUTE` on the `Team2` procedures and `SELECT` on the views only, not read/write on the raw tables and never `db_owner`.

## Testing order

1. Run `EXEC Team2.usp_GetBudget @BusinessUnitCode='SSD', @CostCenterName='Recruiting', @FiscalYear=2024` in SSMS and confirm it returns rows.
2. Test the Get Budget flow on its own with the "Test" button in Power Automate.
3. Wire it to Ara and test in the Copilot Studio chat pane.
4. Only after Q&A works, add the Upsert flow and check `Team2.FactBudget_AuditLog` after each test write.
5. Add the Forecast flow, then build the intake pipeline and test it with `data/intake-tests/HRD_Intake_Sample_2026.xlsx` before the stress test.
