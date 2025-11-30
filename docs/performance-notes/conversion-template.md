# Query Conversion Template

Use this template to convert the remaining T-SQL queries to PostgreSQL and BigQuery.

## Step-by-Step Conversion Process

### Phase 1: Read and Understand
1. Read the T-SQL query completely
2. Identify all CTEs, joins, and window functions
3. Note any T-SQL-specific functions (DATEADD, DATEDIFF, etc.)
4. List all table and column references

### Phase 2: Mechanical Conversion
Follow this checklist for both PostgreSQL and BigQuery:

#### Naming Conventions
- [ ] Table names: `Orders` → `orders` (PostgreSQL/BigQuery)
- [ ] Column names: `OrderID` → `order_id` (PostgreSQL/BigQuery)
- [ ] CTE names: `CustomerOrders` → `customer_orders` (PostgreSQL/BigQuery)

#### Table References
- [ ] T-SQL: `FROM Orders o`
- [ ] PostgreSQL: `FROM orders o`
- [ ] BigQuery: ``FROM `project_id.globalshop_dataset.orders` o``

### Phase 3: Function Conversions

Use this reference table:

| Operation | T-SQL | PostgreSQL | BigQuery |
|-----------|-------|------------|----------|
| **Concatenation** | `FirstName + ' ' + LastName` | `first_name || ' ' || last_name` | `CONCAT(first_name, ' ', last_name)` |
| **Add Days** | `DATEADD(DAY, 30, OrderDate)` | `order_date + INTERVAL '30 days'` | `DATE_ADD(order_date, INTERVAL 30 DAY)` |
| **Add Months** | `DATEADD(MONTH, 6, OrderDate)` | `order_date + INTERVAL '6 months'` | `DATE_ADD(order_date, INTERVAL 6 MONTH)` |
| **Days Between** | `DATEDIFF(DAY, StartDate, EndDate)` | `EXTRACT(DAY FROM (end_date - start_date))::INTEGER` | `DATE_DIFF(end_date, start_date, DAY)` |
| **Months Between** | `DATEDIFF(MONTH, StartDate, EndDate)` | `EXTRACT(YEAR FROM AGE(end_date, start_date)) * 12 + EXTRACT(MONTH FROM AGE(end_date, start_date))` | `DATE_DIFF(end_date, start_date, MONTH)` |
| **Current Date** | `GETDATE()` | `CURRENT_TIMESTAMP` or `CURRENT_DATE` | `CURRENT_TIMESTAMP()` or `CURRENT_DATE()` |
| **Date Truncate** | `DATEFROMPARTS(YEAR(x), MONTH(x), 1)` | `DATE_TRUNC('month', x)::DATE` | `DATE_TRUNC(x, MONTH)` |
| **Division Safe** | `TotalAmount / NULLIF(OrderCount, 0)` | `total_amount / NULLIF(order_count, 0)` | `SAFE_DIVIDE(total_amount, order_count)` |
| **Null Coalesce** | `ISNULL(column, default)` | `COALESCE(column, default)` | `IFNULL(column, default)` |
| **Format Date** | `FORMAT(date, 'yyyy-MM')` | `TO_CHAR(date, 'YYYY-MM')` | `FORMAT_DATE('%Y-%m', date)` |
| **Cast to Int** | `CAST(x AS INT)` | `CAST(x AS INTEGER)` or `x::INTEGER` | `CAST(x AS INT64)` |
| **Cast to String** | `CAST(x AS VARCHAR)` | `CAST(x AS VARCHAR)` or `x::VARCHAR` | `CAST(x AS STRING)` |
| **String Aggregate** | `STRING_AGG(x, ',')` | `STRING_AGG(x, ',')` | `STRING_AGG(x, ',')` |

### Phase 4: Platform-Specific Optimizations

#### PostgreSQL Additions
Add these comments and optimizations:

```sql
-- At the end of complex analytical queries:
-- Performance optimization: Create materialized view for frequent access
-- CREATE MATERIALIZED VIEW mv_<query_name> AS
-- <full query>
-- CREATE INDEX idx_mv_<key_column> ON mv_<query_name>(<key_column>);
-- REFRESH: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_<query_name>;
```

#### BigQuery Additions
Add these optimization notes:

```sql
-- =====================================================
-- BigQuery Optimization: Create a scheduled materialized view
-- =====================================================
-- CREATE MATERIALIZED VIEW `project_id.globalshop_dataset.mv_<name>`
-- PARTITION BY DATE(<date_column>)
-- CLUSTER BY <filter_column1>, <filter_column2>
-- AS <query above>
--
-- Schedule refresh: Use BigQuery scheduled queries or Data Transfer Service
```

## Example: Query 4 Conversion (Cohort Retention)

