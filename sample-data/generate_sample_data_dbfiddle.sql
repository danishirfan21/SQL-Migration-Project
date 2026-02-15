-- =====================================================
-- Sample Data Generation Script - T-SQL
-- =====================================================
-- This script populates the database with realistic sample data
-- for testing and demonstration purposes.
-- Version: dbfiddle.uk compatible (no GO statements, no USE DATABASE)

-- 1. Customers
INSERT INTO Customers (Email, FirstName, LastName, Country, CustomerSegment, IsActive) VALUES
('john.doe@email.com', 'John', 'Doe', 'USA', 'Gold', 1),
('jane.smith@email.com', 'Jane', 'Smith', 'UK', 'Silver', 1),
('robert.brown@email.com', 'Robert', 'Brown', 'Canada', 'Bronze', 1),
('emily.davis@email.com', 'Emily', 'Davis', 'Australia', 'Platinum', 1),
('michael.wilson@email.com', 'Michael', 'Wilson', 'Germany', 'Gold', 1),
('sarah.miller@email.com', 'Sarah', 'Miller', 'France', 'Silver', 1),
('david.taylor@email.com', 'David', 'Taylor', 'Japan', 'Bronze', 1),
('linda.anderson@email.com', 'Linda', 'Anderson', 'USA', 'Platinum', 1),
('james.thomas@email.com', 'James', 'Thomas', 'UK', 'Gold', 1),
('elizabeth.jackson@email.com', 'Elizabeth', 'Jackson', 'Canada', 'Silver', 1);

-- 2. Suppliers
INSERT INTO Suppliers (SupplierName, Country, ContactEmail, Rating, IsActive) VALUES
('TechGiant Solutions', 'USA', 'contact@techgiant.com', 4.8, 1),
('Global Electronics', 'China', 'sales@globalelec.cn', 4.5, 1),
('EuroSoft Hardware', 'Germany', 'info@eurosoft.de', 4.2, 1),
('Pacific Gadgets', 'Japan', 'support@pacificgadgets.jp', 4.7, 1),
('InnoTech India', 'India', 'biz@innotech.in', 3.9, 1);

-- 3. Products
INSERT INTO Products (ProductName, Category, SubCategory, SupplierID, BasePrice, CurrentPrice, CostPrice, IsActive) VALUES
('UltraBook Pro 15', 'Electronics', 'Laptops', 1, 1200.00, 1499.99, 900.00, 1),
('SmartWatch Elite', 'Electronics', 'Wearables', 2, 200.00, 249.99, 150.00, 1),
('NoiseCancel Headphones', 'Electronics', 'Audio', 4, 250.00, 299.99, 180.00, 1),
('ErgoKeyboard K9', 'Computers', 'Peripherals', 3, 80.00, 99.99, 50.00, 1),
('4K Monitor 32in', 'Electronics', 'Monitors', 1, 400.00, 499.99, 320.00, 1),
('Wireless Mouse Pro', 'Computers', 'Peripherals', 2, 40.00, 59.99, 25.00, 1),
('SSD Drive 1TB', 'Computers', 'Storage', 1, 100.00, 129.99, 70.00, 1),
('Gaming Laptop RTX', 'Electronics', 'Laptops', 4, 1500.00, 1899.99, 1200.00, 1),
('Webcam 1080p', 'Computers', 'Peripherals', 5, 50.00, 79.99, 35.00, 1),
('Mechanical Keyboard G', 'Computers', 'Peripherals', 4, 120.00, 159.99, 90.00, 1);

