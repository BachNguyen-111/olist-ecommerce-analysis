/* ============================================================================
   05_analysis.sql
   Olist E-Commerce Analysis: one query per business question (SQL Server)
   ----------------------------------------------------------------------------
   Business rules (from docs/01_project_charter.md, same as the dashboard):
     - Scope    : delivered orders only (order_status = 'delivered')
     - Revenue  : item price + freight_value, from order_items
     - On time  : delivered on or before the estimated date, by calendar day
     - Customer : customer_unique_id (customer_id changes on every order)
   "Expected" values are the results on the full Kaggle dataset, used to
   check that the Power BI cards match (see sql/05_results.md).
   Queries 12-13 need the sellers table loaded (see 03_create_tables.sql).

   Question map (docs/01_project_charter.md):
     Q1 revenue & AOV ........... Query 3      Q5 repeat customers ...... Query 5
     Q2 monthly trend ........... Query 7      Q6 top categories ........ Query 6
     Q3 slow / late states ...... Query 4, 9   Q7 why orders are late ... Query 12, 13
     Q4 lateness vs reviews ..... Query 8, 10, 14     Peaks ............. Query 11
   ============================================================================ */
USE Olist_Retail_DB;
GO

/* ----------------------------------------------------------------------------
   Query 1: Row-count sanity check (all 8 tables)
   Expected: orders 99,441 | order_items 112,650 | customers 99,441
             products 32,951 | category_translation 71 (73 after DQ-05 fix)
             order_reviews 99,224 | sellers 3,095 | order_payments 103,886
   ---------------------------------------------------------------------------- */
SELECT 'orders'               AS table_name, COUNT(*) AS total_rows FROM orders
UNION ALL
SELECT 'order_items',                        COUNT(*)               FROM order_items
UNION ALL
SELECT 'customers',                          COUNT(*)               FROM customers
UNION ALL
SELECT 'products',                           COUNT(*)               FROM products
UNION ALL
SELECT 'category_translation',               COUNT(*)               FROM category_translation
UNION ALL
SELECT 'order_reviews',                      COUNT(*)               FROM order_reviews
UNION ALL
SELECT 'sellers',                            COUNT(*)               FROM sellers
UNION ALL
SELECT 'order_payments',                     COUNT(*)               FROM order_payments;


/* ----------------------------------------------------------------------------
   Query 2: Order-status audit (justifies the delivered-only scope, DQ-01)
   Expected: delivered 96,478 (97.02%) | shipped 1,107 | canceled 625
             unavailable 609 | invoiced 314 | processing 301 | created 5 | approved 2
   ---------------------------------------------------------------------------- */
SELECT
    order_status,
    COUNT(*)                                                         AS total_orders,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))   AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;


/* ----------------------------------------------------------------------------
   Query 3 -- Answers Q1: How much revenue do delivered orders bring in?
   Expected: 96,478 orders | 110,197 items | revenue R$15,419,773.75
             (product R$13,221,498.11 + shipping R$2,198,275.64) | AOV R$159.83
   ---------------------------------------------------------------------------- */
SELECT
    COUNT(DISTINCT o.order_id)                                          AS total_delivered_orders,
    COUNT(*)                                                            AS total_items_sold,
    CAST(SUM(oi.price + oi.freight_value) AS DECIMAL(12,2))             AS total_revenue,
    CAST(SUM(oi.price)                    AS DECIMAL(12,2))             AS product_revenue,
    CAST(SUM(oi.freight_value)            AS DECIMAL(12,2))             AS shipping_revenue,
    CAST(SUM(oi.price + oi.freight_value)
         / COUNT(DISTINCT o.order_id)     AS DECIMAL(10,2))             AS avg_order_value
FROM orders      AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';


/* ----------------------------------------------------------------------------
   Query 4 -- Answers Q3: Which states have the slowest, least reliable delivery?
   States with fewer than 500 orders are excluded so tiny samples don't top
   the ranking.
   Expected (worst 3): MA 82.57% on time, 21.5 days | CE 86.24%, 21.2 days
                       BA 87.84%, 19.3 days. Brazil overall: 93.23%, 12.5 days
   ---------------------------------------------------------------------------- */
