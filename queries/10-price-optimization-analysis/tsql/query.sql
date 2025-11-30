-- =====================================================
-- Query 10: Price Optimization and Elasticity Analysis
-- Platform: T-SQL (SQL Server)
-- =====================================================
-- Business Goal: Analyze price changes impact on sales and optimize pricing strategy

WITH PriceChanges AS (
    -- Identify all price changes with date ranges
    SELECT
        ph.ProductID,
        ph.Price AS OldPrice,
        ph.EffectiveDate,
        ph.EndDate,
        LEAD(ph.Price) OVER (PARTITION BY ph.ProductID ORDER BY ph.EffectiveDate) AS NewPrice,
        LEAD(ph.EffectiveDate) OVER (PARTITION BY ph.ProductID ORDER BY ph.EffectiveDate) AS NewPriceDate
    FROM PriceHistory ph
    WHERE ph.EffectiveDate >= DATEADD(MONTH, -12, GETDATE())
),
PriceChangeMetrics AS (
    SELECT
        pc.ProductID,
        pc.OldPrice,
        pc.NewPrice,
        pc.EffectiveDate AS OldPriceDate,
        pc.NewPriceDate,
        DATEDIFF(DAY, pc.EffectiveDate, ISNULL(pc.NewPriceDate, GETDATE())) AS DaysAtOldPrice,
        -- Calculate price change percentage
        ((pc.NewPrice - pc.OldPrice) / NULLIF(pc.OldPrice, 0) * 100) AS PriceChangePct,
        -- Sales before price change
        (SELECT COUNT(DISTINCT o.OrderID)
         FROM Orders o
         INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
         WHERE oi.ProductID = pc.ProductID
           AND o.OrderDate >= pc.EffectiveDate
           AND o.OrderDate < ISNULL(pc.NewPriceDate, GETDATE())
           AND o.OrderStatus IN ('Delivered', 'Shipped')) AS OrdersAtOldPrice,
        (SELECT ISNULL(SUM(oi.Quantity), 0)
         FROM Orders o
         INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
         WHERE oi.ProductID = pc.ProductID
           AND o.OrderDate >= pc.EffectiveDate
           AND o.OrderDate < ISNULL(pc.NewPriceDate, GETDATE())
           AND o.OrderStatus IN ('Delivered', 'Shipped')) AS UnitsAtOldPrice,
        (SELECT ISNULL(SUM(oi.LineTotal), 0)
         FROM Orders o
         INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
         WHERE oi.ProductID = pc.ProductID
           AND o.OrderDate >= pc.EffectiveDate
           AND o.OrderDate < ISNULL(pc.NewPriceDate, GETDATE())
           AND o.OrderStatus IN ('Delivered', 'Shipped')) AS RevenueAtOldPrice,
        -- Sales after price change (if applicable)
        CASE WHEN pc.NewPriceDate IS NOT NULL THEN
            (SELECT COUNT(DISTINCT o.OrderID)
             FROM Orders o
             INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
             WHERE oi.ProductID = pc.ProductID
               AND o.OrderDate >= pc.NewPriceDate
               AND o.OrderDate < DATEADD(DAY, DATEDIFF(DAY, pc.EffectiveDate, pc.NewPriceDate), pc.NewPriceDate)
               AND o.OrderStatus IN ('Delivered', 'Shipped'))
        END AS OrdersAtNewPrice,
        CASE WHEN pc.NewPriceDate IS NOT NULL THEN
            (SELECT ISNULL(SUM(oi.Quantity), 0)
             FROM Orders o
             INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
             WHERE oi.ProductID = pc.ProductID
               AND o.OrderDate >= pc.NewPriceDate
               AND o.OrderDate < DATEADD(DAY, DATEDIFF(DAY, pc.EffectiveDate, pc.NewPriceDate), pc.NewPriceDate)
               AND o.OrderStatus IN ('Delivered', 'Shipped'))
        END AS UnitsAtNewPrice
    FROM PriceChanges pc
    WHERE pc.NewPrice IS NOT NULL
),
ProductContext AS (
    SELECT
        p.ProductID,
        p.ProductName,
        p.Category,
        p.SubCategory,
        p.CurrentPrice,
        p.CostPrice,
        ((p.CurrentPrice - p.CostPrice) / NULLIF(p.CurrentPrice, 0) * 100) AS CurrentMarginPct,
        -- Current sales velocity
        (SELECT COUNT(*)
         FROM Orders o
         INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
         WHERE oi.ProductID = p.ProductID
           AND o.OrderDate >= DATEADD(DAY, -30, GETDATE())
           AND o.OrderStatus IN ('Delivered', 'Shipped')) AS RecentOrders30d,
        -- Competitor/category average price
        (SELECT AVG(p2.CurrentPrice)
         FROM Products p2
         WHERE p2.Category = p.Category
           AND p2.IsActive = 1) AS CategoryAvgPrice
    FROM Products p
    WHERE p.IsActive = 1
),
ElasticityAnalysis AS (
    SELECT
        pcm.*,
        pc.ProductName,
        pc.Category,
        pc.SubCategory,
        pc.CurrentPrice,
        pc.CostPrice,
        pc.CurrentMarginPct,
        pc.CategoryAvgPrice,
        -- Calculate daily sales rates
        UnitsAtOldPrice / NULLIF(CAST(DaysAtOldPrice AS FLOAT), 0) AS DailySalesAtOldPrice,
        CASE WHEN NewPriceDate IS NOT NULL THEN
            UnitsAtNewPrice / NULLIF(CAST(DaysAtOldPrice AS FLOAT), 0)
        END AS DailySalesAtNewPrice,
        -- Price elasticity estimation
        CASE
            WHEN PriceChangePct <> 0 AND UnitsAtNewPrice IS NOT NULL THEN
                ((UnitsAtNewPrice / NULLIF(CAST(DaysAtOldPrice AS FLOAT), 0) -
                  UnitsAtOldPrice / NULLIF(CAST(DaysAtOldPrice AS FLOAT), 0)) /
                 NULLIF(UnitsAtOldPrice / NULLIF(CAST(DaysAtOldPrice AS FLOAT), 0), 0) * 100) /
                NULLIF(PriceChangePct, 0)
        END AS PriceElasticity
    FROM PriceChangeMetrics pcm
    INNER JOIN ProductContext pc ON pcm.ProductID = pc.ProductID
)
SELECT
    ProductID,
    ProductName,
    Category,
    SubCategory,
    CAST(OldPrice AS DECIMAL(10,2)) AS OldPrice,
    CAST(NewPrice AS DECIMAL(10,2)) AS NewPrice,
    CAST(CurrentPrice AS DECIMAL(10,2)) AS CurrentPrice,
    CAST(CostPrice AS DECIMAL(10,2)) AS CostPrice,
    CAST(CategoryAvgPrice AS DECIMAL(10,2)) AS CategoryAvgPrice,
    CAST(PriceChangePct AS DECIMAL(6,2)) AS PriceChangePct,
    CAST(CurrentMarginPct AS DECIMAL(5,2)) AS CurrentMarginPct,
    UnitsAtOldPrice,
    UnitsAtNewPrice,
    CAST(DailySalesAtOldPrice AS DECIMAL(8,2)) AS DailySalesAtOldPrice,
    CAST(DailySalesAtNewPrice AS DECIMAL(8,2)) AS DailySalesAtNewPrice,
    CAST(RevenueAtOldPrice AS DECIMAL(12,2)) AS RevenueAtOldPrice,
    CAST(PriceElasticity AS DECIMAL(6,3)) AS PriceElasticity,
    -- Elasticity classification
    CASE
        WHEN PriceElasticity IS NULL THEN 'Insufficient Data'
        WHEN ABS(PriceElasticity) > 1 THEN 'Elastic (Price Sensitive)'
        WHEN ABS(PriceElasticity) < 1 THEN 'Inelastic (Price Insensitive)'
        ELSE 'Unit Elastic'
    END AS ElasticityType,
    -- Revenue impact of price change
    CAST((UnitsAtNewPrice / NULLIF(CAST(DaysAtOldPrice AS FLOAT), 0) * NewPrice * DaysAtOldPrice) -
         RevenueAtOldPrice AS DECIMAL(12,2)) AS ProjectedRevenueImpact,
    -- Pricing recommendation
    CASE
        WHEN CurrentPrice < CategoryAvgPrice * 0.85 AND CurrentMarginPct > 30 THEN 'Consider Price Increase'
        WHEN CurrentPrice > CategoryAvgPrice * 1.15 AND PriceElasticity < -1 THEN 'Consider Price Decrease'
        WHEN CurrentMarginPct < 20 AND DailySalesAtOldPrice > 10 THEN 'Increase Price to Improve Margin'
        WHEN PriceElasticity IS NOT NULL AND PriceElasticity > -0.5 THEN 'Price Increase Opportunity'
        WHEN PriceElasticity < -2 THEN 'Highly Price Sensitive - Avoid Increases'
        ELSE 'Current Price Optimal'
    END AS PricingRecommendation,
    -- Optimal price suggestion (simplified)
    CAST(
        CASE
            WHEN CurrentMarginPct < 20 THEN CurrentPrice * 1.10
            WHEN CurrentPrice < CategoryAvgPrice * 0.9 THEN CurrentPrice * 1.05
            WHEN CurrentPrice > CategoryAvgPrice * 1.1 AND PriceElasticity < -1 THEN CurrentPrice * 0.95
            ELSE CurrentPrice
        END
    AS DECIMAL(10,2)) AS SuggestedPrice
FROM ElasticityAnalysis
WHERE DaysAtOldPrice >= 7  -- Minimum time period for analysis
ORDER BY ABS(PriceElasticity) DESC, RevenueAtOldPrice DESC;
