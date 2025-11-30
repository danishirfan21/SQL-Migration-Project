-- =====================================================
-- Query 2: Inventory Reorder Analysis with Forecasting
-- Platform: T-SQL (SQL Server)
-- =====================================================
-- Business Goal: Identify products needing reorder based on current stock,
-- sales velocity, and lead time forecasting

WITH SalesVelocity AS (
    -- Calculate daily sales rate over last 30, 60, and 90 days
    SELECT
        p.ProductID,
        p.ProductName,
        p.Category,
        p.SupplierID,
        SUM(CASE WHEN o.OrderDate >= DATEADD(DAY, -30, GETDATE()) THEN oi.Quantity ELSE 0 END) AS Qty_Last30Days,
        SUM(CASE WHEN o.OrderDate >= DATEADD(DAY, -60, GETDATE()) THEN oi.Quantity ELSE 0 END) AS Qty_Last60Days,
        SUM(CASE WHEN o.OrderDate >= DATEADD(DAY, -90, GETDATE()) THEN oi.Quantity ELSE 0 END) AS Qty_Last90Days,
        COUNT(DISTINCT CASE WHEN o.OrderDate >= DATEADD(DAY, -30, GETDATE()) THEN o.OrderID END) AS Orders_Last30Days,
        AVG(oi.UnitPrice) AS AvgSellingPrice
    FROM Products p
    LEFT JOIN OrderItems oi ON p.ProductID = oi.ProductID
    LEFT JOIN Orders o ON oi.OrderID = o.OrderID
        AND o.OrderStatus IN ('Delivered', 'Shipped', 'Processing')
    WHERE p.IsActive = 1
    GROUP BY p.ProductID, p.ProductName, p.Category, p.SupplierID
),
InventoryStatus AS (
    -- Current inventory levels aggregated across warehouses
    SELECT
        i.ProductID,
        SUM(i.QuantityOnHand) AS TotalStockOnHand,
        MIN(i.ReorderLevel) AS MinReorderLevel,
        MIN(i.ReorderQuantity) AS ReorderQuantity,
        COUNT(DISTINCT i.WarehouseLocation) AS WarehouseCount,
        STRING_AGG(i.WarehouseLocation + ':' + CAST(i.QuantityOnHand AS VARCHAR), ', ') AS StockByWarehouse
    FROM Inventory i
    GROUP BY i.ProductID
),
SupplierMetrics AS (
    -- Supplier lead time and reliability
    SELECT
        s.SupplierID,
        s.SupplierName,
        s.Country AS SupplierCountry,
        s.Rating AS SupplierRating,
        AVG(DATEDIFF(DAY, it.TransactionDate, i.LastRestocked)) AS AvgLeadTimeDays
    FROM Suppliers s
    LEFT JOIN Products p ON s.SupplierID = p.SupplierID
    LEFT JOIN Inventory i ON p.ProductID = i.ProductID
    LEFT JOIN InventoryTransactions it ON p.ProductID = it.ProductID
        AND it.TransactionType = 'Purchase'
    WHERE s.IsActive = 1
    GROUP BY s.SupplierID, s.SupplierName, s.Country, s.Rating
),
ReorderAnalysis AS (
    SELECT
        sv.ProductID,
        sv.ProductName,
        sv.Category,
        inv.TotalStockOnHand,
        inv.MinReorderLevel,
        inv.ReorderQuantity,
        inv.WarehouseCount,
        inv.StockByWarehouse,
        -- Calculate velocity metrics
        CAST(sv.Qty_Last30Days / 30.0 AS DECIMAL(10,2)) AS DailySalesRate30D,
        CAST(sv.Qty_Last60Days / 60.0 AS DECIMAL(10,2)) AS DailySalesRate60D,
        CAST(sv.Qty_Last90Days / 90.0 AS DECIMAL(10,2)) AS DailySalesRate90D,
        -- Weighted average (recent sales weighted higher)
        CAST(
            (sv.Qty_Last30Days / 30.0 * 0.5) +
            (sv.Qty_Last60Days / 60.0 * 0.3) +
            (sv.Qty_Last90Days / 90.0 * 0.2)
        AS DECIMAL(10,2)) AS WeightedDailySalesRate,
        sm.SupplierName,
        sm.SupplierCountry,
        sm.SupplierRating,
        ISNULL(sm.AvgLeadTimeDays, 14) AS EstimatedLeadTimeDays,
        sv.AvgSellingPrice,
        -- Calculate days until stockout
        CASE
            WHEN sv.Qty_Last30Days = 0 THEN 999
            ELSE CAST(inv.TotalStockOnHand / NULLIF((sv.Qty_Last30Days / 30.0), 0) AS INT)
        END AS DaysUntilStockout,
        -- Priority score
        CASE
            WHEN inv.TotalStockOnHand <= inv.MinReorderLevel THEN 'CRITICAL'
            WHEN inv.TotalStockOnHand <= inv.MinReorderLevel * 1.5 THEN 'HIGH'
            WHEN inv.TotalStockOnHand <= inv.MinReorderLevel * 2 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS ReorderPriority
    FROM SalesVelocity sv
    INNER JOIN InventoryStatus inv ON sv.ProductID = inv.ProductID
    LEFT JOIN SupplierMetrics sm ON sv.SupplierID = sm.SupplierID
)
SELECT
    ProductID,
    ProductName,
    Category,
    TotalStockOnHand,
    MinReorderLevel,
    ReorderQuantity,
    WarehouseCount,
    StockByWarehouse,
    DailySalesRate30D,
    WeightedDailySalesRate,
    DaysUntilStockout,
    EstimatedLeadTimeDays,
    -- Recommended order quantity
    CASE
        WHEN DaysUntilStockout < EstimatedLeadTimeDays THEN
            CAST(
                ReorderQuantity +
                (WeightedDailySalesRate * EstimatedLeadTimeDays * 1.5)  -- 50% safety stock
            AS INT)
        WHEN ReorderPriority IN ('CRITICAL', 'HIGH') THEN ReorderQuantity
        ELSE 0
    END AS RecommendedOrderQty,
    CAST(
        CASE
            WHEN DaysUntilStockout < EstimatedLeadTimeDays THEN
                (ReorderQuantity + (WeightedDailySalesRate * EstimatedLeadTimeDays * 1.5)) * AvgSellingPrice
            WHEN ReorderPriority IN ('CRITICAL', 'HIGH') THEN
                ReorderQuantity * AvgSellingPrice
            ELSE 0
        END
    AS DECIMAL(12,2)) AS EstimatedOrderValue,
    ReorderPriority,
    SupplierName,
    SupplierCountry,
    SupplierRating,
    AvgSellingPrice
FROM ReorderAnalysis
WHERE ReorderPriority IN ('CRITICAL', 'HIGH', 'MEDIUM')
    OR DaysUntilStockout < 30
ORDER BY
    CASE ReorderPriority
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        ELSE 4
    END,
    DaysUntilStockout ASC;
