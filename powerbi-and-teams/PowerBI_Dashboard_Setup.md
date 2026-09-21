# Power BI Dashboard Setup (Passive — No Agent Involved)

This is just a report that pulls live from `Team2` views through the same on-prem gateway you already set up for Power Automate. No chat, no Agent 3 — you or anyone with access just opens it in Power BI whenever they want to look.

Do this on your **work computer** (where SQL Server access and the gateway are).

---

## 1. Install Power BI Desktop (if not already)

Get it from the Microsoft Store, or powerbi.com → Download Power BI Desktop. Free.

---

## 2. Connect to your data

1. Open Power BI Desktop → **Get Data** → search **SQL Server** → **Connect**.
2. **Server**: `<SQL_SERVER>` (same as your other connections)
3. **Database**: `COSTANALYSER`
4. **Data Connectivity mode**: choose **Import** (simplest — loads a snapshot, refreshes on a schedule you set; recommended given your data size).
5. Click **OK**, sign in with Windows authentication if prompted.

---

## 3. Pick the tables

In the **Navigator** window, check the boxes for:
- `Team2.vw_BudgetDetail`
- `Team2.vw_ControllableExpenseSummary`

Click **Load**.

---

## 4. Build the report

Some suggested visuals to start with (drag fields from the right-hand panel onto the canvas):

- **Card**: Total Controllable Expenses (from `vw_ControllableExpenseSummary`)
- **Bar chart**: Amount by Business Unit
- **Line chart**: Amount by Fiscal Year (trend across 2022-2025+)
- **Table/Matrix**: Cost Center × GL Description × Amount, filterable
- **Slicers**: Business Unit, Fiscal Year, Value Type (Actual/Plan) — lets viewers filter without editing the report

Rename the page tab (bottom) to something like "HRD Cost Overview."

---

## 5. Publish to Power BI Service

1. Click **Publish** (top ribbon, Home tab).
2. Sign in with your work Microsoft 365 account if prompted.
3. Choose a workspace — "My workspace" is fine to start, or a shared team workspace if others need to see it too.
4. Click **Select**, wait for it to finish, click the link it gives you to open it in the browser.

---

## 6. Connect it to the gateway (for automatic refresh)

Publishing only uploads a snapshot — to keep it current automatically, point the dataset at your existing gateway:

1. In Power BI Service (app.powerbi.com), go to the workspace → find your dataset (not the report) → **⋯** → **Settings**.
2. Expand **Gateway connection**. You should see the same on-prem gateway you registered earlier for Power Automate — select it. (If it's not listed, someone with gateway-admin rights needs to add your account/dataset to that gateway's allowed users in the Power Platform admin center.)
3. Under **Data source credentials**, enter the same Windows Authentication credentials used for the SQL connection. Click **Sign in** / **Apply**.

---

## 7. Set a refresh schedule

Still in dataset **Settings** → expand **Scheduled refresh**:
1. Toggle it **On**.
2. Pick a frequency (e.g. Daily) and a time.
3. Click **Apply**.

Now the dashboard updates itself on schedule — no manual steps, no chat, no agent.

---

## 8. Test it

1. Click **Refresh now** once (same **⋯** menu on the dataset) to confirm it runs successfully rather than waiting for the schedule.
2. Open the report and confirm your test/real data shows correctly, including any recent test rows from your intake pipeline testing (2026/2027) if you haven't cleaned those out yet.
3. Share the report link (or add people to the workspace) with whoever needs to view it — they don't need Power BI Desktop, just a browser and access.
