-- ============================================================
-- HRD Cost Breakdown - Intake Pipeline (Agent 1 -> Agent 2)
-- Staging table + procedures for bulk file-drop processing.
-- Safe to run anytime - only adds new objects, touches nothing
-- in BusinessUnit / CostCenter / GLDescription / FactBudget.
-- ============================================================

USE COSTANALYSER;
GO

-- ------------------------------------------------------------
-- 1. STAGING TABLE - landing zone for a file drop. Nothing here
--    is trusted yet. Agent 1 writes raw rows in; Agent 2 reads,
--    validates, and only then writes to the real FactBudget table.
-- ------------------------------------------------------------
IF OBJECT_ID('Team2.StagingBudgetImport','U') IS NOT NULL DROP TABLE Team2.StagingBudgetImport;
GO

CREATE TABLE Team2.StagingBudgetImport (
    staging_id              BIGINT          IDENTITY(1,1) PRIMARY KEY,
    batch_id                 UNIQUEIDENTIFIER NOT NULL,
    raw_business_unit         VARCHAR(150)   NOT NULL,
    raw_cost_center             VARCHAR(150) NOT NULL,
    raw_gl_description            VARCHAR(150) NOT NULL,
    raw_fiscal_year                  VARCHAR(20) NOT NULL,
    raw_value_type                      VARCHAR(20) NOT NULL,
    raw_amount                             VARCHAR(50) NOT NULL,
    matched_business_unit_id                  INT NULL,
    matched_cost_center_id                       INT NULL,
    matched_gl_description_id                       INT NULL,
    match_status                                       VARCHAR(20) NOT NULL DEFAULT 'Pending', -- Pending / Matched / Unmatched
    process_status                                        VARCHAR(20) NOT NULL DEFAULT 'Pending', -- Pending / Written / Rejected
    reject_reason                                            VARCHAR(500) NULL,
    source_file                                                 VARCHAR(300) NULL,
    staged_at                                                      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    processed_at                                                      DATETIME2 NULL
);
GO
CREATE INDEX IX_StagingBudgetImport_BatchId ON Team2.StagingBudgetImport(batch_id);
GO

-- ------------------------------------------------------------
-- 2. STAGE ONE ROW - Agent 1 calls this once per row from the
--    uploaded file (via "Apply to each" over the Excel table).
--    Attempts to fuzzy-match the text against existing dimensions;
--    never creates new cost centers/GL lines automatically.
-- ------------------------------------------------------------
IF OBJECT_ID('Team2.usp_StageBudgetRow','P') IS NOT NULL DROP PROCEDURE Team2.usp_StageBudgetRow;
GO

