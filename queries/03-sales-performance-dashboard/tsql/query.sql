-- =====================================================
-- Query 3: Sales Performance Dashboard - Multi-Dimensional Analysis
-- Platform: T-SQL (SQL Server)
-- =====================================================
-- Business Goal: Create comprehensive sales dashboard with YoY growth,
-- category performance, and trending metrics

WITH DateDimension AS (
    -- Generate date periods for comparison
    SELECT
        DATEADD(MONTH, -12, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)) AS CurrentYearStart,
        DATEADD(MONTH, -24, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)) AS PriorYearStart,
        DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1) AS CurrentMonthStart,
        DATEADD(DAY, -90, GETDATE()) AS Last90DaysStart
),
SalesByPeriod AS (
    SELECT
        p.Category,
        p.SubCategory,
        o.ShippingCountry,
        -- Current year metrics
        SUM(CASE
            WHEN o.OrderDate >= dd.CurrentYearStart THEN oi.LineTotal
            ELSE 0
        END) AS CurrentYearRevenue,
        SUM(CASE
            WHEN o.OrderDate >= dd.CurrentYearStart THEN oi.Quantity
            ELSE 0
        END) AS CurrentYearUnits,
        COUNT(DISTINCT CASE
            WHEN o.OrderDate >= dd.CurrentYearStart THEN o.OrderID
        END) AS CurrentYearOrders,
        -- Prior year metrics
        SUM(CASE
            WHEN o.OrderDate >= dd.PriorYearStart
                AND o.OrderDate < dd.CurrentYearStart THEN oi.LineTotal
            ELSE 0
        END) AS PriorYearRevenue,
        SUM(CASE
            WHEN o.OrderDate >= dd.PriorYearStart
                AND o.OrderDate < dd.CurrentYearStart THEN oi.Quantity
            ELSE 0
        END) AS PriorYearUnits,
        -- Current month
        SUM(CASE
            WHEN o.OrderDate >= dd.CurrentMonthStart THEN oi.LineTotal
            ELSE 0
        END) AS CurrentMonthRevenue,
        -- Last 90 days
        SUM(CASE
            WHEN o.OrderDate >= dd.Last90DaysStart THEN oi.LineTotal
            ELSE 0
        END) AS Last90DaysRevenue,
        AVG(oi.UnitPrice) AS AvgUnitPrice,
        AVG(oi.Discount) AS AvgDiscountPct
    FROM Orders o
    INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
    INNER JOIN Products p ON oi.ProductID = p.ProductID
    CROSS JOIN DateDimension dd
    WHERE o.OrderStatus IN ('Delivered', 'Shipped')
        AND o.OrderDate >= dd.PriorYearStart
    GROUP BY
        p.Category,
        p.SubCategory,
        o.ShippingCountry,
        dd.CurrentYearStart,
        dd.PriorYearStart,
        dd.CurrentMonthStart,
        dd.Last90DaysStart
),
PerformanceMetrics AS (
    SELECT
        Category,
        SubCategory,
        ShippingCountry,
        CurrentYearRevenue,
        CurrentYearUnits,
        CurrentYearOrders,
        PriorYearRevenue,
        PriorYearUnits,
        CurrentMonthRevenue,
        Last90DaysRevenue,
        AvgUnitPrice,
        AvgDiscountPct,
        -- Growth calculations
        CASE
            WHEN PriorYearRevenue > 0 THEN
                ((CurrentYearRevenue - PriorYearRevenue) / PriorYearRevenue * 100)
            ELSE NULL
        END AS YoYRevenueGrowthPct,
        CASE
            WHEN PriorYearUnits > 0 THEN
                ((CurrentYearUnits - PriorYearUnits) / CAST(PriorYearUnits AS DECIMAL) * 100)
            ELSE NULL
        END AS YoYUnitsGrowthPct,
        -- Market share within category
        CurrentYearRevenue * 100.0 /
            SUM(CurrentYearRevenue) OVER (PARTITION BY Category) AS CategoryMarketSharePct,
        -- Performance ranking
        RANK() OVER (ORDER BY CurrentYearRevenue DESC) AS RevenueRank,
        DENSE_RANK() OVER (PARTITION BY Category ORDER BY CurrentYearRevenue DESC) AS CategoryRank,
        -- Moving averages
        AVG(Last90DaysRevenue) OVER (
            PARTITION BY Category
            ORDER BY CurrentYearRevenue DESC
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS MovingAvg3Periods
    FROM SalesByPeriod
),
TopProducts AS (
    -- Best performing products per category
    SELECT
        p.Category,
        p.ProductName,
        SUM(oi.LineTotal) AS ProductRevenue,
        ROW_NUMBER() OVER (PARTITION BY p.Category ORDER BY SUM(oi.LineTotal) DESC) AS ProductRank
    FROM Orders o
    INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
    INNER JOIN Products p ON oi.ProductID = p.ProductID
    WHERE o.OrderDate >= DATEADD(MONTH, -12, GETDATE())
        AND o.OrderStatus IN ('Delivered', 'Shipped')
    GROUP BY p.Category, p.ProductName
)
SELECT
    pm.Category,
    pm.SubCategory,
    pm.ShippingCountry,
    CAST(pm.CurrentYearRevenue AS DECIMAL(12,2)) AS CurrentYearRevenue,
    pm.CurrentYearUnits,
    pm.CurrentYearOrders,
    CAST(pm.PriorYearRevenue AS DECIMAL(12,2)) AS PriorYearRevenue,
    CAST(pm.CurrentMonthRevenue AS DECIMAL(12,2)) AS CurrentMonthRevenue,
    CAST(pm.YoYRevenueGrowthPct AS DECIMAL(10,2)) AS YoYRevenueGrowthPct,
    CAST(pm.YoYUnitsGrowthPct AS DECIMAL(10,2)) AS YoYUnitsGrowthPct,
    CAST(pm.CategoryMarketSharePct AS DECIMAL(5,2)) AS CategoryMarketSharePct,
    pm.RevenueRank,
    pm.CategoryRank,
    CAST(pm.AvgUnitPrice AS DECIMAL(10,2)) AS AvgUnitPrice,
    CAST(pm.AvgDiscountPct AS DECIMAL(5,2)) AS AvgDiscountPct,
    tp.ProductName AS TopProduct,
    CAST(tp.ProductRevenue AS DECIMAL(12,2)) AS TopProductRevenue,
    -- Performance tier
    CASE
        WHEN pm.YoYRevenueGrowthPct >= 20 THEN 'High Growth'
        WHEN pm.YoYRevenueGrowthPct >= 5 THEN 'Steady Growth'
        WHEN pm.YoYRevenueGrowthPct >= -5 THEN 'Stable'
        WHEN pm.YoYRevenueGrowthPct >= -20 THEN 'Declining'
        ELSE 'Significant Decline'
    END AS PerformanceTier
FROM PerformanceMetrics pm
LEFT JOIN TopProducts tp ON pm.Category = tp.Category
    AND tp.ProductRank = 1
WHERE pm.CurrentYearRevenue > 1000  -- Filter low-revenue segments
ORDER BY pm.CurrentYearRevenue DESC;
