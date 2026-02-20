# SQL Migration Portfolio: T-SQL → PostgreSQL → BigQuery

A comprehensive portfolio project demonstrating advanced SQL migration skills across three major database platforms: Microsoft SQL Server (T-SQL), PostgreSQL, and Google BigQuery.

## 📋 Project Overview

This project showcases enterprise-level SQL query migration and optimization across different database platforms. It includes:

- **Realistic Dataset**: E-commerce platform with 9 interconnected tables
- **10 Complex Analytical Queries**: Each demonstrating different SQL features
- **Cross-Platform Migrations**: Every query translated to T-SQL, PostgreSQL, and BigQuery
- **Performance Optimization**: Platform-specific indexing and optimization strategies
- **Production-Ready Code**: Complete with documentation and best practices

## 🎯 Skills Demonstrated

### SQL Expertise
- ✅ Complex Common Table Expressions (CTEs) with multiple levels
- ✅ Advanced Window Functions (ROW_NUMBER, RANK, NTILE, LAG/LEAD)
- ✅ Multi-table Joins (INNER, LEFT, CROSS)
- ✅ Conditional Aggregations and CASE Statements
- ✅ Date/Time Calculations and Manipulations
- ✅ String Operations and Concatenations
- ✅ Subqueries and Correlated Subqueries

### Platform-Specific Knowledge
- ✅ T-SQL: IDENTITY columns, FORMAT(), STRING_AGG(), OPTION hints
- ✅ PostgreSQL: SERIAL, materialized views, EXTRACT(), ::casting
- ✅ BigQuery: STRUCT/ARRAY, SAFE_DIVIDE(), table partitioning/clustering

### Data Engineering
- ✅ Schema design with proper normalization
- ✅ Indexing strategies for query optimization
- ✅ Performance tuning and query optimization
- ✅ Handling NULL values and division by zero
- ✅ Data type conversions across platforms

## 📊 Dataset Scenario

**Domain**: Multi-vendor E-commerce Platform (GlobalShop)

### Database Schema

#### Core Tables
1. **Customers** (10K+ records)
   - Customer demographics and segmentation
   - Registration tracking

2. **Products** (5K+ records)
   - Product catalog with categories
   - Supplier relationships
   - Pricing information

3. **Orders** (100K+ records)
   - Transaction history
   - Order status tracking
   - Shipping details

4. **OrderItems** (250K+ records)
   - Line item details
   - Quantity and pricing

5. **Inventory** (15K+ records)
   - Multi-warehouse stock levels
   - Reorder thresholds

#### Supporting Tables
6. **Suppliers** - Vendor information and ratings
7. **InventoryTransactions** - Stock movement history
8. **ProductReviews** - Customer feedback
9. **PriceHistory** - Historical pricing data

### Entity Relationship
```
Customers 1→N Orders 1→N OrderItems N→1 Products N→1 Suppliers
                                     ↓
                                 Inventory
                                     ↓
                           InventoryTransactions
```

## 🔍 Query Catalog

### 1. **Customer Lifetime Value (CLV) Analysis**
**Complexity**: ⭐⭐⭐⭐
- **Features**: 3-level CTEs, window functions, multiple aggregations
- **Use Case**: Identify high-value customers, predict churn
- **Key Metrics**: Total revenue, retention, favorite categories, CLV score

[View Details](./queries/01-customer-lifetime-value/README.md)

### 2. **Inventory Reorder Analysis with Forecasting**
**Complexity**: ⭐⭐⭐⭐
- **Features**: Sales velocity calculations, supplier metrics, weighted averages
- **Use Case**: Automated reorder recommendations, prevent stockouts
- **Key Metrics**: Days until stockout, reorder priority, lead time analysis

[View Details](./queries/02-inventory-reorder-analysis/)

### 3. **Sales Performance Dashboard**
**Complexity**: ⭐⭐⭐⭐⭐
- **Features**: Year-over-year analysis, date dimensions, market share
- **Use Case**: Executive dashboard, trend analysis
- **Key Metrics**: YoY growth, category performance, moving averages

[View Details](./queries/03-sales-performance-dashboard/)

