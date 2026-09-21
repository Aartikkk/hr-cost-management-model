# Forecast Tool Setup — HRD - Forecast Budget (on Agent 0)

## 0. Run the SQL first

Run `HRD_Team2_usp_ForecastBudget.sql` in SSMS against `COSTANALYSER`. Creates `Team2.usp_ForecastBudget` — read-only, never writes to any table. Test it directly with the sample `EXEC` statement at the bottom of the script before wiring up the flow.

---

## 1. Build the flow

Same pattern as your other two tools. Agent 0 → **Tools** tab → **+ Add a tool** → **Flow** → **Create a new flow**. Name it `HRD - Forecast Budget`.

---

## 2. Add 5 inputs to the trigger

| Name | Type | Required | Description |
|---|---|---|---|
| BusinessUnitCode | Text | Yes | The business unit code. Must be one of: SSD, HRS_CIG, or ATPD. Map full names like "HRS & CIG" to HRS_CIG. |
| CostCenterName | Text | Yes | The exact cost center or department name. |
| GLDescription | Text | Yes | The exact GL line item or total being forecasted (e.g. "Total Labor", "Business Support"). |
| ValueType | Text | Yes | Must be exactly "Actual" or "Plan". |
| TargetYear | Number | Yes | The future fiscal year to estimate, e.g. 2026 or 2027. |

---

## 3. Add the SQL action

**+** → **SQL Server** → **"Execute stored procedure (V2)"**. Same connection as your other tools. Procedure: `Team2.usp_ForecastBudget`. Map the 5 inputs to the matching parameters.

---

## 4. Configure the response

"Respond to the agent" → **+ Add an output** → name `ForecastResult`, type **Text**. Click **fx** and enter:

```
string(outputs('Execute_stored_procedure_(V2)')?['body/ResultSets'])
```

(adjust the action name in quotes if Power Automate numbered it differently, e.g. `_(V2)_2`)

Save, then **Publish**.

---

## 5. Set the tool's own description

```
Use this tool when the user asks for a future-year estimate, projection, or forecast (a year that hasn't happened yet / has no real data). Do NOT use HRD-GetBudget for this — that tool only returns real recorded data. This tool computes an estimate from historical trend data and always returns it labeled as an estimate, never as an actual or plan value.
```

---

## 6. Add to Agent 0's Instructions

Append this new block to the Instructions box (after the write-back section):

```
If the user asks for a forecast, projection, or estimate for a future year (a year with no actual data yet), use the 'HRD-ForecastBudget' tool instead of HRD-GetBudget. Always tell the user clearly that this is an ESTIMATE, not real recorded data, and state how many years of history it's based on (e.g. "based on a trend across 2022-2025"). If the tool reports insufficient data, tell the user plainly that there isn't enough history to forecast that combination - do not make up a number yourself. If the tool reports that actual data already exists for that year, just report that real value normally instead of calling it an estimate. Never write a forecasted/estimated value to the database - forecasts are informational only and are never saved, even if the user seems to want to record them. If someone wants to record a real number, that's a job for HRD-UpsertBudgetEntry with a real confirmed value, not a forecast.
```

---

## 7. Test

1. Fresh chat: *"What's the estimated Total Labor for SSD Recruiting in 2026?"* — confirm it uses this tool (not GetBudget), returns a number labeled as an estimate, and mentions the years of history used.
2. Try a combination you know has less than 2 years of data (or an obviously new/rare one) — confirm it says there isn't enough data rather than guessing.
3. Try asking it to "save" or "record" the forecasted number — confirm it declines and explains forecasts aren't written to the database.
