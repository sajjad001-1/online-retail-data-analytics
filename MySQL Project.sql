use new_schema_1;
CREATE TABLE online_retail (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate VARCHAR(50),
    UnitPrice DECIMAL(10,2),
    CustomerID VARCHAR(20),
    Country VARCHAR(100)
);
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/online_retail.csv'
INTO TABLE online_retail
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
select count(*) from online_retail;
select * from online_retail limit 10;
select * from online_retail
where UnitPrice = 0.00
or UnitPrice is null
or Quantity = 0;
DELETE FROM online_retail 
WHERE UnitPrice = 0.00 
   OR Quantity = 0 
   OR Description IS NULL
   OR Description LIKE '%bad debt%'
   OR Description LIKE '%amazon fee%';
   SELECT 
    COUNT(*) AS Remaining_Rows,
    MIN(UnitPrice) AS Min_Price,
    AVG(UnitPrice) AS Avg_Price,
    MAX(UnitPrice) AS Max_Price
FROM online_retail;

ALTER TABLE online_retail ADD COLUMN NewInvoiceDate DATETIME;
UPDATE online_retail
SET NewInvoiceDate = STR_TO_DATE(InvoiceDate, '%c/%e/%Y %H:%i')
WHERE InvoiceDate IS NOT NULL AND InvoiceDate != '';
ALTER TABLE online_retail DROP COLUMN InvoiceDate;
ALTER TABLE online_retail RENAME COLUMN NewInvoiceDate TO InvoiceDate;
SELECT 
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS YearMonth,
    SUM(Quantity * UnitPrice) AS TotalRevenue,
    SUM(Quantity) AS TotalItemsSold
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%' AND Quantity > 0
GROUP BY YearMonth
ORDER BY YearMonth;

WITH OrderTotals AS (
    SELECT 
        Country,
        InvoiceNo,
        SUM(Quantity * UnitPrice) AS OrderValue
    FROM online_retail
    WHERE InvoiceNo NOT LIKE 'C%' AND Quantity > 0
    GROUP BY Country, InvoiceNo
)
SELECT 
    Country,
    SUM(OrderValue) AS TotalRevenue,
    AVG(OrderValue) AS AverageOrderValue
FROM OrderTotals
GROUP BY Country
ORDER BY TotalRevenue DESC;

SELECT 
    COUNT(DISTINCT InvoiceNo) AS TotalCancelledOrders,
    ABS(SUM(Quantity * UnitPrice)) AS TotalMoneyLost
FROM online_retail
WHERE InvoiceNo LIKE 'C%';


SELECT AVG(TotalItems), MAX(TotalItems) 
FROM (SELECT InvoiceNo, SUM(Quantity) AS TotalItems FROM online_retail GROUP BY InvoiceNo) AS sub;

WITH OrderTotals AS (
    SELECT 
        InvoiceNo,
        SUM(Quantity) AS TotalItems,
        SUM(Quantity * UnitPrice) AS TotalRevenue
    FROM online_retail
    WHERE InvoiceNo NOT LIKE 'C%' AND Quantity > 0
    GROUP BY InvoiceNo
)
SELECT 
    CASE 
        WHEN TotalItems >= 500 THEN 'Wholesale'
        ELSE 'Retail'
    END AS OrderSegment,
    COUNT(InvoiceNo) AS NumberOfOrders,
    SUM(TotalRevenue) AS TotalSegmentRevenue
FROM OrderTotals
GROUP BY OrderSegment;

WITH CustomerSpend AS (
    SELECT 
        CustomerID,
        SUM(Quantity * UnitPrice) AS LifetimeSpend,
        PERCENT_RANK() OVER (ORDER BY SUM(Quantity * UnitPrice) DESC) AS SpendRank
    FROM online_retail
    WHERE CustomerID IS NOT NULL 
      AND InvoiceNo NOT LIKE 'C%' 
      AND Quantity > 0
    GROUP BY CustomerID
)
SELECT CustomerID, LifetimeSpend
FROM CustomerSpend
WHERE SpendRank <= 0.01
ORDER BY LifetimeSpend DESC;

WITH RankedOrders AS (
    SELECT 
        CustomerID,
        InvoiceNo,
        MIN(InvoiceDate) AS OrderDate,
        DENSE_RANK() OVER (PARTITION BY CustomerID ORDER BY MIN(InvoiceDate)) AS OrderRank
    FROM online_retail
    WHERE CustomerID IS NOT NULL AND InvoiceNo NOT LIKE 'C%' AND Quantity > 0
    GROUP BY CustomerID, InvoiceNo
),
FirstTwoOrders AS (
    SELECT 
        CustomerID,
        MAX(CASE WHEN OrderRank = 1 THEN OrderDate END) AS FirstOrderDate,
        MAX(CASE WHEN OrderRank = 2 THEN OrderDate END) AS SecondOrderDate
    FROM RankedOrders
    WHERE OrderRank IN (1, 2)
    GROUP BY CustomerID
)
SELECT 
    AVG(DATEDIFF(SecondOrderDate, FirstOrderDate)) AS AvgDaysToSecondPurchase
FROM FirstTwoOrders
WHERE SecondOrderDate IS NOT NULL;

WITH DatasetRange AS (
    SELECT MAX(InvoiceDate) AS MaxDate FROM online_retail
),
CustomerActivity AS (
    SELECT 
        CustomerID,
        SUM(CASE WHEN InvoiceDate <= DATE_SUB((SELECT MaxDate FROM DatasetRange), INTERVAL 6 MONTH) THEN Quantity * UnitPrice ELSE 0 END) AS EarlySpend,
        SUM(CASE WHEN InvoiceDate > DATE_SUB((SELECT MaxDate FROM DatasetRange), INTERVAL 6 MONTH) THEN Quantity * UnitPrice ELSE 0 END) AS RecentSpend
    FROM online_retail
    WHERE CustomerID IS NOT NULL AND InvoiceNo NOT LIKE 'C%' AND Quantity > 0
    GROUP BY CustomerID
)
SELECT CustomerID, EarlySpend
FROM CustomerActivity
WHERE EarlySpend > 1000
  AND RecentSpend = 0
ORDER BY EarlySpend DESC;

SELECT 
    CASE 
        WHEN CustomerID IS NULL OR CustomerID = '' THEN 'Guest Checkout'
        ELSE 'Registered Account'
    END AS AccountType,
    COUNT(DISTINCT InvoiceNo) AS TotalOrders,
    SUM(Quantity * UnitPrice) AS TotalRevenue
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%' AND Quantity > 0
GROUP BY AccountType;

WITH DatasetRange AS (
    SELECT MAX(InvoiceDate) AS MaxDate FROM online_retail
)
SELECT StockCode, Description, MAX(InvoiceDate) AS LastSaleDate
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%' AND Quantity > 0
GROUP BY StockCode, Description
HAVING LastSaleDate < DATE_SUB((SELECT MaxDate FROM DatasetRange), INTERVAL 6 MONTH)
ORDER BY LastSaleDate ASC;

CREATE INDEX idx_online_retail_invoice_stock ON online_retail (InvoiceNo, StockCode);
