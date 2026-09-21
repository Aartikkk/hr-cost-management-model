# Auto Intake Pipeline Setup (Agent 1 + Agent 2 combined flow)

Requires `HRD_Team2_IntakePipeline.sql` already run in SSMS (creates the staging table + 3 procedures this flow calls).

This is a **standalone Power Automate flow** — built directly in Power Automate (make.powerautomate.com), NOT from inside a Copilot Studio agent's Tools panel. It's not triggered by chat; it runs automatically the moment a file lands in your OneDrive drop box folder.

---

## 0. Before you build: prepare the upload template

Every file dropped in the folder must be an Excel file containing one worksheet with these exact column headers, formatted as a proper **Excel Table** (not just typed-in headers — select your data, then Insert → Table, or Ctrl+T). Power Automate's Excel connector can only read from real Tables, not plain ranges.

```
BusinessUnit | CostCenter | GLDescription | FiscalYear | ValueType | Amount
```

One row per data point. Example row: `SSD | Recruiting | Labor - US Company Regular | 2026 | Actual | 300000`

---

## 1. Create the flow

1. Go to **make.powerautomate.com** → **Create** → **Automated cloud flow**.
2. Name it: `HRD - Auto Intake Pipeline`
3. Search for a trigger: **"When a file is created in a folder"** (OneDrive for Business connector). Select it.
4. Click **Create**.

---

## 2. Configure the trigger

1. In the trigger step, click the **folder picker** icon and browse to your drop box folder.
2. Save.

---

## 3. Create a variable for the batch ID

Every file that comes in needs a unique ID to tag all its rows together in staging.

1. Click **+** below the trigger → search **"Initialize variable"** → add it.
2. Name: `BatchId`
3. Type: **String**
4. Value: click into the value box, switch to **Expression**, type `guid()`, click OK. (This generates a fresh unique ID every time the flow runs.)

---

## 4. Get the file and read its rows

1. Click **+** → search **OneDrive for Business** → **"Get file content"**.
2. File: click the field, and from dynamic content pick the trigger's **File identifier** (or "Id").
3. Click **+** again → search **Excel Online (Business)** → **"List rows present in a table"**.
4. **Location**: OneDrive for Business
5. **Document Library**: OneDrive
6. **File**: click the folder icon and browse to select the file dynamically — actually, since the file changes each time, click into the File field and instead pick the trigger's file identifier from dynamic content (same value used in step 4.2).
7. **Table**: once a valid file is referenced, this dropdown should show the table name inside that workbook (e.g., "Table1") — select it.

---

## 5. Loop through the rows and stage each one

1. Click **+** below "List rows present in a table" → search **"Apply to each"**.
2. **Select an output from previous steps**: pick **value** (the list of rows from step 4).
3. Inside the loop, click **+** → search **SQL Server** → **"Execute stored procedure (V2)"**.
4. Use your existing connection. Database `COSTANALYSER`. Procedure: `Team2.usp_StageBudgetRow`
5. Map parameters:
   - `BatchId` → the `BatchId` variable from step 3
   - `BusinessUnit` → dynamic content: `BusinessUnit` (from the current row)
   - `CostCenter` → dynamic content: `CostCenter`
   - `GLDescription` → dynamic content: `GLDescription`
   - `FiscalYear` → dynamic content: `FiscalYear`
   - `ValueType` → dynamic content: `ValueType`
   - `Amount` → dynamic content: `Amount`
   - `SourceFile` → dynamic content: the trigger's file **Name**

---

## 6. Process the whole batch (after the loop ends)

Make sure this next step is placed **below and outside** the "Apply to each" box — not inside it.

1. Click the **+** below the "Apply to each" box → search **SQL Server** → **"Execute stored procedure (V2)"**.
2. Procedure: `Team2.usp_ProcessStagingBatch`
3. Parameters:
   - `BatchId` → the `BatchId` variable
   - `ProcessedBy` → type the literal text `Agent1-AutoIntake`

---

## 7. Send yourself a summary notification

Since no one is watching a chat when this runs automatically, send a notification so you actually know what happened.

1. Click **+** → search **Office 365 Outlook** → **"Send an email (V2)"**.
2. **To**: your own email address.
3. **Subject**: `HRD Intake - ` then insert dynamic content: the trigger's file **Name**.
4. **Body**, type this and insert the matching dynamic content pill in place of each bracket:
   ```
   File processed: [file name]
   Rows written: [rows_written output from usp_ProcessStagingBatch]
   Rows rejected: [rows_rejected output from usp_ProcessStagingBatch]
   ```
   (The exact output field names will show in the dynamic content picker once you click into the body — look for outputs from the "Execute stored procedure" step in Section 6.)

---

## 8. Save, publish (if applicable), and test

1. Click **Save**.
2. To test: drop a small test Excel file (2-3 rows, following the template in Section 0, using a fiscal year that doesn't exist yet like 2026 so you can clearly see new rows appear) into your OneDrive drop box folder.
3. Wait a minute or two (OneDrive triggers poll periodically, not instantly), then check **My flows → HRD - Auto Intake Pipeline → run history** to see if it ran and whether it succeeded.
4. Check your email for the summary.
5. Verify in SSMS:
   ```sql
   SELECT * FROM Team2.StagingBudgetImport WHERE batch_id = (SELECT TOP 1 batch_id FROM Team2.StagingBudgetImport ORDER BY staging_id DESC);
   SELECT TOP 10 * FROM Team2.FactBudget_AuditLog ORDER BY changed_at DESC;
   ```
   You should see your test rows staged, matched, and written — with existing 2022-2025 data completely untouched.
