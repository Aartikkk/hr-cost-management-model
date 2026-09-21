-- ============================================================
-- HRD Cost Breakdown - Team2 Agent Interface Layer
-- Purpose: Views + stored procedures that Power Automate flows
-- call on behalf of the 4 Copilot Studio agents, so
-- agents never touch raw tables directly.
-- Requires: HRD_CostBreakdown_Team2.sql already run successfully
-- (Team2.BusinessUnit, CostCenter, GLDescription, FactBudget exist)
-- ============================================================

USE COSTANALYSER;
GO

-- ------------------------------------------------------------
-- 1. AUDIT LOG - every write an agent makes gets recorded here.
-- This is your safety net: if an agent writes something wrong,
-- you can see exactly what changed, when, and revert it.
-- ------------------------------------------------------------
IF OBJECT_ID('Team2.FactBudget_AuditLog','U') IS NOT NULL DROP TABLE Team2.FactBudget_AuditLog;
GO

CREATE TABLE Team2.FactBudget_AuditLog (
    audit_id            BIGINT          IDENTITY(1,1) PRIMARY KEY,
    fact_id              BIGINT         NULL,
    cost_center_id         INT          NOT NULL,
    gl_description_id       INT         NOT NULL,
    fiscal_year               SMALLINT  NOT NULL,
    value_type                 VARCHAR(10) NOT NULL,
    old_amount                   DECIMAL(18,2) NULL,
    new_amount                     DECIMAL(18,2) NULL,
    change_type                      VARCHAR(10) NOT NULL, -- 'INSERT' or 'UPDATE'
    changed_by                         VARCHAR(100) NULL,   -- pass the agent/user name from Copilot Studio
    source                                VARCHAR(100) NULL, -- e.g. 'CopilotAgent-CostQA'
    changed_at                              DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ------------------------------------------------------------
-- 2. READ VIEW - flat, denormalized, human-readable.
-- Power Automate "Get rows" / Power BI / agents all read
-- from this instead of joining 4 tables themselves.
-- ------------------------------------------------------------
IF OBJECT_ID('Team2.vw_BudgetDetail','V') IS NOT NULL DROP VIEW Team2.vw_BudgetDetail;
GO

CREATE VIEW Team2.vw_BudgetDetail AS
SELECT
    f.fact_id,
    bu.business_unit_code,
    bu.business_unit_name,
    cc.cost_center_id,
    cc.cost_center_name,
    gl.gl_description_id,
    gl.description         AS gl_description,
    gl.measure_type,
    gl.is_subtotal,
    f.fiscal_year,
    f.value_type,
    f.amount,
    f.source_sheet
FROM Team2.FactBudget f
JOIN Team2.CostCenter   cc ON cc.cost_center_id = f.cost_center_id
JOIN Team2.BusinessUnit bu ON bu.business_unit_id = cc.business_unit_id
JOIN Team2.GLDescription gl ON gl.gl_description_id = f.gl_description_id;
GO

-- ------------------------------------------------------------
-- 3. REPORTING VIEW - one row per business unit/cost center/year,
-- using "Total Controllable Expenses" as the authoritative
-- bottom-line figure. This is what a report-trigger flow or
-- Power BI dashboard should point at for summary numbers.
-- ------------------------------------------------------------
IF OBJECT_ID('Team2.vw_ControllableExpenseSummary','V') IS NOT NULL DROP VIEW Team2.vw_ControllableExpenseSummary;
GO

CREATE VIEW Team2.vw_ControllableExpenseSummary AS
SELECT
    business_unit_code,
    business_unit_name,
    cost_center_name,
    fiscal_year,
    value_type,
    amount AS total_controllable_expenses
FROM Team2.vw_BudgetDetail
WHERE gl_description = 'Total Controllable Expenses';
GO

-- ------------------------------------------------------------
-- 4. READ PROC - for the Q&A agent(s).
-- All parameters are optional and use partial (LIKE) matching
-- on text fields, since a conversational agent won't always
-- pass the exact casing/spelling a user typed.
-- - Business unit matches on code OR name ("HRS_CIG" or "HRS & CIG")
-- - Commas, hyphens and & are ignored when matching names
-- - Subtotals are hidden when browsing broadly, but a subtotal
--   the user asks for by name is always returned
-- ------------------------------------------------------------
IF OBJECT_ID('Team2.usp_GetBudget','P') IS NOT NULL DROP PROCEDURE Team2.usp_GetBudget;
GO

CREATE PROCEDURE Team2.usp_GetBudget
    @BusinessUnitCode  VARCHAR(50)  = NULL,
    @CostCenterName    VARCHAR(150) = NULL,
    @GLDescription     VARCHAR(150) = NULL,
    @FiscalYear        SMALLINT     = NULL,
    @ValueType         VARCHAR(10)  = NULL,
    @IncludeSubtotals  BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        business_unit_code, business_unit_name, cost_center_name,
        gl_description, measure_type, fiscal_year, value_type, amount
    FROM Team2.vw_BudgetDetail
    WHERE (@BusinessUnitCode IS NULL
           OR business_unit_code LIKE '%' + @BusinessUnitCode + '%'
           OR business_unit_name LIKE '%' + @BusinessUnitCode + '%')
      AND (@CostCenterName IS NULL
           OR REPLACE(REPLACE(REPLACE(cost_center_name, ',', ''), '&', ''), '-', '')
              LIKE '%' + REPLACE(REPLACE(REPLACE(@CostCenterName, ',', ''), '&', ''), '-', '') + '%')
      AND (@GLDescription IS NULL
           OR REPLACE(REPLACE(REPLACE(gl_description, ',', ''), '&', ''), '-', '')
              LIKE '%' + REPLACE(REPLACE(REPLACE(@GLDescription, ',', ''), '&', ''), '-', '') + '%')
      AND (@FiscalYear       IS NULL OR fiscal_year = @FiscalYear)
      AND (@ValueType        IS NULL OR value_type = @ValueType)
      AND (@IncludeSubtotals = 1 OR is_subtotal = 0 OR @GLDescription IS NOT NULL)
    ORDER BY business_unit_name, cost_center_name, fiscal_year;
END
GO

-- ------------------------------------------------------------
-- 5. WRITE PROC - for the data-entry agent(s).
-- Deliberately narrow: it will NOT create new cost centers or
-- GL lines on the fly (that requires a real decision, not an
-- agent guess) - it only inserts/updates an amount for an
-- EXISTING business unit + cost center + GL line combination.
-- Every write is logged to the audit table.
-- ------------------------------------------------------------
IF OBJECT_ID('Team2.usp_UpsertBudgetEntry','P') IS NOT NULL DROP PROCEDURE Team2.usp_UpsertBudgetEntry;
GO

CREATE PROCEDURE Team2.usp_UpsertBudgetEntry
    @BusinessUnitCode VARCHAR(20),
    @CostCenterName   VARCHAR(150),
    @GLDescription    VARCHAR(150),
    @FiscalYear       SMALLINT,
    @ValueType        VARCHAR(10) = 'Actual',
    @Amount           DECIMAL(18,2),
    @ChangedBy        VARCHAR(100) = NULL,
    @Source           VARCHAR(100) = 'CopilotAgent'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CostCenterId INT, @GLDescriptionId INT, @FactId BIGINT, @OldAmount DECIMAL(18,2);

    SELECT @CostCenterId = cc.cost_center_id
    FROM Team2.CostCenter cc
    JOIN Team2.BusinessUnit bu ON bu.business_unit_id = cc.business_unit_id
    WHERE bu.business_unit_code = @BusinessUnitCode
      AND cc.cost_center_name = @CostCenterName;

    IF @CostCenterId IS NULL
    BEGIN
        RAISERROR('No matching cost center "%s" under business unit "%s". Check spelling/exact name - this procedure will not create a new cost center.', 16, 1, @CostCenterName, @BusinessUnitCode);
        RETURN;
    END

    SELECT @GLDescriptionId = gl_description_id
    FROM Team2.GLDescription
    WHERE description = @GLDescription;

    IF @GLDescriptionId IS NULL
    BEGIN
        RAISERROR('No matching GL description "%s". Check spelling/exact name - this procedure will not create a new GL line.', 16, 1, @GLDescription);
        RETURN;
    END

    IF @ValueType NOT IN ('Actual','Plan')
    BEGIN
        RAISERROR('ValueType must be ''Actual'' or ''Plan''.', 16, 1);
        RETURN;
    END

    BEGIN TRAN;

    SELECT @FactId = fact_id, @OldAmount = amount
    FROM Team2.FactBudget
    WHERE cost_center_id = @CostCenterId
      AND gl_description_id = @GLDescriptionId
      AND fiscal_year = @FiscalYear
      AND value_type = @ValueType;

    IF @FactId IS NULL
    BEGIN
        INSERT INTO Team2.FactBudget (cost_center_id, gl_description_id, fiscal_year, value_type, amount, source_sheet)
        VALUES (@CostCenterId, @GLDescriptionId, @FiscalYear, @ValueType, @Amount, @Source);

        SET @FactId = SCOPE_IDENTITY();

        INSERT INTO Team2.FactBudget_AuditLog (fact_id, cost_center_id, gl_description_id, fiscal_year, value_type, old_amount, new_amount, change_type, changed_by, source)
        VALUES (@FactId, @CostCenterId, @GLDescriptionId, @FiscalYear, @ValueType, NULL, @Amount, 'INSERT', @ChangedBy, @Source);
    END
    ELSE
    BEGIN
        UPDATE Team2.FactBudget
        SET amount = @Amount
        WHERE fact_id = @FactId;

        INSERT INTO Team2.FactBudget_AuditLog (fact_id, cost_center_id, gl_description_id, fiscal_year, value_type, old_amount, new_amount, change_type, changed_by, source)
        VALUES (@FactId, @CostCenterId, @GLDescriptionId, @FiscalYear, @ValueType, @OldAmount, @Amount, 'UPDATE', @ChangedBy, @Source);
    END

    COMMIT TRAN;

    -- Return the resulting row so Power Automate can pass a confirmation back to the agent
    SELECT * FROM Team2.vw_BudgetDetail WHERE fact_id = @FactId;
END
GO

-- ------------------------------------------------------------
-- 6. REPORT-TRIGGER PROC - for the report/refresh agent(s).
-- Returns a compact summary suitable for an Excel export or
-- as the payload before/after a Power BI dataset refresh.
-- ------------------------------------------------------------
IF OBJECT_ID('Team2.usp_GetControllableExpenseSummary','P') IS NOT NULL DROP PROCEDURE Team2.usp_GetControllableExpenseSummary;
GO

CREATE PROCEDURE Team2.usp_GetControllableExpenseSummary
    @BusinessUnitCode VARCHAR(20) = NULL,
    @FiscalYear       SMALLINT    = NULL,
    @ValueType        VARCHAR(10) = 'Actual'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT business_unit_name, cost_center_name, fiscal_year, value_type, total_controllable_expenses
    FROM Team2.vw_ControllableExpenseSummary
    WHERE (@BusinessUnitCode IS NULL OR business_unit_code = @BusinessUnitCode)
      AND (@FiscalYear       IS NULL OR fiscal_year = @FiscalYear)
      AND (@ValueType        IS NULL OR value_type = @ValueType)
    ORDER BY business_unit_name, cost_center_name, fiscal_year;
END
GO

-- ------------------------------------------------------------
-- 7. Sanity checks - run these after executing the script
-- ------------------------------------------------------------
EXEC Team2.usp_GetBudget @BusinessUnitCode = 'SSD', @CostCenterName = 'Recruiting', @FiscalYear = 2024;
GO
SELECT TOP 10 * FROM Team2.vw_ControllableExpenseSummary ORDER BY fiscal_year DESC;
GO
