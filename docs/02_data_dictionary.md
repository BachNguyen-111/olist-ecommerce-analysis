# Data Dictionary — Olist_Retail_DB

Source: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle). Profiled from the raw CSVs. Currency is Brazilian real (R$).

See the [ERD](02_erd.png) for how the tables join.

## Tables at a glance

| Table | One row = | Primary key | Rows |
| --- | --- | --- | --- |
| orders | One row per order (the fact table) | order_id | 99,441 |
| order_items | One row per item in an order | order_id + order_item_id | 112,650 |
| customers | One row per customer_id, which means one row per order | customer_id | 99,441 |
| products | One row per product | product_id | 32,951 |
| order_reviews | One review left for one order | review_id + order_id | 99,224 |
| order_payments | One payment on an order | order_id + payment_sequential | 103,886 |
| sellers | One row per seller | seller_id | 3,095 |
| category_translation | One row per category: Portuguese name to English name | product_category_name | 71 |

## Why grain matters

Joining `orders` to `order_items` gives one row per **item**, not per order. Counting rows after that join overstates orders by about 14% (110,197 items vs 96,478 delivered orders, so 14.2% more rows than orders). Every query therefore uses `COUNT(DISTINCT order_id)` to count orders.

Likewise, `customer_id` is new on every order. Use `customer_unique_id` to count real customers.

## orders

One row per order (the fact table). Primary key: **order_id**. Rows: 99,441.

| Column | SQL type | Meaning | Nulls | Distinct values | Example |
| --- | --- | --- | --- | --- | --- |
| order_id | NVARCHAR(50) | Unique order ID | 0 | 99,441 | `e481f51cbdc54678b7cc49136f2d6af7` |
| customer_id | NVARCHAR(50) | Links to customers; a new customer_id is created for every order | 0 | 99,441 | `9ef432eb6251297304e76186b10a928d` |
| order_status | NVARCHAR(50) | delivered, shipped, canceled, unavailable, invoiced, processing, created, approved | 0 | 8 | `delivered` |
| order_purchase_timestamp | DATETIME2 | When the customer placed the order | 0 | 98,875 | `2017-10-02 10:56:33` |
| order_approved_at | DATETIME2 | When payment was approved | 160 | 90,733 | `2017-10-02 11:07:15` |
| order_delivered_carrier_date | DATETIME2 | When the seller handed the order to the carrier | 1,783 | 81,018 | `2017-10-04 19:55:00` |
| order_delivered_customer_date | DATETIME2 | When the customer received the order | 2,965 | 95,664 | `2017-10-10 21:25:13` |
| order_estimated_delivery_date | DATETIME2 | Delivery date promised to the customer at purchase | 0 | 459 | `2017-10-18 00:00:00` |

## order_items

One row per item in an order. An order with 3 items has 3 rows. Primary key: **order_id + order_item_id**. Rows: 112,650.

| Column | SQL type | Meaning | Nulls | Distinct values | Example |
| --- | --- | --- | --- | --- | --- |
| order_id | NVARCHAR(50) | Links to orders | 0 | 98,666 | `00010242fe8c5a6d1ba2dd792cb16214` |
| order_item_id | TINYINT | Item number within the order (1, 2, 3…) | 0 | 21 | `1` |
| product_id | NVARCHAR(50) | Links to products | 0 | 32,951 | `4244733e06e7ecb4970a6e2683c13e61` |
| seller_id | NVARCHAR(50) | Links to sellers | 0 | 3,095 | `48436dade18ac8b2bce089ec2a041202` |
| shipping_limit_date | DATETIME2 | Deadline for the seller to hand the item to the carrier | 0 | 93,318 | `2017-09-19 09:45:35` |
| price | DECIMAL(10,2) | Item price in R$ | 0 | 5,968 | `58.9` |
| freight_value | DECIMAL(10,2) | Shipping charged for this item in R$ | 0 | 6,999 | `13.29` |

## customers

One row per customer_id, which means one row per order. Primary key: **customer_id**. Rows: 99,441.

