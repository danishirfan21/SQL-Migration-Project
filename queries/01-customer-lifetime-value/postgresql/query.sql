-- =====================================================
-- Query 1: Customer Lifetime Value (CLV) Analysis
-- Platform: PostgreSQL
-- =====================================================
-- Business Goal: Calculate customer lifetime value, segmentation,
-- and identify high-value customers with purchase patterns

WITH customer_orders AS (
    -- Aggregate order data per customer
    SELECT
        c.customer_id,
        c.email,
        c.first_name || ' ' || c.last_name AS full_name,
        c.country,
        c.registration_date,
        c.customer_segment,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.total_amount) AS total_revenue,
        AVG(o.total_amount) AS avg_order_value,
        MIN(o.order_date) AS first_order_date,
        MAX(o.order_date) AS last_order_date,
        EXTRACT(DAY FROM (MAX(o.order_date) - MIN(o.order_date)))::INTEGER AS customer_lifespan_days
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
        AND o.order_status NOT IN ('Cancelled', 'Returned')
    WHERE c.is_active = TRUE
    GROUP BY
        c.customer_id,
        c.email,
        c.first_name,
        c.last_name,
        c.country,
        c.registration_date,
        c.customer_segment
),
customer_metrics AS (
    -- Calculate advanced metrics
    SELECT
        *,
        CASE
            WHEN customer_lifespan_days = 0 THEN total_revenue
            ELSE total_revenue / NULLIF(customer_lifespan_days, 0) * 365
        END AS annualized_revenue,
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP - last_order_date))::INTEGER AS days_since_last_order,
        CASE
            WHEN EXTRACT(DAY FROM (CURRENT_TIMESTAMP - last_order_date)) > 180 THEN 'At Risk'
            WHEN EXTRACT(DAY FROM (CURRENT_TIMESTAMP - last_order_date)) > 90 THEN 'Declining'
            WHEN total_orders >= 5 THEN 'Active'
            ELSE 'New'
        END AS customer_status,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        NTILE(10) OVER (ORDER BY total_revenue DESC) AS revenue_decile
    FROM customer_orders
    WHERE total_orders > 0
),
category_purchases AS (
    -- Get favorite product category per customer
    SELECT
        o.customer_id,
        p.category AS favorite_category,
        SUM(oi.line_total) AS category_spend,
        ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY SUM(oi.line_total) DESC) AS category_rank
    FROM orders o
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY o.customer_id, p.category
)
SELECT
    cm.customer_id,
    cm.email,
    cm.full_name,
    cm.country,
    cm.customer_segment,
    cm.total_orders,
    ROUND(cm.total_revenue::NUMERIC, 2) AS total_revenue,
    ROUND(cm.avg_order_value::NUMERIC, 2) AS avg_order_value,
    ROUND(cm.annualized_revenue::NUMERIC, 2) AS annualized_revenue,
    cm.customer_lifespan_days,
    cm.days_since_last_order,
    cm.customer_status,
    cm.revenue_rank,
    cm.revenue_decile,
    cp.favorite_category,
    ROUND(cp.category_spend::NUMERIC, 2) AS favorite_category_spend,
    -- Calculate CLV Score (weighted metric)
    ROUND(
        (cm.total_revenue * 0.4) +
        (cm.total_orders * 50 * 0.3) +
        (cm.annualized_revenue * 0.3),
    2) AS clv_score
FROM customer_metrics cm
LEFT JOIN category_purchases cp ON cm.customer_id = cp.customer_id
    AND cp.category_rank = 1
WHERE cm.total_revenue > 100  -- Filter out low-value customers
ORDER BY cm.total_revenue DESC;

-- Performance optimization: Create materialized view for frequent access
-- CREATE MATERIALIZED VIEW mv_customer_lifetime_value AS
-- <query above>
-- CREATE INDEX idx_mv_clv_revenue ON mv_customer_lifetime_value(total_revenue DESC);
-- REFRESH: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_lifetime_value;
