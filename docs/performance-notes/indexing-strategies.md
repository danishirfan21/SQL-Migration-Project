# Indexing Strategies Across Platforms

## Table of Contents
1. [General Principles](#general-principles)
2. [T-SQL (SQL Server) Indexing](#t-sql-sql-server-indexing)
3. [PostgreSQL Indexing](#postgresql-indexing)
4. [BigQuery Optimization](#bigquery-optimization)
5. [Query-Specific Recommendations](#query-specific-recommendations)

## General Principles

### When to Index
- ✅ Columns used in WHERE clauses frequently
- ✅ Columns used in JOIN conditions
- ✅ Columns used in ORDER BY
- ✅ Foreign key columns
- ✅ Columns with high selectivity (many unique values)

### When NOT to Index
- ❌ Small tables (< 1,000 rows)
- ❌ Columns with low selectivity (few unique values)
- ❌ Columns updated very frequently
- ❌ Tables with heavy INSERT/UPDATE operations
- ❌ Wide columns (TEXT, VARCHAR(MAX), etc.)

## T-SQL (SQL Server) Indexing

### 1. Clustered Index

**Rule**: One per table, determines physical order

```sql
-- Primary key is clustered by default
CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    CustomerID INT NOT NULL,
    OrderDate DATETIME2 NOT NULL
);

-- Explicit clustered index on date (for time-series data)
CREATE CLUSTERED INDEX IX_Orders_OrderDate
ON Orders(OrderDate);
```

**Best Practices**:
- Use on sequential values (IDENTITY, dates)
- Avoid on GUIDs (causes fragmentation)
- Keep clustered key narrow (4-8 bytes ideal)

### 2. Nonclustered Index

```sql
-- Basic nonclustered index
CREATE NONCLUSTERED INDEX IX_Orders_Customer
ON Orders(CustomerID);

-- Composite index (column order matters!)
CREATE NONCLUSTERED INDEX IX_Orders_Customer_Date
ON Orders(CustomerID, OrderDate DESC);

-- Include columns (covering index)
CREATE NONCLUSTERED INDEX IX_Orders_Customer_Date_Covering
ON Orders(CustomerID, OrderDate DESC)
INCLUDE (TotalAmount, OrderStatus);
```

**INCLUDE Columns**:
- Adds columns to index leaf level only
- Query can be satisfied entirely from index (index seek + no key lookup)
- Don't index these columns, just include them

### 3. Filtered Index

```sql
-- Index only active orders
CREATE NONCLUSTERED INDEX IX_Orders_Active
ON Orders(OrderDate)
WHERE OrderStatus NOT IN ('Cancelled', 'Returned');

-- Index only high-value orders
CREATE NONCLUSTERED INDEX IX_Orders_HighValue
ON Orders(CustomerID, OrderDate)
INCLUDE (TotalAmount)
WHERE TotalAmount > 1000;
```

**Benefits**:
- Smaller index size
- Lower maintenance cost
- Better selectivity

### 4. Columnstore Index

```sql
-- Nonclustered columnstore (for analytics on OLTP table)
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Orders
ON Orders (OrderID, CustomerID, OrderDate, TotalAmount, OrderStatus);

-- Clustered columnstore (for data warehouse tables)
CREATE CLUSTERED COLUMNSTORE INDEX CCI_OrderHistory
ON OrderHistory;
```

**When to Use**:
- Tables > 1 million rows
- Analytical queries with aggregations
- Minimal updates (batch inserts preferred)
- Can coexist with rowstore indexes

### 5. Full-Text Index

```sql
-- Enable full-text search
CREATE FULLTEXT CATALOG ft_catalog;

CREATE FULLTEXT INDEX ON Products(ProductName, Description)
KEY INDEX PK_Products
ON ft_catalog;

-- Query
SELECT * FROM Products
WHERE CONTAINS(ProductName, 'laptop OR notebook');
```

### Recommended Indexes for E-Commerce Schema

```sql
-- Customers
CREATE NONCLUSTERED INDEX IX_Customers_Email ON Customers(Email);
CREATE NONCLUSTERED INDEX IX_Customers_Segment ON Customers(CustomerSegment)
    INCLUDE (Country) WHERE IsActive = 1;

-- Orders
CREATE NONCLUSTERED INDEX IX_Orders_Customer_Date ON Orders(CustomerID, OrderDate DESC)
    INCLUDE (TotalAmount, OrderStatus);
CREATE NONCLUSTERED INDEX IX_Orders_Date_Status ON Orders(OrderDate, OrderStatus)
    INCLUDE (CustomerID, TotalAmount);
CREATE NONCLUSTERED INDEX IX_Orders_Status ON Orders(OrderStatus)
    WHERE OrderStatus IN ('Pending', 'Processing');

-- OrderItems
CREATE NONCLUSTERED INDEX IX_OrderItems_Product ON OrderItems(ProductID)
    INCLUDE (OrderID, Quantity, LineTotal);
CREATE NONCLUSTERED INDEX IX_OrderItems_Order_Product ON OrderItems(OrderID, ProductID);

-- Products
CREATE NONCLUSTERED INDEX IX_Products_Category ON Products(Category, SubCategory)
    WHERE IsActive = 1;
CREATE NONCLUSTERED INDEX IX_Products_Supplier ON Products(SupplierID)
    INCLUDE (ProductName, CurrentPrice);

-- Inventory
CREATE NONCLUSTERED INDEX IX_Inventory_Product ON Inventory(ProductID);
CREATE NONCLUSTERED INDEX IX_Inventory_LowStock ON Inventory(ProductID, WarehouseLocation)
    WHERE QuantityOnHand <= ReorderLevel;
```

### Maintenance

```sql
-- Check index fragmentation
SELECT
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.avg_fragmentation_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
    AND ips.page_count > 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- Rebuild index (> 30% fragmentation)
ALTER INDEX IX_Orders_Customer_Date ON Orders REBUILD;

-- Reorganize index (10-30% fragmentation)
ALTER INDEX IX_Orders_Customer_Date ON Orders REORGANIZE;

-- Update statistics
UPDATE STATISTICS Orders;
```

## PostgreSQL Indexing

### 1. B-tree Index (Default)

```sql
-- Basic index
CREATE INDEX idx_orders_customer ON orders(customer_id);

-- Composite index
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date DESC);

-- Covering index (INCLUDE, PostgreSQL 11+)
CREATE INDEX idx_orders_customer_date_covering
ON orders(customer_id, order_date)
INCLUDE (total_amount, order_status);

-- Expression index
CREATE INDEX idx_customers_lower_email ON customers(LOWER(email));

-- Partial index (like SQL Server filtered index)
CREATE INDEX idx_orders_active ON orders(order_date)
WHERE order_status NOT IN ('Cancelled', 'Returned');
```

### 2. Hash Index

```sql
-- Hash index (equality comparisons only, no range queries)
CREATE INDEX idx_customers_email_hash ON customers USING HASH(email);
```

**When to Use**:
- Only equality comparisons (WHERE email = 'x')
- NOT for range queries (>, <, BETWEEN)
- Generally B-tree is preferred

### 3. GIN Index (Generalized Inverted Index)

```sql
-- Full-text search
CREATE INDEX idx_products_name_gin
ON products USING GIN(to_tsvector('english', product_name));

-- Array columns
CREATE INDEX idx_tags_gin ON products USING GIN(tags);

-- JSONB columns
CREATE INDEX idx_metadata_gin ON products USING GIN(metadata);

-- Query usage
SELECT * FROM products
WHERE to_tsvector('english', product_name) @@ to_tsquery('laptop & computer');
```

### 4. GiST Index (Generalized Search Tree)

```sql
-- Geometric data
CREATE INDEX idx_locations_gist ON warehouses USING GIST(location);

-- Range types
CREATE INDEX idx_price_ranges_gist ON promotions USING GIST(price_range);

-- Full-text search (alternative to GIN)
CREATE INDEX idx_products_name_gist
ON products USING GIST(to_tsvector('english', product_name));
```

### 5. BRIN Index (Block Range Index)

```sql
-- For very large tables with natural ordering
CREATE INDEX idx_orders_date_brin ON orders USING BRIN(order_date);
```

**When to Use**:
- Very large tables (100M+ rows)
- Naturally ordered data (timestamps, IDs)
- Much smaller than B-tree
- Lower precision, but fast for range scans

### Recommended Indexes for E-Commerce Schema

```sql
-- Customers
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_segment ON customers(customer_segment)
    INCLUDE (country) WHERE is_active = TRUE;
CREATE INDEX idx_customers_reg_date ON customers(registration_date);

-- Orders
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date DESC)
    INCLUDE (total_amount, order_status);
CREATE INDEX idx_orders_date_status ON orders(order_date, order_status);
CREATE INDEX idx_orders_date_brin ON orders USING BRIN(order_date);  -- If very large

-- OrderItems
CREATE INDEX idx_order_items_product ON order_items(product_id)
    INCLUDE (order_id, quantity, line_total);
CREATE INDEX idx_order_items_order ON order_items(order_id);

-- Products
CREATE INDEX idx_products_category ON products(category, sub_category)
    WHERE is_active = TRUE;
CREATE INDEX idx_products_name_gin ON products
    USING GIN(to_tsvector('english', product_name));

-- Inventory
CREATE INDEX idx_inventory_product ON inventory(product_id);
CREATE INDEX idx_inventory_low_stock ON inventory(product_id)
    WHERE quantity_on_hand <= reorder_level;
```

### Maintenance

```sql
-- Analyze table (update statistics)
ANALYZE orders;

-- Vacuum and analyze
VACUUM ANALYZE orders;

-- Reindex specific index
REINDEX INDEX idx_orders_customer_date;

-- Reindex table
REINDEX TABLE orders;

-- Check index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC;

-- Find unused indexes
SELECT
    schemaname,
    tablename,
    indexname
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexname NOT LIKE 'pg_toast%';
```

## BigQuery Optimization

### No Traditional Indexes!

BigQuery does NOT use traditional indexes. Instead:

### 1. Partitioning

```sql
-- Date partitioning (most common)
CREATE TABLE `project.dataset.orders`
(
    order_id INT64,
    customer_id INT64,
    order_date DATE,
    total_amount NUMERIC
)
PARTITION BY order_date
OPTIONS(
    partition_expiration_days=730,
    require_partition_filter=true
);

-- Timestamp partitioning
CREATE TABLE `project.dataset.events`
(
    event_id INT64,
    event_timestamp TIMESTAMP,
    user_id INT64
)
PARTITION BY DATE(event_timestamp);

-- Integer range partitioning
CREATE TABLE `project.dataset.products`
(
    product_id INT64,
    category STRING
)
PARTITION BY RANGE_BUCKET(product_id, GENERATE_ARRAY(0, 1000000, 10000));
```

**Benefits**:
- Query only relevant partitions (cost reduction)
- Faster query execution
- Automatic partition pruning

**Best Practices**:
- Partition by date/timestamp for time-series data
- Always filter on partition column in queries
- Use `require_partition_filter=true` to enforce

### 2. Clustering

```sql
-- Cluster by up to 4 columns
CREATE TABLE `project.dataset.orders`
(
    order_id INT64,
    customer_id INT64,
    order_date DATE,
    country STRING,
    total_amount NUMERIC
)
PARTITION BY order_date
CLUSTER BY customer_id, country;
```

**Benefits**:
- Co-locates related data
- Faster filtering and aggregation
- Reduces bytes scanned (cost reduction)

**Best Practices**:
- Cluster by columns used in WHERE, JOIN, GROUP BY
- Order matters: most selective first
- Combine with partitioning for best results

### 3. Recommended Schema for E-Commerce

```sql
-- Customers (no partitioning for small dimension table)
CREATE TABLE `project.dataset.customers` (
    customer_id INT64,
    email STRING,
    country STRING,
    customer_segment STRING,
    registration_date TIMESTAMP
)
CLUSTER BY customer_segment, country;

-- Orders (partition + cluster)
CREATE TABLE `project.dataset.orders` (
    order_id INT64,
    customer_id INT64,
    order_date TIMESTAMP,
    total_amount NUMERIC,
    order_status STRING,
    shipping_country STRING
)
PARTITION BY DATE(order_date)
CLUSTER BY customer_id, order_status
OPTIONS(
    partition_expiration_days=730,
    require_partition_filter=true
);

-- OrderItems (cluster only, inherits date from join)
CREATE TABLE `project.dataset.order_items` (
    order_item_id INT64,
    order_id INT64,
    product_id INT64,
    quantity INT64,
    unit_price NUMERIC,
    line_total NUMERIC
)
CLUSTER BY order_id, product_id;

-- Products (cluster by category)
CREATE TABLE `project.dataset.products` (
    product_id INT64,
    product_name STRING,
    category STRING,
    supplier_id INT64,
    current_price NUMERIC
)
CLUSTER BY category, supplier_id;

-- Inventory (cluster by warehouse and product)
CREATE TABLE `project.dataset.inventory` (
    inventory_id INT64,
    product_id INT64,
    warehouse_location STRING,
    quantity_on_hand INT64,
    reorder_level INT64
)
CLUSTER BY warehouse_location, product_id;
```

### 4. Query Optimization Techniques

```sql
-- BAD: Full table scan
SELECT * FROM `project.dataset.orders`;

-- GOOD: Partition pruning
SELECT *
FROM `project.dataset.orders`
WHERE DATE(order_date) BETWEEN '2024-01-01' AND '2024-12-31';

-- GOOD: Clustering filter
SELECT *
FROM `project.dataset.orders`
WHERE customer_id = 12345
  AND order_status = 'Delivered'
  AND DATE(order_date) >= '2024-01-01';

-- GOOD: Select only needed columns
SELECT order_id, total_amount
FROM `project.dataset.orders`
WHERE DATE(order_date) = '2024-06-15';

-- GOOD: Approximate aggregations (faster + cheaper)
SELECT APPROX_COUNT_DISTINCT(customer_id) AS unique_customers
FROM `project.dataset.orders`;

-- GOOD: Materialize expensive CTEs
CREATE TEMP TABLE customer_metrics AS
SELECT customer_id, SUM(total_amount) AS total_revenue
FROM `project.dataset.orders`
GROUP BY customer_id;

SELECT * FROM customer_metrics WHERE total_revenue > 10000;
```

## Query-Specific Recommendations

### Query 1: Customer Lifetime Value

**T-SQL**:
```sql
CREATE NONCLUSTERED INDEX IX_Orders_Customer_Date
ON Orders(CustomerID, OrderDate)
INCLUDE (TotalAmount, OrderStatus);

CREATE NONCLUSTERED INDEX IX_OrderItems_Product
ON OrderItems(ProductID) INCLUDE (OrderID, LineTotal);
```

**PostgreSQL**:
```sql
CREATE INDEX idx_orders_customer_date
ON orders(customer_id, order_date)
INCLUDE (total_amount, order_status);

-- Materialized view for frequent access
CREATE MATERIALIZED VIEW mv_customer_lifetime_value AS
<full query>;
```

**BigQuery**:
```sql
-- Partition orders by date, cluster by customer
PARTITION BY DATE(order_date)
CLUSTER BY customer_id, order_status
```

### Query 2: Inventory Reorder Analysis

**T-SQL**:
```sql
CREATE NONCLUSTERED INDEX IX_Inventory_Product_Reorder
ON Inventory(ProductID, QuantityOnHand, ReorderLevel)
INCLUDE (ReorderQuantity, WarehouseLocation);
```

**PostgreSQL**:
```sql
CREATE INDEX idx_inventory_low_stock
ON inventory(product_id, quantity_on_hand)
WHERE quantity_on_hand <= reorder_level;
```

**BigQuery**:
```sql
CLUSTER BY warehouse_location, product_id
```

### Query 5: Product Affinity (Self-Join Heavy)

**T-SQL**:
```sql
CREATE NONCLUSTERED INDEX IX_OrderItems_Order_Product
ON OrderItems(OrderID, ProductID) INCLUDE (Quantity, LineTotal);
```

**PostgreSQL**:
```sql
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- Consider hash join optimization
SET enable_hashjoin = on;
SET work_mem = '256MB';
```

**BigQuery**:
```sql
CLUSTER BY order_id, product_id

-- Pre-aggregate to reduce self-join cost
WITH order_products AS (
    SELECT order_id, ARRAY_AGG(STRUCT(product_id, product_name)) AS products
    FROM order_items
    GROUP BY order_id
)
-- Use UNNEST for efficient processing
```

## Summary

| Platform | Primary Strategy | Maintenance | Cost Model |
|----------|------------------|-------------|------------|
| **T-SQL** | B-tree indexes + columnstore | Regular rebuild/reorganize | Storage + compute |
| **PostgreSQL** | B-tree + GIN + materialized views | VACUUM + ANALYZE | Storage + compute |
| **BigQuery** | Partitioning + clustering | Automatic | Bytes scanned |

**Key Takeaways**:
1. **T-SQL**: Rich indexing options, requires maintenance
2. **PostgreSQL**: Flexible index types, good for mixed workloads
3. **BigQuery**: No indexes, rely on partitioning/clustering and query optimization