### Original T-SQL Fragment
```sql
WITH CustomerCohorts AS (
    SELECT
        c.CustomerID,
        c.Email,
        DATEFROMPARTS(YEAR(c.RegistrationDate), MONTH(c.RegistrationDate), 1) AS CohortMonth,
        c.RegistrationDate
    FROM Customers c
    WHERE c.IsActive = 1
        AND c.RegistrationDate >= DATEADD(MONTH, -24, GETDATE())
)
```

### PostgreSQL Conversion
```sql
WITH customer_cohorts AS (
    SELECT
        c.customer_id,
        c.email,
        DATE_TRUNC('month', c.registration_date)::DATE AS cohort_month,
        c.registration_date
    FROM customers c
    WHERE c.is_active = TRUE
        AND c.registration_date >= CURRENT_DATE - INTERVAL '24 months'
)
```

### BigQuery Conversion
```sql
WITH customer_cohorts AS (
    SELECT
        c.customer_id,
        c.email,
        DATE_TRUNC(c.registration_date, MONTH) AS cohort_month,
        c.registration_date
    FROM `project_id.globalshop_dataset.customers` c
    WHERE c.is_active = TRUE
        AND c.registration_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 24 MONTH)
)
```

## Common Patterns

### Pattern 1: Date-Based Filtering

```sql
-- T-SQL
WHERE OrderDate >= DATEADD(MONTH, -6, GETDATE())

-- PostgreSQL
WHERE order_date >= CURRENT_DATE - INTERVAL '6 months'

-- BigQuery
WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH)
-- OR for TIMESTAMP:
WHERE order_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 MONTH)
```

### Pattern 2: Conditional Aggregation

```sql
-- T-SQL
SUM(CASE WHEN OrderStatus = 'Delivered' THEN TotalAmount ELSE 0 END) AS DeliveredRevenue

-- PostgreSQL (same)
SUM(CASE WHEN order_status = 'Delivered' THEN total_amount ELSE 0 END) AS delivered_revenue

-- BigQuery (same)
SUM(CASE WHEN order_status = 'Delivered' THEN total_amount ELSE 0 END) AS delivered_revenue
```

### Pattern 3: Window Functions with Partition

```sql
-- T-SQL
ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY OrderDate DESC) AS RowNum

-- PostgreSQL
ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS row_num

-- BigQuery (same as PostgreSQL)
ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS row_num
```

### Pattern 4: String Aggregation

```sql
-- T-SQL
STRING_AGG(ProductName, ', ') WITHIN GROUP (ORDER BY ProductName) AS Products

-- PostgreSQL
STRING_AGG(product_name, ', ' ORDER BY product_name) AS products

-- BigQuery
STRING_AGG(product_name, ', ' ORDER BY product_name) AS products
```

### Pattern 5: NTILE (Percentiles)

```sql
-- T-SQL
NTILE(10) OVER (ORDER BY TotalRevenue DESC) AS RevenueDecile

-- PostgreSQL (same)
NTILE(10) OVER (ORDER BY total_revenue DESC) AS revenue_decile

-- BigQuery (same)
NTILE(10) OVER (ORDER BY total_revenue DESC) AS revenue_decile
```

## Testing Your Conversion

### 1. Syntax Validation

**PostgreSQL:**
```sql
-- Check syntax without executing
EXPLAIN <your query>;
```

**BigQuery:**
```bash
# Dry run to validate syntax and estimate cost
bq query --dry_run '<your query>'
```

### 2. Result Comparison

After running on all platforms, compare:
- Row counts should match
- Aggregated values should match (within rounding)
- Sorting order should be consistent

### 3. Performance Check

**PostgreSQL:**
```sql
EXPLAIN (ANALYZE, BUFFERS) <your query>;
```

**BigQuery:**
```bash
# Check bytes processed
bq query --dry_run '<your query>'
# Expected: < 1 TB per query with proper partitioning
```

## Conversion Workflow

For each remaining query (4, 6, 7, 9, 10):

### Step 1: Create Files
```bash
# PostgreSQL
touch queries/<query-name>/postgresql/query.sql

# BigQuery
touch queries/<query-name>/bigquery/query.sql
```

### Step 2: Copy and Modify

1. Copy the T-SQL query to PostgreSQL file
2. Use Find/Replace for common patterns:
   - Find: `([A-Z][a-z]+)([A-Z])` Replace: `\l\1_\l\2` (PascalCase → snake_case)
   - Find: `GETDATE()` Replace: `CURRENT_TIMESTAMP`
   - Find: `DATEADD` Replace: `+ INTERVAL`
   - Find: `DATEDIFF(DAY,` Replace: `DATE_DIFF(`
3. Manually fix complex expressions
4. Add PostgreSQL-specific optimizations