CREATE PROCEDURE Team2.usp_StageBudgetRow
    @BatchId          UNIQUEIDENTIFIER,
    @BusinessUnit      VARCHAR(150),
    @CostCenter        VARCHAR(150),
    @GLDescription     VARCHAR(150),
    @FiscalYear        VARCHAR(20),
    @ValueType         VARCHAR(20),
    @Amount            VARCHAR(50),
    @SourceFile        VARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BuId INT, @CcId INT, @GlId INT;

    SELECT TOP 1 @BuId = bu.business_unit_id
    FROM Team2.BusinessUnit bu
    WHERE bu.business_unit_code = @BusinessUnit
       OR bu.business_unit_name LIKE '%' + @BusinessUnit + '%';

    SELECT TOP 1 @CcId = cc.cost_center_id
    FROM Team2.CostCenter cc
    WHERE cc.business_unit_id = @BuId
      AND cc.cost_center_name LIKE '%' + @CostCenter + '%';

    SELECT TOP 1 @GlId = gl.gl_description_id
    FROM Team2.GLDescription gl
    WHERE gl.description LIKE '%' + @GLDescription + '%';

    INSERT INTO Team2.StagingBudgetImport
        (batch_id, raw_business_unit, raw_cost_center, raw_gl_description, raw_fiscal_year, raw_value_type, raw_amount,
         matched_business_unit_id, matched_cost_center_id, matched_gl_description_id, match_status, source_file)
    VALUES
        (@BatchId, @BusinessUnit, @CostCenter, @GLDescription, @FiscalYear, @ValueType, @Amount,
         @BuId, @CcId, @GlId,
         CASE WHEN @BuId IS NOT NULL AND @CcId IS NOT NULL AND @GlId IS NOT NULL THEN 'Matched' ELSE 'Unmatched' END,
         @SourceFile);

    -- Return what was (or wasn't) matched so Agent 1 can report it immediately if needed
    SELECT SCOPE_IDENTITY() AS staging_id, @BuId AS matched_business_unit_id,
           @CcId AS matched_cost_center_id, @GlId AS matched_gl_description_id;
END
GO

-- ------------------------------------------------------------
-- 3. BATCH SUMMARY - check match status before/after processing.
--    Agent 1 can call this after staging all rows to decide
--    whether to proceed or hold for review.
-- ------------------------------------------------------------
IF OBJECT_ID('Team2.usp_GetStagingBatchSummary','P') IS NOT NULL DROP PROCEDURE Team2.usp_GetStagingBatchSummary;
GO

CREATE PROCEDURE Team2.usp_GetStagingBatchSummary
    @BatchId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(*) AS total_rows,
        SUM(CASE WHEN match_status = 'Matched' THEN 1 ELSE 0 END) AS matched_rows,
        SUM(CASE WHEN match_status = 'Unmatched' THEN 1 ELSE 0 END) AS unmatched_rows
    FROM Team2.StagingBudgetImport
    WHERE batch_id = @BatchId;

    -- Detail on exactly which rows couldn't be matched, for human review
    SELECT staging_id, raw_business_unit, raw_cost_center, raw_gl_description, raw_fiscal_year, raw_value_type, raw_amount
    FROM Team2.StagingBudgetImport
    WHERE batch_id = @BatchId AND match_status = 'Unmatched';
END
GO

-- ------------------------------------------------------------
-- 4. PROCESS BATCH - Agent 2 calls this once per file drop.
--    Validates matched rows, bulk-writes valid ones into
--    FactBudget (insert-or-update, never deletes existing data),
--    logs every change to the audit table, and rejects (without
--    writing) anything that fails validation.
-- ------------------------------------------------------------
IF OBJECT_ID('Team2.usp_ProcessStagingBatch','P') IS NOT NULL DROP PROCEDURE Team2.usp_ProcessStagingBatch;
GO

CREATE PROCEDURE Team2.usp_ProcessStagingBatch
    @BatchId     UNIQUEIDENTIFIER,
    @ProcessedBy VARCHAR(100) = 'Agent2-DataTransformation'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Reject unmatched rows outright - never guess at dimensions
    UPDATE Team2.StagingBudgetImport
    SET process_status = 'Rejected', reject_reason = 'Cost center, business unit, or GL description could not be matched', processed_at = SYSUTCDATETIME()
    WHERE batch_id = @BatchId AND match_status = 'Unmatched' AND process_status = 'Pending';

    -- Reject rows with a non-numeric amount
    UPDATE Team2.StagingBudgetImport
    SET process_status = 'Rejected', reject_reason = 'Amount is not a valid number', processed_at = SYSUTCDATETIME()
    WHERE batch_id = @BatchId AND process_status = 'Pending' AND TRY_CAST(raw_amount AS DECIMAL(18,2)) IS NULL;

    -- Reject rows with an invalid fiscal year
    UPDATE Team2.StagingBudgetImport
    SET process_status = 'Rejected', reject_reason = 'Fiscal year is not a valid year', processed_at = SYSUTCDATETIME()
    WHERE batch_id = @BatchId AND process_status = 'Pending' AND (TRY_CAST(raw_fiscal_year AS SMALLINT) IS NULL OR TRY_CAST(raw_fiscal_year AS SMALLINT) NOT BETWEEN 2000 AND 2100);

    -- Reject rows with an invalid value type
    UPDATE Team2.StagingBudgetImport
    SET process_status = 'Rejected', reject_reason = 'ValueType must be Actual or Plan', processed_at = SYSUTCDATETIME()
    WHERE batch_id = @BatchId AND process_status = 'Pending' AND raw_value_type NOT IN ('Actual','Plan');

    -- Reject duplicate rows within the same batch (same target cell appearing twice)
    ;WITH dupes AS (
        SELECT staging_id,
               ROW_NUMBER() OVER (PARTITION BY matched_cost_center_id, matched_gl_description_id, raw_fiscal_year, raw_value_type ORDER BY staging_id) AS rn
        FROM Team2.StagingBudgetImport
        WHERE batch_id = @BatchId AND process_status = 'Pending'
    )
    UPDATE s
    SET process_status = 'Rejected', reject_reason = 'Duplicate row within this batch', processed_at = SYSUTCDATETIME()
    FROM Team2.StagingBudgetImport s
    JOIN dupes d ON d.staging_id = s.staging_id
    WHERE d.rn > 1;

    BEGIN TRAN;

    -- Everything still Pending at this point has passed all checks - write it
    DECLARE @ToWrite TABLE (staging_id BIGINT, cost_center_id INT, gl_description_id INT, fiscal_year SMALLINT, value_type VARCHAR(10), amount DECIMAL(18,2));

    INSERT INTO @ToWrite
    SELECT staging_id, matched_cost_center_id, matched_gl_description_id,
           TRY_CAST(raw_fiscal_year AS SMALLINT), raw_value_type, TRY_CAST(raw_amount AS DECIMAL(18,2))
    FROM Team2.StagingBudgetImport
    WHERE batch_id = @BatchId AND process_status = 'Pending';

    -- Update existing rows (same cost center + GL + year + value type already exists)
    UPDATE fb
    SET fb.amount = w.amount
    OUTPUT inserted.fact_id, inserted.cost_center_id, inserted.gl_description_id, inserted.fiscal_year, inserted.value_type,
           deleted.amount, inserted.amount, 'UPDATE', @ProcessedBy, 'Agent1->Agent2 batch import'
    INTO Team2.FactBudget_AuditLog(fact_id, cost_center_id, gl_description_id, fiscal_year, value_type, old_amount, new_amount, change_type, changed_by, source)
    FROM Team2.FactBudget fb
    JOIN @ToWrite w ON w.cost_center_id = fb.cost_center_id AND w.gl_description_id = fb.gl_description_id
                    AND w.fiscal_year = fb.fiscal_year AND w.value_type = fb.value_type;

    -- Insert brand-new rows (e.g. a new fiscal year that doesn't exist yet - this is the common case)
    INSERT INTO Team2.FactBudget (cost_center_id, gl_description_id, fiscal_year, value_type, amount, source_sheet)
    OUTPUT inserted.fact_id, inserted.cost_center_id, inserted.gl_description_id, inserted.fiscal_year, inserted.value_type,
           NULL, inserted.amount, 'INSERT', @ProcessedBy, 'Agent1->Agent2 batch import'
    INTO Team2.FactBudget_AuditLog(fact_id, cost_center_id, gl_description_id, fiscal_year, value_type, old_amount, new_amount, change_type, changed_by, source)
    SELECT w.cost_center_id, w.gl_description_id, w.fiscal_year, w.value_type, w.amount, 'Agent1 batch import'
    FROM @ToWrite w
    WHERE NOT EXISTS (
        SELECT 1 FROM Team2.FactBudget fb
        WHERE fb.cost_center_id = w.cost_center_id AND fb.gl_description_id = w.gl_description_id
          AND fb.fiscal_year = w.fiscal_year AND fb.value_type = w.value_type
    );

    UPDATE Team2.StagingBudgetImport
    SET process_status = 'Written', processed_at = SYSUTCDATETIME()
    WHERE staging_id IN (SELECT staging_id FROM @ToWrite);

    COMMIT TRAN;

    -- Final summary for Agent 2 to report back
    SELECT
        SUM(CASE WHEN process_status = 'Written' THEN 1 ELSE 0 END) AS rows_written,
        SUM(CASE WHEN process_status = 'Rejected' THEN 1 ELSE 0 END) AS rows_rejected
    FROM Team2.StagingBudgetImport
    WHERE batch_id = @BatchId;

    SELECT staging_id, raw_cost_center, raw_gl_description, raw_fiscal_year, reject_reason
    FROM Team2.StagingBudgetImport
    WHERE batch_id = @BatchId AND process_status = 'Rejected';
END
GO
