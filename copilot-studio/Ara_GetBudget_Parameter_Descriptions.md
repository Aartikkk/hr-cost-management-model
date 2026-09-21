# Agent 0 — Improved Parameter Descriptions for "HRD - Get Budget" Tool

Run `HRD_Team2_usp_GetBudget_v3.sql` first (fixes the subtotal-filtering bug). Then update these two parameter descriptions in Copilot Studio (Agent 0 → Tools → HRD - Get Budget → click each parameter). Replace the existing description text with what's below — full copy-paste.

---

## CostCenterName — new description

```
The specific department/cost center name. This is always one of these exact 17 values (match the closest one, even with typos or partial phrasing):

SSD business unit: Recruiting, Sourcing, Recruiting-Corporate Services, Relocation, Admin, Domestic Recruiting

HRS_CIG business unit: Human Resources Services, Training and Development, Compensation & Organization, Personnel Administration, Human Resources Adm/Planning, Central Investigations

ATPD business unit: Academic & Technical Programs, Student Placement Events & Systems, Academic Programs, Technical/Professional, Employee & Student Support

If the user's phrase matches one of these names (even loosely, e.g. "student placement" or "recruiting corp services"), it belongs in THIS parameter, never in GLDescription.
```

---

## GLDescription — new description

```
The specific financial category or line item being asked about. This is always one of these exact values (match the closest one):

Detail cost lines: Labor - US Company Regular, Labor - Regular Accrual, Labor - Incentive Plan, Labor - Special Employees, Loaned Employees Cost, Salary overtime expenses, Consultants Compensation, Temporary Labor, Invoiced Labor, Corporate Obligations, Recruiting, Public Affairs Activities, Environmental Services, Computer & Communications, Facility Operations & Maintenance, Leases, Business Support, Employee Support

Summary/subtotal lines (dollar totals that roll up several detail lines): Total Labor, Total Materials, Total Invoices, Total Net Direct Expenses, Total Allocations, Total Controllable Expenses

Headcount lines (these are employee counts, not dollars): Total Headcount, Regular+Excl. Regular, Saudi Riyal Chapter 8, Supplemental, Special Employee

Do not put a department or cost center name in this field — cost center names go in CostCenterName instead. If the user asks a broad question without naming a specific category (e.g. "what did SSD Recruiting spend in 2024"), leave this blank rather than guessing — the tool will return everything for that cost center/year.
```

---

## Also add to Agent 0's Instructions (append, don't replace existing text)

```
When calling the HRD - Get Budget tool: CostCenterName is always a department/team name (e.g. "Recruiting", "Student Placement Events & Systems"). GLDescription is always a financial category or total (e.g. "Labor", "Total Controllable Expenses", "Total Headcount"). Never put a cost center name into the GLDescription field or vice versa. If a user's question names a specific total or summary line (e.g. "total controllable expenses," "total labor"), pass it in GLDescription exactly as asked — the tool will always return it correctly regardless of whether it's a subtotal.
```
