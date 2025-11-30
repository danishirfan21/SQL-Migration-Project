-- =====================================================
-- Query 5: Product Affinity Analysis (Market Basket)
-- Platform: BigQuery (Standard SQL)
-- =====================================================

WITH product_pairs AS (
    SELECT
        p1.product_id AS product_a_id,
        p1.product_name AS product_a_name,
        p1.category AS product_a_category,
        p2.product_id AS product_b_id,
        p2.product_name AS product_b_name,
        p2.category AS product_b_category,
        oi1.order_id
    FROM `project_id.globalshop_dataset.order_items` oi1
    INNER JOIN `project_id.globalshop_dataset.order_items` oi2
        ON oi1.order_id = oi2.order_id
        AND oi1.product_id < oi2.product_id
    INNER JOIN `project_id.globalshop_dataset.products` p1
        ON oi1.product_id = p1.product_id
    INNER JOIN `project_id.globalshop_dataset.products` p2
        ON oi2.product_id = p2.product_id
    INNER JOIN `project_id.globalshop_dataset.orders` o
        ON oi1.order_id = o.order_id
    WHERE o.order_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 MONTH)
        AND o.order_status IN ('Delivered', 'Shipped')
        AND p1.is_active = TRUE
        AND p2.is_active = TRUE
),
product_totals AS (
    SELECT
        product_id,
        COUNT(DISTINCT order_id) AS total_orders
    FROM `project_id.globalshop_dataset.order_items` oi
    INNER JOIN `project_id.globalshop_dataset.orders` o
        ON oi.order_id = o.order_id
    WHERE o.order_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 MONTH)
        AND o.order_status IN ('Delivered', 'Shipped')
    GROUP BY product_id
),
affinity_metrics AS (
    SELECT
        pp.product_a_id,
        pp.product_a_name,
        pp.product_a_category,
        pp.product_b_id,
        pp.product_b_name,
        pp.product_b_category,
        COUNT(DISTINCT pp.order_id) AS co_occurrence_count,
        pta.total_orders AS product_a_total_orders,
        ptb.total_orders AS product_b_total_orders
    FROM product_pairs pp
    LEFT JOIN product_totals pta ON pp.product_a_id = pta.product_id
    LEFT JOIN product_totals ptb ON pp.product_b_id = ptb.product_id
    GROUP BY
        pp.product_a_id, pp.product_a_name, pp.product_a_category,
        pp.product_b_id, pp.product_b_name, pp.product_b_category,
        pta.total_orders, ptb.total_orders
    HAVING COUNT(DISTINCT pp.order_id) >= 5
),
total_orders_base AS (
    SELECT COUNT(DISTINCT order_id) AS total_orders
    FROM `project_id.globalshop_dataset.orders`
    WHERE order_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 MONTH)
        AND order_status IN ('Delivered', 'Shipped')
),
affinity_scores AS (
    SELECT
        am.*,
        ROUND(am.co_occurrence_count * 100.0 / tob.total_orders, 2) AS support_pct,
        ROUND(SAFE_DIVIDE(am.co_occurrence_count * 100.0, am.product_a_total_orders), 2) AS confidence_a_to_b,
        ROUND(SAFE_DIVIDE(am.co_occurrence_count * 100.0, am.product_b_total_orders), 2) AS confidence_b_to_a,
        ROUND(
            SAFE_DIVIDE(
                am.co_occurrence_count,
                SAFE_DIVIDE(am.product_a_total_orders * am.product_b_total_orders, tob.total_orders)
            ),
        4) AS lift_score
    FROM affinity_metrics am
    CROSS JOIN total_orders_base tob
),
revenue_impact AS (
    SELECT
        a.*,
        ROUND(AVG(oi.unit_price), 2) AS product_b_avg_price,
        ROUND(a.product_a_total_orders * SAFE_DIVIDE(a.confidence_a_to_b, 100) * AVG(oi.unit_price), 2) AS potential_revenue_opportunity
    FROM affinity_scores a
    INNER JOIN `project_id.globalshop_dataset.order_items` oi
        ON a.product_b_id = oi.product_id
    GROUP BY
        a.product_a_id, a.product_a_name, a.product_a_category,
        a.product_b_id, a.product_b_name, a.product_b_category,
        a.co_occurrence_count, a.product_a_total_orders, a.product_b_total_orders,
        a.support_pct, a.confidence_a_to_b, a.confidence_b_to_a, a.lift_score
)
SELECT
    product_a_name,
    product_a_category,
    product_b_name,
    product_b_category,
    co_occurrence_count AS times_purchased_together,
    product_a_total_orders AS product_a_individual_orders,
    product_b_total_orders AS product_b_individual_orders,
    support_pct,
    confidence_a_to_b AS confidence_pct_a_to_b,
    confidence_b_to_a AS confidence_pct_b_to_a,
    lift_score,
    product_b_avg_price,
    potential_revenue_opportunity,
    CASE
        WHEN lift_score >= 3 AND confidence_a_to_b >= 30 THEN 'Strong'
        WHEN lift_score >= 2 AND confidence_a_to_b >= 20 THEN 'Moderate'
        WHEN lift_score >= 1.5 AND confidence_a_to_b >= 10 THEN 'Weak'
        ELSE 'Insufficient'
    END AS recommendation_strength,
    CASE
        WHEN lift_score >= 3 AND confidence_a_to_b >= 30 THEN 'Create Bundle Offer'
        WHEN lift_score >= 2 AND confidence_a_to_b >= 20 THEN 'Add to Recommendation Engine'
        WHEN product_a_category <> product_b_category THEN 'Cross-Category Promotion'
        ELSE 'Monitor'
    END AS suggested_action
FROM revenue_impact
WHERE lift_score > 1
ORDER BY lift_score DESC, confidence_a_to_b DESC;