### 4. **Cohort Retention Analysis**
**Complexity**: ⭐⭐⭐⭐
- **Features**: Cohort segmentation, retention curves, time-based analysis
- **Use Case**: Customer retention tracking, cohort comparison
- **Key Metrics**: Month-over-month retention, cohort quality score

[View Details](./queries/04-cohort-retention-analysis/)

### 5. **Product Affinity Analysis (Market Basket)**
**Complexity**: ⭐⭐⭐⭐⭐
- **Features**: Self-joins, correlation metrics, recommendation engine
- **Use Case**: Cross-sell opportunities, product bundling
- **Key Metrics**: Support, confidence, lift score, revenue opportunity

[View Details](./queries/05-product-affinity-analysis/)

### 6. **Supplier Performance Scorecard**
**Complexity**: ⭐⭐⭐
- **Features**: Multi-dimensional scoring, aggregations
- **Use Case**: Vendor management, procurement decisions
- **Key Metrics**: Quality ratings, lead times, stockout frequency

[View Details](./queries/06-supplier-performance-metrics/)

### 7. **Revenue Trend Forecasting**
**Complexity**: ⭐⭐⭐⭐
- **Features**: Moving averages, LAG/LEAD, seasonality detection
- **Use Case**: Revenue predictions, budget planning
- **Key Metrics**: MoM/YoY growth, forecast confidence, seasonality index

[View Details](./queries/07-revenue-trend-forecasting/)

### 8. **Customer Segmentation (RFM Analysis)**
**Complexity**: ⭐⭐⭐⭐
- **Features**: RFM modeling, NTILE(), advanced CASE logic
- **Use Case**: Marketing segmentation, targeted campaigns
- **Key Metrics**: Recency, frequency, monetary scores, churn risk

[View Details](./queries/08-customer-segmentation/)

### 9. **Order Fulfillment Analytics**
**Complexity**: ⭐⭐⭐⭐
- **Features**: SLA tracking, time calculations, performance scoring
- **Use Case**: Operations monitoring, bottleneck identification
- **Key Metrics**: Processing time, SLA compliance, fulfillment score

[View Details](./queries/09-order-fulfillment-analytics/)

### 10. **Price Optimization and Elasticity**
**Complexity**: ⭐⭐⭐⭐⭐
- **Features**: Price elasticity calculations, LEAD() for time-series
- **Use Case**: Dynamic pricing, margin optimization
- **Key Metrics**: Price elasticity, optimal price suggestions, revenue impact

[View Details](./queries/10-price-optimization-analysis/)

## 🗂️ Repository Structure

```
SQL-Migration-Project/
├── README.md (this file)
├── schemas/
│   ├── tsql/schema.sql
│   ├── postgresql/schema.sql
│   └── bigquery/schema.sql
├── queries/
│   ├── 01-customer-lifetime-value/
│   │   ├── tsql/query.sql
│   │   ├── postgresql/query.sql
│   │   ├── bigquery/query.sql
│   │   └── README.md
│   ├── 02-inventory-reorder-analysis/
│   │   └── ... (same structure)
│   ├── ... (queries 03-10)
├── docs/
│   ├── performance-notes/
│   │   ├── indexing-strategies.md
│   │   ├── bigquery-optimization.md
│   │   └── migration-guide.md
└── sample-data/
    └── (Sample CSV files for testing)
```

## 🚀 Getting Started

### Prerequisites

- **SQL Server** 2019+ or Azure SQL Database
- **PostgreSQL** 13+
- **Google Cloud Platform** account with BigQuery access

### Setup Instructions

#### 1. SQL Server (T-SQL)
```sql
-- Create database
CREATE DATABASE GlobalShopDB;
GO

-- Run schema
USE GlobalShopDB;
-- Execute schemas/tsql/schema.sql

-- Run any query
-- Execute queries/01-customer-lifetime-value/tsql/query.sql
```

#### 2. PostgreSQL
```bash
# Create database
createdb globalshop_db

# Run schema
psql globalshop_db < schemas/postgresql/schema.sql

# Run any query
psql globalshop_db < queries/01-customer-lifetime-value/postgresql/query.sql
```

#### 3. BigQuery
```bash
# Create dataset
bq mk --dataset project_id:globalshop_dataset

# Run schema (update project_id in file first)
bq query --use_legacy_sql=false < schemas/bigquery/schema.sql

# Run any query
bq query --use_legacy_sql=false < queries/01-customer-lifetime-value/bigquery/query.sql
```

