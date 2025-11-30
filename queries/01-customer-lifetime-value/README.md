# Query 1: Customer Lifetime Value (CLV) Analysis

## Business Objective
Calculate comprehensive customer lifetime value metrics to identify high-value customers, predict churn risk, and understand purchase patterns for targeted marketing campaigns.

## Query Complexity
- **CTEs**: 3 levels of Common Table Expressions
- **Window Functions**: ROW_NUMBER(), NTILE(), partitioning
- **Aggregations**: SUM, AVG, COUNT, MIN, MAX
- **Joins**: LEFT JOIN (2), INNER JOIN (2)
- **Conditional Logic**: Multiple CASE statements
- **Date Calculations**: Customer lifespan, days since last order

## Syntax Differences

### String Concatenation
- **T-SQL**: `FirstName + ' ' + LastName`
- **PostgreSQL**: `first_name || ' ' || last_name`
- **BigQuery**: `CONCAT(first_name, ' ', last_name)`

### Date Differences
- **T-SQL**: `DATEDIFF(DAY, StartDate, EndDate)`
- **PostgreSQL**: `EXTRACT(DAY FROM (EndDate - StartDate))::INTEGER`
- **BigQuery**: `DATE_DIFF(EndDate, StartDate, DAY)`

### Current Date/Time
- **T-SQL**: `GETDATE()`
- **PostgreSQL**: `CURRENT_TIMESTAMP`
- **BigQuery**: `CURRENT_DATE()` or `CURRENT_TIMESTAMP()`

### Boolean Values
- **T-SQL**: `BIT` type, `1` = true
- **PostgreSQL**: `BOOLEAN` type, `TRUE`/`FALSE`
- **BigQuery**: `BOOL` type, `TRUE`/`FALSE`

### Division by Zero Handling
- **T-SQL**: `NULLIF(denominator, 0)`
- **PostgreSQL**: `NULLIF(denominator, 0)`
- **BigQuery**: `SAFE_DIVIDE(numerator, denominator)` (returns NULL on division by zero)

### Table/Column Naming
- **T-SQL**: PascalCase (e.g., `CustomerID`)
- **PostgreSQL**: snake_case (e.g., `customer_id`)
- **BigQuery**: snake_case with fully qualified names (e.g., `` `project_id.dataset.table` ``)

## Performance Considerations

### T-SQL (SQL Server)
**Indexing Strategy:**
```sql
-- Composite index for customer-order joins
CREATE INDEX IX_Orders_Customer_Date ON Orders(CustomerID, OrderDate)
    INCLUDE (TotalAmount, OrderStatus);

-- Index for order items aggregation
CREATE INDEX IX_OrderItems_Product_Order ON OrderItems(ProductID, OrderID)
    INCLUDE (LineTotal);
```

**Optimization:**
- `OPTION (MAXDOP 4)`: Controls parallelism for consistent performance
- Statistics should be updated regularly on large tables
- Consider columnstore index for Orders table if > 1M rows
- Query Store can track performance over time

**Estimated Cost:**
- Medium-high (multiple aggregations and window functions)
- Parallel execution likely for large datasets

### PostgreSQL
**Indexing Strategy:**
```sql
-- Composite B-tree indexes
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date)
    INCLUDE (total_amount, order_status);

-- Partial index for active customers only
CREATE INDEX idx_customers_active ON customers(customer_id)
    WHERE is_active = TRUE;
```

**Optimization:**
- **Materialized View**: Best for this analytical query
```sql
CREATE MATERIALIZED VIEW mv_customer_lifetime_value AS
<full query>;

CREATE INDEX idx_mv_clv_revenue ON mv_customer_lifetime_value(total_revenue DESC);
CREATE INDEX idx_mv_clv_segment ON mv_customer_lifetime_value(customer_segment);

-- Refresh strategy
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_lifetime_value;
```
- Use `EXPLAIN (ANALYZE, BUFFERS)` to analyze query plan
- `work_mem` setting important for sorts and window functions
- Consider partitioning Orders table by date if very large

**Estimated Cost:**
- Efficient with proper indexes
- Materialized view recommended for repeated access

### BigQuery
**Optimization Strategy:**
```sql
-- Partitioning (already applied in schema)
PARTITION BY DATE(order_date)  -- On orders table

-- Clustering (already applied)
CLUSTER BY customer_id, order_status  -- On orders table
```

**Key Differences:**
- **No traditional indexes**: Uses partitioning and clustering
- **Columnar storage**: Efficient for selective column reads
- **Automatic query optimization**: BigQuery optimizes joins and aggregations
- **Slot-based pricing**: Cost based on bytes processed

**Cost Optimization:**
```sql
-- Only process necessary partitions
WHERE DATE(order_date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR)

-- Avoid SELECT *; specify exact columns needed
```

**Materialized View:**
```sql
CREATE MATERIALIZED VIEW `project_id.globalshop_dataset.mv_customer_clv`
PARTITION BY DATE(last_order_date)
CLUSTER BY customer_segment, country
AS <query>;

-- Auto-refresh via scheduled queries or set refresh manually
```

**Estimated Cost:**
- Scans full orders and order_items tables (bytes processed = cost)
- Materialized view significantly reduces costs for repeated queries
- Partition pruning critical for cost control

## Query Results Schema

| Column | Type | Description |
|--------|------|-------------|
| customer_id | INT | Unique customer identifier |
| email | STRING | Customer email |
| full_name | STRING | Customer full name |
| country | STRING | Customer country |
| customer_segment | STRING | Current segment (Bronze/Silver/Gold/Platinum) |
| total_orders | INT | Total completed orders |
| total_revenue | DECIMAL | Lifetime revenue from customer |
| avg_order_value | DECIMAL | Average order amount |
| annualized_revenue | DECIMAL | Revenue normalized to yearly rate |
| customer_lifespan_days | INT | Days between first and last order |
| days_since_last_order | INT | Recency metric |
| customer_status | STRING | Active/New/Declining/At Risk |
| revenue_rank | INT | Rank by total revenue |
| revenue_decile | INT | Revenue decile (1=top 10%) |
| favorite_category | STRING | Most-purchased product category |
| favorite_category_spend | DECIMAL | Spending in favorite category |
| clv_score | DECIMAL | Composite CLV score |

## Use Cases
1. **Marketing Segmentation**: Target high CLV customers with premium offers
2. **Churn Prevention**: Identify "At Risk" customers for retention campaigns
3. **Product Recommendations**: Use favorite_category for personalization
4. **Revenue Forecasting**: Annualized revenue helps predict future income
5. **Customer Success**: Prioritize support for top revenue deciles
