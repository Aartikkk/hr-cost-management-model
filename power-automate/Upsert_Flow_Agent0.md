# Write-Back Tool Setup — on Agent 0 (Orchestrator)

Same tool as before, just built on Agent 0 this time instead of a separate agent, since Agent 0 is the only agent that talks to users. Requires `HRD_Team2_AgentInterface.sql` already run (creates `usp_UpsertBudgetEntry`, already done earlier).

---

## 1. Add to Agent 0's existing Instructions

Go to Agent 0 → wherever its Instructions/system prompt box is (same place you already edited for the Q&A fixes). **Append** this to the end of what's already there — don't delete the existing Q&A instructions:

```
You can also write/update cost and budget entries using the "HRD - Upsert Budget Entry" tool. Rules for this:
- Before calling this tool, always restate back to the user: the business unit, cost center, GL line/category, fiscal year, value type (Actual or Plan), and the dollar amount. Ask the user to explicitly confirm (e.g. "yes, save that") before calling the tool. Never write data without confirmation.
- Valid business units are: SSD, HRS_CIG (also called "HRS & CIG"), and ATPD.
- Valid value types are only "Actual" or "Plan" — if the user doesn't specify, ask which one they mean; do not assume.
- If the tool returns an error saying the cost center or GL line wasn't found, tell the user exactly what wasn't recognized and ask them to double check the spelling. Do not guess or substitute a different name yourself.
- Do not invent or guess new cost centers or GL line items that don't already exist — the tool will not create them and will intentionally error out if you try.
- After a successful save, always tell the user exactly what was recorded (business unit, cost center, GL line, year, value type, amount) so they can verify it's correct.
```

---

## 2. Build the flow

1. Open **Agent 0** → **Tools** tab → **+ Add a tool** → **Flow** → **Create a new flow**.
2. Name it: `HRD - Upsert Budget Entry`

---

## 3. Trigger inputs

Add these 7 inputs to "When an agent calls the flow":

| Name | Type | Required | Description (paste exactly) |
|---|---|---|---|
| BusinessUnitCode | Text | Yes | The business unit code. Must be one of: SSD, HRS_CIG, or ATPD. Map full names like "HRS & CIG" to HRS_CIG. |
| CostCenterName | Text | Yes | The exact cost center or department name. Must match an existing cost center — do not abbreviate or guess. |
| GLDescription | Text | Yes | The exact GL line item name (e.g. "Labor - US Company Regular", "Business Support", "Total Labor"). Must match exactly. |
| FiscalYear | Number | Yes | The 4-digit fiscal year, e.g. 2024 or 2025. |
| ValueType | Text | Yes | Must be exactly "Actual" or "Plan". |
| Amount | Number | Yes | The dollar amount as a plain number, e.g. 50000. |
| ChangedBy | Text | No | The person making this change, for audit logging. Leave blank if unknown. |

---

## 4. Add the SQL step

1. Click **+** between trigger and "Respond to the agent."
2. Search **SQL Server** → **"Execute stored procedure (V2)"**.
3. Server `<SQL_SERVER>`, Database `COSTANALYSER`, Procedure `usp_UpsertBudgetEntry`.
4. Map: BusinessUnitCode, CostCenterName, GLDescription, FiscalYear, ValueType, Amount, ChangedBy → matching trigger inputs.
5. `Source` field → type the literal text `Agent0-Orchestrator` (not dynamic content — this labels every write in the audit log as coming through the orchestrator).

---

## 5. Configure the response

1. Click **"Respond to the agent"** → **+ Add an output** → name `ConfirmationMessage`, type **Text**.
2. Value: click the lightning bolt, select this SQL step's result. If you get a type warning, use **fx** instead and type (adjust the action name if yours differs):
   ```
   string(outputs('Execute_stored_procedure_(V2)')?['body/ResultSets'])
   ```
3. **Save**, then **Publish**.

---

## 6. Set the tool's own description

Back in Agent 0's Tools list, click `HRD - Upsert Budget Entry`, set its description:
```
Use this tool to add or update a cost/budget entry. This WRITES data — only call it after the user has clearly stated the business unit, cost center, GL line, fiscal year, value type, and dollar amount, AND has explicitly confirmed they want to save it.
```

---

## 7. Test

1. Fresh chat with Agent 0.
2. Try: *"Update SSD Recruiting's Business Support for 2024 to $999,999"* (obviously fake test number).
3. Confirm it restates the details and asks for confirmation before saving — if not, recheck Section 1's instructions were actually saved.
4. Confirm, then verify:
```sql
SELECT TOP 5 * FROM Team2.FactBudget_AuditLog ORDER BY changed_at DESC;
```
Look for `source = 'Agent0-Orchestrator'` and the correct old/new amounts.
