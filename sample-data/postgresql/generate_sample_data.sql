-- =====================================================
-- Sample Data Generation Script - PostgreSQL
-- =====================================================
-- This script populates the database with realistic sample data
-- for testing and demonstration purposes.

-- 1. Customers
INSERT INTO customers (email, first_name, last_name, country, customer_segment, is_active) VALUES
('john.doe@email.com', 'John', 'Doe', 'USA', 'Gold', TRUE),
('jane.smith@email.com', 'Jane', 'Smith', 'UK', 'Silver', TRUE),
('robert.brown@email.com', 'Robert', 'Brown', 'Canada', 'Bronze', TRUE),
('emily.davis@email.com', 'Emily', 'Davis', 'Australia', 'Platinum', TRUE),
('michael.wilson@email.com', 'Michael', 'Wilson', 'Germany', 'Gold', TRUE),
('sarah.miller@email.com', 'Sarah', 'Miller', 'France', 'Silver', TRUE),
('david.taylor@email.com', 'David', 'Taylor', 'Japan', 'Bronze', TRUE),
('linda.anderson@email.com', 'Linda', 'Anderson', 'USA', 'Platinum', TRUE),
('james.thomas@email.com', 'James', 'Thomas', 'UK', 'Gold', TRUE),
('elizabeth.jackson@email.com', 'Elizabeth', 'Jackson', 'Canada', 'Silver', TRUE);

-- 2. Suppliers
INSERT INTO suppliers (supplier_name, country, contact_email, rating, is_active) VALUES
('TechGiant Solutions', 'USA', 'contact@techgiant.com', 4.8, TRUE),
('Global Electronics', 'China', 'sales@globalelec.cn', 4.5, TRUE),
('EuroSoft Hardware', 'Germany', 'info@eurosoft.de', 4.2, TRUE),
('Pacific Gadgets', 'Japan', 'support@pacificgadgets.jp', 4.7, TRUE),
('InnoTech India', 'India', 'biz@innotech.in', 3.9, TRUE);

-- 3. Products
INSERT INTO products (product_name, category, sub_category, supplier_id, base_price, current_price, cost_price, is_active) VALUES
('UltraBook Pro 15', 'Electronics', 'Laptops', 1, 1200.00, 1499.99, 900.00, TRUE),
('SmartWatch Elite', 'Electronics', 'Wearables', 2, 200.00, 249.99, 150.00, TRUE),
('NoiseCancel Headphones', 'Electronics', 'Audio', 4, 250.00, 299.99, 180.00, TRUE),
('ErgoKeyboard K9', 'Computers', 'Peripherals', 3, 80.00, 99.99, 50.00, TRUE),
('4K Monitor 32in', 'Electronics', 'Monitors', 1, 400.00, 499.99, 320.00, TRUE),
('Wireless Mouse Pro', 'Computers', 'Peripherals', 2, 40.00, 59.99, 25.00, TRUE),
('SSD Drive 1TB', 'Computers', 'Storage', 1, 100.00, 129.99, 70.00, TRUE),
('Gaming Laptop RTX', 'Electronics', 'Laptops', 4, 1500.00, 1899.99, 1200.00, TRUE),
('Webcam 1080p', 'Computers', 'Peripherals', 5, 50.00, 79.99, 35.00, TRUE),
('Mechanical Keyboard G', 'Computers', 'Peripherals', 4, 120.00, 159.99, 90.00, TRUE);

-- 4. Orders
-- Note: order_date is spread out to test CLV and cohort analysis
INSERT INTO orders (customer_id, order_date, total_amount, shipping_cost, tax_amount, order_status, payment_method, shipping_country) VALUES
(1, CURRENT_TIMESTAMP - INTERVAL '12 months', 1549.98, 50.00, 50.00, 'Delivered', 'Credit Card', 'USA'),
(1, CURRENT_TIMESTAMP - INTERVAL '6 months', 299.99, 10.00, 15.00, 'Delivered', 'Credit Card', 'USA'),
(2, CURRENT_TIMESTAMP - INTERVAL '11 months', 249.99, 15.00, 12.00, 'Delivered', 'PayPal', 'UK'),
(3, CURRENT_TIMESTAMP - INTERVAL '10 months', 99.99, 5.00, 5.00, 'Delivered', 'Debit Card', 'Canada'),
(4, CURRENT_TIMESTAMP - INTERVAL '9 months', 1499.99, 60.00, 75.00, 'Delivered', 'Credit Card', 'Australia'),
(4, CURRENT_TIMESTAMP - INTERVAL '1 month', 79.99, 10.00, 5.00, 'Shipped', 'Credit Card', 'Australia'),
(5, CURRENT_TIMESTAMP - INTERVAL '8 months', 299.99, 20.00, 15.00, 'Delivered', 'Credit Card', 'Germany'),
(6, CURRENT_TIMESTAMP - INTERVAL '7 months', 129.99, 10.00, 8.00, 'Delivered', 'PayPal', 'France'),
(7, CURRENT_TIMESTAMP - INTERVAL '6 months', 499.99, 30.00, 25.00, 'Delivered', 'Bank Transfer', 'Japan'),
(8, CURRENT_TIMESTAMP - INTERVAL '5 months', 1899.99, 80.00, 95.00, 'Delivered', 'Credit Card', 'USA'),
(1, CURRENT_TIMESTAMP - INTERVAL '10 days', 59.99, 5.00, 3.00, 'Processing', 'Credit Card', 'USA'),
(9, CURRENT_TIMESTAMP - INTERVAL '4 months', 159.99, 15.00, 10.00, 'Delivered', 'Credit Card', 'UK'),
(10, CURRENT_TIMESTAMP - INTERVAL '3 months', 99.99, 10.00, 5.00, 'Delivered', 'PayPal', 'Canada'),
(4, CURRENT_TIMESTAMP - INTERVAL '5 days', 249.99, 15.00, 12.00, 'Pending', 'Credit Card', 'Australia'),
(2, CURRENT_TIMESTAMP - INTERVAL '2 months', 1499.99, 45.00, 60.00, 'Delivered', 'Credit Card', 'UK');

