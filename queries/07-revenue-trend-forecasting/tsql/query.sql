-- =====================================================
-- Query 7: Revenue Trend Analysis with Simple Forecasting
-- Platform: T-SQL (SQL Server)
-- =====================================================
-- Business Goal: Analyze revenue trends and predict future performance

WITH MonthlyRevenue AS (
    SELECT
        DATEFROMPARTS(YEAR(o.OrderDate), MONTH(o.OrderDate), 1) AS RevenueMonth,
        p.Category,
        SUM(oi.LineTotal) AS TotalRevenue,
        COUNT(DISTINCT o.OrderID) AS OrderCount,
        COUNT(DISTINCT o.CustomerID) AS UniqueCustomers,
        AVG(o.TotalAmount) AS AvgOrderValue
    FROM Orders o
    INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
    INNER JOIN Products p ON oi.ProductID = p.ProductID
    WHERE o.OrderStatus IN ('Delivered', 'Shipped')
        AND o.OrderDate >= DATEADD(MONTH, -18, GETDATE())
    GROUP BY
        DATEFROMPARTS(YEAR(o.OrderDate), MONTH(o.OrderDate), 1),
        p.Category
),
TrendMetrics AS (
    SELECT
        RevenueMonth,
        Category,
        TotalRevenue,
        OrderCount,
        UniqueCustomers,
        AvgOrderValue,
        -- Moving averages
        AVG(TotalRevenue) OVER (
            PARTITION BY Category
            ORDER BY RevenueMonth
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS MovingAvg3Month,
        AVG(TotalRevenue) OVER (
            PARTITION BY Category
            ORDER BY RevenueMonth
            ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
        ) AS MovingAvg6Month,
        -- Month-over-Month growth
        LAG(TotalRevenue, 1) OVER (PARTITION BY Category ORDER BY RevenueMonth) AS PrevMonthRevenue,
        -- Year-over-Year comparison
        LAG(TotalRevenue, 12) OVER (PARTITION BY Category ORDER BY RevenueMonth) AS SameMonthLastYear,
        -- Ranking
        DENSE_RANK() OVER (PARTITION BY Category ORDER BY TotalRevenue DESC) AS RevenueRank,
        ROW_NUMBER() OVER (PARTITION BY Category ORDER BY RevenueMonth) AS MonthSequence
    FROM MonthlyRevenue
),
TrendAnalysis AS (
    SELECT
        RevenueMonth,
        Category,
        TotalRevenue,
        OrderCount,
        UniqueCustomers,
        AvgOrderValue,
        MovingAvg3Month,
        MovingAvg6Month,
        -- Growth calculations
        CASE
            WHEN PrevMonthRevenue > 0 THEN
                ((TotalRevenue - PrevMonthRevenue) / PrevMonthRevenue * 100)
            ELSE NULL
        END AS MoMGrowthPct,
        CASE
            WHEN SameMonthLastYear > 0 THEN
                ((TotalRevenue - SameMonthLastYear) / SameMonthLastYear * 100)
            ELSE NULL
        END AS YoYGrowthPct,
        -- Simple linear forecast for next month (based on 3-month trend)
        MovingAvg3Month +
            ((TotalRevenue - PrevMonthRevenue) * 1.2)  -- Weighted recent trend
        AS SimpleForecastNextMonth,
        -- Seasonality factor
        TotalRevenue / NULLIF(MovingAvg6Month, 0) AS SeasonalityIndex
    FROM TrendMetrics
)
SELECT
    FORMAT(RevenueMonth, 'yyyy-MM') AS Month,
    Category,
    CAST(TotalRevenue AS DECIMAL(12,2)) AS ActualRevenue,
    OrderCount,
    UniqueCustomers,
    CAST(AvgOrderValue AS DECIMAL(10,2)) AS AvgOrderValue,
    CAST(MovingAvg3Month AS DECIMAL(12,2)) AS MovingAvg3Month,
    CAST(MovingAvg6Month AS DECIMAL(12,2)) AS MovingAvg6Month,
    CAST(MoMGrowthPct AS DECIMAL(5,2)) AS MoMGrowthPct,
    CAST(YoYGrowthPct AS DECIMAL(5,2)) AS YoYGrowthPct,
    CAST(SimpleForecastNextMonth AS DECIMAL(12,2)) AS ForecastNextMonth,
    CAST(SeasonalityIndex AS DECIMAL(4,2)) AS SeasonalityIndex,
    -- Trend classification
    CASE
        WHEN MoMGrowthPct >= 10 THEN 'Strong Upward'
        WHEN MoMGrowthPct >= 5 THEN 'Moderate Upward'
        WHEN MoMGrowthPct >= -5 THEN 'Stable'
        WHEN MoMGrowthPct >= -10 THEN 'Moderate Downward'
        ELSE 'Strong Downward'
    END AS TrendDirection,
    -- Forecast confidence
    CASE
        WHEN ABS(SeasonalityIndex - 1) < 0.2 THEN 'High'
        WHEN ABS(SeasonalityIndex - 1) < 0.4 THEN 'Medium'
        ELSE 'Low'
    END AS ForecastConfidence
FROM TrendAnalysis
WHERE RevenueMonth >= DATEADD(MONTH, -12, GETDATE())
ORDER BY Category, RevenueMonth DESC;
