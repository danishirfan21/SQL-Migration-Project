-- =====================================================
-- Query 2: Inventory Reorder Analysis with Forecasting
-- Platform: BigQuery (Standard SQL)
-- =====================================================
-- Business Goal: Identify products needing reorder based on current stock,
-- sales velocity, and lead time forecasting

WITH sales_velocity AS (
    -- Calculate daily sales rate over last 30, 60, and 90 days
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        p.supplier_id,
        SUM(CASE WHEN o.order_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY) THEN oi.quantity ELSE 0 END) AS qty_last_30_days,
        SUM(CASE WHEN o.order_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 60 DAY) THEN oi.quantity ELSE 0 END) AS qty_last_60_days,
        SUM(CASE WHEN o.order_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY) THEN oi.quantity ELSE 0 END) AS qty_last_90_days,
        COUNT(DISTINCT CASE WHEN o.order_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY) THEN o.order_id END) AS orders_last_30_days,
        AVG(oi.unit_price) AS avg_selling_price
    FROM `project_id.globalshop_dataset.products` p
    LEFT JOIN `project_id.globalshop_dataset.order_items` oi ON p.product_id = oi.product_id
    LEFT JOIN `project_id.globalshop_dataset.orders` o ON oi.order_id = o.order_id
        AND o.order_status IN ('Delivered', 'Shipped', 'Processing')
    WHERE p.is_active = TRUE
    GROUP BY p.product_id, p.product_name, p.category, p.supplier_id
),
inventory_status AS (
    -- Current inventory levels aggregated across warehouses
    SELECT
        i.product_id,
        SUM(i.quantity_on_hand) AS total_stock_on_hand,
        MIN(i.reorder_level) AS min_reorder_level,
        MIN(i.reorder_quantity) AS reorder_quantity,
        COUNT(DISTINCT i.warehouse_location) AS warehouse_count,
        STRING_AGG(CONCAT(i.warehouse_location, ':', CAST(i.quantity_on_hand AS STRING)), ', ') AS stock_by_warehouse
    FROM `project_id.globalshop_dataset.inventory` i
    GROUP BY i.product_id
),
supplier_metrics AS (
    -- Supplier lead time and reliability
    SELECT
        s.supplier_id,
        s.supplier_name,
        s.country AS supplier_country,
        s.rating AS supplier_rating,
        AVG(DATE_DIFF(DATE(i.last_restocked), DATE(it.transaction_date), DAY)) AS avg_lead_time_days
    FROM `project_id.globalshop_dataset.suppliers` s
    LEFT JOIN `project_id.globalshop_dataset.products` p ON s.supplier_id = p.supplier_id
    LEFT JOIN `project_id.globalshop_dataset.inventory` i ON p.product_id = i.product_id
    LEFT JOIN `project_id.globalshop_dataset.inventory_transactions` it ON p.product_id = it.product_id
        AND it.transaction_type = 'Purchase'
    WHERE s.is_active = TRUE
    GROUP BY s.supplier_id, s.supplier_name, s.country, s.rating
),
reorder_analysis AS (
    SELECT
        sv.product_id,
        sv.product_name,
        sv.category,
        inv.total_stock_on_hand,
        inv.min_reorder_level,
        inv.reorder_quantity,
        inv.warehouse_count,
        inv.stock_by_warehouse,
        -- Calculate velocity metrics
        ROUND(SAFE_DIVIDE(sv.qty_last_30_days, 30), 2) AS daily_sales_rate_30d,
        ROUND(SAFE_DIVIDE(sv.qty_last_60_days, 60), 2) AS daily_sales_rate_60d,
        ROUND(SAFE_DIVIDE(sv.qty_last_90_days, 90), 2) AS daily_sales_rate_90d,
        -- Weighted average (recent sales weighted higher)
        ROUND(
            (SAFE_DIVIDE(sv.qty_last_30_days, 30) * 0.5) +
            (SAFE_DIVIDE(sv.qty_last_60_days, 60) * 0.3) +
            (SAFE_DIVIDE(sv.qty_last_90_days, 90) * 0.2),
        2) AS weighted_daily_sales_rate,
        sm.supplier_name,
        sm.supplier_country,
        sm.supplier_rating,
        IFNULL(sm.avg_lead_time_days, 14) AS estimated_lead_time_days,
        sv.avg_selling_price,
        -- Calculate days until stockout
        CASE
            WHEN sv.qty_last_30_days = 0 THEN 999
            ELSE CAST(SAFE_DIVIDE(inv.total_stock_on_hand, SAFE_DIVIDE(sv.qty_last_30_days, 30)) AS INT64)
        END AS days_until_stockout,
        -- Priority score
        CASE
            WHEN inv.total_stock_on_hand <= inv.min_reorder_level THEN 'CRITICAL'
            WHEN inv.total_stock_on_hand <= inv.min_reorder_level * 1.5 THEN 'HIGH'
            WHEN inv.total_stock_on_hand <= inv.min_reorder_level * 2 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS reorder_priority
    FROM sales_velocity sv
    INNER JOIN inventory_status inv ON sv.product_id = inv.product_id
    LEFT JOIN supplier_metrics sm ON sv.supplier_id = sm.supplier_id
)
SELECT
    product_id,
    product_name,
    category,
    total_stock_on_hand,
    min_reorder_level,
    reorder_quantity,
    warehouse_count,
    stock_by_warehouse,
    daily_sales_rate_30d,
    weighted_daily_sales_rate,
    days_until_stockout,
    estimated_lead_time_days,
    -- Recommended order quantity
    CASE
        WHEN days_until_stockout < estimated_lead_time_days THEN
            CAST(reorder_quantity +
            (weighted_daily_sales_rate * estimated_lead_time_days * 1.5) AS INT64)
        WHEN reorder_priority IN ('CRITICAL', 'HIGH') THEN reorder_quantity
        ELSE 0
    END AS recommended_order_qty,
    ROUND(
        CASE
            WHEN days_until_stockout < estimated_lead_time_days THEN
                (reorder_quantity + (weighted_daily_sales_rate * estimated_lead_time_days * 1.5)) * avg_selling_price
            WHEN reorder_priority IN ('CRITICAL', 'HIGH') THEN
                reorder_quantity * avg_selling_price
            ELSE 0
        END,
    2) AS estimated_order_value,
    reorder_priority,
    supplier_name,
    supplier_country,
    supplier_rating,
    avg_selling_price
FROM reorder_analysis
WHERE reorder_priority IN ('CRITICAL', 'HIGH', 'MEDIUM')
    OR days_until_stockout < 30
ORDER BY
    CASE reorder_priority
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        ELSE 4
    END,
    days_until_stockout ASC;
