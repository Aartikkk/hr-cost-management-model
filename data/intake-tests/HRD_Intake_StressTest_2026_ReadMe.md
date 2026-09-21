# Intake Stress Test — HRD_Intake_StressTest_2026.xlsx

A bigger, messier test file for the "HRD - Auto Intake Pipeline" flow — 99 rows instead of 7, tagged fiscal year **2026** (kept sequential with your real 2022-2025 data, no gap).

**This is a different file from `HRD Intake Sample 2026.xlsx`** — that original file should stay in your drop-box folder untouched (needed for the flow's file/table reference, per the connection troubleshooting). This new file just happens to also use fiscal year 2026 as its data tag, but is a completely separate upload.

**Before dropping this in:** clean out old 2026/2027 test data first, so this test starts from a clean slate (see cleanup queries below, run these BEFORE, not after).

## What's in it

**~85 valid rows** — every one of the 17 real cost centers, each paired with 5 different real GL line items, mostly `Actual` with some `Plan`.

**14 deliberately broken rows**, mixed in randomly, one for each rejection path in `usp_ProcessStagingBatch`:

| Type of problem | Expected result |
|---|---|
| Cost center name that doesn't exist | Rejected — "could not be matched" |
| GL description that doesn't exist | Rejected — "could not be matched" |
| Business unit code that doesn't exist | Rejected — "could not be matched" |
| Amount isn't a number ("N/A", "fifty thousand") | Rejected — "Amount is not a valid number" |
| Fiscal year isn't valid ("not-a-year", 3050) | Rejected — "Fiscal year is not a valid year" |
| Value type isn't Actual/Plan ("Estimate", "Budgeted") | Rejected — "ValueType must be Actual or Plan" |
| Same row appearing twice in the file | Second copy rejected — "Duplicate row within this batch" |

## Step order

1. **First**, clean up old test data in SSMS:
```sql
SELECT fiscal_year, COUNT(*) AS row_count
FROM Team2.FactBudget
GROUP BY fiscal_year
ORDER BY fiscal_year;

DELETE FROM Team2.FactBudget WHERE fiscal_year IN (2026, 2027);
DELETE FROM Team2.FactBudget_AuditLog WHERE fiscal_year IN (2026, 2027);
DELETE FROM Team2.StagingBudgetImport WHERE raw_fiscal_year IN ('2026', '2027');
```
2. **Then** drop `HRD_Intake_StressTest_2026.xlsx` into the drop-box folder (alongside the existing sample file, don't remove that one).
3. Wait for the flow to trigger and finish — 99 rows will take noticeably longer than the 7-row test.
4. Check the email/SSMS for results.

## What to check afterward in SSMS

```sql
SELECT process_status, COUNT(*) 
FROM Team2.StagingBudgetImport 
WHERE batch_id = (SELECT TOP 1 batch_id FROM Team2.StagingBudgetImport ORDER BY staging_id DESC)
GROUP BY process_status;

SELECT raw_business_unit, raw_cost_center, raw_gl_description, raw_fiscal_year, raw_value_type, raw_amount, reject_reason
FROM Team2.StagingBudgetImport
WHERE batch_id = (SELECT TOP 1 batch_id FROM Team2.StagingBudgetImport ORDER BY staging_id DESC)
  AND process_status = 'Rejected';

SELECT fiscal_year, COUNT(*) FROM Team2.FactBudget GROUP BY fiscal_year ORDER BY fiscal_year;
```
Expected result: ~85 new rows written under fiscal_year 2026, 14 rejected, and 2022-2025 completely unchanged.

## Then: Power BI refresh test

Once the SQL side looks right, go to Power BI Service → your dataset → **Refresh now**, then open the report and confirm the new 2026 numbers show up. That's the full chain proven end to end.
