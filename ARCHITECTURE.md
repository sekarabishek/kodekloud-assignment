# ARCHITECTURE.md

## Architecture Overview

This project implements a layered data pipeline using dbt Core and PostgreSQL. Raw CSV data is ingested via dbt seeds, standardized through staging models, and transformed into a dimensional data model with analytics views.

---

## Architecture Diagram

┌─────────────────────────────────────────────────────────────────────┐
│                        DATA SOURCES                                 │
│   customers.csv   orders.csv   courses.csv   consumption_october.csv│
└──────────────────────────────┬──────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│                     INGESTION LAYER (dbt seed)                      │
│                                                                     │
│   Raw CSVs loaded into PostgreSQL as seed tables                    │
│   Schema: public                                                    │
└──────────────────────────────┬──────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│                   STAGING LAYER (dbt models - views)                │
│                                                                     │
│   stg_customers     - type casting, mixed date format handling      │
│   stg_orders        - type casting, null customer ID handling       │
│   stg_courses       - trimming, uppercasing course type             │
│   stg_consumption   - type casting, static month assignment         │
└──────────────────────────────┬──────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│                    MART LAYER (dbt models - tables)                  │
│                                                                     │
│   DIMENSIONS                                                        │
│   ├── dim_course              SCD Type 1, one row per course        │
│   └── dim_customer            SCD Type 2 ready, one row per customer│
│                                                                     │
│   FACTS                                                             │
│   ├── fact_order              One row per order                     │
│   ├── fact_consumption        One row per customer-course-month     │
│   └── fact_revenue_attribution One row per customer-course-month    │
└──────────────────────────────┬──────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│                 ANALYTICS LAYER (dbt models - views)                │
│                                                                     │
│   view_monthly_mrr_arr          MRR, ARR, customer movement metrics │
│   view_course_revenue_monthly   Course revenue, royalties, rankings │
└─────────────────────────────────────────────────────────────────────┘


---

## Technology Choices

| Component          | Technology       | Rationale                                                        |
|--------------------|------------------|------------------------------------------------------------------|
| Transformation     | dbt Core 1.11.7  | Industry standard for SQL-based transformation and testing       |
| Database           | PostgreSQL 14     | Reliable, free, supports window functions and CTEs               |
| Ingestion          | dbt seeds         | Simple and reproducible for static CSV files                     |
| Python             | 3.11              | Stable version compatible with dbt and Airflow                   |
| Orchestration      | Airflow 2.9.3     | Installed and available; dbt commands can be triggered via DAGs   |

---

## Data Flow

### 1. Ingestion

Raw CSV files are loaded into PostgreSQL using `dbt seed`. This approach was chosen because:
- The source data is static CSV files
- Seeds are version-controlled alongside the project
- No external ingestion tooling is needed
- Reproducible with a single command

### 2. Staging

Staging models clean and standardize raw data:
- Cast columns to correct types
- Handle mixed date formats (DD/MM/YY HH24:MI and YYYY-MM-DD HH24:MI:SS)
- Handle blank/null values safely
- Trim whitespace from text fields
- Uppercase categorical fields for consistency

### 3. Dimensional Modeling

**dim_course (SCD Type 1)**
- One row per course
- Overwrites on change
- Includes derived field: is_revenue_generating

**dim_customer (SCD Type 2 ready)**
- One row per customer (current state)
- Includes SCD2 tracking columns: effective_from_date, effective_to_date, is_current
- Can be extended to full SCD2 using dbt snapshots

### 4. Fact Tables

**fact_order**
- One row per order
- Subscription type and tier parsed from line_items
- Monthly value calculated (yearly orders amortized to monthly)
- First/latest order flags and order sequence per customer

**fact_consumption**
- One row per customer per course per month
- Aggregated from raw consumption records
- Consumption percentage of month calculated
- Revenue eligibility flagged based on course type

**fact_revenue_attribution**
- One row per customer per course per month
- Revenue attributed based on paid-course consumption percentage
- Only the latest order per customer per month is used to avoid duplication
- Instructor royalties calculated at 20% of attributed revenue

### 5. Analytics Views

**view_monthly_mrr_arr**
- Monthly MRR and ARR
- MRR movement breakdown: new, churned, expansion, contraction
- Customer counts: total, new, retained
- ARPU and quick ratio

**view_course_revenue_monthly**
- Revenue and engagement metrics per course per month
- Instructor royalties
- Revenue rank and popularity rank within each month

---

## Key Design Decisions

### 1. dbt-first approach
All transformation logic lives in dbt SQL models. This keeps the pipeline declarative, testable, and easy to document.

### 2. Seeds for ingestion
Since the source data is static CSV, dbt seeds are simpler and more reproducible than a custom Python ingestion script.

### 3. One order per customer per month for revenue attribution
Customers with multiple orders in the same month had their revenue duplicated across consumption rows. The fix uses only the latest order per customer per month, preventing attribution percentages from exceeding 1.0.

### 4. Exclude non-subscription orders from revenue attribution
Business packs, labs, and study group purchases (86 orders) are excluded from subscription-based revenue attribution because they do not follow the monthly/yearly subscription model.

### 5. Separate virtual environments
dbt and Airflow are installed in separate Python virtual environments to avoid dependency conflicts.

---

## Scalability Considerations

If this pipeline needed to scale to production:

| Concern                | Current Approach       | Production Approach                          |
|------------------------|------------------------|----------------------------------------------|
| Ingestion              | dbt seeds (CSV)        | Fivetran/Airbyte syncing from source systems |
| Database               | Local PostgreSQL       | Cloud warehouse (BigQuery, Snowflake)        |
| Orchestration          | Manual dbt commands    | Airflow DAGs triggering dbt                  |
| SCD Type 2             | Current-state table    | dbt snapshots with incremental tracking      |
| Testing                | dbt tests              | dbt tests + Great Expectations               |
| Monitoring             | Manual validation      | dbt Cloud or Elementary for observability     |
| Data volume            | ~90K rows total        | Partitioning, incremental models             |

---

## Assumptions

1. Consumption data covers October 2022 only
2. Revenue attribution is based on paid-course watch time only
3. Free course consumption is tracked but excluded from revenue attribution
4. Instructor royalties are 20% of attributed revenue
5. Yearly subscriptions are amortized evenly across 12 months
6. Business pack, lab, and study group orders are not subscription revenue
