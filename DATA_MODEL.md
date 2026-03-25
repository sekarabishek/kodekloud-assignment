# DATA_MODEL.md

## Data Model Overview

This project follows a layered dbt approach:

- **Seeds**: raw CSV inputs loaded into PostgreSQL
- **Staging models**: cleaned and standardized source data (materialized as views)
- **Mart models**: dimensional and fact tables (materialized as tables)
- **Analytics views**: business-facing reporting models (materialized as views)

---

## Entity Relationship Summary

				┌──────────────┐
                │  dim_course  │
                │  (SCD1)      │
                └──────┬───────┘
                       │ course_key
       ┌───────────────┼───────────────────┐
       │               │                   │
┌──────▼───────┐ ┌─────▼──────────┐ ┌──────▼──────────────────┐
│ fact_        │ │ fact_          │ │ fact_revenue_           │
│ consumption  │ │ order          │ │ attribution             │
└──────▲───────┘ └─────▲──────────┘ └──────▲──────────────────┘
       │               │                   │
       │ customer_key  │ customer_key      │ customer_key
       └───────────────┼───────────────────┘
                       │
                ┌──────┴───────┐
                │ dim_customer │
                │ (SCD2 ready) │
                └──────────────┘

---

## Seeds (Raw Data)

| Seed                   | Rows   | Description                     |
|------------------------|--------|---------------------------------|
| customers              | 35,597 | Customer master data            |
| orders                 | 22,201 | Order transactions              |
| consumption_october    | 31,858 | October 2022 video consumption  |
| courses                | 48     | Course catalog                  |

---

## Staging Models

### stg_customers
- **Source:** customers seed
- **Materialization:** view
- **Key transformations:**
  - Cast Customer ID to bigint
  - Handle mixed date formats (DD/MM/YY HH24:MI and YYYY-MM-DD HH24:MI:SS)
  - Cast Total Spent to numeric

| Column                | Type           | Description                    |
|-----------------------|----------------|--------------------------------|
| customer_id           | bigint         | Customer identifier            |
| first_paid_order_date | timestamp      | First revenue-generating order |
| first_order_date      | timestamp      | First order of any type        |
| total_spent           | numeric(10,2)  | Lifetime spend                 |

### stg_orders
- **Source:** orders seed
- **Materialization:** view
- **Key transformations:**
  - Handle mixed date formats
  - Safely cast blank Customer ID to null
  - Cast revenue to numeric

| Column                  | Type           | Description              |
|-------------------------|----------------|--------------------------|
| order_id                | bigint         | Order identifier         |
| order_number            | text           | Business order number    |
| order_created_at        | timestamp      | Order timestamp          |
| customer_id             | bigint         | Customer identifier      |
| line_items              | text           | Product description      |
| billing_address_country | text           | ISO country code         |
| net_usd                 | numeric(12,2)  | Order total in USD       |

### stg_courses
- **Source:** courses seed
- **Materialization:** view
- **Key transformations:**
  - Trim whitespace
  - Uppercase course type

| Column            | Type | Description        |
|-------------------|------|--------------------|
| course_name       | text | Course name        |
| course_type       | text | PAID or FREE       |
| course_instructor | text | Instructor name    |

### stg_consumption
- **Source:** consumption_october seed
- **Materialization:** view
- **Key transformations:**
  - Cast User ID to bigint
  - Assign static consumption month (2022-10-01)

| Column            | Type    | Description                   |
|-------------------|---------|-------------------------------|
| user_id           | bigint  | User/customer identifier      |
| course_name       | text    | Course name                   |
| minutes_consumed  | integer | Minutes watched               |
| consumption_month | date    | Month of consumption activity |

---

## Dimensions

### dim_course
- **Type:** SCD Type 1
- **Grain:** One row per course
- **Materialization:** table
- **Source:** stg_courses
- **Row count:** 48

| Column                 | Type      | Description                          |
|------------------------|-----------|--------------------------------------|
| course_key             | bigint    | Surrogate key                        |
| course_name            | text      | Natural key                          |
| course_type            | text      | PAID or FREE                         |
| course_instructor      | text      | Instructor name                      |
| is_revenue_generating  | boolean   | True if course type is PAID          |
| total_duration_minutes | integer   | Placeholder                          |
| lesson_count           | integer   | Placeholder                          |
| enrollment_count       | integer   | Placeholder                          |
| created_at             | timestamp | Record created timestamp             |
| updated_at             | timestamp | Record updated timestamp             |