5. Copy PostgreSQL version to BigQuery file
6. Update table references to `` `project_id.dataset.table` ``
7. Replace PostgreSQL-specific syntax with BigQuery equivalents
8. Add partitioning/clustering comments

### Step 3: Test
```bash
# PostgreSQL
psql globalshop_db -f queries/<query-name>/postgresql/query.sql

# BigQuery
bq query --dry_run "$(cat queries/<query-name>/bigquery/query.sql)"
```

### Step 4: Document

Create `queries/<query-name>/README.md`:

```markdown
# Query <N>: <Name>

## Business Objective
<What business problem does this solve?>

## Query Complexity
<List CTEs, window functions, joins, etc.>

## Syntax Differences

### <Function Category>
- **T-SQL**: <example>
- **PostgreSQL**: <example>
- **BigQuery**: <example>

## Performance Considerations

### T-SQL (SQL Server)
**Indexing Strategy:**
<recommended indexes>

### PostgreSQL
**Optimization:**
<materialized view or index recommendations>

### BigQuery
**Optimization Strategy:**
<partitioning and clustering>
```

## Quick Reference Card

Keep this handy while converting:

```
Naming:           PascalCase  →  snake_case
Tables (BQ):      TableName   →  `project_id.dataset.table_name`
GETDATE():        →  CURRENT_TIMESTAMP (PG/BQ)
DATEADD():        →  + INTERVAL (PG) / DATE_ADD() (BQ)
DATEDIFF():       →  EXTRACT/AGE (PG) / DATE_DIFF() (BQ)
ISNULL():         →  COALESCE() (PG) / IFNULL() (BQ)
Concat (+):       →  || (PG) / CONCAT() (BQ)
BIT:              →  BOOLEAN (PG) / BOOL (BQ)
VARCHAR:          →  VARCHAR (PG) / STRING (BQ)
INT:              →  INTEGER (PG) / INT64 (BQ)
DECIMAL(p,s):     →  NUMERIC(p,s) (both)
Division (/):     →  same (PG) / SAFE_DIVIDE() (BQ)
```

## Remaining Queries to Convert

- [ ] Query 4: Cohort Retention Analysis
  - **Complexity**: Medium (DATEDIFF for month calculations)
  - **Key Challenge**: Month difference calculation between dates
  - **Estimated Time**: 30 minutes per platform

- [ ] Query 6: Supplier Performance
  - **Complexity**: Low (straightforward aggregations)
  - **Key Challenge**: None major
  - **Estimated Time**: 20 minutes per platform

- [ ] Query 7: Revenue Trend Forecasting
  - **Complexity**: Medium (LAG/LEAD, date truncation)
  - **Key Challenge**: Date truncation and FORMAT
  - **Estimated Time**: 30 minutes per platform

- [ ] Query 9: Order Fulfillment Analytics
  - **Complexity**: Medium (time calculations, semicolon CTE)
  - **Key Challenge**: Remove semicolon before WITH, time arithmetic
  - **Estimated Time**: 30 minutes per platform

- [ ] Query 10: Price Optimization
  - **Complexity**: High (LEAD for price changes, nested subqueries)
  - **Key Challenge**: Scalar subqueries in SELECT, LEAD window function
  - **Estimated Time**: 45 minutes per platform

**Total Estimated Time**:
- PostgreSQL: ~3 hours
- BigQuery: ~3 hours
- **Total: ~6 hours to complete all remaining conversions**

## Tips for Success

1. **Convert one query at a time** - Don't try to do all at once
2. **Test frequently** - Run syntax checks after each major change
3. **Use EXPLAIN** - Verify query plans on both platforms
4. **Document as you go** - Create README files immediately
5. **Compare results** - Ensure output matches across platforms
6. **Ask for help** - Reference the migration guide liberally

## Common Mistakes to Avoid

❌ Forgetting to change table names to snake_case
❌ Missing `` `backticks` `` in BigQuery table references
❌ Using DATEDIFF incorrectly (argument order differs)
❌ Forgetting to replace ISNULL with COALESCE/IFNULL
❌ Not adding project_id to BigQuery tables
❌ Keeping IDENTITY in PostgreSQL (use SERIAL)
❌ Using INT instead of INT64 in BigQuery
❌ Forgetting to update column names in ORDER BY, GROUP BY

## Final Checklist

Before considering a conversion complete:

- [ ] Query executes without syntax errors
- [ ] Column names follow snake_case convention
- [ ] Table references are correct for platform
- [ ] All date functions are converted
- [ ] String concatenation uses correct syntax
- [ ] Division operations handle null/zero safely
- [ ] Window functions use correct syntax
- [ ] Data types are platform-appropriate
- [ ] Comments explain platform-specific optimizations
- [ ] README.md documents key differences
- [ ] Query has been tested with sample data

---

**You've got this! The patterns repeat, so each query gets faster to convert. Good luck! 🚀**