-- 4. Orders
-- Note: OrderDate is spread out to test CLV and cohort analysis
INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, ShippingCost, TaxAmount, OrderStatus, PaymentMethod, ShippingCountry) VALUES
(1, DATEADD(MONTH, -12, GETDATE()), 1549.98, 50.00, 50.00, 'Delivered', 'Credit Card', 'USA'),
(1, DATEADD(MONTH, -6, GETDATE()), 299.99, 10.00, 15.00, 'Delivered', 'Credit Card', 'USA'),
(2, DATEADD(MONTH, -11, GETDATE()), 249.99, 15.00, 12.00, 'Delivered', 'PayPal', 'UK'),
(3, DATEADD(MONTH, -10, GETDATE()), 99.99, 5.00, 5.00, 'Delivered', 'Debit Card', 'Canada'),
(4, DATEADD(MONTH, -9, GETDATE()), 1499.99, 60.00, 75.00, 'Delivered', 'Credit Card', 'Australia'),
(4, DATEADD(MONTH, -1, GETDATE()), 79.99, 10.00, 5.00, 'Shipped', 'Credit Card', 'Australia'),
(5, DATEADD(MONTH, -8, GETDATE()), 299.99, 20.00, 15.00, 'Delivered', 'Credit Card', 'Germany'),
(6, DATEADD(MONTH, -7, GETDATE()), 129.99, 10.00, 8.00, 'Delivered', 'PayPal', 'France'),
(7, DATEADD(MONTH, -6, GETDATE()), 499.99, 30.00, 25.00, 'Delivered', 'Bank Transfer', 'Japan'),
(8, DATEADD(MONTH, -5, GETDATE()), 1899.99, 80.00, 95.00, 'Delivered', 'Credit Card', 'USA'),
(1, DATEADD(DAY, -10, GETDATE()), 59.99, 5.00, 3.00, 'Processing', 'Credit Card', 'USA'),
(9, DATEADD(MONTH, -4, GETDATE()), 159.99, 15.00, 10.00, 'Delivered', 'Credit Card', 'UK'),
(10, DATEADD(MONTH, -3, GETDATE()), 99.99, 10.00, 5.00, 'Delivered', 'PayPal', 'Canada'),
(4, DATEADD(DAY, -5, GETDATE()), 249.99, 15.00, 12.00, 'Pending', 'Credit Card', 'Australia'),
(2, DATEADD(MONTH, -2, GETDATE()), 1499.99, 45.00, 60.00, 'Delivered', 'Credit Card', 'UK');

-- 5. OrderItems
INSERT INTO OrderItems (OrderID, ProductID, Quantity, UnitPrice, Discount) VALUES
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
INSERT INTO Inventory (ProductID, WarehouseLocation, QuantityOnHand, ReorderLevel, ReorderQuantity, LastRestocked) VALUES
(1, 'NA-East', 50, 10, 20, DATEADD(MONTH, -1, GETDATE())),
(2, 'APAC-Tokyo', 100, 25, 50, DATEADD(MONTH, -2, GETDATE())),
(3, 'EU-Central', 45, 15, 30, DATEADD(MONTH, -1, GETDATE())),
(4, 'EU-Central', 80, 20, 40, DATEADD(MONTH, -3, GETDATE())),
(5, 'NA-West', 30, 5, 15, DATEADD(MONTH, -1, GETDATE())),
(6, 'NA-East', 200, 50, 100, DATEADD(MONTH, -1, GETDATE())),
(7, 'NA-West', 150, 40, 80, DATEADD(MONTH, -2, GETDATE())),
(8, 'APAC-Sydney', 20, 10, 10, DATEADD(MONTH, -1, GETDATE())),
(9, 'UK-London', 120, 30, 60, DATEADD(MONTH, -4, GETDATE())),
(10, 'NA-East', 60, 20, 40, DATEADD(MONTH, -1, GETDATE()));

-- 7. InventoryTransactions
INSERT INTO InventoryTransactions (ProductID, TransactionType, Quantity, TransactionDate, OrderID, Notes) VALUES
(1, 'Purchase', 100, DATEADD(MONTH, -6, GETDATE()), NULL, 'Initial stock'),
(1, 'Sale', -1, DATEADD(MONTH, -12, GETDATE()), 1, 'Order fulfillment'),
(3, 'Sale', -1, DATEADD(MONTH, -6, GETDATE()), 2, 'Order fulfillment'),
(1, 'Adjustment', -2, DATEADD(DAY, -20, GETDATE()), NULL, 'Damaged during relocation');

-- 8. ProductReviews
INSERT INTO ProductReviews (ProductID, CustomerID, Rating, ReviewText, ReviewDate, IsVerifiedPurchase) VALUES
(1, 1, 5, 'Best laptop I have ever owned! Super fast.', DATEADD(MONTH, -11, GETDATE()), 1),
(3, 1, 4, 'Great sound, but a bit heavy.', DATEADD(MONTH, -5, GETDATE()), 1),
(2, 2, 5, 'Love the design and battery life.', DATEADD(MONTH, -10, GETDATE()), 1),
(1, 4, 3, 'Powerful but expensive.', DATEADD(MONTH, -8, GETDATE()), 1);

-- 9. PriceHistory
INSERT INTO PriceHistory (ProductID, Price, EffectiveDate, EndDate, ChangeReason) VALUES
(1, 1399.99, DATEADD(YEAR, -1, GETDATE()), DATEADD(MONTH, -6, GETDATE()), 'Initial Launch'),
(1, 1499.99, DATEADD(MONTH, -6, GETDATE()), NULL, 'Price Adjustment'),
(2, 249.99, DATEADD(MONTH, -11, GETDATE()), NULL, 'Initial Launch');

-- Sample data loaded successfully
