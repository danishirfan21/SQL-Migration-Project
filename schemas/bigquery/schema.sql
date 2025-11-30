-- =====================================================
-- E-Commerce Platform Database Schema - BigQuery
-- =====================================================
-- Scenario: Multi-vendor e-commerce platform with inventory management
-- Dataset: globalshop_dataset

-- Note: Run this in BigQuery Console or via bq CLI
-- Create dataset: bq mk --dataset project_id:globalshop_dataset

-- Customers Table
CREATE TABLE `project_id.globalshop_dataset.customers` (
    customer_id INT64 NOT NULL,
    email STRING NOT NULL,
    first_name STRING NOT NULL,
    last_name STRING NOT NULL,
    country STRING,
    registration_date TIMESTAMP,
    customer_segment STRING,
    is_active BOOL
)
PARTITION BY DATE(registration_date)
CLUSTER BY customer_segment, country
OPTIONS(
    description="Customer master data with segmentation"
);

-- Suppliers Table
CREATE TABLE `project_id.globalshop_dataset.suppliers` (
    supplier_id INT64 NOT NULL,
    supplier_name STRING NOT NULL,
    country STRING,
    contact_email STRING,
    rating FLOAT64,
    is_active BOOL
)
OPTIONS(
    description="Supplier information and ratings"
);

-- Products Table
CREATE TABLE `project_id.globalshop_dataset.products` (
    product_id INT64 NOT NULL,
    product_name STRING NOT NULL,
    category STRING NOT NULL,
    sub_category STRING,
    supplier_id INT64 NOT NULL,
    base_price NUMERIC(10,2) NOT NULL,
    current_price NUMERIC(10,2) NOT NULL,
    cost_price NUMERIC(10,2) NOT NULL,
    is_active BOOL,
    created_date TIMESTAMP
)
CLUSTER BY category, supplier_id
OPTIONS(
    description="Product catalog with pricing information"
);

-- Orders Table
CREATE TABLE `project_id.globalshop_dataset.orders` (
    order_id INT64 NOT NULL,
    customer_id INT64 NOT NULL,
    order_date TIMESTAMP NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL,
    shipping_cost NUMERIC(8,2),
    tax_amount NUMERIC(10,2),
    order_status STRING,
    payment_method STRING,
    shipping_country STRING
)
PARTITION BY DATE(order_date)
CLUSTER BY customer_id, order_status
OPTIONS(
    description="Order transactions partitioned by date"
);

-- OrderItems Table
CREATE TABLE `project_id.globalshop_dataset.order_items` (
    order_item_id INT64 NOT NULL,
    order_id INT64 NOT NULL,
    product_id INT64 NOT NULL,
    quantity INT64 NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    discount NUMERIC(5,2),
    line_total NUMERIC(12,2)
)
CLUSTER BY order_id, product_id
OPTIONS(
    description="Order line items with product details"
);

-- Inventory Table
CREATE TABLE `project_id.globalshop_dataset.inventory` (
    inventory_id INT64 NOT NULL,
    product_id INT64 NOT NULL,
    warehouse_location STRING NOT NULL,
    quantity_on_hand INT64 NOT NULL,
    reorder_level INT64 NOT NULL,
    reorder_quantity INT64 NOT NULL,
    last_restocked TIMESTAMP
)
CLUSTER BY warehouse_location, product_id
OPTIONS(
    description="Current inventory levels by warehouse"
);

-- InventoryTransactions Table
CREATE TABLE `project_id.globalshop_dataset.inventory_transactions` (
    transaction_id INT64 NOT NULL,
    product_id INT64 NOT NULL,
    transaction_type STRING,
    quantity INT64 NOT NULL,
    transaction_date TIMESTAMP,
    order_id INT64,
    notes STRING
)
PARTITION BY DATE(transaction_date)
CLUSTER BY product_id, transaction_type
OPTIONS(
    description="Inventory movement history partitioned by date"
);

-- ProductReviews Table
CREATE TABLE `project_id.globalshop_dataset.product_reviews` (
    review_id INT64 NOT NULL,
    product_id INT64 NOT NULL,
    customer_id INT64 NOT NULL,
    rating INT64,
    review_text STRING,
    review_date TIMESTAMP,
    is_verified_purchase BOOL
)
PARTITION BY DATE(review_date)
CLUSTER BY product_id
OPTIONS(
    description="Product reviews and ratings"
);

-- PriceHistory Table
CREATE TABLE `project_id.globalshop_dataset.price_history` (
    price_history_id INT64 NOT NULL,
    product_id INT64 NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    effective_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP,
    change_reason STRING
)
PARTITION BY DATE(effective_date)
CLUSTER BY product_id
OPTIONS(
    description="Historical price changes for products"
);

-- =====================================================
-- BigQuery-Specific Optimizations:
-- =====================================================
-- 1. Partitioning by date columns for time-series queries
-- 2. Clustering on frequently filtered/joined columns
-- 3. No traditional indexes - uses clustering instead
-- 4. NUMERIC type for precise decimal calculations
-- 5. Table descriptions for documentation
