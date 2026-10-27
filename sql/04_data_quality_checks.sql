/* ============================================================================
   04_data_quality_checks.sql
   Five checks on every table before any KPI is reported.
   ----------------------------------------------------------------------------
   1. Completeness  - missing values
   2. Uniqueness    - duplicate keys
   3. Validity      - values in an allowed range
   4. Consistency   - dates in a logical order
   5. Integrity     - every child row has a parent
   "Expected" = the result on the full Kaggle dataset. Each finding and the
   decision taken is logged in docs/04_issue_log.md (DQ-xx ids below).
   ============================================================================ */
USE Olist_Retail_DB;
GO

/* ---------------------------------------------------------------------------
   1. COMPLETENESS
   --------------------------------------------------------------------------- */

-- 1a. NULLs in the order date columns, by status.
--     Expected: NULL dates are normal for orders not yet shipped/delivered.
SELECT
    order_status,
    COUNT(*)                                                             AS orders,
    SUM(CASE WHEN order_approved_at             IS NULL THEN 1 ELSE 0 END) AS no_approved_date,
    SUM(CASE WHEN order_delivered_carrier_date  IS NULL THEN 1 ELSE 0 END) AS no_carrier_date,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS no_delivery_date
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- 1b. DQ-03: delivered orders with no delivery date.            Expected: 8
SELECT COUNT(*) AS delivered_missing_delivery_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- 1c. DQ-04: products with no category.                         Expected: 610
SELECT COUNT(*) AS products_no_category
FROM products
WHERE product_category_name IS NULL;

-- 1d. DQ-05: categories with no English translation.            Expected: 2
--     (pc_gamer, portateis_cozinha_e_preparadores_de_alimentos)
--     Returns 0 rows once 03_foreign_keys.sql step 2 has added them.
SELECT DISTINCT p.product_category_name
FROM products AS p
LEFT JOIN category_translation AS ct
    ON ct.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;

-- 1e. DQ-08: orders with no items.                              Expected: 775
--     (almost all are canceled/unavailable orders)
SELECT o.order_status, COUNT(*) AS orders_without_items
FROM orders AS o
WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id)
GROUP BY o.order_status
ORDER BY orders_without_items DESC;

-- 1f. DQ-09: delivered orders with no review.                   Expected: 646
SELECT COUNT(*) AS delivered_no_review
FROM orders AS o
WHERE o.order_status = 'delivered'
  AND NOT EXISTS (SELECT 1 FROM order_reviews r WHERE r.order_id = o.order_id);

/* ---------------------------------------------------------------------------
   2. UNIQUENESS
   --------------------------------------------------------------------------- */

-- 2a. DQ-06: orders with more than one review.                  Expected: 547
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) AS x;

-- 2b. DQ-06: review_ids attached to more than one order.        Expected: 789
SELECT COUNT(*) AS review_ids_on_multiple_orders
FROM (SELECT review_id FROM order_reviews GROUP BY review_id HAVING COUNT(*) > 1) AS x;

-- 2c. Duplicate (review_id, order_id) pairs.                    Expected: 0
--     -> the pair is safe to use as the primary key.
SELECT COUNT(*) AS duplicate_pairs
FROM (SELECT review_id, order_id FROM order_reviews
      GROUP BY review_id, order_id HAVING COUNT(*) > 1) AS x;

-- 2d. DQ-07: real customers (customer_unique_id) with more than one customer_id.
--     Expected: 2,997 -> customer_id is per order.
SELECT COUNT(*) AS people_with_multiple_customer_ids
FROM (SELECT customer_unique_id FROM customers
      GROUP BY customer_unique_id HAVING COUNT(*) > 1) AS x;

/* ---------------------------------------------------------------------------
   3. VALIDITY
   --------------------------------------------------------------------------- */

-- 3a. Prices, freight and review scores in range.
--     Expected: price_zero_or_less 0 | free_freight 383 | bad_scores 0
SELECT
    (SELECT COUNT(*) FROM order_items   WHERE price <= 0)                     AS price_zero_or_less,
    (SELECT COUNT(*) FROM order_items   WHERE freight_value = 0)              AS free_freight,
    (SELECT COUNT(*) FROM order_reviews WHERE review_score NOT BETWEEN 1 AND 5) AS bad_scores;

-- 3b. DQ-10: odd payment rows.
--     Expected: zero_value 9 | zero_installments 2 | not_defined 3
SELECT
    SUM(CASE WHEN payment_value = 0           THEN 1 ELSE 0 END) AS zero_value,
    SUM(CASE WHEN payment_installments = 0    THEN 1 ELSE 0 END) AS zero_installments,
    SUM(CASE WHEN payment_type = 'not_defined' THEN 1 ELSE 0 END) AS not_defined
FROM order_payments;

-- 3c. Date range of purchases.
--     Expected: 2016-09-04 to 2018-10-17 (delivered orders end Aug 2018)
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order,
       MAX(CASE WHEN order_status = 'delivered' THEN order_purchase_timestamp END) AS last_delivered_order
FROM orders;

/* ---------------------------------------------------------------------------
   4. CONSISTENCY
   --------------------------------------------------------------------------- */

-- 4a. Dates out of order.
--     Expected: delivered_before_purchase 0 | carrier_before_purchase 166
--               delivered_before_carrier 23
SELECT
    SUM(CASE WHEN order_delivered_customer_date < order_purchase_timestamp     THEN 1 ELSE 0 END) AS delivered_before_purchase,
    SUM(CASE WHEN order_delivered_carrier_date  < order_purchase_timestamp     THEN 1 ELSE 0 END) AS carrier_before_purchase,
    SUM(CASE WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 1 ELSE 0 END) AS delivered_before_carrier
FROM orders;

-- 4b. DQ-11: revenue reconciliation, items vs payments (delivered orders).
--     Expected: items 15,419,773.75 | payments 15,422,461.77 | diff 2,688.02
SELECT
    (SELECT SUM(oi.price + oi.freight_value)
     FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
     WHERE o.order_status = 'delivered')                                   AS item_revenue,
    (SELECT SUM(p.payment_value)
     FROM order_payments p JOIN orders o ON o.order_id = p.order_id
     WHERE o.order_status = 'delivered')                                   AS payment_revenue;

/* ---------------------------------------------------------------------------
   5. REFERENTIAL INTEGRITY  (all expected 0)
   --------------------------------------------------------------------------- */
SELECT
    (SELECT COUNT(*) FROM order_items oi   LEFT JOIN orders    o ON o.order_id    = oi.order_id   WHERE o.order_id    IS NULL) AS items_no_order,
    (SELECT COUNT(*) FROM order_items oi   LEFT JOIN products  p ON p.product_id  = oi.product_id WHERE p.product_id  IS NULL) AS items_no_product,
    (SELECT COUNT(*) FROM order_items oi   LEFT JOIN sellers   s ON s.seller_id   = oi.seller_id  WHERE s.seller_id   IS NULL) AS items_no_seller,
    (SELECT COUNT(*) FROM orders o         LEFT JOIN customers c ON c.customer_id = o.customer_id WHERE c.customer_id IS NULL) AS orders_no_customer,
    (SELECT COUNT(*) FROM order_reviews r  LEFT JOIN orders    o ON o.order_id    = r.order_id    WHERE o.order_id    IS NULL) AS reviews_no_order,
    (SELECT COUNT(*) FROM order_payments p LEFT JOIN orders    o ON o.order_id    = p.order_id    WHERE o.order_id    IS NULL) AS payments_no_order;
