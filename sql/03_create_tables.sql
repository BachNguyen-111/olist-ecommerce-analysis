/* ============================================================================
   03_create_tables.sql
   Olist_Retail_DB: database and table definitions (SQL Server / T-SQL)
   ----------------------------------------------------------------------------
   Purpose : Rebuild the database from the raw Kaggle CSVs in one run, so
             the project can be reproduced without clicking through the
             Import Flat File wizard.
   Run     : In SSMS, change the CSV folder path in the BULK INSERT
             section, then execute the whole script.
   WARNING : This DROPS and rebuilds the tables. Don't run it on a
             database you want to keep as-is; back it up first.
   Source  : https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
   Note    : Column names match the tables used in sql/05_analysis.sql
             and the Power BI model (e.g. category_translation.english_name).
   ===================================================================== */

IF DB_ID('Olist_Retail_DB') IS NULL
    CREATE DATABASE Olist_Retail_DB;
GO
USE Olist_Retail_DB;
GO

/* Drop in child-to-parent order so foreign keys don't block the drops */
DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
                     customers, products, sellers, category_translation;
GO

CREATE TABLE customers (
    customer_id              NVARCHAR(50)  NOT NULL,
    customer_unique_id       NVARCHAR(50)  NOT NULL,
    customer_zip_code_prefix NVARCHAR(10)  NOT NULL,   -- text keeps leading zeros
    customer_city            NVARCHAR(100) NOT NULL,
    customer_state           NCHAR(2)      NOT NULL,
    CONSTRAINT PK_customers PRIMARY KEY (customer_id)
);

CREATE TABLE category_translation (
    product_category_name    NVARCHAR(100) NOT NULL,
    english_name             NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_category_translation PRIMARY KEY (product_category_name)
);

CREATE TABLE products (
    product_id                 NVARCHAR(50)  NOT NULL,
    product_category_name      NVARCHAR(100) NULL,     -- 610 products have no category
    product_name_lenght        INT           NULL,     -- misspelling is from the source
    product_description_lenght INT           NULL,
    product_photos_qty         INT           NULL,
    product_weight_g           INT           NULL,
    product_length_cm          INT           NULL,
    product_height_cm          INT           NULL,
    product_width_cm           INT           NULL,
    CONSTRAINT PK_products PRIMARY KEY (product_id)
);

CREATE TABLE sellers (
    seller_id              NVARCHAR(50)  NOT NULL,
    seller_zip_code_prefix NVARCHAR(10)  NOT NULL,
    seller_city            NVARCHAR(100) NOT NULL,
    seller_state           NCHAR(2)      NOT NULL,
    CONSTRAINT PK_sellers PRIMARY KEY (seller_id)
);

CREATE TABLE orders (
    order_id                      NVARCHAR(50) NOT NULL,
    customer_id                   NVARCHAR(50) NOT NULL,
    order_status                  NVARCHAR(20) NOT NULL,
    order_purchase_timestamp      DATETIME2    NOT NULL,
    order_approved_at             DATETIME2    NULL,   -- NULL until payment approved
    order_delivered_carrier_date  DATETIME2    NULL,   -- NULL until shipped
    order_delivered_customer_date DATETIME2    NULL,   -- NULL until delivered
    order_estimated_delivery_date DATETIME2    NOT NULL,
    CONSTRAINT PK_orders PRIMARY KEY (order_id)
);

CREATE TABLE order_items (
    order_id            NVARCHAR(50)  NOT NULL,
    order_item_id       TINYINT       NOT NULL,
    product_id          NVARCHAR(50)  NOT NULL,
    seller_id           NVARCHAR(50)  NOT NULL,
    shipping_limit_date DATETIME2     NOT NULL,
    price               DECIMAL(10,2) NOT NULL,
    freight_value       DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_order_items PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id             NVARCHAR(50)  NOT NULL,
    payment_sequential   INT           NOT NULL,
    payment_type         NVARCHAR(20)  NOT NULL,
    payment_installments INT           NOT NULL,
    payment_value        DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_order_payments PRIMARY KEY (order_id, payment_sequential)
);

/* Neither review_id nor order_id is unique on its own (see docs/04_issue_log.md),
   so the key is the pair. */
CREATE TABLE order_reviews (
    review_id               NVARCHAR(50) NOT NULL,
    order_id                NVARCHAR(50) NOT NULL,
    review_score            TINYINT      NOT NULL,
    review_creation_date    DATETIME2    NOT NULL,
    review_answer_timestamp DATETIME2    NOT NULL,
    CONSTRAINT PK_order_reviews PRIMARY KEY (review_id, order_id),
    CONSTRAINT CK_review_score CHECK (review_score BETWEEN 1 AND 5)
);
GO

/* ----------------------------------------------------------------------------
   Load the CSVs (SQL Server 2017+ for FORMAT = 'CSV').
   Change the folder path to where your CSVs live. The path must be readable
   by the SQL Server service account. If BULK INSERT is blocked, use
   Tasks > Import Flat File instead and keep the column types above.
   ---------------------------------------------------------------------------- */
SET DATEFORMAT mdy;   -- the reviews file stores dates as m/d/yyyy

/* Line endings differ between the files. Six use LF only ('0x0a'); the
   translation and reviews files use Windows CRLF ('\r\n'). If a load fails
   with a conversion or truncation error on the LAST column, swap that file's
   ROWTERMINATOR (Excel re-saves files with CRLF). */
BULK INSERT customers            FROM 'C:\olist_data\olist_customers_dataset.csv'            WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a');
BULK INSERT category_translation FROM 'C:\olist_data\product_category_name_translation.csv'  WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '\r\n');
BULK INSERT products             FROM 'C:\olist_data\olist_products_dataset.csv'             WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a');
BULK INSERT sellers              FROM 'C:\olist_data\olist_sellers_dataset.csv'              WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a');
BULK INSERT orders               FROM 'C:\olist_data\olist_orders_dataset.csv'               WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a');
BULK INSERT order_items          FROM 'C:\olist_data\olist_order_items_dataset.csv'          WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a');
BULK INSERT order_payments       FROM 'C:\olist_data\olist_order_payments_dataset.csv'       WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a');
BULK INSERT order_reviews        FROM 'C:\olist_data\olist_order_reviews_dataset.csv'        WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '\r\n');
GO

/* ----------------------------------------------------------------------------
   Load check: compare against the CSV row counts.
   Expected: customers 99,441 | category_translation 71 | products 32,951
             sellers 3,095 | orders 99,441 | order_items 112,650
             order_payments 103,886 | order_reviews 99,224
   ---------------------------------------------------------------------------- */
SELECT 'customers' AS table_name, COUNT(*) AS total_rows FROM customers
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation
UNION ALL SELECT 'products',             COUNT(*) FROM products
UNION ALL SELECT 'sellers',              COUNT(*) FROM sellers
UNION ALL SELECT 'orders',               COUNT(*) FROM orders
UNION ALL SELECT 'order_items',          COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments',       COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',        COUNT(*) FROM order_reviews;
