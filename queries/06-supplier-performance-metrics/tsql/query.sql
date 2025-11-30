-- =====================================================
-- Query 6: Supplier Performance Scorecard
-- Platform: T-SQL (SQL Server)
-- =====================================================
-- Business Goal: Evaluate supplier performance across multiple dimensions

WITH SupplierProducts AS (
    SELECT
        s.SupplierID,
        s.SupplierName,
        s.Country,
        s.Rating AS SupplierRating,
        COUNT(DISTINCT p.ProductID) AS ProductCount,
        SUM(CASE WHEN p.IsActive = 1 THEN 1 ELSE 0 END) AS ActiveProductCount
    FROM Suppliers s
    LEFT JOIN Products p ON s.SupplierID = p.SupplierID
    WHERE s.IsActive = 1
    GROUP BY s.SupplierID, s.SupplierName, s.Country, s.Rating
),
SalesPerformance AS (
    SELECT
        p.SupplierID,
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        SUM(oi.Quantity) AS TotalUnitsSold,
        SUM(oi.LineTotal) AS TotalRevenue,
        AVG(oi.LineTotal) AS AvgLineItemValue,
        -- Product returns/cancellations
        COUNT(DISTINCT CASE
            WHEN o.OrderStatus IN ('Cancelled', 'Returned') THEN o.OrderID
        END) AS ProblematicOrders
    FROM Products p
    INNER JOIN OrderItems oi ON p.ProductID = oi.ProductID
    INNER JOIN Orders o ON oi.OrderID = o.OrderID
    WHERE o.OrderDate >= DATEADD(MONTH, -12, GETDATE())
    GROUP BY p.SupplierID
),
InventoryMetrics AS (
    SELECT
        p.SupplierID,
        COUNT(DISTINCT CASE
            WHEN i.QuantityOnHand <= i.ReorderLevel THEN i.ProductID
        END) AS ProductsNeedingReorder,
        AVG(DATEDIFF(DAY, it.TransactionDate, i.LastRestocked)) AS AvgRestockLeadTimeDays,
        SUM(CASE
            WHEN i.QuantityOnHand = 0 THEN 1 ELSE 0
        END) AS StockoutCount
    FROM Products p
    LEFT JOIN Inventory i ON p.ProductID = i.ProductID
    LEFT JOIN InventoryTransactions it ON p.ProductID = it.ProductID
        AND it.TransactionType = 'Purchase'
    GROUP BY p.SupplierID
),
QualityMetrics AS (
    SELECT
        p.SupplierID,
        AVG(pr.Rating) AS AvgProductRating,
        COUNT(pr.ReviewID) AS TotalReviews,
        SUM(CASE WHEN pr.Rating >= 4 THEN 1 ELSE 0 END) * 100.0 /
            NULLIF(COUNT(pr.ReviewID), 0) AS PositiveReviewPct
    FROM Products p
    LEFT JOIN ProductReviews pr ON p.ProductID = pr.ProductID
    WHERE pr.ReviewDate >= DATEADD(MONTH, -12, GETDATE())
    GROUP BY p.SupplierID
)
SELECT
    sp.SupplierID,
    sp.SupplierName,
    sp.Country,
    sp.ProductCount,
    sp.ActiveProductCount,
    ISNULL(sales.TotalOrders, 0) AS TotalOrders,
    ISNULL(sales.TotalUnitsSold, 0) AS TotalUnitsSold,
    CAST(ISNULL(sales.TotalRevenue, 0) AS DECIMAL(12,2)) AS TotalRevenue,
    CAST(ISNULL(sales.AvgLineItemValue, 0) AS DECIMAL(10,2)) AS AvgLineItemValue,
    ISNULL(sales.ProblematicOrders, 0) AS ProblematicOrders,
    CAST(
        ISNULL(sales.ProblematicOrders, 0) * 100.0 /
        NULLIF(sales.TotalOrders, 0)
    AS DECIMAL(5,2)) AS ProblematicOrderPct,
    ISNULL(inv.ProductsNeedingReorder, 0) AS ProductsNeedingReorder,
    CAST(ISNULL(inv.AvgRestockLeadTimeDays, 0) AS DECIMAL(5,1)) AS AvgLeadTimeDays,
    ISNULL(inv.StockoutCount, 0) AS StockoutCount,
    CAST(ISNULL(qm.AvgProductRating, 0) AS DECIMAL(3,2)) AS AvgProductRating,
    ISNULL(qm.TotalReviews, 0) AS TotalReviews,
    CAST(ISNULL(qm.PositiveReviewPct, 0) AS DECIMAL(5,2)) AS PositiveReviewPct,
    -- Composite Performance Score (0-100)
    CAST(
        (sp.SupplierRating * 10) +  -- Supplier rating (0-50)
        (ISNULL(qm.AvgProductRating, 0) * 10) +  -- Product rating (0-50)
        ((100 - ISNULL(sales.ProblematicOrders, 0) * 100.0 / NULLIF(sales.TotalOrders, 1)) * 0.2) +  -- Order quality
        (CASE
            WHEN inv.AvgRestockLeadTimeDays <= 7 THEN 15
            WHEN inv.AvgRestockLeadTimeDays <= 14 THEN 10
            WHEN inv.AvgRestockLeadTimeDays <= 21 THEN 5
            ELSE 0
        END)  -- Lead time score
    AS DECIMAL(5,1)) AS PerformanceScore,
    -- Performance tier
    CASE
        WHEN sp.SupplierRating >= 4.5
             AND ISNULL(qm.AvgProductRating, 0) >= 4
             AND ISNULL(sales.ProblematicOrders, 0) * 100.0 / NULLIF(sales.TotalOrders, 1) < 5
            THEN 'Preferred'
        WHEN sp.SupplierRating >= 3.5
             AND ISNULL(qm.AvgProductRating, 0) >= 3
            THEN 'Approved'
        WHEN sp.SupplierRating >= 2.5 THEN 'Conditional'
        ELSE 'Under Review'
    END AS SupplierTier
FROM SupplierProducts sp
LEFT JOIN SalesPerformance sales ON sp.SupplierID = sales.SupplierID
LEFT JOIN InventoryMetrics inv ON sp.SupplierID = inv.SupplierID
LEFT JOIN QualityMetrics qm ON sp.SupplierID = qm.SupplierID
ORDER BY PerformanceScore DESC;
