-- =====================================================
-- Query 3: Sales Performance Dashboard - Multi-Dimensional Analysis
-- Platform: PostgreSQL
-- =====================================================
-- Business Goal: Create comprehensive sales dashboard with YoY growth,
-- category performance, and trending metrics

WITH date_dimension AS (
    -- Generate date periods for comparison
    SELECT
        DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '12 months' AS current_year_start,
        DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '24 months' AS prior_year_start,
        DATE_TRUNC('month', CURRENT_DATE) AS current_month_start,
        CURRENT_DATE - INTERVAL '90 days' AS last_90_days_start
),
sales_by_period AS (
    SELECT
        p.category,
        p.sub_category,
        o.shipping_country,
        -- Current year metrics
        SUM(CASE
            WHEN o.order_date >= dd.current_year_start THEN oi.line_total
            ELSE 0
        END) AS current_year_revenue,
        SUM(CASE
            WHEN o.order_date >= dd.current_year_start THEN oi.quantity
            ELSE 0
        END) AS current_year_units,
        COUNT(DISTINCT CASE
            WHEN o.order_date >= dd.current_year_start THEN o.order_id
        END) AS current_year_orders,
        -- Prior year metrics
        SUM(CASE
            WHEN o.order_date >= dd.prior_year_start
                AND o.order_date < dd.current_year_start THEN oi.line_total
            ELSE 0
        END) AS prior_year_revenue,
        SUM(CASE
            WHEN o.order_date >= dd.prior_year_start
                AND o.order_date < dd.current_year_start THEN oi.quantity
            ELSE 0
        END) AS prior_year_units,
        -- Current month
        SUM(CASE
            WHEN o.order_date >= dd.current_month_start THEN oi.line_total
            ELSE 0
        END) AS current_month_revenue,
        -- Last 90 days
        SUM(CASE
            WHEN o.order_date >= dd.last_90_days_start THEN oi.line_total
            ELSE 0
        END) AS last_90_days_revenue,
        AVG(oi.unit_price) AS avg_unit_price,
        AVG(oi.discount) AS avg_discount_pct
    FROM orders o
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN products p ON oi.product_id = p.product_id
    CROSS JOIN date_dimension dd
    WHERE o.order_status IN ('Delivered', 'Shipped')
        AND o.order_date >= dd.prior_year_start
    GROUP BY
        p.category,
        p.sub_category,
        o.shipping_country,
        dd.current_year_start,
        dd.prior_year_start,
        dd.current_month_start,
        dd.last_90_days_start
),
performance_metrics AS (
    SELECT
        category,
        sub_category,
        shipping_country,
        current_year_revenue,
        current_year_units,
        current_year_orders,
        prior_year_revenue,
        prior_year_units,
        current_month_revenue,
        last_90_days_revenue,
        avg_unit_price,
        avg_discount_pct,
        -- Growth calculations
        CASE
            WHEN prior_year_revenue > 0 THEN
                ((current_year_revenue - prior_year_revenue) / prior_year_revenue * 100)
            ELSE NULL
        END AS yoy_revenue_growth_pct,
        CASE
            WHEN prior_year_units > 0 THEN
                ((current_year_units - prior_year_units)::NUMERIC / prior_year_units * 100)
            ELSE NULL
        END AS yoy_units_growth_pct,
        -- Market share within category
        current_year_revenue * 100.0 / NULLIF(SUM(current_year_revenue) OVER (PARTITION BY category), 0) AS category_market_share_pct,
        -- Performance ranking
        RANK() OVER (ORDER BY current_year_revenue DESC) AS revenue_rank,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY current_year_revenue DESC) AS category_rank,
        -- Moving averages
        AVG(last_90_days_revenue) OVER (
            PARTITION BY category
            ORDER BY current_year_revenue DESC
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg_3_periods
    FROM sales_by_period
),
top_products AS (
    -- Best performing products per category
    SELECT
        p.category,
        p.product_name,
        SUM(oi.line_total) AS product_revenue,
        ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(oi.line_total) DESC) AS product_rank
    FROM orders o
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '12 months'
        AND o.order_status IN ('Delivered', 'Shipped')
    GROUP BY p.category, p.product_name
)
SELECT
    pm.category,
    pm.sub_category,
    pm.shipping_country,
    ROUND(pm.current_year_revenue::NUMERIC, 2) AS current_year_revenue,
    pm.current_year_units,
    pm.current_year_orders,
    ROUND(pm.prior_year_revenue::NUMERIC, 2) AS prior_year_revenue,
    ROUND(pm.current_month_revenue::NUMERIC, 2) AS current_month_revenue,
    ROUND(pm.yoy_revenue_growth_pct::NUMERIC, 2) AS yoy_revenue_growth_pct,
    ROUND(pm.yoy_units_growth_pct::NUMERIC, 2) AS yoy_units_growth_pct,
    ROUND(pm.category_market_share_pct::NUMERIC, 2) AS category_market_share_pct,
    pm.revenue_rank,
    pm.category_rank,
    ROUND(pm.avg_unit_price::NUMERIC, 2) AS avg_unit_price,
    ROUND(pm.avg_discount_pct::NUMERIC, 2) AS avg_discount_pct,
    tp.product_name AS top_product,
    ROUND(tp.product_revenue::NUMERIC, 2) AS top_product_revenue,
    -- Performance tier
    CASE
        WHEN pm.yoy_revenue_growth_pct >= 20 THEN 'High Growth'
        WHEN pm.yoy_revenue_growth_pct >= 5 THEN 'Steady Growth'
        WHEN pm.yoy_revenue_growth_pct >= -5 THEN 'Stable'
        WHEN pm.yoy_revenue_growth_pct >= -20 THEN 'Declining'
        ELSE 'Significant Decline'
    END AS performance_tier
FROM performance_metrics pm
LEFT JOIN top_products tp ON pm.category = tp.category
    AND tp.product_rank = 1
WHERE pm.current_year_revenue > 1000  -- Filter low-revenue segments
ORDER BY pm.current_year_revenue DESC;
