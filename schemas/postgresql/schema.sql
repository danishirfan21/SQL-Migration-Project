-- =====================================================
-- E-Commerce Platform Database Schema - PostgreSQL
-- =====================================================
-- Scenario: Multi-vendor e-commerce platform with inventory management
-- Database: globalshop_db

-- Create database (run separately)
-- CREATE DATABASE globalshop_db;

-- Customers Table
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    country VARCHAR(50),
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    customer_segment VARCHAR(20) CHECK (customer_segment IN ('Bronze', 'Silver', 'Gold', 'Platinum')),
    is_active BOOLEAN DEFAULT TRUE
);

CREATE INDEX ix_customer_email ON customers(email);
CREATE INDEX ix_customer_segment ON customers(customer_segment);
CREATE INDEX ix_customer_reg_date ON customers(registration_date);

-- Suppliers Table
CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(200) NOT NULL,
    country VARCHAR(50),
    contact_email VARCHAR(255),
    rating DECIMAL(3,2) CHECK (rating BETWEEN 0 AND 5),
    is_active BOOLEAN DEFAULT TRUE
);

CREATE INDEX ix_supplier_rating ON suppliers(rating);

-- Products Table
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL,
    sub_category VARCHAR(100),
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    base_price DECIMAL(10,2) NOT NULL,
    current_price DECIMAL(10,2) NOT NULL,
    cost_price DECIMAL(10,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_product_category ON products(category);
CREATE INDEX ix_product_supplier ON products(supplier_id);

-- Orders Table
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date TIMESTAMP NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    shipping_cost DECIMAL(8,2) DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    order_status VARCHAR(20) CHECK (order_status IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled', 'Returned')),
    payment_method VARCHAR(50),
    shipping_country VARCHAR(50)
);

CREATE INDEX ix_order_customer ON orders(customer_id);
CREATE INDEX ix_order_date ON orders(order_date);
CREATE INDEX ix_order_status ON orders(order_status);

-- OrderItems Table
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(order_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount DECIMAL(5,2) DEFAULT 0,
    line_total DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price * (1 - discount/100)) STORED
);

CREATE INDEX ix_order_item_order ON order_items(order_id);
CREATE INDEX ix_order_item_product ON order_items(product_id);

-- Inventory Table
CREATE TABLE inventory (
    inventory_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    warehouse_location VARCHAR(100) NOT NULL,
    quantity_on_hand INTEGER NOT NULL,
    reorder_level INTEGER NOT NULL,
    reorder_quantity INTEGER NOT NULL,
    last_restocked TIMESTAMP
);

CREATE INDEX ix_inventory_product ON inventory(product_id);
CREATE INDEX ix_inventory_location ON inventory(warehouse_location);

-- InventoryTransactions Table
CREATE TABLE inventory_transactions (
    transaction_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    transaction_type VARCHAR(20) CHECK (transaction_type IN ('Purchase', 'Sale', 'Adjustment', 'Return')),
    quantity INTEGER NOT NULL,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    order_id INTEGER REFERENCES orders(order_id),
    notes VARCHAR(500)
);

CREATE INDEX ix_inv_trans_product ON inventory_transactions(product_id);
CREATE INDEX ix_inv_trans_date ON inventory_transactions(transaction_date);

-- ProductReviews Table
CREATE TABLE product_reviews (
    review_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    review_text VARCHAR(2000),
    review_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_verified_purchase BOOLEAN DEFAULT FALSE
);

CREATE INDEX ix_review_product ON product_reviews(product_id);
CREATE INDEX ix_review_date ON product_reviews(review_date);

-- PriceHistory Table
CREATE TABLE price_history (
    price_history_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    price DECIMAL(10,2) NOT NULL,
    effective_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP,
    change_reason VARCHAR(200)
);

CREATE INDEX ix_price_hist_product ON price_history(product_id);
CREATE INDEX ix_price_hist_date ON price_history(effective_date);

-- Create composite indexes for common query patterns
CREATE INDEX ix_orders_customer_date ON orders(customer_id, order_date);
CREATE INDEX ix_order_items_product_order ON order_items(product_id, order_id);