SELECT
    c.customer_state,
    COUNT(*)                                                           AS delivered_orders,
    CAST(AVG(CAST(DATEDIFF(DAY, o.order_purchase_timestamp,
                                o.order_delivered_customer_date)
                  AS DECIMAL(10,2))) AS DECIMAL(5,1))                   AS avg_delivery_days,
    CAST(100.0 * SUM(CASE
                        WHEN CAST(o.order_delivered_customer_date AS DATE)
                          <= CAST(o.order_estimated_delivery_date AS DATE)
                        THEN 1 ELSE 0
                     END) / COUNT(*) AS DECIMAL(5,2))                   AS on_time_pct
FROM orders    AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 500
ORDER BY on_time_pct ASC;


/* ----------------------------------------------------------------------------
   Query 5 -- Answers Q5: How many customers come back for a second order?
   Expected: 93,358 unique customers | 2,801 repeat | 3.00%
   ---------------------------------------------------------------------------- */
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM orders    AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                                                       AS total_unique_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)               AS repeat_customers,
    CAST(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,2))                               AS repeat_customer_pct
FROM customer_orders;


/* ----------------------------------------------------------------------------
   Query 6 -- Answers Q6: Which categories drive the most revenue?
   Untranslated categories fall back to the Portuguese name (DQ-05).
   Expected (top 3 by product revenue): health_beauty R$1,233,131.72
            watches_gifts R$1,166,176.98 | bed_bath_table R$1,023,434.76
   ---------------------------------------------------------------------------- */
SELECT TOP 10
    COALESCE(ct.english_name, p.product_category_name, 'uncategorized') AS category,
    COUNT(DISTINCT o.order_id)                                          AS total_orders,
    CAST(SUM(oi.price)                    AS DECIMAL(12,2))             AS product_revenue,
    CAST(SUM(oi.freight_value)            AS DECIMAL(12,2))             AS shipping_revenue,
    CAST(SUM(oi.price + oi.freight_value) AS DECIMAL(12,2))             AS total_revenue
FROM orders                      AS o
JOIN order_items                 AS oi ON oi.order_id   = o.order_id
JOIN products                    AS p  ON p.product_id  = oi.product_id
LEFT JOIN category_translation   AS ct ON ct.product_category_name = p.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY COALESCE(ct.english_name, p.product_category_name, 'uncategorized')
ORDER BY product_revenue DESC;


/* ----------------------------------------------------------------------------
   Query 7 -- Answers Q2: How is revenue trending month to month?
   Expected: Jan 2017 R$127,482.37 -> peak Nov 2017 R$1,153,364.20
             (Black Friday) -> Jan-Aug 2018 about R$1.06M a month
   ---------------------------------------------------------------------------- */
SELECT
    DATEFROMPARTS(YEAR(o.order_purchase_timestamp),
                  MONTH(o.order_purchase_timestamp), 1)              AS order_month,
    COUNT(DISTINCT o.order_id)                                       AS delivered_orders,
    CAST(SUM(oi.price + oi.freight_value) AS DECIMAL(12,2))          AS total_revenue
FROM orders      AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATEFROMPARTS(YEAR(o.order_purchase_timestamp),
                       MONTH(o.order_purchase_timestamp), 1)
ORDER BY order_month;


/* ----------------------------------------------------------------------------
   Query 8 -- Answers Q4: Does late delivery hurt review scores?
   Some orders have several reviews, so average per order first (DQ-06).
   Expected: On time 89,443 orders, 4.29 | 1-3 days late 1,852, 3.29
             4-7 days late 1,748, 2.11 | 8+ days late 2,781, 1.70
   ---------------------------------------------------------------------------- */
