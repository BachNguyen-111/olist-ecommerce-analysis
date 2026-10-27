# Project Charter: Olist Delivery & Customer Experience Analysis

> **Note:** This is a portfolio project. Olist's public dataset is real, but the stakeholder, the kickoff and the timeline are simulated to show how a real analytics engagement runs.

| | |
| --- | --- |
| **Client** | Olist (Brazilian e-commerce marketplace) |
| **Stakeholder** | Head of Operations (simulated) |
| **Data** | Olist public dataset: 99,441 orders, Sep 2016 – Oct 2018 |
| **Tools** | SQL Server (T-SQL), Power BI (DAX), Claude (AI pair analyst: DAX, review and validation in Python) |
| **Duration** | 3 weeks |

## 1. Background

Olist connects small sellers to large Brazilian marketplaces and handles the logistics in between. Its reputation depends on two things the customer actually sees: whether the order arrives when promised, and whether the experience is good enough to leave a good review and buy again.

## 2. Business problem

Review scores vary widely, and some regions wait much longer for deliveries than others. Leadership wants to know **how delivery performance affects customer satisfaction, and where to focus logistics investment first.**

## 3. Business questions

Each question maps to SQL queries in `sql/05_analysis.sql` and to a dashboard visual.

| # | Question | Query | Dashboard |
| --- | --- | --- | --- |
| Q1 | How much revenue do delivered orders bring in, and what is the average order value? | Query 3 | Overview KPI cards |
| Q2 | How is revenue trending month to month? | Query 7 | Overview revenue trend |
| Q3 | Which states have the slowest delivery and the lowest on-time rate? | Queries 4, 9 | Overview state chart; Delivery state-share chart |
| Q4 | Does late delivery lower review scores, and by how much? | Queries 8, 10, 14 | Delivery review card, Late Revenue card and review-by-delay chart |
| Q5 | How many customers come back for a second order? | Query 5 | Overview Repeat Customer Rate card |
| Q6 | Which product categories drive the most revenue? | Query 6 | Overview top-categories chart |
| Q7 | Why are orders late: seller handling, carrier transit, or distance between seller and customer? | Queries 12, 13 | Delivery route chart and days-per-stage chart |

## 4. KPI definitions

These definitions are fixed for the whole project. SQL and Power BI must return the same number for each.

| KPI | Definition | Why it matters |
| --- | --- | --- |
| Total revenue | Sum of `price + freight_value` from order_items, delivered orders only | Overall business size |
| Delivered orders | `COUNT(DISTINCT order_id)` where `order_status = 'delivered'` | Volume actually fulfilled |
| Average order value (AOV) | Total revenue ÷ delivered orders | Basket size |
| Avg delivery days | Calendar days from purchase to customer delivery | Logistics speed |
| On-time rate | % of delivered orders received on or before the estimated date (compared by calendar day) | Promise kept to the customer |
| Repeat-customer rate | % of unique customers (`customer_unique_id`) with 2+ delivered orders | Loyalty |
| Avg review score | Mean of each order's average review (1–5 stars) | Satisfaction |

## 5. Scope

**In scope**
- Delivered orders, purchased Sep 2016 – Aug 2018 (no delivered orders exist after Aug 2018)
- Customer geography (the state the order shipped to) and seller geography (the state it shipped from)
- Tables: orders, order_items, customers, products, category_translation, order_reviews, sellers

**Out of scope**
- Ranking individual sellers (only seller location is used)
- Payment behaviour such as installments (order_payments is used only to reconcile revenue)
- Forecasting and causal testing

## 6. Assumptions

- Revenue = item price + freight. It is not payment value, which also includes installment interest (the two differ by R$2,688, or 0.02%).
- "On time" compares calendar dates, so an order delivered at 11 pm on its estimated date counts as on time.
- The estimated delivery date shown to the customer is the promise that matters for satisfaction.
- Review score is a fair proxy for customer satisfaction.

## 7. Deliverables

| Phase | Deliverable | File |
| --- | --- | --- |
| 1 | Project charter | `docs/01_project_charter.md` |
| 2 | Data dictionary + ERD | `docs/02_data_dictionary.md`, `docs/02_erd.png` |
| 3 | Database scripts | `sql/03_create_tables.sql`, `sql/03_foreign_keys.sql` |
| 4 | Data quality checks + issue log | `sql/04_data_quality_checks.sql`, `docs/04_issue_log.md` |
| 5 | Analysis queries + results | `sql/05_analysis.sql`, `sql/05_results.md` |
| 6 | Power BI dashboard + model, measures and QA | `powerbi/Olist main.pbix`, `powerbi/README.md` |
| 7 | Executive summary | `docs/07_executive_summary.md` |
| 8 | README + public repo | `README.md` |

## 8. Timeline

| Week | Work |
| --- | --- |
| 1 | Charter, data discovery, database load, data quality checks |
| 2 | SQL analysis, Power BI dashboard, reconciliation |
| 3 | Findings, recommendations, executive summary, GitHub packaging |

## 9. Success criteria

- Every business question in section 3 has a numeric answer and a recommendation.
- Every dashboard KPI matches its SQL query (differences explained in the issue log).
- A non-technical reader can understand the headline finding from the executive summary alone.
