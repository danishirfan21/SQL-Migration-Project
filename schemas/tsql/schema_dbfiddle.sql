-- =====================================================
-- E-Commerce Platform Database Schema - T-SQL (SQL Server)
-- =====================================================
-- Scenario: Multi-vendor e-commerce platform with inventory management
-- Version: dbfiddle.uk compatible (no GO statements, no CREATE DATABASE)

-- Customers Table
CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    Email VARCHAR(255) NOT NULL UNIQUE,
    FirstName VARCHAR(100) NOT NULL,
    LastName VARCHAR(100) NOT NULL,
    Country VARCHAR(50),
    RegistrationDate DATETIME2 DEFAULT GETDATE(),
    CustomerSegment VARCHAR(20) CHECK (CustomerSegment IN ('Bronze', 'Silver', 'Gold', 'Platinum')),
    IsActive BIT DEFAULT 1,
    INDEX IX_Customer_Email (Email),
    INDEX IX_Customer_Segment (CustomerSegment),
    INDEX IX_Customer_RegDate (RegistrationDate)
);

-- Products Table
CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName VARCHAR(200) NOT NULL,
    Category VARCHAR(100) NOT NULL,
    SubCategory VARCHAR(100),
    SupplierID INT NOT NULL,
    BasePrice DECIMAL(10,2) NOT NULL,
    CurrentPrice DECIMAL(10,2) NOT NULL,
    CostPrice DECIMAL(10,2) NOT NULL,
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    INDEX IX_Product_Category (Category),
    INDEX IX_Product_Supplier (SupplierID)
);

-- Suppliers Table
CREATE TABLE Suppliers (
    SupplierID INT IDENTITY(1,1) PRIMARY KEY,
    SupplierName VARCHAR(200) NOT NULL,
    Country VARCHAR(50),
    ContactEmail VARCHAR(255),
    Rating DECIMAL(3,2) CHECK (Rating BETWEEN 0 AND 5),
    IsActive BIT DEFAULT 1,
    INDEX IX_Supplier_Rating (Rating)
);

-- Orders Table
CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME2 NOT NULL,
    TotalAmount DECIMAL(12,2) NOT NULL,
    ShippingCost DECIMAL(8,2) DEFAULT 0,
    TaxAmount DECIMAL(10,2) DEFAULT 0,
    OrderStatus VARCHAR(20) CHECK (OrderStatus IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled', 'Returned')),
    PaymentMethod VARCHAR(50),
    ShippingCountry VARCHAR(50),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    INDEX IX_Order_Customer (CustomerID),
    INDEX IX_Order_Date (OrderDate),
    INDEX IX_Order_Status (OrderStatus)
);

-- OrderItems Table
CREATE TABLE OrderItems (
    OrderItemID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    Discount DECIMAL(5,2) DEFAULT 0,
    LineTotal AS (Quantity * UnitPrice * (1 - Discount/100)) PERSISTED,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    INDEX IX_OrderItem_Order (OrderID),
    INDEX IX_OrderItem_Product (ProductID)
);

-- Inventory Table
CREATE TABLE Inventory (
    InventoryID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT NOT NULL,
    WarehouseLocation VARCHAR(100) NOT NULL,
    QuantityOnHand INT NOT NULL,
    ReorderLevel INT NOT NULL,
    ReorderQuantity INT NOT NULL,
    LastRestocked DATETIME2,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    INDEX IX_Inventory_Product (ProductID),
    INDEX IX_Inventory_Location (WarehouseLocation)
);

-- InventoryTransactions Table
CREATE TABLE InventoryTransactions (
    TransactionID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT NOT NULL,
    TransactionType VARCHAR(20) CHECK (TransactionType IN ('Purchase', 'Sale', 'Adjustment', 'Return')),
    Quantity INT NOT NULL,
    TransactionDate DATETIME2 DEFAULT GETDATE(),
    OrderID INT NULL,
    Notes VARCHAR(500),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    INDEX IX_InvTrans_Product (ProductID),
    INDEX IX_InvTrans_Date (TransactionDate)
);

-- ProductReviews Table
CREATE TABLE ProductReviews (
    ReviewID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT NOT NULL,
    CustomerID INT NOT NULL,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    ReviewText VARCHAR(2000),
    ReviewDate DATETIME2 DEFAULT GETDATE(),
    IsVerifiedPurchase BIT DEFAULT 0,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    INDEX IX_Review_Product (ProductID),
    INDEX IX_Review_Date (ReviewDate)
);

-- PriceHistory Table
CREATE TABLE PriceHistory (
    PriceHistoryID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    EffectiveDate DATETIME2 NOT NULL,
    EndDate DATETIME2,
    ChangeReason VARCHAR(200),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    INDEX IX_PriceHist_Product (ProductID),
    INDEX IX_PriceHist_Date (EffectiveDate)
);

-- Add Foreign Key for Products -> Suppliers
ALTER TABLE Products
ADD CONSTRAINT FK_Products_Suppliers
FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID);