## 📚 Key Migration Differences

### Syntax Variations

| Feature | T-SQL | PostgreSQL | BigQuery |
|---------|-------|------------|----------|
| **String Concat** | `+` | `||` or `CONCAT()` | `CONCAT()` |
| **Auto-increment** | `IDENTITY(1,1)` | `SERIAL` | No native support |
| **Date Diff** | `DATEDIFF(unit, d1, d2)` | `EXTRACT()` or `-` | `DATE_DIFF(d2, d1, unit)` |
| **Current Date** | `GETDATE()` | `CURRENT_TIMESTAMP` | `CURRENT_TIMESTAMP()` |
| **Null Handling** | `ISNULL()` | `COALESCE()` | `IFNULL()` or `COALESCE()` |
| **String Aggregation** | `STRING_AGG()` | `STRING_AGG()` | `STRING_AGG()` |
| **Top N** | `TOP N` | `LIMIT N` | `LIMIT N` |
| **Division by Zero** | `NULLIF()` | `NULLIF()` | `SAFE_DIVIDE()` |

### Performance Optimization

#### T-SQL (SQL Server)
- **Indexes**: B-tree and columnstore indexes
- **Hints**: `OPTION (MAXDOP N)`, `WITH (NOLOCK)`
- **Statistics**: Auto-update statistics
- **Tools**: Query Store, Execution Plans

#### PostgreSQL
- **Indexes**: B-tree, GIN, BRIN indexes
- **Materialized Views**: For expensive analytical queries
- **Vacuum**: Regular maintenance required
- **Tools**: EXPLAIN ANALYZE, pg_stat_statements

#### BigQuery
- **Partitioning**: By date/timestamp columns
- **Clustering**: Up to 4 columns for filtering
- **No Indexes**: Columnar storage handles optimization
- **Cost**: Based on bytes scanned (optimize with partitions)

## 💡 Performance Highlights

### Query 1 (Customer Lifetime Value)
- **T-SQL**: Columnstore index recommended for Orders table (>1M rows)
- **PostgreSQL**: Materialized view reduces execution from 8s to <100ms
- **BigQuery**: Partition pruning reduces cost by 70%

### Query 5 (Product Affinity)
- **T-SQL**: Self-join optimization with proper indexing critical
- **PostgreSQL**: Parallel query execution with work_mem tuning
- **BigQuery**: Clustering by product_id enables efficient joins

### Query 8 (RFM Segmentation)
- **T-SQL**: NTILE() window function performs well with statistics
- **PostgreSQL**: Hash aggregate for faster grouping
- **BigQuery**: Approximate aggregations for massive datasets

## 🎓 Learning Outcomes

After exploring this repository, you'll understand:

1. **How to translate** complex analytical queries across platforms
2. **When to use** platform-specific features (materialized views, partitioning)
3. **How to optimize** queries for performance on each platform
4. **Best practices** for schema design and indexing
5. **Cost considerations** especially for cloud-based BigQuery

## 🛠️ Technologies Used

- **SQL Server 2019+** (T-SQL)
- **PostgreSQL 13+**
- **Google BigQuery** (Standard SQL)
- **Git** for version control
- **Markdown** for documentation

## 📈 Use Cases

This portfolio demonstrates skills relevant to:

- **Data Engineer** roles requiring multi-platform SQL expertise
- **Analytics Engineer** positions with data warehouse experience
- **Database Administrator** roles involving migrations
- **Business Intelligence** developers working across platforms
- **Data Analyst** roles requiring advanced SQL

## 🔗 Additional Resources

- [SQL Server Documentation](https://docs.microsoft.com/sql/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [BigQuery Documentation](https://cloud.google.com/bigquery/docs)
- [Migration Best Practices](./docs/performance-notes/migration-guide.md)

## 📝 License

This project is available for educational and portfolio purposes. Feel free to use, modify, and reference.

## 🙏 Acknowledgments

Dataset scenario inspired by real-world e-commerce analytics challenges. Query patterns based on common business intelligence requirements in enterprise environments.

---

**⭐ Star this repository if you find it helpful for learning SQL migrations!**
