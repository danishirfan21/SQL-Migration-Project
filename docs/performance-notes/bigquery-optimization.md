# BigQuery Optimization Guide

## Cost Model Understanding

BigQuery pricing is based on:
1. **Storage**: $0.02/GB/month (first 10GB free)
2. **Queries**: $5/TB scanned (first 1TB/month free)
3. **Streaming inserts**: $0.01/200MB

**Key Insight**: Query cost = bytes scanned, NOT bytes returned

## Cost Optimization Strategies

### 1. Partition Pruning

```sql
-- BAD: Scans entire table (expensive!)
SELECT *
FROM `project.dataset.orders`
WHERE order_status = 'Delivered';
-- Cost: Scans ALL data in table

-- GOOD: Uses partition filter
SELECT *
FROM `project.dataset.orders`
WHERE DATE(order_date) = '2024-06-15'
  AND order_status = 'Delivered';
-- Cost: Scans only 1 day's partition

-- BEST: Range partition filter
SELECT *
FROM `project.dataset.orders`
WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31'
  AND order_status = 'Delivered';
-- Cost: Scans only 1 year of data
```

**Savings Example**:
- Table size: 1 TB (3 years of data)
- Without partition filter: $5 per query
- With 1-year filter: $1.67 per query (67% savings)
- With 1-day filter: $0.01 per query (99.8% savings)

### 2. Column Selection

```sql
-- BAD: Selects all columns (columnar storage advantage lost)
SELECT *
FROM `project.dataset.orders`
WHERE DATE(order_date) = '2024-06-15';
-- Scans: ALL columns in partition

-- GOOD: Select only needed columns
SELECT order_id, customer_id, total_amount
FROM `project.dataset.orders`
WHERE DATE(order_date) = '2024-06-15';
-- Scans: Only 3 columns in partition

-- Example:
-- Table: 100 columns, 1 GB/day partition
-- SELECT *: 1 GB scanned
-- SELECT 3 columns: ~30 MB scanned (97% savings)
```

### 3. Clustering Benefits

```sql
-- Without clustering
SELECT *
FROM `project.dataset.orders`
WHERE DATE(order_date) = '2024-06-15'
  AND customer_id = 12345;
-- Scans: Entire day's partition

-- With clustering on customer_id
CREATE TABLE `project.dataset.orders`
PARTITION BY DATE(order_date)
CLUSTER BY customer_id;

SELECT *
FROM `project.dataset.orders`
WHERE DATE(order_date) = '2024-06-15'
  AND customer_id = 12345;
-- Scans: Only blocks containing customer_id = 12345
-- Typical reduction: 10-50% depending on data distribution
```

### 4. Materialized Views

```sql
-- Expensive query run frequently
SELECT
    customer_id,
    DATE_TRUNC(order_date, MONTH) AS month,
    SUM(total_amount) AS monthly_revenue,
    COUNT(*) AS order_count
FROM `project.dataset.orders`
WHERE order_date >= '2023-01-01'
GROUP BY customer_id, month;
-- Cost: $X every time

-- Create materialized view (one-time cost, auto-refreshed)
CREATE MATERIALIZED VIEW `project.dataset.mv_monthly_customer_revenue`
PARTITION BY month
CLUSTER BY customer_id
AS
SELECT
    customer_id,
    DATE_TRUNC(order_date, MONTH) AS month,
    SUM(total_amount) AS monthly_revenue,
    COUNT(*) AS order_count
FROM `project.dataset.orders`
WHERE order_date >= '2023-01-01'
GROUP BY customer_id, month;

-- Query the materialized view (much cheaper)
SELECT * FROM `project.dataset.mv_monthly_customer_revenue`
WHERE customer_id = 12345;
-- Cost: Only scans materialized view (typically 90%+ cheaper)
```

### 5. Approximate Aggregations

```sql
-- EXACT: Expensive for large tables
SELECT COUNT(DISTINCT customer_id) AS unique_customers
FROM `project.dataset.orders`;
-- Cost: Full table scan + expensive GROUP BY

-- APPROXIMATE: Much faster and cheaper
SELECT APPROX_COUNT_DISTINCT(customer_id) AS unique_customers
FROM `project.dataset.orders`;
-- Cost: ~10x faster, same scan but lighter processing
-- Accuracy: ±1-2% (acceptable for most analytics)

-- Other approximate functions
SELECT
    APPROX_QUANTILES(total_amount, 100)[OFFSET(50)] AS median_order,
    APPROX_TOP_COUNT(product_id, 10) AS top_products
FROM `project.dataset.orders`;
```

### 6. Avoid SELECT DISTINCT on Large Tables

```sql
-- BAD: Expensive distinct operation
SELECT DISTINCT customer_id
FROM `project.dataset.orders`;

-- GOOD: Use GROUP BY instead (often better optimized)
SELECT customer_id
FROM `project.dataset.orders`
GROUP BY customer_id;

-- BEST: Use approximate if exact count not needed
SELECT APPROX_COUNT_DISTINCT(customer_id)
FROM `project.dataset.orders`;
```

