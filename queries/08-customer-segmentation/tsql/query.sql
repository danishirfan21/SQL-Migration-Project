-- =====================================================
-- Query 8: Advanced Customer Segmentation (RFM Analysis)
-- Platform: T-SQL (SQL Server)
-- =====================================================
-- Business Goal: Segment customers using RFM (Recency, Frequency, Monetary) model

WITH CustomerRFM AS (
    SELECT
        c.CustomerID,
        c.Email,
        c.FirstName + ' ' + c.LastName AS FullName,
        c.Country,
        c.CustomerSegment AS CurrentSegment,
        -- Recency: Days since last purchase
        DATEDIFF(DAY, MAX(o.OrderDate), GETDATE()) AS RecencyDays,
        -- Frequency: Number of orders
        COUNT(DISTINCT o.OrderID) AS Frequency,
        -- Monetary: Total spending
        SUM(o.TotalAmount) AS MonetaryValue,
        -- Additional metrics
        AVG(o.TotalAmount) AS AvgOrderValue,
        MIN(o.OrderDate) AS FirstOrderDate,
        MAX(o.OrderDate) AS LastOrderDate,
        DATEDIFF(DAY, MIN(o.OrderDate), MAX(o.OrderDate)) AS CustomerLifespanDays
    FROM Customers c
    INNER JOIN Orders o ON c.CustomerID = o.CustomerID
    WHERE o.OrderStatus IN ('Delivered', 'Shipped')
        AND c.IsActive = 1
    GROUP BY
        c.CustomerID,
        c.Email,
        c.FirstName,
        c.LastName,
        c.Country,
        c.CustomerSegment
),
RFMScores AS (
    SELECT
        *,
        -- Calculate RFM scores (1-5, where 5 is best)
        NTILE(5) OVER (ORDER BY RecencyDays ASC) AS R_Score,  -- Lower days = better
        NTILE(5) OVER (ORDER BY Frequency DESC) AS F_Score,
        NTILE(5) OVER (ORDER BY MonetaryValue DESC) AS M_Score,
        -- Combined RFM score
        CAST(
            (NTILE(5) OVER (ORDER BY RecencyDays ASC) * 100) +
            (NTILE(5) OVER (ORDER BY Frequency DESC) * 10) +
            (NTILE(5) OVER (ORDER BY MonetaryValue DESC))
        AS VARCHAR(3)) AS RFM_Combined
    FROM CustomerRFM
),
SegmentClassification AS (
    SELECT
        *,
        -- Detailed segmentation based on RFM
        CASE
            WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
            WHEN R_Score >= 3 AND F_Score >= 4 AND M_Score >= 4 THEN 'Loyal Customers'
            WHEN R_Score >= 4 AND F_Score <= 2 AND M_Score >= 3 THEN 'Big Spenders'
            WHEN R_Score >= 4 AND F_Score >= 3 AND M_Score <= 3 THEN 'Promising'
            WHEN R_Score >= 3 AND F_Score >= 2 AND M_Score >= 2 THEN 'Potential Loyalists'
            WHEN R_Score <= 2 AND F_Score >= 4 AND M_Score >= 4 THEN 'At Risk'
            WHEN R_Score <= 2 AND F_Score >= 2 AND M_Score >= 3 THEN 'Cant Lose Them'
            WHEN R_Score >= 3 AND F_Score <= 2 AND M_Score <= 2 THEN 'Need Attention'
            WHEN R_Score <= 2 AND F_Score <= 2 THEN 'Hibernating'
            ELSE 'About to Sleep'
        END AS RFM_Segment,
        -- Predicted LTV tier
        CASE
            WHEN M_Score >= 4 AND F_Score >= 4 THEN 'High Value'
            WHEN M_Score >= 3 AND F_Score >= 3 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS Value_Tier,
        -- Churn risk
        CASE
            WHEN RecencyDays > 180 THEN 'High Risk'
            WHEN RecencyDays > 90 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS Churn_Risk
    FROM RFMScores
)
SELECT
    CustomerID,
    Email,
    FullName,
    Country,
    CurrentSegment,
    RecencyDays,
    Frequency AS TotalOrders,
    CAST(MonetaryValue AS DECIMAL(12,2)) AS TotalSpending,
    CAST(AvgOrderValue AS DECIMAL(10,2)) AS AvgOrderValue,
    CustomerLifespanDays,
    R_Score AS RecencyScore,
    F_Score AS FrequencyScore,
    M_Score AS MonetaryScore,
    RFM_Combined AS RFM_Score,
    RFM_Segment,
    Value_Tier,
    Churn_Risk,
    -- Marketing recommendations
    CASE
        WHEN RFM_Segment = 'Champions' THEN 'Reward program, early access to new products'
        WHEN RFM_Segment = 'Loyal Customers' THEN 'Upsell higher value products'
        WHEN RFM_Segment = 'Big Spenders' THEN 'Premium offers, VIP treatment'
        WHEN RFM_Segment = 'At Risk' THEN 'Reactivation campaign, special discounts'
        WHEN RFM_Segment = 'Cant Lose Them' THEN 'Win-back campaign, personalized offers'
        WHEN RFM_Segment = 'Promising' THEN 'Engagement campaign, build loyalty'
        WHEN RFM_Segment = 'Need Attention' THEN 'Limited time offers'
        WHEN RFM_Segment = 'Hibernating' THEN 'Re-engagement email series'
        ELSE 'General marketing'
    END AS MarketingStrategy,
    -- Expected action
    CASE
        WHEN RecencyDays <= 30 AND Frequency >= 5 THEN 'Likely to purchase soon'
        WHEN RecencyDays <= 60 AND M_Score >= 4 THEN 'Target for premium products'
        WHEN RecencyDays > 90 AND Frequency >= 3 THEN 'Send reactivation offer'
        WHEN RecencyDays > 180 THEN 'High churn risk - urgent action needed'
        ELSE 'Monitor'
    END AS NextAction
FROM SegmentClassification
ORDER BY MonetaryValue DESC, Frequency DESC;