WITH review_per_order AS (
    SELECT order_id, AVG(CAST(review_score AS DECIMAL(4,2))) AS avg_score
    FROM order_reviews
    GROUP BY order_id
),
delivery_outcome AS (
    SELECT
        o.order_id,
        CASE
            WHEN DATEDIFF(DAY, o.order_estimated_delivery_date,
                               o.order_delivered_customer_date) <= 0  THEN '1. On time'
            WHEN DATEDIFF(DAY, o.order_estimated_delivery_date,
                               o.order_delivered_customer_date) <= 3  THEN '2. 1-3 days late'
            WHEN DATEDIFF(DAY, o.order_estimated_delivery_date,
                               o.order_delivered_customer_date) <= 7  THEN '3. 4-7 days late'
            ELSE '4. 8+ days late'
        END AS outcome
    FROM orders AS o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    d.outcome,
    COUNT(*)                                     AS orders,
    CAST(AVG(r.avg_score) AS DECIMAL(3,2))       AS avg_review_score
FROM delivery_outcome AS d
JOIN review_per_order AS r
    ON r.order_id = d.order_id
GROUP BY d.outcome
ORDER BY d.outcome;


/* ----------------------------------------------------------------------------
   Query 9 -- Supports Q3/Q4: Are late orders concentrated in a few states?
   Compares each state's share of orders with its share of late orders.
   Expected: RJ is 12.8% of orders but 22.9% of late orders. The 7 states
             below 90% on time (MA, CE, BA, RJ, PA, ES, PB) are 21.8% of
             orders but 39.3% of late orders.
   ---------------------------------------------------------------------------- */
WITH delivered AS (
    SELECT
        c.customer_state,
        CASE WHEN CAST(o.order_delivered_customer_date AS DATE)
                > CAST(o.order_estimated_delivery_date AS DATE)
             THEN 1 ELSE 0 END AS is_late
    FROM orders    AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    customer_state,
    COUNT(*)                                                            AS orders,
    SUM(is_late)                                                        AS late_orders,
    CAST(100.0 * COUNT(*)     / SUM(COUNT(*))     OVER () AS DECIMAL(5,1)) AS pct_of_orders,
    CAST(100.0 * SUM(is_late) / SUM(SUM(is_late)) OVER () AS DECIMAL(5,1)) AS pct_of_late_orders
FROM delivered
GROUP BY customer_state
ORDER BY late_orders DESC;


/* ----------------------------------------------------------------------------
   Query 10 -- Supports Q4: How much of the bad-review problem is lateness?
   Expected: late orders are 6.7% of reviewed orders but 32.5% of
             orders with an average review of 2 stars or less.
   ---------------------------------------------------------------------------- */
WITH review_per_order AS (
    SELECT order_id, AVG(CAST(review_score AS DECIMAL(4,2))) AS avg_score
    FROM order_reviews
    GROUP BY order_id
),
scored AS (
    SELECT
        CASE WHEN CAST(o.order_delivered_customer_date AS DATE)
                > CAST(o.order_estimated_delivery_date AS DATE)
             THEN 1 ELSE 0 END                 AS is_late,
        CASE WHEN r.avg_score <= 2 THEN 1 ELSE 0 END AS is_bad_review
    FROM orders AS o
    JOIN review_per_order AS r ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    CAST(100.0 * AVG(CAST(is_late AS DECIMAL(5,2)))                    AS DECIMAL(5,1)) AS pct_orders_late,
    CAST(100.0 * SUM(is_late * is_bad_review) / SUM(is_bad_review)     AS DECIMAL(5,1)) AS pct_bad_reviews_from_late_orders
FROM scored;


/* ----------------------------------------------------------------------------
   Query 11 -- Supports recommendation 2: when did late rates spike?
   Expected: late rate is usually 1-8%, but 12.4% in Nov 2017 (Black Friday),
             14.1% in Feb 2018 and 19.0% in Mar 2018.
   ---------------------------------------------------------------------------- */
SELECT
    DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1) AS order_month,
    COUNT(*)                                                                         AS delivered_orders,
    CAST(100.0 * SUM(CASE WHEN CAST(order_delivered_customer_date AS DATE)
                             > CAST(order_estimated_delivery_date AS DATE)
                          THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1))             AS late_rate_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
GROUP BY DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1)
ORDER BY order_month;


/* ----------------------------------------------------------------------------
   Query 12 -- Answers Q7: Do orders shipped from another state arrive late?
   An order counts as cross-state if any of its sellers is in a different
   state from the customer.
   Expected: cross-state 61,895 orders (64.2%), 15.1 days, 8.0% late,
             76.1% of all late orders | same state 34,575 orders (35.8%),
             7.9 days, 4.5% late
   ---------------------------------------------------------------------------- */
WITH order_route AS (
    SELECT
        o.order_id,
        MAX(CASE WHEN s.seller_state <> c.customer_state THEN 1 ELSE 0 END) AS is_cross_state
    FROM orders      AS o
    JOIN customers   AS c  ON c.customer_id = o.customer_id
    JOIN order_items AS oi ON oi.order_id   = o.order_id
    JOIN sellers     AS s  ON s.seller_id   = oi.seller_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY o.order_id
),
scored AS (
    SELECT
        r.is_cross_state,
        DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_days,
        DATEDIFF(DAY, o.order_purchase_timestamp, o.order_estimated_delivery_date) AS promised_days,
        CASE WHEN CAST(o.order_delivered_customer_date AS DATE)
                > CAST(o.order_estimated_delivery_date AS DATE)
             THEN 1 ELSE 0 END AS is_late
    FROM order_route AS r
    JOIN orders      AS o ON o.order_id = r.order_id
)
SELECT
    CASE WHEN is_cross_state = 1 THEN 'Seller in another state'
         ELSE 'Seller in same state' END                                     AS route,
    COUNT(*)                                                                 AS orders,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER ()          AS DECIMAL(5,1))  AS pct_of_orders,
    CAST(AVG(CAST(delivery_days AS DECIMAL(10,2)))         AS DECIMAL(5,1))  AS avg_delivery_days,
    CAST(AVG(CAST(promised_days AS DECIMAL(10,2)))         AS DECIMAL(5,1))  AS avg_promised_days,
    CAST(100.0 * SUM(is_late) / COUNT(*)                   AS DECIMAL(5,1))  AS late_rate_pct,
    CAST(100.0 * SUM(is_late) / SUM(SUM(is_late)) OVER () AS DECIMAL(5,1))  AS pct_of_late_orders
