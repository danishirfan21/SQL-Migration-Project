-- =====================================================
-- Query 8: Advanced Customer Segmentation (RFM Analysis)
-- Platform: BigQuery (Standard SQL)
-- =====================================================
-- Business Goal: Segment customers using RFM (Recency, Frequency, Monetary) model

WITH customer_rfm AS (
    SELECT
        c.customer_id,
        c.email,
        CONCAT(c.first_name, ' ', c.last_name) AS full_name,
        c.country,
        c.customer_segment AS current_segment,
        -- Recency: Days since last purchase
        DATE_DIFF(CURRENT_DATE(), DATE(MAX(o.order_date)), DAY) AS recency_days,
        -- Frequency: Number of orders
        COUNT(DISTINCT o.order_id) AS frequency,
        -- Monetary: Total spending
        SUM(o.total_amount) AS monetary_value,
        -- Additional metrics
        AVG(o.total_amount) AS avg_order_value,
        MIN(o.order_date) AS first_order_date,
        MAX(o.order_date) AS last_order_date,
        DATE_DIFF(DATE(MAX(o.order_date)), DATE(MIN(o.order_date)), DAY) AS customer_lifespan_days
    FROM `project_id.globalshop_dataset.customers` c
    INNER JOIN `project_id.globalshop_dataset.orders` o ON c.customer_id = o.customer_id
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
        -- Calculate RFM scores (1-5, where 5 is best)
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score_raw, -- Higher days = worse
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score_raw,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score_raw
    FROM customer_rfm
),
rfm_scores_final AS (
    -- BigQuery NTILE behaves the same, but we want 5 as best.
    -- If we order by ASC for RecencyDays, NTILE 5 is worst.
    -- Wait, T-SQL used: NTILE(5) OVER (ORDER BY RecencyDays ASC) AS R_Score.
    -- In T-SQL if RecencyDays are [1, 10, 20, 50, 100], NTILE 1 is [1], NTILE 5 is [100].
    -- Usually 5 is the best score. So 1 day recency should be 5.
    -- So T-SQL should have used DESC or we adjust.
    -- T-SQL comment says "1-5, where 5 is best".
    -- Let's stick to the logic: 5 is best (highest frequency, highest monetary, lowest recency).
    SELECT
        *,
        -- R Score: 5 is best (most recent)
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score, -- Lower days = NTILE 1 in BQ?
        -- Actually, in BQ: NTILE(5) OVER (ORDER BY recency_days ASC) -> small values get 1.
        -- We want small recency to get 5.
        -- So:
        (6 - NTILE(5) OVER (ORDER BY recency_days ASC)) AS R_Score_Adj,
        NTILE(5) OVER (ORDER BY frequency ASC) AS F_Score_Adj,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS M_Score_Adj
    FROM customer_rfm
),
rfm_segments_base AS (
    SELECT
        *,
        -- Simplified NTILE call for the R/F/M scores
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_tile,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_tile,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_tile
    FROM customer_rfm
),
rfm_scored AS (
    SELECT
        *,
        -- 5 is Best, 1 is Worst
        (6 - r_tile) AS r_score,
        f_tile AS f_score,
        m_tile AS m_score
    FROM rfm_segments_base
),
segment_classification AS (
    SELECT
        *,
        -- Combined RFM score as string
        CONCAT(CAST(r_score AS STRING), CAST(f_score AS STRING), CAST(m_score AS STRING)) AS rfm_combined,
        -- Detailed segmentation based on RFM
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
        -- Predicted LTV tier
        CASE
            WHEN m_score >= 4 AND f_score >= 4 THEN 'High Value'
            WHEN m_score >= 3 AND f_score >= 3 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS value_tier,
        -- Churn risk
        CASE
            WHEN recency_days > 180 THEN 'High Risk'
            WHEN recency_days > 90 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS churn_risk
    FROM rfm_scored
)
SELECT
    customer_id,
    email,
    full_name,
    country,
    current_segment,
    recency_days,
    frequency AS total_orders,
    ROUND(monetary_value, 2) AS total_spending,
    ROUND(avg_order_value, 2) AS avg_order_value,
    customer_lifespan_days,
    r_score AS recency_score,
    f_score AS frequency_score,
    m_score AS monetary_score,
    rfm_combined AS rfm_score,
    rfm_segment,
    value_tier,
    churn_risk,
    -- Marketing recommendations
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
    -- Expected action
    CASE
        WHEN recency_days <= 30 AND frequency >= 5 THEN 'Likely to purchase soon'
        WHEN recency_days <= 60 AND m_score >= 4 THEN 'Target for premium products'
        WHEN recency_days > 90 AND frequency >= 3 THEN 'Send reactivation offer'
        WHEN recency_days > 180 THEN 'High churn risk - urgent action needed'
        ELSE 'Monitor'
    END AS next_action
FROM segment_classification
ORDER BY monetary_value DESC, frequency DESC;
