-- ============================================================
-- HRD Cost Breakdown - Forecast tool
-- Adds Team2.usp_ForecastBudget: projects a future-year estimate
-- using a linear trend across existing historical years.
-- Never writes anything - read-only, returns an ESTIMATE label.
-- Run this in SSMS against the COSTANALYSER database.
-- ============================================================

USE COSTANALYSER;
GO

CREATE OR ALTER PROCEDURE Team2.usp_ForecastBudget
    @BusinessUnitCode NVARCHAR(50),
    @CostCenterName   NVARCHAR(200),
    @GLDescription    NVARCHAR(200),
    @ValueType        NVARCHAR(20),
    @TargetYear       INT
AS
BEGIN
    SET NOCOUNT ON;

    -- If the target year already has real data, just return that instead of forecasting.
    DECLARE @ExistingAmount DECIMAL(18,2);

    SELECT @ExistingAmount = amount
    FROM Team2.vw_BudgetDetail
    WHERE (business_unit_code = @BusinessUnitCode OR business_unit_name LIKE '%' + @BusinessUnitCode + '%')
      AND REPLACE(REPLACE(REPLACE(cost_center_name, ',', ''), '&', ''), '-', '')
          LIKE '%' + REPLACE(REPLACE(REPLACE(@CostCenterName, ',', ''), '&', ''), '-', '') + '%'
      AND REPLACE(REPLACE(REPLACE(gl_description, ',', ''), '&', ''), '-', '')
          LIKE '%' + REPLACE(REPLACE(REPLACE(@GLDescription, ',', ''), '&', ''), '-', '') + '%'
      AND fiscal_year = @TargetYear
      AND value_type = @ValueType;

    IF @ExistingAmount IS NOT NULL
    BEGIN
        SELECT
            @BusinessUnitCode AS business_unit_code,
            @CostCenterName   AS cost_center_name,
            @GLDescription    AS gl_description,
            @ValueType        AS value_type,
            @TargetYear       AS target_year,
            @ExistingAmount   AS projected_amount,
            0                 AS years_of_history_used,
            CAST(NULL AS INT) AS earliest_year,
            CAST(NULL AS INT) AS latest_year,
            'ACTUAL_DATA_EXISTS' AS method,
            'This year already has real data recorded - returning the actual value instead of a forecast.' AS status_message;
        RETURN;
    END

    -- Gather historical data points for this exact combination
    DECLARE @n INT, @sumX FLOAT, @sumY FLOAT, @sumXY FLOAT, @sumX2 FLOAT,
            @minYear INT, @maxYear INT;

    SELECT
        @n       = COUNT(*),
        @sumX    = SUM(CAST(fiscal_year AS FLOAT)),
        @sumY    = SUM(CAST(amount AS FLOAT)),
        @sumXY   = SUM(CAST(fiscal_year AS FLOAT) * CAST(amount AS FLOAT)),
        @sumX2   = SUM(CAST(fiscal_year AS FLOAT) * CAST(fiscal_year AS FLOAT)),
        @minYear = MIN(fiscal_year),
        @maxYear = MAX(fiscal_year)
    FROM Team2.vw_BudgetDetail
    WHERE (business_unit_code = @BusinessUnitCode OR business_unit_name LIKE '%' + @BusinessUnitCode + '%')
      AND REPLACE(REPLACE(REPLACE(cost_center_name, ',', ''), '&', ''), '-', '')
          LIKE '%' + REPLACE(REPLACE(REPLACE(@CostCenterName, ',', ''), '&', ''), '-', '') + '%'
      AND REPLACE(REPLACE(REPLACE(gl_description, ',', ''), '&', ''), '-', '')
          LIKE '%' + REPLACE(REPLACE(REPLACE(@GLDescription, ',', ''), '&', ''), '-', '') + '%'
      AND value_type = @ValueType;

    -- Not enough data points to fit a trend line
    IF @n IS NULL OR @n < 2
    BEGIN
        SELECT
            @BusinessUnitCode AS business_unit_code,
            @CostCenterName   AS cost_center_name,
            @GLDescription    AS gl_description,
            @ValueType        AS value_type,
            @TargetYear       AS target_year,
            CAST(NULL AS DECIMAL(18,2)) AS projected_amount,
            ISNULL(@n, 0)     AS years_of_history_used,
            @minYear          AS earliest_year,
            @maxYear          AS latest_year,
            'INSUFFICIENT_DATA' AS method,
            'Not enough historical data to forecast - need at least 2 years of data for this combination.' AS status_message;
        RETURN;
    END

    -- Least-squares linear regression: y = slope * year + intercept
    DECLARE @slope FLOAT, @intercept FLOAT, @projected FLOAT;

    SET @slope     = (@n * @sumXY - @sumX * @sumY) / (@n * @sumX2 - @sumX * @sumX);
    SET @intercept = (@sumY - @slope * @sumX) / @n;
    SET @projected = @slope * @TargetYear + @intercept;

    SELECT
        @BusinessUnitCode AS business_unit_code,
        @CostCenterName   AS cost_center_name,
        @GLDescription    AS gl_description,
        @ValueType        AS value_type,
        @TargetYear       AS target_year,
        CAST(@projected AS DECIMAL(18,2)) AS projected_amount,
        @n                AS years_of_history_used,
        @minYear          AS earliest_year,
        @maxYear          AS latest_year,
        'LINEAR_TREND' AS method,
        'This is an ESTIMATE based on a linear trend across ' + CAST(@n AS VARCHAR)
            + ' years of historical data (' + CAST(@minYear AS VARCHAR) + '-' + CAST(@maxYear AS VARCHAR)
            + '). It is not a stored actual or plan value.' AS status_message;
END
GO

-- ============================================================
-- Quick test (run after creating the procedure):
-- EXEC Team2.usp_ForecastBudget
--     @BusinessUnitCode = 'SSD',
--     @CostCenterName = 'Recruiting',
--     @GLDescription = 'Total Labor',
--     @ValueType = 'Actual',
--     @TargetYear = 2026;
-- ============================================================
