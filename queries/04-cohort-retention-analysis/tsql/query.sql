-- =====================================================
-- Query 4: Cohort Retention Analysis
-- Platform: T-SQL (SQL Server)
-- =====================================================
-- Business Goal: Analyze customer retention by registration cohort
-- Track repeat purchase behavior over time

WITH CustomerCohorts AS (
    -- Assign customers to monthly cohorts based on registration
    SELECT
        c.CustomerID,
        c.Email,
        DATEFROMPARTS(YEAR(c.RegistrationDate), MONTH(c.RegistrationDate), 1) AS CohortMonth,
        c.RegistrationDate
    FROM Customers c
    WHERE c.IsActive = 1
        AND c.RegistrationDate >= DATEADD(MONTH, -24, GETDATE())
),
OrderActivity AS (
    -- Get all orders with cohort info
    SELECT
        cc.CustomerID,
        cc.CohortMonth,
        o.OrderID,
        o.OrderDate,
        o.TotalAmount,
        DATEDIFF(MONTH, cc.CohortMonth, o.OrderDate) AS MonthsSinceCohort
    FROM CustomerCohorts cc
    INNER JOIN Orders o ON cc.CustomerID = o.CustomerID
    WHERE o.OrderStatus IN ('Delivered', 'Shipped')
),
CohortMetrics AS (
    SELECT
        CohortMonth,
        COUNT(DISTINCT CustomerID) AS CohortSize,
        -- Month 0 (first month)
        COUNT(DISTINCT CASE WHEN MonthsSinceCohort = 0 THEN CustomerID END) AS Month0Customers,
        SUM(CASE WHEN MonthsSinceCohort = 0 THEN TotalAmount ELSE 0 END) AS Month0Revenue,
        -- Retention months 1-12
        COUNT(DISTINCT CASE WHEN MonthsSinceCohort = 1 THEN CustomerID END) AS Month1Customers,
        COUNT(DISTINCT CASE WHEN MonthsSinceCohort = 2 THEN CustomerID END) AS Month2Customers,
        COUNT(DISTINCT CASE WHEN MonthsSinceCohort = 3 THEN CustomerID END) AS Month3Customers,
        COUNT(DISTINCT CASE WHEN MonthsSinceCohort = 6 THEN CustomerID END) AS Month6Customers,
        COUNT(DISTINCT CASE WHEN MonthsSinceCohort = 12 THEN CustomerID END) AS Month12Customers,
        -- Revenue by retention month
        SUM(CASE WHEN MonthsSinceCohort = 1 THEN TotalAmount ELSE 0 END) AS Month1Revenue,
        SUM(CASE WHEN MonthsSinceCohort = 3 THEN TotalAmount ELSE 0 END) AS Month3Revenue,
        SUM(CASE WHEN MonthsSinceCohort = 6 THEN TotalAmount ELSE 0 END) AS Month6Revenue,
        SUM(CASE WHEN MonthsSinceCohort = 12 THEN TotalAmount ELSE 0 END) AS Month12Revenue,
        -- Average order values
        AVG(CASE WHEN MonthsSinceCohort = 0 THEN TotalAmount END) AS Month0AvgOrderValue,
        AVG(CASE WHEN MonthsSinceCohort >= 1 THEN TotalAmount END) AS RepeatAvgOrderValue
    FROM OrderActivity
    GROUP BY CohortMonth
)
SELECT
    FORMAT(CohortMonth, 'yyyy-MM') AS CohortMonth,
    CohortSize,
    Month0Customers,
    CAST(Month0Revenue AS DECIMAL(12,2)) AS Month0Revenue,
    CAST(Month0AvgOrderValue AS DECIMAL(10,2)) AS Month0AvgOrderValue,
    -- Retention rates
    Month1Customers,
    CAST(Month1Customers * 100.0 / NULLIF(Month0Customers, 0) AS DECIMAL(5,2)) AS Month1RetentionPct,
    Month2Customers,
    CAST(Month2Customers * 100.0 / NULLIF(Month0Customers, 0) AS DECIMAL(5,2)) AS Month2RetentionPct,
    Month3Customers,
    CAST(Month3Customers * 100.0 / NULLIF(Month0Customers, 0) AS DECIMAL(5,2)) AS Month3RetentionPct,
    Month6Customers,
    CAST(Month6Customers * 100.0 / NULLIF(Month0Customers, 0) AS DECIMAL(5,2)) AS Month6RetentionPct,
    Month12Customers,
    CAST(Month12Customers * 100.0 / NULLIF(Month0Customers, 0) AS DECIMAL(5,2)) AS Month12RetentionPct,
    -- Revenue per retained customer
    CAST(Month1Revenue / NULLIF(Month1Customers, 0) AS DECIMAL(10,2)) AS Month1RevenuePerCustomer,
    CAST(Month3Revenue / NULLIF(Month3Customers, 0) AS DECIMAL(10,2)) AS Month3RevenuePerCustomer,
    CAST(Month6Revenue / NULLIF(Month6Customers, 0) AS DECIMAL(10,2)) AS Month6RevenuePerCustomer,
    CAST(RepeatAvgOrderValue AS DECIMAL(10,2)) AS RepeatAvgOrderValue,
    -- Cohort quality score
    CAST(
        (Month0Customers * 0.1) +
        (Month3Customers * 100.0 / NULLIF(Month0Customers, 0) * 0.4) +
        (Month6Customers * 100.0 / NULLIF(Month0Customers, 0) * 0.5)
    AS DECIMAL(10,2)) AS CohortQualityScore
FROM CohortMetrics
WHERE CohortSize >= 10  -- Minimum cohort size for statistical relevance
ORDER BY CohortMonth DESC;