| Column | SQL type | Meaning | Nulls | Distinct values | Example |
| --- | --- | --- | --- | --- | --- |
| customer_id | NVARCHAR(50) | Key used by orders | 0 | 99,441 | `06b8999e2fba1a1fbc88172c00ba8bc7` |
| customer_unique_id | NVARCHAR(50) | The real person; use this to count customers and repeat buyers | 0 | 96,096 | `861eff4711a542e4b93843c6dd7febb0` |
| customer_zip_code_prefix | NVARCHAR(10) | First 5 digits of the ZIP code (keep as text to preserve leading zeros) | 0 | 14,994 | `14409` |
| customer_city | NVARCHAR(100) | City | 0 | 4,119 | `franca` |
| customer_state | NCHAR(2) | State code, e.g. SP | 0 | 27 | `SP` |

## products

One row per product. Primary key: **product_id**. Rows: 32,951.

| Column | SQL type | Meaning | Nulls | Distinct values | Example |
| --- | --- | --- | --- | --- | --- |
| product_id | NVARCHAR(50) | Unique product ID | 0 | 32,951 | `1e9e8ef04dbcff4541ed26657ea517e5` |
| product_category_name | NVARCHAR(100) | Category in Portuguese; links to category_translation | 610 | 73 | `perfumaria` |
| product_name_lenght | INT | Characters in the product name (column name is misspelled in the source) | 610 | 66 | `40` |
| product_description_lenght | INT | Characters in the description (misspelled in the source) | 610 | 2,960 | `287` |
| product_photos_qty | INT | Number of product photos | 610 | 19 | `1` |
| product_weight_g | INT | Weight in grams | 2 | 2,204 | `225` |
| product_length_cm | INT | Length in cm | 2 | 99 | `16` |
| product_height_cm | INT | Height in cm | 2 | 102 | `10` |
| product_width_cm | INT | Width in cm | 2 | 95 | `14` |

## order_reviews

One review left for one order. Some orders have several reviews, and some review IDs cover several orders. Primary key: **review_id + order_id**. Rows: 99,224.

| Column | SQL type | Meaning | Nulls | Distinct values | Example |
| --- | --- | --- | --- | --- | --- |
| review_id | NVARCHAR(50) | Review ID (not unique by itself) | 0 | 98,410 | `7bc2406110b926393aa56f80a40eba40` |
| order_id | NVARCHAR(50) | Links to orders (not unique by itself) | 0 | 98,673 | `73fc7af87114b39712e6da79b0a377eb` |
| review_score | TINYINT | Stars, 1 to 5 | 0 | 5 | `4` |
| review_creation_date | DATETIME2 | When the review survey was sent | 0 | 636 | `1/18/2018 0:00` |
| review_answer_timestamp | DATETIME2 | When the customer answered | 0 | 88,867 | `1/18/2018 21:46` |

## order_payments

One payment on an order. Orders can be split across payment methods or vouchers. Primary key: **order_id + payment_sequential**. Rows: 103,886.

| Column | SQL type | Meaning | Nulls | Distinct values | Example |
| --- | --- | --- | --- | --- | --- |
| order_id | NVARCHAR(50) | Links to orders | 0 | 99,440 | `b81ef226f3fe1789b1e8b2acac839d17` |
| payment_sequential | INT | Payment number within the order | 0 | 29 | `1` |
| payment_type | NVARCHAR(20) | credit_card, boleto, voucher, debit_card, not_defined | 0 | 5 | `credit_card` |
| payment_installments | INT | Number of installments chosen | 0 | 24 | `8` |
| payment_value | DECIMAL(10,2) | Amount paid in R$ | 0 | 29,077 | `99.33` |

## sellers

One row per seller. Primary key: **seller_id**. Rows: 3,095.

| Column | SQL type | Meaning | Nulls | Distinct values | Example |
| --- | --- | --- | --- | --- | --- |
| seller_id | NVARCHAR(50) | Unique seller ID | 0 | 3,095 | `3442f8959a84dea7ee197c632cb2df15` |
| seller_zip_code_prefix | NVARCHAR(10) | First 5 digits of the ZIP code | 0 | 2,246 | `13023` |
| seller_city | NVARCHAR(100) | City | 0 | 611 | `campinas` |
| seller_state | NCHAR(2) | State code | 0 | 23 | `SP` |

## category_translation

One row per category: Portuguese name to English name. Primary key: **product_category_name**. Rows: 71.

| Column | SQL type | Meaning | Nulls | Distinct values | Example |
| --- | --- | --- | --- | --- | --- |
| product_category_name | NVARCHAR(100) | Category in Portuguese | 0 | 71 | `beleza_saude` |
| product_category_name_english | NVARCHAR(100) | Category in English (renamed english_name in Olist_Retail_DB) | 0 | 71 | `health_beauty` |
