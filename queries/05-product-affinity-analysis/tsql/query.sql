-- =====================================================
-- Query 5: Product Affinity Analysis (Market Basket)
-- Platform: T-SQL (SQL Server)
-- =====================================================
-- Business Goal: Identify products frequently purchased together
-- for cross-selling and bundling strategies

WITH ProductPairs AS (
    -- Self-join order items to find product combinations
    SELECT
        p1.ProductID AS ProductA_ID,
        p1.ProductName AS ProductA_Name,
        p1.Category AS ProductA_Category,
        p2.ProductID AS ProductB_ID,
        p2.ProductName AS ProductB_Name,
        p2.Category AS ProductB_Category,
        oi1.OrderID
    FROM OrderItems oi1
    INNER JOIN OrderItems oi2 ON oi1.OrderID = oi2.OrderID
        AND oi1.ProductID < oi2.ProductID  -- Avoid duplicates
    INNER JOIN Products p1 ON oi1.ProductID = p1.ProductID
    INNER JOIN Products p2 ON oi2.ProductID = p2.ProductID
    INNER JOIN Orders o ON oi1.OrderID = o.OrderID
    WHERE o.OrderDate >= DATEADD(MONTH, -6, GETDATE())
        AND o.OrderStatus IN ('Delivered', 'Shipped')
        AND p1.IsActive = 1
        AND p2.IsActive = 1
),
AffinityMetrics AS (
    SELECT
        ProductA_ID,
        ProductA_Name,
        ProductA_Category,
        ProductB_ID,
        ProductB_Name,
        ProductB_Category,
        COUNT(DISTINCT OrderID) AS CoOccurrenceCount,
        -- Calculate total occurrences of each product
        (SELECT COUNT(DISTINCT oi.OrderID)
         FROM OrderItems oi
         INNER JOIN Orders o ON oi.OrderID = o.OrderID
         WHERE oi.ProductID = ProductA_ID
           AND o.OrderDate >= DATEADD(MONTH, -6, GETDATE())
           AND o.OrderStatus IN ('Delivered', 'Shipped')) AS ProductA_TotalOrders,
        (SELECT COUNT(DISTINCT oi.OrderID)
         FROM OrderItems oi
         INNER JOIN Orders o ON oi.OrderID = o.OrderID
         WHERE oi.ProductID = ProductB_ID
           AND o.OrderDate >= DATEADD(MONTH, -6, GETDATE())
           AND o.OrderStatus IN ('Delivered', 'Shipped')) AS ProductB_TotalOrders
    FROM ProductPairs
    GROUP BY
        ProductA_ID, ProductA_Name, ProductA_Category,
        ProductB_ID, ProductB_Name, ProductB_Category
    HAVING COUNT(DISTINCT OrderID) >= 5  -- Minimum threshold
),
AffinityScores AS (
    SELECT
        *,
        -- Support: How often do these products appear together?
        CAST(CoOccurrenceCount * 100.0 /
            (SELECT COUNT(DISTINCT OrderID)
             FROM Orders
             WHERE OrderDate >= DATEADD(MONTH, -6, GETDATE())
               AND OrderStatus IN ('Delivered', 'Shipped'))
        AS DECIMAL(5,2)) AS SupportPct,
        -- Confidence: If ProductA is purchased, what's the likelihood of ProductB?
        CAST(CoOccurrenceCount * 100.0 / NULLIF(ProductA_TotalOrders, 0) AS DECIMAL(5,2)) AS ConfidenceA_to_B,
        -- Reverse confidence
        CAST(CoOccurrenceCount * 100.0 / NULLIF(ProductB_TotalOrders, 0) AS DECIMAL(5,2)) AS ConfidenceB_to_A,
        -- Lift: How much more likely are they purchased together vs independently?
        CAST(
            (CoOccurrenceCount * 1.0) /
            NULLIF(
                (ProductA_TotalOrders * ProductB_TotalOrders * 1.0) /
                (SELECT COUNT(DISTINCT OrderID)
                 FROM Orders
                 WHERE OrderDate >= DATEADD(MONTH, -6, GETDATE())
                   AND OrderStatus IN ('Delivered', 'Shipped')),
            0)
        AS DECIMAL(10,4)) AS LiftScore
    FROM AffinityMetrics
),
RevenueImpact AS (
    -- Calculate potential revenue from recommendations
    SELECT
        a.*,
        CAST(AVG(oi.UnitPrice) AS DECIMAL(10,2)) AS ProductB_AvgPrice,
        CAST(a.ProductA_TotalOrders * (a.ConfidenceA_to_B / 100.0) *
             AVG(oi.UnitPrice) AS DECIMAL(12,2)) AS PotentialRevenueOpportunity
    FROM AffinityScores a
    INNER JOIN OrderItems oi ON a.ProductB_ID = oi.ProductID
    GROUP BY
        a.ProductA_ID, a.ProductA_Name, a.ProductA_Category,
        a.ProductB_ID, a.ProductB_Name, a.ProductB_Category,
        a.CoOccurrenceCount, a.ProductA_TotalOrders, a.ProductB_TotalOrders,
        a.SupportPct, a.ConfidenceA_to_B, a.ConfidenceB_to_A, a.LiftScore
)
SELECT
    ProductA_Name,
    ProductA_Category,
    ProductB_Name,
    ProductB_Category,
    CoOccurrenceCount AS TimesPurchasedTogether,
    ProductA_TotalOrders AS ProductA_IndividualOrders,
    ProductB_TotalOrders AS ProductB_IndividualOrders,
    SupportPct,
    ConfidenceA_to_B AS ConfidencePct_A_to_B,
    ConfidenceB_to_A AS ConfidencePct_B_to_A,
    LiftScore,
    ProductB_AvgPrice,
    PotentialRevenueOpportunity,
    -- Recommendation strength
    CASE
        WHEN LiftScore >= 3 AND ConfidenceA_to_B >= 30 THEN 'Strong'
        WHEN LiftScore >= 2 AND ConfidenceA_to_B >= 20 THEN 'Moderate'
        WHEN LiftScore >= 1.5 AND ConfidenceA_to_B >= 10 THEN 'Weak'
        ELSE 'Insufficient'
    END AS RecommendationStrength,
    -- Suggested action
    CASE
        WHEN LiftScore >= 3 AND ConfidenceA_to_B >= 30 THEN 'Create Bundle Offer'
        WHEN LiftScore >= 2 AND ConfidenceA_to_B >= 20 THEN 'Add to Recommendation Engine'
        WHEN ProductA_Category <> ProductB_Category THEN 'Cross-Category Promotion'
        ELSE 'Monitor'
    END AS SuggestedAction
FROM RevenueImpact
WHERE LiftScore > 1  -- Only show positive correlations
ORDER BY LiftScore DESC, ConfidenceA_to_B DESC;