FROM scored
GROUP BY is_cross_state
ORDER BY is_cross_state DESC;


/* ----------------------------------------------------------------------------
   Query 13 -- Answers Q7: Where does the delay happen?
   Splits delivery time into seller handling (purchase -> handed to carrier)
   and carrier transit (carrier -> customer). Same split as the Power BI
   measures Avg Seller To Carrier Days and Avg Carrier To Customer Days.
   Expected: on time 89,936 orders: seller 3.0 days, carrier 7.9, promised 24.5
             late     6,533 orders: seller 6.0 days, carrier 27.9, promised 23.3
   (166 orders have a carrier date before purchase, DQ-12; they are kept.)
   ---------------------------------------------------------------------------- */
WITH stages AS (
    SELECT
        CASE WHEN CAST(o.order_delivered_customer_date AS DATE)
                > CAST(o.order_estimated_delivery_date AS DATE)
             THEN 'Late' ELSE 'On time' END                                                   AS delivery_status,
        DATEDIFF(DAY, o.order_purchase_timestamp,     o.order_delivered_carrier_date)  AS seller_days,
        DATEDIFF(DAY, o.order_delivered_carrier_date, o.order_delivered_customer_date) AS carrier_days,
        DATEDIFF(DAY, o.order_purchase_timestamp,     o.order_estimated_delivery_date) AS promised_days
    FROM orders AS o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_delivered_carrier_date  IS NOT NULL
)
SELECT
    delivery_status,
    COUNT(*)                                                        AS orders,
    CAST(AVG(CAST(seller_days   AS DECIMAL(10,2))) AS DECIMAL(5,1)) AS avg_seller_days,
    CAST(AVG(CAST(carrier_days  AS DECIMAL(10,2))) AS DECIMAL(5,1)) AS avg_carrier_days,
    CAST(AVG(CAST(promised_days AS DECIMAL(10,2))) AS DECIMAL(5,1)) AS avg_promised_days
FROM stages
GROUP BY delivery_status
ORDER BY delivery_status DESC;


/* ----------------------------------------------------------------------------
   Query 14 -- Supports Q4: How much revenue comes from late orders?
   Same rule as the Power BI measure Late Revenue.
   Expected: 6,534 late orders | R$1,150,892.13 | 7.5% of delivered revenue
             (R$15,418,394.83 for orders with a delivery date)
   ---------------------------------------------------------------------------- */
WITH order_revenue AS (
    SELECT
        o.order_id,
        CASE WHEN CAST(o.order_delivered_customer_date AS DATE)
                > CAST(o.order_estimated_delivery_date AS DATE)
             THEN 1 ELSE 0 END                AS is_late,
        SUM(oi.price + oi.freight_value)      AS revenue
    FROM orders      AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY o.order_id, o.order_delivered_customer_date, o.order_estimated_delivery_date
)
SELECT
    SUM(is_late)                                                              AS late_orders,
    CAST(SUM(CASE WHEN is_late = 1 THEN revenue ELSE 0 END) AS DECIMAL(12,2)) AS late_revenue,
    CAST(SUM(revenue)                                        AS DECIMAL(12,2)) AS delivered_revenue,
    CAST(100.0 * SUM(CASE WHEN is_late = 1 THEN revenue ELSE 0 END)
         / SUM(revenue)                                      AS DECIMAL(5,1))  AS late_revenue_pct
FROM order_revenue;
