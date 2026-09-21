# 2027 Budget Data — HRD_Intake_2027_Budget.xlsx

A complete, clean, presentation-ready budget file for fiscal year 2027 — built for the demo video, not a stress test. Every row is valid; nothing here is meant to be rejected.

## What's in it

**697 rows** — all 17 real cost centers × all 41 real GL line items (every detail line, every subtotal, and headcount), `value_type = Actual` only (no Plan placeholders, since those were empty in the real 2022-2025 data too and add nothing to a demo).

**Numbers are realistic, not random.** I pulled your actual 2025 Actual figures from `HRD_CostBreakdown_Team2.sql` and grew every cost center by a modest 6-15% (varies slightly per cost center so it doesn't look artificially uniform), then rebuilt every subtotal from its real components so everything still adds up correctly:

- Total Labor = sum of the 6 Labor detail lines
- Total Invoices = sum of the relevant detail lines (Consultants, Temporary Labor, Corporate Obligations, Recruiting, Public Affairs, Environmental Services, Computer & Communications, Facility Ops, Leases, Business Support, Employee Support)
- Total Net Direct Expenses = Total Labor + Total Materials + Total Invoices
- Total Allocations = sum of the 12 reallocation/billing/depreciation lines
- Total Controllable Expenses = Total Net Direct Expenses + Total Allocations
- Total Headcount = sum of Regular+Excl. Regular, Saudi Riyal Chapter 8, and Supplemental (Special Employee is tracked separately, same as in your real data)

Company-wide Total Controllable Expenses for 2027 comes out to **$61.46M** — a reasonable step up from 2025 across all three business units. Headcount by department is realistic small whole numbers (0-37 people depending on the department).

## Before you run this for the demo

Make sure fiscal_year 2026 test data is either left as-is (it's a legitimate, fully-validated dataset at this point, fine to show in the recording) or cleaned up if you want the demo to start from a clean 2022-2025 baseline before adding 2027 live on camera:

```sql
-- Only run this if you want to clear 2026 test data before the recording
DELETE FROM Team2.FactBudget WHERE fiscal_year = 2026;
DELETE FROM Team2.FactBudget_AuditLog WHERE fiscal_year = 2026;
DELETE FROM Team2.StagingBudgetImport WHERE raw_fiscal_year = '2026';
```

## Running it

Drop `HRD_Intake_2027_Budget.xlsx` into the drop-box folder (a fresh upload, not overwriting an existing file, so the trigger fires cleanly). With 697 rows this will take noticeably longer than any previous test — expect several minutes, not seconds.

## Verify it worked

```sql
-- Should show ~697 written, 0 (or very close to 0) rejected
SELECT process_status, COUNT(*) 
FROM Team2.StagingBudgetImport 
WHERE batch_id = (SELECT TOP 1 batch_id FROM Team2.StagingBudgetImport ORDER BY staging_id DESC)
GROUP BY process_status;

-- Confirm 2027 landed correctly and 2022-2025 is still untouched
SELECT fiscal_year, COUNT(*) FROM Team2.FactBudget GROUP BY fiscal_year ORDER BY fiscal_year;

-- Spot-check: Total Controllable Expenses per business unit, 2025 vs 2027
SELECT business_unit_name, fiscal_year, SUM(total_controllable_expenses) AS total_cost
FROM Team2.vw_ControllableExpenseSummary
WHERE fiscal_year IN (2025, 2027) AND value_type = 'Actual'
GROUP BY business_unit_name, fiscal_year
ORDER BY business_unit_name, fiscal_year;
```

## Audit log — everything that changed, today's run

```sql
USE COSTANALYSER;
GO

SELECT 
    al.changed_at,
    bu.business_unit_name,
    cc.cost_center_name,
    gl.description AS gl_description,
    al.fiscal_year,
    al.value_type,
    al.old_amount,
    al.new_amount,
    al.change_type,
    al.changed_by,
    al.source
FROM Team2.FactBudget_AuditLog al
JOIN Team2.CostCenter cc ON cc.cost_center_id = al.cost_center_id
JOIN Team2.BusinessUnit bu ON bu.business_unit_id = cc.business_unit_id
JOIN Team2.GLDescription gl ON gl.gl_description_id = al.gl_description_id
WHERE CAST(al.changed_at AS DATE) = CAST(GETUTCDATE() AS DATE)
ORDER BY al.changed_at DESC;
```

This is a good one to show on camera — it's the clearest single proof that every one of the 697 rows was individually logged with an old value (blank, since these are new inserts), new value, and source ("Agent1->Agent2 batch import"), timestamped exactly when the pipeline ran.

## After the demo

Once you're happy with the recording, refresh the Power BI dataset so the dashboard picks up 2027 too — same "Refresh now" step as before.