### dim_customer
- **Type:** SCD Type 2 (implemented via dbt snapshot)
- **Grain:** One row per customer
- **Materialization:** table
- **Source:** stg_customers
- **Row count:** 35,579

| Column               | Type           | Description                       |
|----------------------|----------------|-----------------------------------|
| customer_key         | bigint         | Surrogate key                     |
| customer_id          | bigint         | Natural key                       |
| first_paid_order_date| timestamp      | First revenue-generating order    |
| first_order_date     | timestamp      | First order of any type           |
| total_spent          | numeric(10,2)  | Lifetime spend                    |
| customer_status      | text           | Placeholder                       |
| effective_from_date  | timestamp      | SCD2 effective start              |
| effective_to_date    | timestamp      | SCD2 effective end (null=current) |
| is_current           | boolean        | True for current record           |
| created_at           | timestamp      | Record created timestamp          |
| updated_at           | timestamp      | Record updated timestamp          |

---

## Fact Tables

### fact_order
- **Grain:** One row per order
- **Materialization:** table
- **Source:** stg_orders joined to dim_customer
- **Row count:** 22,202

| Column                       | Type           | Description                              |
|------------------------------|----------------|------------------------------------------|
| order_key                    | bigint         | Surrogate key                            |
| order_id                     | bigint         | Natural key                              |
| order_number                 | text           | Business order number                    |
| customer_key                 | bigint         | FK to dim_customer                       |
| date_key                     | bigint         | Date key (YYYYMMDD)                      |
| order_created_at             | timestamp      | Order timestamp                          |
| line_items                   | text           | Product description                      |
| billing_country              | text           | ISO country code                         |
| subscription_type            | text           | MONTHLY, YEARLY, or null                 |
| subscription_tier            | text           | PROFESSIONAL, STANDARD, or null          |
| subscription_interval_months | integer        | 1 for monthly, 12 for yearly             |
| net_amount_usd               | numeric(12,2)  | Order total in USD                       |
| monthly_value                | numeric(12,2)  | Amortized monthly value                  |
| is_first_order               | boolean        | True if first order for customer         |
| is_latest_order              | boolean        | True if most recent order for customer   |
| order_sequence               | integer        | Order number for this customer           |
| created_at                   | timestamp      | Record created timestamp                 |
| updated_at                   | timestamp      | Record updated timestamp                 |

**Subscription classification breakdown:**

| Type     | Tier         | Count |
|----------|--------------|-------|
| MONTHLY  | STANDARD     | 9,472 |
| YEARLY   | PROFESSIONAL | 6,317 |
| MONTHLY  | PROFESSIONAL | 3,462 |
| YEARLY   | STANDARD     | 2,865 |
| null     | null         | 86    |

The 86 unclassified orders are business packs, labs, and study group purchases.

### fact_consumption
- **Grain:** One row per customer per course per month
- **Materialization:** table
- **Source:** stg_consumption joined to dim_customer and dim_course
- **Row count:** 21,262

| Column                         | Type           | Description                                    |
|--------------------------------|----------------|------------------------------------------------|
| consumption_key                | bigint         | Surrogate key                                  |
| customer_key                   | bigint         | FK to dim_customer                             |
| course_key                     | bigint         | FK to dim_course                               |
| date_key                       | bigint         | Date key (YYYYMMDD)                            |
| consumption_month              | date           | Month of consumption                           |
| total_minutes_consumed         | bigint         | Total watch time in minutes                    |
| total_hours_consumed           | numeric(10,2)  | Derived: minutes / 60                          |
| unique_sessions                | bigint         | Placeholder                                    |
| completion_percentage          | numeric(5,2)   | Placeholder                                    |
| consumption_percentage_of_month| numeric(5,4)   | Share of total watch time this month           |
| is_revenue_eligible            | boolean        | True if course is PAID                         |
| created_at                     | timestamp      | Record created timestamp                       |
| updated_at                     | timestamp      | Record updated timestamp                       |

