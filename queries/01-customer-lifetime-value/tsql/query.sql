-- =====================================================
-- Query 1: Customer Lifetime Value (CLV) Analysis
-- Platform: T-SQL (SQL Server)
-- =====================================================
-- Business Goal: Calculate customer lifetime value, segmentation,
-- and identify high-value customers with purchase patterns

WITH CustomerOrders AS (
    -- Aggregate order data per customer
    SELECT
        c.CustomerID,
        c.Email,
        c.FirstName + ' ' + c.LastName AS FullName,
        c.Country,
        c.RegistrationDate,
        c.CustomerSegment,
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        SUM(o.TotalAmount) AS TotalRevenue,
        AVG(o.TotalAmount) AS AvgOrderValue,
        MIN(o.OrderDate) AS FirstOrderDate,
        MAX(o.OrderDate) AS LastOrderDate,
        DATEDIFF(DAY, MIN(o.OrderDate), MAX(o.OrderDate)) AS CustomerLifespanDays
    FROM Customers c
    LEFT JOIN Orders o ON c.CustomerID = o.CustomerID
        AND o.OrderStatus NOT IN ('Cancelled', 'Returned')
    WHERE c.IsActive = 1
    GROUP BY
        c.CustomerID,
        c.Email,
        c.FirstName,
        c.LastName,
        c.Country,
        c.RegistrationDate,
        c.CustomerSegment
),
CustomerMetrics AS (
    -- Calculate advanced metrics
    SELECT
        *,
        CASE
            WHEN CustomerLifespanDays = 0 THEN TotalRevenue
            ELSE TotalRevenue / NULLIF(CustomerLifespanDays, 0) * 365
        END AS AnnualizedRevenue,
        DATEDIFF(DAY, LastOrderDate, GETDATE()) AS DaysSinceLastOrder,
        CASE
            WHEN DATEDIFF(DAY, LastOrderDate, GETDATE()) > 180 THEN 'At Risk'
            WHEN DATEDIFF(DAY, LastOrderDate, GETDATE()) > 90 THEN 'Declining'
            WHEN TotalOrders >= 5 THEN 'Active'
            ELSE 'New'
        END AS CustomerStatus,
        ROW_NUMBER() OVER (ORDER BY TotalRevenue DESC) AS RevenueRank,
        NTILE(10) OVER (ORDER BY TotalRevenue DESC) AS RevenueDecile
    FROM CustomerOrders
    WHERE TotalOrders > 0
),
CategoryPurchases AS (
    -- Get favorite product category per customer
    SELECT
        o.CustomerID,
        p.Category AS FavoriteCategory,
        SUM(oi.LineTotal) AS CategorySpend,
        ROW_NUMBER() OVER (PARTITION BY o.CustomerID ORDER BY SUM(oi.LineTotal) DESC) AS CategoryRank
    FROM Orders o
    INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
    INNER JOIN Products p ON oi.ProductID = p.ProductID
    WHERE o.OrderStatus NOT IN ('Cancelled', 'Returned')
    GROUP BY o.CustomerID, p.Category
)
SELECT
    cm.CustomerID,
    cm.Email,
    cm.FullName,
    cm.Country,
    cm.CustomerSegment,
    cm.TotalOrders,
    CAST(cm.TotalRevenue AS DECIMAL(12,2)) AS TotalRevenue,
    CAST(cm.AvgOrderValue AS DECIMAL(10,2)) AS AvgOrderValue,
    CAST(cm.AnnualizedRevenue AS DECIMAL(12,2)) AS AnnualizedRevenue,
    cm.CustomerLifespanDays,
    cm.DaysSinceLastOrder,
    cm.CustomerStatus,
    cm.RevenueRank,
    cm.RevenueDecile,
    cp.FavoriteCategory,
    CAST(cp.CategorySpend AS DECIMAL(12,2)) AS FavoriteCategorySpend,
    -- Calculate CLV Score (weighted metric)
    CAST(
        (cm.TotalRevenue * 0.4) +
        (cm.TotalOrders * 50 * 0.3) +
        (cm.AnnualizedRevenue * 0.3)
    AS DECIMAL(12,2)) AS CLVScore
FROM CustomerMetrics cm
LEFT JOIN CategoryPurchases cp ON cm.CustomerID = cp.CustomerID
    AND cp.CategoryRank = 1
WHERE cm.TotalRevenue > 100  -- Filter out low-value customers
ORDER BY cm.TotalRevenue DESC
OPTION (MAXDOP 4);  -- Limit parallelism for consistency
