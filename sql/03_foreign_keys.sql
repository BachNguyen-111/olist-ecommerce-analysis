/* ============================================================================
   03_foreign_keys.sql
   ----------------------------------------------------------------------------
   Foreign keys document how tables join (matches docs/02_erd.png) and stop
   bad rows from being inserted later. Every orphan check in
   sql/04_data_quality_checks.sql (section 5) returned 0.
   ============================================================================ */
USE Olist_Retail_DB;
GO

/* ----------------------------------------------------------------------------
   Step 0: the Import Flat File wizard loads columns as nullable, and a
   primary key can't be built on a nullable column (Msg 8111). Make the
   order_items key columns NOT NULL, then add the two keys the FKs depend on.
   Skipped if the key already exists (for example after 03_create_tables.sql),
   because a column that is part of a primary key can't be altered.
   ---------------------------------------------------------------------------- */
IF OBJECTPROPERTY(OBJECT_ID('order_items'), 'TableHasPrimaryKey') = 0
BEGIN
    ALTER TABLE order_items ALTER COLUMN order_id      NVARCHAR(50) NOT NULL;
    ALTER TABLE order_items ALTER COLUMN order_item_id TINYINT      NOT NULL;
END
GO
IF OBJECTPROPERTY(OBJECT_ID('order_items'), 'TableHasPrimaryKey') = 0
    ALTER TABLE order_items ADD CONSTRAINT PK_order_items PRIMARY KEY (order_id, order_item_id);
IF OBJECTPROPERTY(OBJECT_ID('sellers'), 'TableHasPrimaryKey') = 0
    ALTER TABLE sellers ADD CONSTRAINT PK_sellers PRIMARY KEY (seller_id);
GO

/* ----------------------------------------------------------------------------
   Step 1: make sure every table has its primary key.
   ---------------------------------------------------------------------------- */
IF OBJECTPROPERTY(OBJECT_ID('customers'), 'TableHasPrimaryKey') = 0
    ALTER TABLE customers            ADD CONSTRAINT PK_customers            PRIMARY KEY (customer_id);
IF OBJECTPROPERTY(OBJECT_ID('category_translation'), 'TableHasPrimaryKey') = 0
    ALTER TABLE category_translation ADD CONSTRAINT PK_category_translation PRIMARY KEY (product_category_name);
IF OBJECTPROPERTY(OBJECT_ID('products'), 'TableHasPrimaryKey') = 0
    ALTER TABLE products             ADD CONSTRAINT PK_products             PRIMARY KEY (product_id);
IF OBJECTPROPERTY(OBJECT_ID('sellers'), 'TableHasPrimaryKey') = 0
    ALTER TABLE sellers              ADD CONSTRAINT PK_sellers              PRIMARY KEY (seller_id);
IF OBJECTPROPERTY(OBJECT_ID('orders'), 'TableHasPrimaryKey') = 0
    ALTER TABLE orders               ADD CONSTRAINT PK_orders               PRIMARY KEY (order_id);
IF OBJECTPROPERTY(OBJECT_ID('order_items'), 'TableHasPrimaryKey') = 0
    ALTER TABLE order_items          ADD CONSTRAINT PK_order_items          PRIMARY KEY (order_id, order_item_id);
IF OBJECTPROPERTY(OBJECT_ID('order_payments'), 'TableHasPrimaryKey') = 0
    ALTER TABLE order_payments       ADD CONSTRAINT PK_order_payments       PRIMARY KEY (order_id, payment_sequential);
IF OBJECTPROPERTY(OBJECT_ID('order_reviews'), 'TableHasPrimaryKey') = 0
    ALTER TABLE order_reviews        ADD CONSTRAINT PK_order_reviews        PRIMARY KEY (review_id, order_id);
GO

/* ----------------------------------------------------------------------------
   Step 2: two Portuguese categories in products have no English row in
   category_translation, which would make the products FK fail.
   Decision logged in docs/04_issue_log.md (issue DQ-05).
   ---------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM category_translation WHERE product_category_name = 'pc_gamer')
    INSERT INTO category_translation VALUES ('pc_gamer', 'pc_gamer');
IF NOT EXISTS (SELECT 1 FROM category_translation WHERE product_category_name = 'portateis_cozinha_e_preparadores_de_alimentos')
    INSERT INTO category_translation VALUES ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_and_food_preparers');
GO

/* ----------------------------------------------------------------------------
   Step 3: foreign keys
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('FK_orders_customers') IS NULL
    ALTER TABLE orders ADD CONSTRAINT FK_orders_customers
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id);

IF OBJECT_ID('FK_order_items_orders') IS NULL
    ALTER TABLE order_items ADD CONSTRAINT FK_order_items_orders
        FOREIGN KEY (order_id) REFERENCES orders (order_id);

IF OBJECT_ID('FK_order_items_products') IS NULL
    ALTER TABLE order_items ADD CONSTRAINT FK_order_items_products
        FOREIGN KEY (product_id) REFERENCES products (product_id);

IF OBJECT_ID('FK_order_items_sellers') IS NULL
    ALTER TABLE order_items ADD CONSTRAINT FK_order_items_sellers
        FOREIGN KEY (seller_id) REFERENCES sellers (seller_id);

IF OBJECT_ID('FK_order_payments_orders') IS NULL
    ALTER TABLE order_payments ADD CONSTRAINT FK_order_payments_orders
        FOREIGN KEY (order_id) REFERENCES orders (order_id);

IF OBJECT_ID('FK_order_reviews_orders') IS NULL
    ALTER TABLE order_reviews ADD CONSTRAINT FK_order_reviews_orders
        FOREIGN KEY (order_id) REFERENCES orders (order_id);

IF OBJECT_ID('FK_products_category') IS NULL
    ALTER TABLE products ADD CONSTRAINT FK_products_category
        FOREIGN KEY (product_category_name) REFERENCES category_translation (product_category_name);
GO

/* ----------------------------------------------------------------------------
   Step 4: indexes on join and filter columns speed up 05_analysis.sql
   ---------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_orders_customer_id')
    CREATE INDEX IX_orders_customer_id  ON orders (customer_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_orders_status')
    CREATE INDEX IX_orders_status       ON orders (order_status)
        INCLUDE (order_purchase_timestamp, order_delivered_customer_date, order_estimated_delivery_date);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_order_items_product')
    CREATE INDEX IX_order_items_product ON order_items (product_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_order_items_seller')
    CREATE INDEX IX_order_items_seller  ON order_items (seller_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_order_reviews_order')
    CREATE INDEX IX_order_reviews_order ON order_reviews (order_id);
GO

/* Confirm: should list 7 foreign keys */
SELECT name                               AS foreign_key,
       OBJECT_NAME(parent_object_id)      AS child_table,
       OBJECT_NAME(referenced_object_id)  AS parent_table
FROM sys.foreign_keys
ORDER BY child_table;
