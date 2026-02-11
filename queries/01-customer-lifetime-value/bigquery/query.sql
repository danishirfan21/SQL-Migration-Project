-- =====================================================
-- Query 1: Customer Lifetime Value (CLV) Analysis
-- Platform: BigQuery (Standard SQL)
-- =====================================================
-- Business Goal: Calculate customer lifetime value, segmentation,
-- and identify high-value customers with purchase patterns

WITH customer_orders AS (
    -- Aggregate order data per customer
    SELECT
        c.customer_id,
        c.email,
        CONCAT(c.first_name, ' ', c.last_name) AS full_name,
        c.country,
        c.registration_date,
        c.customer_segment,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.total_amount) AS total_revenue,
        AVG(o.total_amount) AS avg_order_value,
        MIN(o.order_date) AS first_order_date,
        MAX(o.order_date) AS last_order_date,
        DATE_DIFF(MAX(DATE(o.order_date)), MIN(DATE(o.order_date)), DAY) AS customer_lifespan_days
    FROM `project_id.globalshop_dataset.customers` c
    LEFT JOIN `project_id.globalshop_dataset.orders` o
        ON c.customer_id = o.customer_id
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
            WHEN DATE_DIFF(CURRENT_DATE(), DATE(first_order_date), DAY) < 30 THEN total_revenue
            ELSE SAFE_DIVIDE(total_revenue * 365, DATE_DIFF(CURRENT_DATE(), DATE(first_order_date), DAY))
        END AS annualized_revenue,
        DATE_DIFF(CURRENT_DATE(), DATE(last_order_date), DAY) AS days_since_last_order,
        CASE
            WHEN DATE_DIFF(CURRENT_DATE(), DATE(last_order_date), DAY) > 180 THEN 'At Risk'
            WHEN DATE_DIFF(CURRENT_DATE(), DATE(last_order_date), DAY) > 90 THEN 'Declining'
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
    FROM `project_id.globalshop_dataset.orders` o
    INNER JOIN `project_id.globalshop_dataset.order_items` oi
        ON o.order_id = oi.order_id
    INNER JOIN `project_id.globalshop_dataset.products` p
        ON oi.product_id = p.product_id
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
    ROUND(cm.total_revenue, 2) AS total_revenue,
    ROUND(cm.avg_order_value, 2) AS avg_order_value,
    ROUND(cm.annualized_revenue, 2) AS annualized_revenue,
    cm.customer_lifespan_days,
    cm.days_since_last_order,
    cm.customer_status,
    cm.revenue_rank,
    cm.revenue_decile,
    cp.favorite_category,
    ROUND(cp.category_spend, 2) AS favorite_category_spend,
    -- Calculate CLV Score (weighted metric)
    ROUND(
        (cm.total_revenue * 0.4) +
        (cm.total_orders * 50 * 0.3) +
        (cm.annualized_revenue * 0.3),
    2) AS clv_score
FROM customer_metrics cm
LEFT JOIN category_purchases cp
    ON cm.customer_id = cp.customer_id
    AND cp.category_rank = 1
WHERE cm.total_revenue > 100  -- Filter out low-value customers
ORDER BY cm.total_revenue DESC;

-- =====================================================
-- BigQuery Optimization: Create a scheduled materialized view
-- =====================================================
-- CREATE MATERIALIZED VIEW `project_id.globalshop_dataset.mv_customer_lifetime_value`
-- PARTITION BY DATE(last_order_date)
-- CLUSTER BY customer_segment, country
-- AS <query above>
--
-- Schedule refresh: Use BigQuery scheduled queries or Data Transfer Service
