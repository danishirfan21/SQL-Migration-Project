# Complete SQL Migration Guide: T-SQL → PostgreSQL → BigQuery

## Table of Contents
1. [Data Type Mapping](#data-type-mapping)
2. [Syntax Differences](#syntax-differences)
3. [Function Equivalents](#function-equivalents)
4. [Performance Optimization](#performance-optimization)
5. [Common Pitfalls](#common-pitfalls)
6. [Migration Checklist](#migration-checklist)

## Data Type Mapping

### Numeric Types

| T-SQL | PostgreSQL | BigQuery | Notes |
|-------|------------|----------|-------|
| `INT`, `INTEGER` | `INTEGER`, `INT` | `INT64` | BigQuery uses 64-bit by default |
| `BIGINT` | `BIGINT` | `INT64` | |
| `SMALLINT` | `SMALLINT` | `INT64` | BigQuery has no small int |
| `TINYINT` | `SMALLINT` | `INT64` | PostgreSQL min is SMALLINT |
| `DECIMAL(p,s)` | `DECIMAL(p,s)`, `NUMERIC(p,s)` | `NUMERIC(p,s)` | BigQuery: max p=38, s=9 |
| `MONEY` | `MONEY` | `NUMERIC(19,4)` | Use NUMERIC in BigQuery |
| `FLOAT` | `DOUBLE PRECISION` | `FLOAT64` | |
| `REAL` | `REAL` | `FLOAT64` | |

### String Types

| T-SQL | PostgreSQL | BigQuery | Notes |
|-------|------------|----------|-------|
| `VARCHAR(n)` | `VARCHAR(n)` | `STRING` | BigQuery STRING is unlimited |
| `CHAR(n)` | `CHAR(n)` | `STRING` | |
| `NVARCHAR(n)` | `VARCHAR(n)` | `STRING` | PostgreSQL is UTF-8 by default |
| `TEXT` | `TEXT` | `STRING` | |

### Date/Time Types

| T-SQL | PostgreSQL | BigQuery | Notes |
|-------|------------|----------|-------|
| `DATE` | `DATE` | `DATE` | |
| `DATETIME` | `TIMESTAMP` | `DATETIME` | |
| `DATETIME2` | `TIMESTAMP` | `DATETIME` | Higher precision |
| `TIME` | `TIME` | `TIME` | |
| `DATETIMEOFFSET` | `TIMESTAMP WITH TIME ZONE` | `TIMESTAMP` | BigQuery stores UTC |

### Boolean Types

| T-SQL | PostgreSQL | BigQuery | Notes |
|-------|------------|----------|-------|
| `BIT` | `BOOLEAN` | `BOOL` | T-SQL: 1/0, others: TRUE/FALSE |

## Syntax Differences

### 1. String Concatenation

```sql
-- T-SQL
SELECT FirstName + ' ' + LastName AS FullName

-- PostgreSQL
SELECT first_name || ' ' || last_name AS full_name
-- OR
SELECT CONCAT(first_name, ' ', last_name) AS full_name

-- BigQuery
SELECT CONCAT(first_name, ' ', last_name) AS full_name
```

### 2. Date Arithmetic

```sql
-- T-SQL: Add days
SELECT DATEADD(DAY, 30, OrderDate)
SELECT DATEDIFF(DAY, StartDate, EndDate)

-- PostgreSQL: Add days
SELECT order_date + INTERVAL '30 days'
SELECT EXTRACT(DAY FROM (end_date - start_date))
-- OR for total days:
SELECT DATE_PART('day', end_date - start_date)::INTEGER

-- BigQuery: Add days
SELECT DATE_ADD(order_date, INTERVAL 30 DAY)
SELECT DATE_DIFF(end_date, start_date, DAY)
```

### 3. Current Date/Time

```sql
-- T-SQL
SELECT GETDATE()          -- Returns DATETIME
SELECT SYSDATETIME()      -- Returns DATETIME2
SELECT GETUTCDATE()       -- Returns UTC

-- PostgreSQL
SELECT CURRENT_TIMESTAMP  -- Returns TIMESTAMP WITH TIME ZONE
SELECT NOW()              -- Same as CURRENT_TIMESTAMP
SELECT CURRENT_DATE       -- Returns DATE only

-- BigQuery
SELECT CURRENT_TIMESTAMP()
SELECT CURRENT_DATE()
SELECT CURRENT_DATETIME()
```

### 4. NULL Handling

```sql
-- T-SQL
SELECT ISNULL(column_name, 'default')
SELECT COALESCE(col1, col2, 'default')

-- PostgreSQL
SELECT COALESCE(column_name, 'default')

-- BigQuery
SELECT IFNULL(column_name, 'default')
SELECT COALESCE(column_name, 'default')
```

### 5. Division by Zero

```sql
-- T-SQL
SELECT TotalRevenue / NULLIF(TotalOrders, 0)

-- PostgreSQL
SELECT total_revenue / NULLIF(total_orders, 0)

-- BigQuery
SELECT SAFE_DIVIDE(total_revenue, total_orders)
-- Returns NULL if division by zero
```

### 6. TOP / LIMIT

```sql
-- T-SQL
SELECT TOP 10 * FROM Orders ORDER BY OrderDate DESC

-- PostgreSQL
SELECT * FROM orders ORDER BY order_date DESC LIMIT 10

-- BigQuery
SELECT * FROM orders ORDER BY order_date DESC LIMIT 10
```

### 7. Auto-Increment Columns

```sql
-- T-SQL
CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    ...
);

-- PostgreSQL
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    ...
);
-- OR (PostgreSQL 10+)
CREATE TABLE customers (
    customer_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ...
);

-- BigQuery
-- No native auto-increment
-- Use ROW_NUMBER() or generate IDs in application layer
```

### 8. IF/CASE Statements

```sql
-- T-SQL: IF in procedures
IF @variable > 10
    SELECT 'High'
ELSE
    SELECT 'Low'

-- T-SQL: IIF function (SQL Server 2012+)
SELECT IIF(Quantity > 100, 'Bulk', 'Standard')

-- PostgreSQL: CASE
SELECT CASE WHEN quantity > 100 THEN 'Bulk' ELSE 'Standard' END

-- BigQuery: IF
SELECT IF(quantity > 100, 'Bulk', 'Standard')
-- OR CASE
SELECT CASE WHEN quantity > 100 THEN 'Bulk' ELSE 'Standard' END
```

### 9. String Aggregation

```sql
-- T-SQL (SQL Server 2017+)
SELECT STRING_AGG(product_name, ', ') WITHIN GROUP (ORDER BY product_name)

-- PostgreSQL
SELECT STRING_AGG(product_name, ', ' ORDER BY product_name)

-- BigQuery
SELECT STRING_AGG(product_name, ', ' ORDER BY product_name)
```

### 10. Window Functions

```sql
-- All platforms support similar syntax

-- T-SQL / PostgreSQL / BigQuery
SELECT
    customer_id,
    order_date,
    total_amount,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn,
    RANK() OVER (ORDER BY total_amount DESC) AS revenue_rank,
    LAG(total_amount) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order,
    SUM(total_amount) OVER (PARTITION BY customer_id) AS customer_total
FROM orders
```

## Function Equivalents

### String Functions

| Operation | T-SQL | PostgreSQL | BigQuery |
|-----------|-------|------------|----------|
| Length | `LEN(str)` | `LENGTH(str)` or `CHAR_LENGTH(str)` | `LENGTH(str)` |
| Substring | `SUBSTRING(str, start, len)` | `SUBSTRING(str, start, len)` | `SUBSTR(str, start, len)` |
| Upper | `UPPER(str)` | `UPPER(str)` | `UPPER(str)` |
| Lower | `LOWER(str)` | `LOWER(str)` | `LOWER(str)` |
| Trim | `LTRIM(RTRIM(str))` | `TRIM(str)` | `TRIM(str)` |
| Replace | `REPLACE(str, old, new)` | `REPLACE(str, old, new)` | `REPLACE(str, old, new)` |
| Position | `CHARINDEX(substr, str)` | `POSITION(substr IN str)` | `STRPOS(str, substr)` |

### Math Functions

| Operation | T-SQL | PostgreSQL | BigQuery |
|-----------|-------|------------|----------|
| Round | `ROUND(n, decimals)` | `ROUND(n, decimals)` | `ROUND(n, decimals)` |
| Ceiling | `CEILING(n)` | `CEILING(n)` or `CEIL(n)` | `CEIL(n)` |
| Floor | `FLOOR(n)` | `FLOOR(n)` | `FLOOR(n)` |
| Absolute | `ABS(n)` | `ABS(n)` | `ABS(n)` |
| Power | `POWER(n, exp)` | `POWER(n, exp)` | `POW(n, exp)` |

### Conversion Functions

| Operation | T-SQL | PostgreSQL | BigQuery |
|-----------|-------|------------|----------|
| To String | `CAST(n AS VARCHAR)` or `CONVERT(VARCHAR, n)` | `CAST(n AS VARCHAR)` or `n::VARCHAR` | `CAST(n AS STRING)` |
| To Integer | `CAST(str AS INT)` | `CAST(str AS INTEGER)` or `str::INTEGER` | `CAST(str AS INT64)` |
| To Decimal | `CAST(n AS DECIMAL(10,2))` | `CAST(n AS NUMERIC(10,2))` | `CAST(n AS NUMERIC)` |
| Format | `FORMAT(date, 'yyyy-MM-dd')` | `TO_CHAR(date, 'YYYY-MM-DD')` | `FORMAT_DATE('%Y-%m-%d', date)` |

## Performance Optimization

### T-SQL (SQL Server)

#### Indexing Strategy
```sql
-- Nonclustered index with INCLUDE
CREATE NONCLUSTERED INDEX IX_Orders_Customer_Date
ON Orders(CustomerID, OrderDate DESC)
INCLUDE (TotalAmount, OrderStatus);

-- Filtered index
CREATE INDEX IX_Orders_Active
ON Orders(OrderDate)
WHERE OrderStatus NOT IN ('Cancelled', 'Returned');

-- Columnstore index for analytics
CREATE COLUMNSTORE INDEX NCCI_Orders
ON Orders;
```

#### Query Hints
```sql
-- Limit parallelism
SELECT * FROM Orders
OPTION (MAXDOP 4);

-- Force index usage
SELECT * FROM Orders WITH (INDEX(IX_Orders_Customer_Date))
WHERE CustomerID = 123;

-- Read uncommitted (use cautiously)
SELECT * FROM Orders WITH (NOLOCK);
```

#### Statistics
```sql
-- Update statistics
UPDATE STATISTICS Orders;

-- Rebuild index
ALTER INDEX IX_Orders_Customer_Date ON Orders REBUILD;
```

### PostgreSQL

#### Indexing Strategy
```sql
-- B-tree index (default)
CREATE INDEX idx_orders_customer_date
ON orders(customer_id, order_date DESC);

-- Partial index (like SQL Server filtered index)
CREATE INDEX idx_orders_active
ON orders(order_date)
WHERE order_status NOT IN ('Cancelled', 'Returned');

-- Covering index (INCLUDE equivalent)
CREATE INDEX idx_orders_customer_date
ON orders(customer_id, order_date)
INCLUDE (total_amount, order_status);

-- GIN index for full-text search
CREATE INDEX idx_products_name_gin
ON products USING GIN(to_tsvector('english', product_name));
```

#### Materialized Views
```sql
-- Create materialized view
CREATE MATERIALIZED VIEW mv_customer_metrics AS
SELECT customer_id, SUM(total_amount) AS total_revenue
FROM orders
GROUP BY customer_id;

-- Create index on materialized view
CREATE INDEX idx_mv_customer_metrics_revenue
ON mv_customer_metrics(total_revenue DESC);

-- Refresh materialized view
REFRESH MATERIALIZED VIEW mv_customer_metrics;

-- Concurrent refresh (allows reads during refresh)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_metrics;
```

#### Configuration Tuning
```sql
-- Increase work memory for sorting/aggregation
SET work_mem = '256MB';

-- Enable parallel query execution
SET max_parallel_workers_per_gather = 4;

-- View query plan
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE customer_id = 123;
```

### BigQuery

#### Partitioning
```sql
-- Partition by date
CREATE TABLE `project.dataset.orders`
(
    order_id INT64,
    order_date DATE,
    customer_id INT64,
    total_amount NUMERIC
)
PARTITION BY order_date
OPTIONS(
    partition_expiration_days=730,  -- Auto-delete after 2 years
    require_partition_filter=true   -- Force partition filter in queries
);

-- Integer range partitioning
CREATE TABLE `project.dataset.products`
(
    product_id INT64,
    category STRING
)
PARTITION BY RANGE_BUCKET(product_id, GENERATE_ARRAY(0, 100000, 1000));
```

#### Clustering
```sql
-- Cluster by multiple columns (up to 4)
CREATE TABLE `project.dataset.orders`
(
    order_id INT64,
    customer_id INT64,
    order_date DATE,
    country STRING
)
PARTITION BY DATE(order_date)
CLUSTER BY customer_id, country;
```

#### Cost Optimization
```sql
-- BAD: Scans entire table
SELECT * FROM `project.dataset.orders`;

-- GOOD: Uses partition pruning
SELECT * FROM `project.dataset.orders`
WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31';

-- GOOD: Select only needed columns
SELECT order_id, total_amount FROM `project.dataset.orders`
WHERE order_date >= '2024-01-01';

-- GOOD: Use clustering columns in WHERE
SELECT * FROM `project.dataset.orders`
WHERE customer_id = 12345
  AND order_date >= '2024-01-01';
```

#### Approximate Aggregations (faster, cheaper)
```sql
-- Exact count (expensive)
SELECT COUNT(DISTINCT customer_id) FROM orders;

-- Approximate count (much faster and cheaper)
SELECT APPROX_COUNT_DISTINCT(customer_id) FROM orders;

-- Approximate quantiles
SELECT APPROX_QUANTILES(total_amount, 100)[OFFSET(50)] AS median
FROM orders;
```

## Common Pitfalls

### 1. Case Sensitivity

```sql
-- T-SQL: Case-insensitive by default (depends on collation)
WHERE product_name = 'laptop'  -- Matches 'Laptop', 'LAPTOP'

-- PostgreSQL: Case-sensitive by default
WHERE product_name = 'laptop'  -- Only matches 'laptop'
WHERE LOWER(product_name) = 'laptop'  -- Case-insensitive

-- BigQuery: Case-sensitive
WHERE product_name = 'laptop'  -- Only matches 'laptop'
WHERE LOWER(product_name) = 'laptop'  -- Case-insensitive
```

### 2. Empty String vs NULL

```sql
-- T-SQL: '' and NULL are different
WHERE column_name = ''     -- Matches empty string
WHERE column_name IS NULL  -- Matches NULL

-- PostgreSQL: Same as T-SQL

-- BigQuery: Same as T-SQL
```

### 3. Integer Division

```sql
-- T-SQL
SELECT 5 / 2           -- Returns 2 (integer division)
SELECT 5 / 2.0         -- Returns 2.5 (decimal division)
SELECT CAST(5 AS FLOAT) / 2  -- Returns 2.5

-- PostgreSQL
SELECT 5 / 2           -- Returns 2 (integer division)
SELECT 5 / 2.0         -- Returns 2.5
SELECT 5::FLOAT / 2    -- Returns 2.5

-- BigQuery
SELECT 5 / 2           -- Returns 2.5 (always decimal)
SELECT DIV(5, 2)       -- Returns 2 (integer division)
```

### 4. Boolean Logic

```sql
-- T-SQL: Uses BIT (1/0)
WHERE is_active = 1
WHERE is_active = 0

-- PostgreSQL: Uses BOOLEAN
WHERE is_active = TRUE
WHERE is_active = FALSE
WHERE is_active  -- Shorthand for = TRUE

-- BigQuery: Uses BOOL
WHERE is_active = TRUE
WHERE is_active IS TRUE  -- More explicit
```

### 5. String Escape Characters

```sql
-- T-SQL: Use '' to escape single quote
SELECT 'It''s working'

-- PostgreSQL: Use '' or escape with E
SELECT 'It''s working'
SELECT E'It\'s working'

-- BigQuery: Use '' or \"
SELECT 'It''s working'
SELECT "It's working"  -- Double quotes for strings
```

## Migration Checklist

### Pre-Migration
- [ ] Document current schema and data types
- [ ] Identify T-SQL-specific features (stored procedures, triggers, functions)
- [ ] Analyze query patterns and performance requirements
- [ ] Determine target platform (PostgreSQL, BigQuery, or both)
- [ ] Set up development and testing environments

### Schema Migration
- [ ] Map data types using conversion tables
- [ ] Convert IDENTITY to SERIAL (PostgreSQL) or remove (BigQuery)
- [ ] Update indexes for target platform
- [ ] Modify constraints and default values
- [ ] Convert computed columns
- [ ] Handle temporal tables (if applicable)

### Query Migration
- [ ] Replace T-SQL-specific functions
- [ ] Update date arithmetic operations
- [ ] Convert string concatenation syntax
- [ ] Modify TOP to LIMIT
- [ ] Update variable declarations (for stored procedures)
- [ ] Handle NULL comparison differences
- [ ] Test window function behavior

### Performance Tuning
- [ ] Create appropriate indexes (B-tree for PostgreSQL, clustering for BigQuery)
- [ ] Set up partitioning (especially for BigQuery)
- [ ] Create materialized views (PostgreSQL)
- [ ] Optimize join strategies
- [ ] Update statistics collection
- [ ] Test query execution plans

### Testing
- [ ] Compare query results between platforms
- [ ] Validate data type conversions
- [ ] Test edge cases (NULL, empty strings, division by zero)
- [ ] Performance benchmark critical queries
- [ ] Verify data integrity

### Post-Migration
- [ ] Document platform-specific optimizations
- [ ] Create maintenance procedures
- [ ] Set up monitoring and alerting
- [ ] Train team on new platform features
- [ ] Plan for ongoing optimization

## Resources

- **T-SQL**: [Microsoft SQL Server Documentation](https://docs.microsoft.com/sql/)
- **PostgreSQL**: [PostgreSQL Manual](https://www.postgresql.org/docs/)
- **BigQuery**: [BigQuery Documentation](https://cloud.google.com/bigquery/docs)

## Summary

Migrating between SQL platforms requires understanding:
1. **Syntax differences** in basic operations
2. **Data type mappings** and limitations
3. **Performance optimization** techniques unique to each platform
4. **Cost implications** (especially for cloud-based BigQuery)
5. **Feature availability** across platforms

This guide covers the most common scenarios, but always test thoroughly and consult platform-specific documentation for edge cases.
