# Data

The raw CSVs are not stored in this repo because they're large (about 120 MB in total) and publicly available.

Download them from Kaggle: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).

| File | Rows | Loaded as table |
| --- | --- | --- |
| olist_orders_dataset.csv | 99,441 | orders |
| olist_order_items_dataset.csv | 112,650 | order_items |
| olist_customers_dataset.csv | 99,441 | customers |
| olist_products_dataset.csv | 32,951 | products |
| olist_order_reviews_dataset.csv | 99,224 | order_reviews |
| olist_order_payments_dataset.csv | 103,886 | order_payments |
| olist_sellers_dataset.csv | 3,095 | sellers |
| product_category_name_translation.csv | 71 | category_translation |

The geolocation file in the Kaggle download isn't used in this project.

Put the CSVs in one folder and set that path in `sql/03_create_tables.sql`.