### 7. Optimize Joins

```sql
-- BAD: Large table on left
SELECT *
FROM `project.dataset.orders` o  -- 100M rows
JOIN `project.dataset.customers` c  -- 1M rows
  ON o.customer_id = c.customer_id;

-- GOOD: Smaller table on left (BigQuery uses broadcast join)
SELECT *
FROM `project.dataset.customers` c  -- 1M rows
JOIN `project.dataset.orders` o  -- 100M rows
  ON c.customer_id = o.customer_id;

-- BEST: Filter before joining
SELECT *
FROM `project.dataset.customers` c
JOIN (
    SELECT customer_id, order_id, total_amount
    FROM `project.dataset.orders`
    WHERE DATE(order_date) >= '2024-01-01'
) o ON c.customer_id = o.customer_id;
```

### 8. Use BI Engine

```sql
-- Enable BI Engine for frequently accessed tables/views
ALTER TABLE `project.dataset.orders`
SET OPTIONS (max_staleness = INTERVAL 1 HOUR);

-- BI Engine caches results in memory
-- Queries hit cache instead of scanning storage
-- Cost: $0 for cached queries
```

### 9. Partition Expiration

```sql
-- Automatically delete old partitions
CREATE TABLE `project.dataset.orders`
(
    order_id INT64,
    order_date DATE,
    total_amount NUMERIC
)
PARTITION BY order_date
OPTIONS(
    partition_expiration_days=730,  -- Delete after 2 years
    require_partition_filter=true   -- Force users to filter by date
);

-- Benefits:
-- 1. Reduced storage costs
-- 2. Prevents accidental full table scans
```

### 10. Streaming Insert Optimization

```sql
-- BAD: Individual inserts (expensive)
INSERT INTO `project.dataset.orders` VALUES (1, '2024-06-15', 100);
INSERT INTO `project.dataset.orders` VALUES (2, '2024-06-15', 200);
-- Cost: $0.01/200MB, each row charged separately

-- GOOD: Batch inserts
INSERT INTO `project.dataset.orders` VALUES
    (1, '2024-06-15', 100),
    (2, '2024-06-15', 200),
    (3, '2024-06-15', 300);
-- Cost: Single charge for batch

-- BEST: Use load jobs (FREE up to 1000 loads/day)
bq load --source_format=CSV dataset.orders gs://bucket/data.csv
-- Cost: $0
```

## Query Performance Patterns

### Window Functions

```sql
-- Efficient window function usage
SELECT
    customer_id,
    order_date,
    total_amount,
    -- Partition window appropriately
    SUM(total_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM `project.dataset.orders`
WHERE DATE(order_date) >= '2024-01-01'  -- Always filter!
ORDER BY customer_id, order_date;
```

### CTEs vs Subqueries

```sql
-- CTEs are materialized in BigQuery (good for reuse)
WITH customer_totals AS (
    SELECT customer_id, SUM(total_amount) AS total
    FROM `project.dataset.orders`
    WHERE DATE(order_date) >= '2024-01-01'
    GROUP BY customer_id
)
SELECT * FROM customer_totals WHERE total > 1000
UNION ALL
SELECT * FROM customer_totals WHERE total > 5000;
-- customer_totals is computed once and reused

-- Subqueries are re-evaluated
SELECT * FROM (
    SELECT customer_id, SUM(total_amount) AS total
    FROM `project.dataset.orders`
    GROUP BY customer_id
) WHERE total > 1000;
```

### ARRAY and STRUCT Usage

```sql
-- Denormalize with ARRAY for fewer joins
CREATE TABLE `project.dataset.orders_denormalized` AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    ARRAY_AGG(STRUCT(
        oi.product_id,
        oi.product_name,
        oi.quantity,
        oi.unit_price
    )) AS items
FROM `project.dataset.orders` o
JOIN `project.dataset.order_items` oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.customer_id, o.order_date;

-- Query with UNNEST (faster than join)
SELECT
    order_id,
    item.product_id,
    item.quantity
FROM `project.dataset.orders_denormalized`,
UNNEST(items) AS item
WHERE item.quantity > 5;
```

## Monitoring and Optimization

### 1. Check Query Cost Before Running

```sql
-- Dry run to estimate cost
bq query --dry_run \
'SELECT * FROM `project.dataset.orders` WHERE customer_id = 123'

-- Returns: "Query will process X GB"
-- Cost estimate: X GB * $5/TB = $Y
```

### 2. Query Execution Details

```sql
-- View query plan
bq show -j <job_id>

-- Key metrics to check:
-- - Bytes processed
-- - Bytes billed
-- - Slot time
-- - Shuffle operations
```

### 3. Slot Usage Optimization

```sql
-- Check slot usage
SELECT
    job_id,
    user_email,
    total_slot_ms,
    total_bytes_processed
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
ORDER BY total_slot_ms DESC
LIMIT 10;
```

### 4. Table Size and Growth

