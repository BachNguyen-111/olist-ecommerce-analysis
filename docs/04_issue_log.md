# Data Quality Issue Log

Every problem found while checking the data, how big it is, and what was decided. Queries for each check are in [`sql/04_data_quality_checks.sql`](../sql/04_data_quality_checks.sql).

**Bottom line:** the data is clean enough to report on. Referential integrity is perfect (0 orphan rows in every join), and no issue changes a headline KPI by more than 0.01%. The decisions below make the rules explicit so SQL and Power BI agree.

## Source data issues

| ID | Issue | Rows affected | Impact | Decision |
| --- | --- | --- | --- | --- |
| DQ-01 | Only 97.0% of orders are delivered; the rest are shipped, canceled, unavailable, invoiced, processing, created or approved | 2,963 of 99,441 orders | Including them would count revenue that was never fulfilled | Analyze `order_status = 'delivered'` only (Query 2 shows the split) |
| DQ-02 | Delivered orders stop in Aug 2018; Sep–Oct 2018 only has canceled/in-progress orders | 0 delivered orders after 2018-08-29 | A trend chart through Oct 2018 would show a false collapse | Report period is Sep 2016 – Aug 2018 |
| DQ-03 | Delivered orders with no customer delivery date | 8 orders | Can't measure delivery time | Keep in revenue KPIs; exclude from delivery and on-time KPIs |
| DQ-04 | Products with no category | 610 products (1,537 delivered items) | Category chart would show a blank bar | Label as `uncategorized` |
| DQ-05 | Two Portuguese categories have no English translation (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`) | 22 delivered items | Blank category names; products FK fails | Add both rows to `category_translation` (see `03_foreign_keys.sql`); queries also fall back to the Portuguese name |
| DQ-06 | Reviews have no single-column key: 547 orders have 2+ reviews and 789 review_ids cover 2+ orders | ~1,300 rows | Joining raw reviews double-counts orders | Primary key = (review_id, order_id). Average the score per order before joining (Query 8) |
| DQ-07 | `customer_id` is new on every order; 2,997 real customers have more than one | 2,997 people | Counting customer_id makes the repeat rate look like 0% | Use `customer_unique_id` for customer counts and repeat rate |
| DQ-08 | Orders with no items | 775 orders (603 unavailable, 164 canceled) | None for delivered KPIs | No action; every delivered order has items |
| DQ-09 | Delivered orders with no review | 646 orders (0.7%) | Slightly smaller sample for review analysis | Exclude from review KPIs only |
| DQ-10 | Odd payment rows: 9 with value 0, 2 with 0 installments, 3 with type `not_defined` | 14 rows | None (payments only used to reconcile) | No action; noted |
| DQ-11 | Item revenue (price + freight) vs payments differ for delivered orders | R$15,419,773.75 vs R$15,422,461.77 (R$2,688.02, 0.02%) | Explained by installment interest and vouchers | Revenue KPI uses items, as defined in the charter |
| DQ-12 | Dates out of order: 166 orders handed to the carrier before purchase, 23 delivered before reaching the carrier | 189 orders | Doesn't affect purchase-to-delivery time | Keep; likely timestamp entry errors. Revisit if analyzing carrier speed |
| DQ-13 | 383 items have freight of R$0 | 383 items | None | Keep; free shipping is a valid business case |

## Dashboard reconciliation

Found by comparing every Power BI card with its SQL query (see [Power BI QA](../powerbi/README.md#5-qa-dashboard-vs-sql)).

| ID | Issue | Impact | Decision |
| --- | --- | --- | --- |
| RC-01 | Different "delivered" scope. The first version of the report filtered only on `order_delivered_customer_date` is not blank. That kept 6 canceled orders that have a delivery date and dropped the 8 delivered orders with no date | Dashboard showed 96,476 orders and R$15,419,143.41; SQL showed 96,478 and R$15,419,773.75 | **Resolved.** Added `order_status = "delivered"` to the report filter and kept the date filter, because `Is On Time` would count a blank delivery date as on time. The dashboard now shows 96,470 orders and R$15,418,394.83, matching SQL's delivery KPIs (Queries 4, 9, 14). It differs from Query 3 only by the 8 dateless orders in DQ-03 (R$1,378.92) |
| RC-02 | Delay buckets differ. SQL Query 8 uses On time / 1–3 / 4–7 / 8+ days; the dashboard uses On time / 1–3 / 4–7 / 8–14 / 15+ | None; 8–14 and 15+ add up to SQL's 8+ | Accepted. The dashboard is more detailed |
| RC-03 | Average review: the dashboard averages raw reviews, while SQL averages per order first (DQ-06) | Same to 2 decimals for on time vs late (4.29 vs 2.27); 4–7 days late shows 2.10 vs 2.11 | Accepted |
| RC-04 | `order_reviews` was loaded into Power BI from a CSV, while every other table came from SQL Server | One refresh didn't update everything | **Resolved.** Repointed it to `Olist_Retail_DB.dbo.order_reviews`; all 7 source tables in the model now come from the database |
| RC-05 | Top 10 categories: SQL Query 6 ranks by product revenue, while the dashboard ranks by total revenue including freight | 10th place is toys in SQL and garden_tools in the dashboard; ranks 1–9 are the same | Accepted. Both are valid; freight is part of the revenue definition |
| RC-06 | State cut-off: the dashboard's on-time-by-state chart shows states with 100+ orders, while the "seven states below 90%" finding uses 500+ | The chart shows 10 states below 90% (adds AL, SE, PI) | Accepted. The chart shows every state a manager might ask about; the finding uses the stricter cut-off so small samples don't drive the ranking |
