# Olist E-Commerce: Why Late Deliveries Hurt Reviews

**I analyzed 96K delivered orders from Olist, a Brazilian marketplace, to find how late deliveries affect reviews, why orders are late, and where to fix logistics first.**

SQL Server (T-SQL) · Power BI (DAX) · Built with Claude as an AI assistant

![Delivery page of the Power BI dashboard](powerbi/screenshot_delivery_pbi.png)

*Real public data ([Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)); the client brief is simulated.*

## The question

The Head of Operations asks: **how does delivery performance affect customer satisfaction, and where should we invest first?**

## What I found

1. **Late orders lose up to 2.6 stars.** On-time orders average 4.29 stars, and orders 8+ days late average 1.70. Late orders are 6.7% of reviewed orders but 32.5% of all 1–2 star reviews.
2. **It's regional.** Seven states are below 90% on time and get 39% of all late orders. Rio de Janeiro alone gets 23%.
3. **The delay is with the carrier, on long routes.** Late orders spend 28 days with the carrier vs 8 for on-time ones. Orders shipped from another state are late almost twice as often (8.0% vs 4.5%).
4. **Promises ignore the route.** Late orders were promised the same delivery window as on-time ones, and peaks like Black Friday push the late rate as high as 19%.

## What I recommend

1. Fix delivery in the seven worst states, starting with Rio de Janeiro.
2. Compare carriers on long cross-state routes and move volume to the reliable ones.
3. Set delivery estimates by route and season, not one window for everyone.

Full findings and all six recommendations: [executive summary](docs/07_executive_summary.md) · [findings deck (PDF)](presentation/07_findings_deck.pdf).

## How I used AI

I built this project with Claude as my assistant. I loaded the data, ran the SQL in SQL Server and built the Power BI report myself, and I didn't keep any number until it matched the SQL results.

**What Claude helped with**
- **Syntax:** writing T-SQL, DAX and Power Query when I knew what I wanted but not how to write it.
- **Debugging:** I pasted my error messages (for example, a primary key failing on a nullable column, or a Power Query step returning text instead of a table) and we worked out the fix.
- **DAX measures:** turning my KPI definitions into measures, such as `Share of Late Orders` and the `Route` column.
- **Reviewing my SQL:** catching mistakes like counting items instead of orders, or counting `customer_id`, which changes on every order, instead of real customers.
- **Double-checking results:** recalculating every query in Python as a second check. This caught two dashboard bugs before the final version, including one that showed Rio de Janeiro at 12.4% of orders instead of 12.8%.
- **Feedback:** on chart titles, colors and layout, and on drafts of the docs.
- **Building this repo:** organizing the folders, writing the READMEs and docs, keeping file links and numbers consistent across them, and exporting the findings deck to PDF.
- **Findings deck:** turning my findings into a 9-slide presentation for the Head of Operations.

**What I decided**
- The business questions, KPI definitions and scope.
- The trade-offs, which are all written up in the [issue log](docs/04_issue_log.md).
- The final dashboard design.

## What's in this repo

| Folder | What's inside |
| --- | --- |
| [`docs/`](docs/) | [Project charter](docs/01_project_charter.md) (questions and KPI definitions) · [Data dictionary](docs/02_data_dictionary.md) and [ERD](docs/02_erd.png) · [Issue log](docs/04_issue_log.md) · [Executive summary](docs/07_executive_summary.md) |
| [`sql/`](sql/) | [Create tables](sql/03_create_tables.sql) · [Keys](sql/03_foreign_keys.sql) · [Data quality checks](sql/04_data_quality_checks.sql) · [14 analysis queries](sql/05_analysis.sql) · [Results](sql/05_results.md) |
| [`presentation/`](presentation/) | [Findings deck (PDF)](presentation/07_findings_deck.pdf): 9 slides for the Head of Operations |
| [`powerbi/`](powerbi/) | Screenshots and the [model, measures and QA](powerbi/README.md). The `.pbix` file is under [Releases](https://github.com/BachNguyen-111/olist-ecommerce-analysis/releases/latest) (too big for the repo page) |
| [`images/`](images/) | Charts used in the results |
| [`data/`](data/) | Where to download the CSVs |

## How to run it

1. Download the CSVs from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
2. In SQL Server, run `sql/03_create_tables.sql` (set your CSV folder path first), then `sql/03_foreign_keys.sql`.
3. Run `sql/04_data_quality_checks.sql` and `sql/05_analysis.sql`. Each query lists its expected result.
4. Download `Olist main.pbix` from [Releases](https://github.com/BachNguyen-111/olist-ecommerce-analysis/releases/latest), open it, and point the data source at your SQL Server.

*Limits: this shows correlation, not causation. The data has no carrier names, so carriers can't be compared yet.*