```sql
-- Monitor table sizes
SELECT
    table_name,
    ROUND(size_bytes / POW(10, 9), 2) AS size_gb,
    row_count
FROM `project.dataset.__TABLES__`
ORDER BY size_bytes DESC;

-- Monitor partition sizes
SELECT
    partition_id,
    ROUND(total_logical_bytes / POW(10, 9), 2) AS size_gb,
    total_rows
FROM `project.dataset.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'orders'
ORDER BY partition_id DESC
LIMIT 30;
```

## Best Practices Summary

### DO ✅
1. **Always** filter on partition columns
2. **Select** only needed columns
3. **Use** clustering for frequently filtered columns
4. **Create** materialized views for expensive, frequent queries
5. **Use** approximate aggregations when exact precision not needed
6. **Batch** inserts and use load jobs instead of streaming
7. **Set** partition expiration to manage costs
8. **Monitor** query costs with dry runs
9. **Denormalize** with ARRAY/STRUCT to reduce joins
10. **Use** APPROX_COUNT_DISTINCT instead of COUNT(DISTINCT)

### DON'T ❌
1. **Don't** use SELECT * in production queries
2. **Don't** query without partition filters
3. **Don't** use DISTINCT on large tables (use GROUP BY)
4. **Don't** stream small batches individually
5. **Don't** create too many small partitions (< 1GB each)
6. **Don't** cluster on high-cardinality columns
7. **Don't** join large tables without filtering first
8. **Don't** forget to set partition expiration
9. **Don't** use ORDER BY without LIMIT on large results
10. **Don't** run the same expensive query repeatedly (use caching or MV)

## Cost Comparison Examples

### Example 1: Customer Lifetime Value Query

**Original Query** (Full table scan):
```sql
SELECT customer_id, SUM(total_amount)
FROM `project.dataset.orders`
GROUP BY customer_id;
```
- Bytes scanned: 1 TB
- Cost: $5.00

**Optimized Query** (with partition filter):
```sql
SELECT customer_id, SUM(total_amount)
FROM `project.dataset.orders`
WHERE order_date >= '2023-01-01'
GROUP BY customer_id;
```
- Bytes scanned: 200 GB
- Cost: $1.00
- **Savings: 80%**

**Materialized View** (pre-aggregated):
```sql
CREATE MATERIALIZED VIEW mv_customer_totals AS
SELECT customer_id, SUM(total_amount) AS total_revenue
FROM `project.dataset.orders`
GROUP BY customer_id;

SELECT * FROM mv_customer_totals WHERE customer_id = 123;
```
- Bytes scanned: 1 MB
- Cost: $0.000005
- **Savings: 99.9999%**

### Example 2: Product Affinity Analysis

**Original** (self-join without optimization):
```sql
SELECT p1.product_name, p2.product_name, COUNT(*)
FROM `project.dataset.order_items` oi1
JOIN `project.dataset.order_items` oi2 ON oi1.order_id = oi2.order_id
JOIN `project.dataset.products` p1 ON oi1.product_id = p1.product_id
JOIN `project.dataset.products` p2 ON oi2.product_id = p2.product_id
GROUP BY p1.product_name, p2.product_name;
```
- Bytes scanned: 500 GB
- Cost: $2.50

**Optimized** (pre-aggregate, filter, use clustering):
```sql
WITH filtered_orders AS (
    SELECT order_id, product_id
    FROM `project.dataset.order_items`
    WHERE order_date >= '2024-01-01'  -- Assuming order_date is denormalized
)
SELECT p1.product_name, p2.product_name, COUNT(*) AS co_purchases
FROM filtered_orders oi1
JOIN filtered_orders oi2 ON oi1.order_id = oi2.order_id
  AND oi1.product_id < oi2.product_id
JOIN `project.dataset.products` p1 ON oi1.product_id = p1.product_id
JOIN `project.dataset.products` p2 ON oi2.product_id = p2.product_id
GROUP BY p1.product_name, p2.product_name
HAVING co_purchases > 10;
```
- Bytes scanned: 50 GB
- Cost: $0.25
- **Savings: 90%**

## Tools and Resources

### Query Optimization Tools
1. **BigQuery Console**: Built-in query validator and estimator
2. **Query Plan Visualizer**: Understand query execution
3. **BI Engine**: In-memory acceleration for dashboards
4. **Flex Slots**: Reserve capacity for predictable costs

### Monitoring
```sql
-- Create dashboard for cost monitoring
SELECT
    DATE(creation_time) AS query_date,
    user_email,
    COUNT(*) AS query_count,
    SUM(total_bytes_processed) / POW(10, 12) AS tb_processed,
    SUM(total_bytes_processed) / POW(10, 12) * 5 AS estimated_cost_usd
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    AND job_type = 'QUERY'
GROUP BY query_date, user_email
ORDER BY query_date DESC, tb_processed DESC;
```

## Conclusion

BigQuery optimization is fundamentally different from traditional databases:
- **No indexes** → Use partitioning and clustering
- **Columnar storage** → Select only needed columns
- **Cost = bytes scanned** → Optimize for minimal data access
- **Serverless** → No manual performance tuning needed

Following these guidelines can reduce query costs by **80-99%** while improving performance.