**Revenue eligibility breakdown:**

| Eligible | Rows   | Total Minutes |
|----------|--------|---------------|
| false    | 2,310  | 142,066       |
| true     | 18,952 | 1,506,308     |

### fact_revenue_attribution
- **Grain:** One row per customer per course per month
- **Materialization:** table
- **Source:** fact_consumption joined to fact_order
- **Row count:** 2,529

| Column                      | Type           | Description                                       |
|-----------------------------|----------------|---------------------------------------------------|
| revenue_key                 | bigint         | Surrogate key                                     |
| customer_key                | bigint         | FK to dim_customer                                |
| course_key                  | bigint         | FK to dim_course                                  |
| order_key                   | bigint         | FK to fact_order                                  |
| date_key                    | bigint         | Date key (YYYYMMDD)                               |
| revenue_month               | date           | Revenue attribution month                         |
| subscription_type           | text           | MONTHLY or YEARLY                                 |
| subscription_monthly_value  | numeric(10,2)  | Amortized monthly subscription value              |
| course_minutes_consumed     | bigint         | Minutes watched for this course                   |
| total_paid_minutes_consumed | bigint         | Total paid-course minutes for customer this month |
| attribution_percentage      | numeric(5,4)   | course_minutes / total_paid_minutes               |
| attributed_revenue          | numeric(10,2)  | monthly_value x attribution_percentage            |
| instructor_royalty          | numeric(10,2)  | attributed_revenue x 0.20                         |
| is_free_course              | boolean        | Always false (free courses excluded)              |
| created_at                  | timestamp      | Record created timestamp                          |
| updated_at                  | timestamp      | Record updated timestamp                          |

**Revenue attribution business logic:**
1. Only subscription orders (MONTHLY/YEARLY) are included
2. Only paid-course consumption is used for attribution
3. One order per customer per month (latest order selected)
4. Attribution percentage = course minutes / total paid minutes
5. Attributed revenue = monthly subscription value x attribution percentage
6. Instructor royalty = attributed revenue x 20%

**Validation results:**
- Attribution percentages sum to 1.0 per customer-month: PASS
- Attributed revenue matches subscription monthly value: PASS
- Total attributed revenue for October 2022: $28,342.92

---

## Analytics Views

### view_monthly_mrr_arr
- **Grain:** One row per month
- **Materialization:** view

| Column                     | Description                                  |
|----------------------------|----------------------------------------------|
| month                      | Revenue month                                |
| mrr                        | Monthly recurring revenue                    |
| arr                        | Annual recurring revenue (MRR x 12)          |
| new_mrr                    | MRR from new customers                       |
| churned_mrr                | MRR lost from churned customers              |
| expansion_mrr              | MRR increase from existing customers         |
| contraction_mrr            | MRR decrease from existing customers         |
| net_new_mrr                | Net MRR change                               |
| mrr_growth_rate_pct        | MRR growth rate                              |
| total_customers            | Total paying customers                       |
| new_customers              | New paying customers                         |
| retained_customers         | Retained paying customers                    |
| customer_retention_rate_pct| Customer retention rate                      |
| arpu                       | Average revenue per user                     |
| quick_ratio                | SaaS quick ratio                             |

### view_course_revenue_monthly
- **Grain:** One row per course per month
- **Materialization:** view

| Column                   | Description                                     |
|--------------------------|-------------------------------------------------|
| month                    | Revenue month                                   |
| course_name              | Course name                                     |
| course_type              | PAID                                            |
| instructor               | Instructor name                                 |
| total_revenue            | Total attributed revenue                        |
| avg_revenue_per_student  | Average revenue per student                     |
| total_minutes_consumed   | Total watch time in minutes                     |
| total_hours_consumed     | Total watch time in hours                       |
| avg_minutes_per_student  | Average watch time per student                  |
| unique_students          | Count of unique students                        |
| students_1plus_hours     | Students with 1+ hours of consumption           |
| engagement_rate_pct      | Percentage of students with 1+ hours            |
| total_instructor_royalty | Total instructor royalty (20% of revenue)       |
| revenue_rank             | Revenue rank within month                       |
| popularity_rank          | Popularity rank within month                    |
