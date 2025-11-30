-- =====================================================
-- Query 9: Order Fulfillment Analytics with SLA Tracking
-- Platform: T-SQL (SQL Server)
-- =====================================================
-- Business Goal: Monitor order processing efficiency and identify bottlenecks

;WITH OrderTimeline AS (
    SELECT
        o.OrderID,
        o.CustomerID,
        o.OrderDate,
        o.OrderStatus,
        o.TotalAmount,
        o.ShippingCountry,
        o.PaymentMethod,
        -- Simulate fulfillment stages using date calculations
        DATEADD(HOUR, 2, o.OrderDate) AS ProcessingStartTime,
        DATEADD(HOUR, 24, o.OrderDate) AS PackagingCompletedTime,
        CASE
            WHEN o.OrderStatus IN ('Shipped', 'Delivered') THEN DATEADD(DAY, 1, o.OrderDate)
            ELSE NULL
        END AS ShippedTime,
        CASE
            WHEN o.OrderStatus = 'Delivered' THEN DATEADD(DAY, 5, o.OrderDate)
            ELSE NULL
        END AS DeliveredTime,
        -- SLA targets (in hours)
        CASE
            WHEN o.TotalAmount >= 500 THEN 12  -- Premium orders
            ELSE 24  -- Standard orders
        END AS ProcessingSLA_Hours,
        CASE
            WHEN o.ShippingCountry IN ('USA', 'UK', 'Germany') THEN 48
            ELSE 72
        END AS ShippingSLA_Hours
    FROM Orders o
    WHERE o.OrderDate >= DATEADD(MONTH, -3, GETDATE())
),
FulfillmentMetrics AS (
    SELECT
        OrderID,
        CustomerID,
        OrderDate,
        OrderStatus,
        TotalAmount,
        ShippingCountry,
        PaymentMethod,
        -- Time calculations
        DATEDIFF(HOUR, OrderDate, ProcessingStartTime) AS ProcessingTimeHours,
        DATEDIFF(HOUR, ProcessingStartTime, PackagingCompletedTime) AS PackagingTimeHours,
        DATEDIFF(HOUR, OrderDate, ShippedTime) AS TimeToShipHours,
        DATEDIFF(DAY, OrderDate, DeliveredTime) AS TimeToDeliverDays,
        ProcessingSLA_Hours,
        ShippingSLA_Hours,
        -- SLA compliance
        CASE
            WHEN DATEDIFF(HOUR, OrderDate, PackagingCompletedTime) <= ProcessingSLA_Hours THEN 1
            ELSE 0
        END AS ProcessingSLA_Met,
        CASE
            WHEN DATEDIFF(HOUR, OrderDate, ShippedTime) <= ShippingSLA_Hours THEN 1
            WHEN OrderStatus NOT IN ('Shipped', 'Delivered') THEN NULL
            ELSE 0
        END AS ShippingSLA_Met,
        -- Current order age
        DATEDIFF(HOUR, OrderDate, GETDATE()) AS OrderAgeHours
    FROM OrderTimeline
),
AggregatedMetrics AS (
    SELECT
        ShippingCountry,
        OrderStatus,
        PaymentMethod,
        COUNT(*) AS TotalOrders,
        SUM(TotalAmount) AS TotalRevenue,
        AVG(TotalAmount) AS AvgOrderValue,
        -- Processing metrics
        AVG(CAST(ProcessingTimeHours AS FLOAT)) AS AvgProcessingHours,
        AVG(CAST(PackagingTimeHours AS FLOAT)) AS AvgPackagingHours,
        AVG(CAST(TimeToShipHours AS FLOAT)) AS AvgTimeToShipHours,
        AVG(CAST(TimeToDeliverDays AS FLOAT)) AS AvgDeliveryDays,
        -- SLA compliance rates
        SUM(ProcessingSLA_Met) * 100.0 / NULLIF(COUNT(*), 0) AS ProcessingSLA_CompliancePct,
        SUM(ShippingSLA_Met) * 100.0 / NULLIF(SUM(CASE WHEN ShippingSLA_Met IS NOT NULL THEN 1 ELSE 0 END), 0) AS ShippingSLA_CompliancePct,
        -- Status breakdown
        SUM(CASE WHEN OrderStatus = 'Pending' THEN 1 ELSE 0 END) AS PendingOrders,
        SUM(CASE WHEN OrderStatus = 'Processing' THEN 1 ELSE 0 END) AS ProcessingOrders,
        SUM(CASE WHEN OrderStatus = 'Shipped' THEN 1 ELSE 0 END) AS ShippedOrders,
        SUM(CASE WHEN OrderStatus = 'Delivered' THEN 1 ELSE 0 END) AS DeliveredOrders,
        SUM(CASE WHEN OrderStatus IN ('Cancelled', 'Returned') THEN 1 ELSE 0 END) AS ProblematicOrders
    FROM FulfillmentMetrics
    GROUP BY ShippingCountry, OrderStatus, PaymentMethod
),
PerformanceScore AS (
    SELECT
        *,
        -- Calculate composite fulfillment score (0-100)
        CAST(
            (ProcessingSLA_CompliancePct * 0.4) +
            (ShippingSLA_CompliancePct * 0.4) +
            ((100 - (ProblematicOrders * 100.0 / NULLIF(TotalOrders, 0))) * 0.2)
        AS DECIMAL(5,2)) AS FulfillmentScore
    FROM AggregatedMetrics
)
SELECT
    ShippingCountry,
    OrderStatus,
    PaymentMethod,
    TotalOrders,
    CAST(TotalRevenue AS DECIMAL(12,2)) AS TotalRevenue,
    CAST(AvgOrderValue AS DECIMAL(10,2)) AS AvgOrderValue,
    CAST(AvgProcessingHours AS DECIMAL(5,1)) AS AvgProcessingHours,
    CAST(AvgPackagingHours AS DECIMAL(5,1)) AS AvgPackagingHours,
    CAST(AvgTimeToShipHours AS DECIMAL(5,1)) AS AvgTimeToShipHours,
    CAST(AvgDeliveryDays AS DECIMAL(4,1)) AS AvgDeliveryDays,
    CAST(ProcessingSLA_CompliancePct AS DECIMAL(5,2)) AS ProcessingSLA_CompliancePct,
    CAST(ShippingSLA_CompliancePct AS DECIMAL(5,2)) AS ShippingSLA_CompliancePct,
    PendingOrders,
    ProcessingOrders,
    ShippedOrders,
    DeliveredOrders,
    ProblematicOrders,
    CAST(ProblematicOrders * 100.0 / NULLIF(TotalOrders, 0) AS DECIMAL(5,2)) AS ProblematicOrderPct,
    FulfillmentScore,
    -- Performance classification
    CASE
        WHEN FulfillmentScore >= 90 THEN 'Excellent'
        WHEN FulfillmentScore >= 75 THEN 'Good'
        WHEN FulfillmentScore >= 60 THEN 'Acceptable'
        ELSE 'Needs Improvement'
    END AS PerformanceGrade,
    -- Recommended actions
    CASE
        WHEN ProcessingSLA_CompliancePct < 80 THEN 'Improve processing speed'
        WHEN ShippingSLA_CompliancePct < 80 THEN 'Review shipping partners'
        WHEN ProblematicOrders * 100.0 / NULLIF(TotalOrders, 0) > 10 THEN 'Investigate cancellations/returns'
        WHEN PendingOrders > ProcessingOrders * 2 THEN 'Clear pending backlog'
        ELSE 'Performance on track'
    END AS RecommendedAction
FROM PerformanceScore
WHERE TotalOrders >= 5  -- Minimum sample size
ORDER BY TotalRevenue DESC, FulfillmentScore DESC;
