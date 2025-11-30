-- =====================================================
-- Query 8: Advanced Customer Segmentation (RFM Analysis)
-- Platform: PostgreSQL
-- =====================================================

WITH customer_rfm AS (
    SELECT
        c.customer_id,
        c.email,
        c.first_name || ' ' || c.last_name AS full_name,
        c.country,
        c.customer_segment AS current_segment,
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP - MAX(o.order_date)))::INTEGER AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(o.total_amount) AS monetary_value,
        AVG(o.total_amount) AS avg_order_value,
        MIN(o.order_date) AS first_order_date,
        MAX(o.order_date) AS last_order_date,
        EXTRACT(DAY FROM (MAX(o.order_date) - MIN(o.order_date)))::INTEGER AS customer_lifespan_days
    FROM customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status IN ('Delivered', 'Shipped')
        AND c.is_active = TRUE
    GROUP BY
        c.customer_id,
        c.email,
        c.first_name,
        c.last_name,
        c.country,
        c.customer_segment
),
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value DESC) AS m_score,
        (NTILE(5) OVER (ORDER BY recency_days ASC) * 100 +
         NTILE(5) OVER (ORDER BY frequency DESC) * 10 +
         NTILE(5) OVER (ORDER BY monetary_value DESC))::VARCHAR(3) AS rfm_combined
    FROM customer_rfm
),
segment_classification AS (
    SELECT
        *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 4 AND m_score >= 4 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2 AND m_score >= 3 THEN 'Big Spenders'
            WHEN r_score >= 4 AND f_score >= 3 AND m_score <= 3 THEN 'Promising'
            WHEN r_score >= 3 AND f_score >= 2 AND m_score >= 2 THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score >= 2 AND m_score >= 3 THEN 'Cant Lose Them'
            WHEN r_score >= 3 AND f_score <= 2 AND m_score <= 2 THEN 'Need Attention'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
            ELSE 'About to Sleep'
        END AS rfm_segment,
        CASE
            WHEN m_score >= 4 AND f_score >= 4 THEN 'High Value'
            WHEN m_score >= 3 AND f_score >= 3 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS value_tier,
        CASE
            WHEN recency_days > 180 THEN 'High Risk'
            WHEN recency_days > 90 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS churn_risk
    FROM rfm_scores
)
SELECT
    customer_id,
    email,
    full_name,
    country,
    current_segment,
    recency_days,
    frequency AS total_orders,
    ROUND(monetary_value::NUMERIC, 2) AS total_spending,
    ROUND(avg_order_value::NUMERIC, 2) AS avg_order_value,
    customer_lifespan_days,
    r_score AS recency_score,
    f_score AS frequency_score,
    m_score AS monetary_score,
    rfm_combined AS rfm_score,
    rfm_segment,
    value_tier,
    churn_risk,
    CASE
        WHEN rfm_segment = 'Champions' THEN 'Reward program, early access to new products'
        WHEN rfm_segment = 'Loyal Customers' THEN 'Upsell higher value products'
        WHEN rfm_segment = 'Big Spenders' THEN 'Premium offers, VIP treatment'
        WHEN rfm_segment = 'At Risk' THEN 'Reactivation campaign, special discounts'
        WHEN rfm_segment = 'Cant Lose Them' THEN 'Win-back campaign, personalized offers'
        WHEN rfm_segment = 'Promising' THEN 'Engagement campaign, build loyalty'
        WHEN rfm_segment = 'Need Attention' THEN 'Limited time offers'
        WHEN rfm_segment = 'Hibernating' THEN 'Re-engagement email series'
        ELSE 'General marketing'
    END AS marketing_strategy,
    CASE
        WHEN recency_days <= 30 AND frequency >= 5 THEN 'Likely to purchase soon'
        WHEN recency_days <= 60 AND m_score >= 4 THEN 'Target for premium products'
        WHEN recency_days > 90 AND frequency >= 3 THEN 'Send reactivation offer'
        WHEN recency_days > 180 THEN 'High churn risk - urgent action needed'
        ELSE 'Monitor'
    END AS next_action
FROM segment_classification
ORDER BY monetary_value DESC, frequency DESC;