-- 5. OrderItems
INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount) VALUES
(1, 1, 1, 1499.99, 0.0),
(1, 6, 1, 59.99, 10.0), -- Bundle discount
(2, 3, 1, 299.99, 0.0),
(3, 2, 1, 249.99, 0.0),
(4, 4, 1, 99.99, 0.0),
(5, 1, 1, 1499.99, 0.0),
(6, 9, 1, 79.99, 0.0),
(7, 3, 1, 299.99, 0.0),
(8, 7, 1, 129.99, 0.0),
(9, 5, 1, 499.99, 0.0),
(10, 8, 1, 1899.99, 0.0),
(11, 6, 1, 59.99, 0.0),
(12, 10, 1, 159.99, 0.0),
(13, 4, 1, 99.99, 0.0),
(14, 2, 1, 249.99, 0.0),
(15, 1, 1, 1499.99, 0.0);

-- 6. Inventory
INSERT INTO inventory (product_id, warehouse_location, quantity_on_hand, reorder_level, reorder_quantity, last_restocked) VALUES
(1, 'NA-East', 50, 10, 20, CURRENT_TIMESTAMP - INTERVAL '1 month'),
(2, 'APAC-Tokyo', 100, 25, 50, CURRENT_TIMESTAMP - INTERVAL '2 months'),
(3, 'EU-Central', 45, 15, 30, CURRENT_TIMESTAMP - INTERVAL '1 month'),
(4, 'EU-Central', 80, 20, 40, CURRENT_TIMESTAMP - INTERVAL '3 months'),
(5, 'NA-West', 30, 5, 15, CURRENT_TIMESTAMP - INTERVAL '1 month'),
(6, 'NA-East', 200, 50, 100, CURRENT_TIMESTAMP - INTERVAL '1 month'),
(7, 'NA-West', 150, 40, 80, CURRENT_TIMESTAMP - INTERVAL '2 months'),
(8, 'APAC-Sydney', 20, 10, 10, CURRENT_TIMESTAMP - INTERVAL '1 month'),
(9, 'UK-London', 120, 30, 60, CURRENT_TIMESTAMP - INTERVAL '4 months'),
(10, 'NA-East', 60, 20, 40, CURRENT_TIMESTAMP - INTERVAL '1 month');

-- 7. InventoryTransactions
INSERT INTO inventory_transactions (product_id, transaction_type, quantity, transaction_date, order_id, notes) VALUES
(1, 'Purchase', 100, CURRENT_TIMESTAMP - INTERVAL '6 months', NULL, 'Initial stock'),
(1, 'Sale', -1, CURRENT_TIMESTAMP - INTERVAL '12 months', 1, 'Order fulfillment'),
(3, 'Sale', -1, CURRENT_TIMESTAMP - INTERVAL '6 months', 2, 'Order fulfillment'),
(1, 'Adjustment', -2, CURRENT_TIMESTAMP - INTERVAL '20 days', NULL, 'Damaged during relocation');

-- 8. ProductReviews
INSERT INTO product_reviews (product_id, customer_id, rating, review_text, review_date, is_verified_purchase) VALUES
(1, 1, 5, 'Best laptop I have ever owned! Super fast.', CURRENT_TIMESTAMP - INTERVAL '11 months', TRUE),
(3, 1, 4, 'Great sound, but a bit heavy.', CURRENT_TIMESTAMP - INTERVAL '5 months', TRUE),
(2, 2, 5, 'Love the design and battery life.', CURRENT_TIMESTAMP - INTERVAL '10 months', TRUE),
(1, 4, 3, 'Powerful but expensive.', CURRENT_TIMESTAMP - INTERVAL '8 months', TRUE);

-- 9. PriceHistory
INSERT INTO price_history (product_id, price, effective_date, end_date, change_reason) VALUES
(1, 1399.99, CURRENT_TIMESTAMP - INTERVAL '1 year', CURRENT_TIMESTAMP - INTERVAL '6 months', 'Initial Launch'),
(1, 1499.99, CURRENT_TIMESTAMP - INTERVAL '6 months', NULL, 'Price Adjustment'),
(2, 249.99, CURRENT_TIMESTAMP - INTERVAL '11 months', NULL, 'Initial Launch');

-- Sample data loaded successfully
