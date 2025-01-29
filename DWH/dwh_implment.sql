-- Create the data warehouse database
CREATE DATABASE cashierc_dwh;
GO

USE cashierc_dwh;
GO

-- Create Dim_Date table
CREATE TABLE Dim_Date (
    DateKey INT PRIMARY KEY,
    DateFull DATE,
    Year INT,
    Quarter INT,
    Month INT,
    Day INT,
    DayOfWeek INT,
    DayName NVARCHAR(10),
    MonthName NVARCHAR(10)
);

DECLARE @StartDate DATE = '2024-01-01';
DECLARE @EndDate DATE = '2025-12-31';

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO Dim_Date (
        DateKey,
        DateFull,
        Year,
        Quarter,
        Month,
        Day,
        DayOfWeek,
        DayName,
        MonthName
    )
    VALUES (
        CONVERT(INT, CONVERT(VARCHAR(8), @StartDate, 112)), -- DateKey in format YYYYMMDD
        @StartDate,
        YEAR(@StartDate),
        DATEPART(QUARTER, @StartDate),
        MONTH(@StartDate),
        DAY(@StartDate),
        DATEPART(WEEKDAY, @StartDate),
        DATENAME(WEEKDAY, @StartDate),
        DATENAME(MONTH, @StartDate)
    );

    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;
GO

-- Create Dim_Products table
CREATE TABLE Dim_Products (
    ProductKey BIGINT PRIMARY KEY,
    Name NVARCHAR(255),
    Slug NVARCHAR(255),
    Description NVARCHAR(MAX),
    Image NVARCHAR(255),
    Sku NVARCHAR(255),
    Price DECIMAL(10, 2),
    SalePrice DECIMAL(10, 2),
    Quantity BIGINT,
    IsVisible BIT,
    IsFeatured BIT,
    CreatedAt DATETIME2,
    UpdatedAt DATETIME2
);
GO

INSERT INTO Dim_Products (ProductKey, Name, Slug, Description, Image, Sku, Price, SalePrice, Quantity, IsVisible, IsFeatured, CreatedAt, UpdatedAt)
SELECT id, name, slug, description, image, sku, price, sale_price, quantity, is_visible, is_featured, created_at, updated_at
FROM cashierc.dbo.Products;
GO

-- Create Dim_Categories table
CREATE TABLE Dim_Categories (
    CategoryKey BIGINT PRIMARY KEY,
    Name NVARCHAR(255),
    Slug NVARCHAR(255),
    ParentId BIGINT,
    IsVisible BIT,
    Description NVARCHAR(MAX),
    CreatedAt DATETIME2,
    UpdatedAt DATETIME2
);
GO

INSERT INTO Dim_Categories (CategoryKey, Name, Slug, ParentId, IsVisible, Description, CreatedAt, UpdatedAt)
SELECT id, name, slug, parent_id, is_visible, description, created_at, updated_at
FROM cashierc.dbo.categories;
GO

-- Create Dim_Orders table
CREATE TABLE Dim_Orders (
    OrderKey BIGINT PRIMARY KEY,
    UserKey BIGINT,
    Number NVARCHAR(255),
    TotalPrice DECIMAL(10, 2),
    Status NVARCHAR(50),
    Notes NVARCHAR(MAX),
    CreatedAt DATETIME2,
    UpdatedAt DATETIME2
);
GO

INSERT INTO Dim_Orders (OrderKey, UserKey, Number, TotalPrice, Status, Notes, CreatedAt, UpdatedAt)
SELECT id, user_id, number, total_price, status, notes, created_at, updated_at
FROM cashierc.dbo.orders;
GO

-- Create Dim_Users table
CREATE TABLE Dim_Users (
    UserKey BIGINT PRIMARY KEY,
    Name NVARCHAR(255),
    Email NVARCHAR(255),
    Phone NVARCHAR(255),
    EmailVerifiedAt DATETIME2,
    Otp NVARCHAR(255),
    Password NVARCHAR(255),
    ProfileImage NVARCHAR(255),
    IsAdmin BIT,
    RememberToken NVARCHAR(100),
    CreatedAt DATETIME2,
    UpdatedAt DATETIME2
);
GO

INSERT INTO Dim_Users (UserKey, Name, Email, Phone, EmailVerifiedAt, Otp, Password, ProfileImage, IsAdmin, RememberToken, CreatedAt, UpdatedAt)
SELECT id, name, email, phone, email_verified_at, otp, password, profile_image, is_admin, remember_token, created_at, updated_at
FROM cashierc.dbo.users;
GO

-- Create Fact_Orders table
CREATE TABLE Fact_Orders (
    FactOrderKey BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserKey BIGINT,
    OrderKey BIGINT,
    CategoryKey BIGINT,
    ProductKey BIGINT,
    OrderDateKey INT,
    TotalPrice DECIMAL(10, 2),
    Quantity INT,
    FOREIGN KEY (UserKey) REFERENCES Dim_Users(UserKey),
    FOREIGN KEY (OrderKey) REFERENCES Dim_Orders(OrderKey),
    FOREIGN KEY (CategoryKey) REFERENCES Dim_Categories(CategoryKey),
    FOREIGN KEY (ProductKey) REFERENCES Dim_Products(ProductKey),
    FOREIGN KEY (OrderDateKey) REFERENCES Dim_Date(DateKey)
);
GO

-- Populate Fact_Orders table
INSERT INTO Fact_Orders (UserKey, OrderKey, CategoryKey, ProductKey, OrderDateKey, TotalPrice, Quantity)
SELECT
    u.id AS UserKey,
    o.id AS OrderKey,
    c.id AS CategoryKey,
    p.id AS ProductKey,
    CONVERT(INT, CONVERT(VARCHAR(8), o.created_at, 112)) AS OrderDateKey,
    SUM(oi.quantity * oi.unit_price) AS TotalPrice,
    SUM(oi.quantity) AS Quantity
FROM cashierc.dbo.users u
JOIN cashierc.dbo.orders o ON u.id = o.user_id
JOIN cashierc.dbo.order_items oi ON o.id = oi.order_id
JOIN cashierc.dbo.products p ON oi.product_id = p.id
JOIN cashierc.dbo.category_product cp ON p.id = cp.product_id
JOIN cashierc.dbo.categories c ON c.id = cp.category_id
GROUP BY u.id, o.id, c.id, p.id, CONVERT(INT, CONVERT(VARCHAR(8), o.created_at, 112));
GO
