# ARCHITECTURE.md

## Executive Summary

This project implements a modern data platform for KodeKloud, an e-learning SaaS company serving 35,000+ customers with 48 courses. The platform replaces manual spreadsheet-based revenue analysis with an automated, tested, and reproducible analytics pipeline.

The architecture follows a layered approach using dbt Core for SQL-based transformations and PostgreSQL as the data warehouse. Raw CSV data is ingested via dbt seeds, cleaned through staging models, and transformed into a star schema dimensional model with five analytics views covering MRR/ARR tracking, course revenue attribution, instructor royalties, customer health, and consumption trends.

The key architectural decisions prioritize correctness and simplicity over complexity. Revenue attribution logic — the core business requirement — is implemented with full validation, handling edge cases like refunds, duplicate orders, mixed date formats, and non-subscription products. The pipeline is fully idempotent and reproducible with a single command (`dbt build`), producing 65 passing steps including 50 data quality tests.

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
│   Validation: data type casting, null handling in staging layer     │
└──────────────────────────────┬──────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│                   STAGING LAYER (dbt models - views)                │
│                                                                     │
│   stg_customers     - type casting, mixed date format handling,     │
│                       deduplication, null customer ID filtering     │
│   stg_orders        - type casting, null customer ID handling,      │
│                       mixed date format handling                    │
│   stg_courses       - trimming, uppercasing course type             │
│   stg_consumption   - type casting, blank course name filtering,    │
│                       static month assignment                       │
└──────────────────────────────┬──────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│                    MART LAYER (dbt models - tables)                 │
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
│   view_monthly_mrr_arr            MRR, ARR, customer movements      │
│   view_course_revenue_monthly     Course revenue, royalties, ranks  │
│   view_instructor_royalties_monthly  Instructor payments            │
│   view_customer_subscription_status  Customer health monitoring     │
│   view_consumption_trends           Engagement metrics              │
└──────────────────────────────┬──────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│              ORCHESTRATION & MONITORING                             │
│                                                                     │
│   Apache Airflow 2.9.3    DAG: seed → staging → dims → facts →      │
│                           analytics → test                          │
│   dbt tests (50)          Schema + singular revenue validation      │
│   PostgreSQL metadata DB  Airflow task tracking                     │
└─────────────────────────────────────────────────────────────────────┘

### Entity Relationship Diagram

```mermaid
erDiagram
    dim_customer ||--o{ fact_order : "places"
    dim_customer ||--o{ fact_consumption : "consumes"
    dim_course ||--o{ fact_consumption : "consumed_in"
    dim_course ||--o{ fact_revenue_attribution : "generates"
    fact_order ||--o{ fact_revenue_attribution : "funds"
    dim_customer ||--o{ fact_revenue_attribution : "earns"

    dim_customer {
        bigint customer_key PK
        bigint customer_id NK
        timestamp first_paid_order_date
        timestamp first_order_date
        numeric total_spent
        text customer_status
        timestamp effective_from_date
        timestamp effective_to_date
        boolean is_current
    }

    dim_course {
        bigint course_key PK
        text course_name NK
        text course_type
        text course_instructor
        boolean is_revenue_generating
    }

    fact_order {
        bigint order_key PK
        bigint order_id NK
        bigint customer_key FK
        bigint date_key
        timestamp order_created_at
        text subscription_type
        text subscription_tier
        numeric net_amount_usd
        numeric monthly_value
        boolean is_first_order
        boolean is_latest_order
        integer order_sequence
    }

    fact_consumption {
        bigint consumption_key PK
        bigint customer_key FK
        bigint course_key FK
        bigint date_key
        date consumption_month
        bigint total_minutes_consumed
        numeric consumption_percentage_of_month
        boolean is_revenue_eligible
    }

    fact_revenue_attribution {
        bigint revenue_key PK
        bigint customer_key FK
        bigint course_key FK
        bigint order_key FK
        bigint date_key
        date revenue_month
        text subscription_type
        numeric subscription_monthly_value
        bigint course_minutes_consumed
        bigint total_paid_minutes_consumed
        numeric attribution_percentage
        numeric attributed_revenue
        numeric instructor_royalty
        boolean is_free_course
    }


Technology Stack
Data Warehouse
Choice: PostgreSQL 14

Justification:

Free and open source — zero licensing cost for development
Full support for window functions, CTEs, and complex analytical queries needed for revenue attribution
Well-supported dbt adapter
Production-ready with support for partitioning and indexing at scale
Easy local setup for reviewers to reproduce results
The assignment explicitly lists PostgreSQL as an acceptable alternative to BigQuery
Trade-off: PostgreSQL lacks native columnar storage and auto-scaling that BigQuery or Snowflake provide. For production at 10x scale, migrating to BigQuery (KodeKloud's preferred stack) would be recommended.

Data Transformation
Choice: dbt Core 1.11.7

Justification:

Industry standard for SQL-based transformation in modern data stacks
Built-in testing framework (schema tests + singular tests) critical for revenue accuracy validation
Automatic dependency resolution and DAG execution
Self-documenting with dbt docs generate for lineage visualization
Version-controlled SQL models that are easy to review, test, and maintain
Supports incremental models for production scale
Aligns with KodeKloud's preferred transformation approach
Ingestion
Choice: dbt seeds

Justification:

Source data is static CSV files — seeds are the simplest reproducible approach
CSVs are version-controlled alongside transformation logic
One command (dbt seed) loads all data
No external tooling required
For production: replace with Fivetran or Airbyte for real-time source system ingestion
Orchestration
Choice: Apache Airflow 2.9.3

Justification:

KodeKloud's preferred orchestration tool (Cloud Composer on GCP)
Installed and configured locally with PostgreSQL metadata database
DAG provided at pipelines/orchestration/dbt_pipeline_dag.py
Supports retry logic, alerting, and dependency management
Task-level monitoring and logging
Python
Choice: Python 3.11

Justification:

Matches KodeKloud's requirement (Python 3.11+)
Stable version with broad library compatibility
Used for dbt runtime and Airflow


Data Flow

1. Ingestion

Raw CSV files loaded into PostgreSQL via dbt seed
Four source tables created: customers, orders, courses, consumption_october
Full refresh on each seed run (idempotent)

2. Staging Layer

Business logic for data cleaning applied
Mixed date formats handled (DD/MM/YY HH24:MI and YYYY-MM-DD HH24:MI:SS)
Null/blank values safely cast or filtered
Duplicate customer records deduplicated (keeping highest total_spent)
Blank course names in consumption filtered out
Materialized as views (lightweight, always current)

3. Mart Layer — Dimensions

dim_course (SCD Type 1): One row per course, overwrites on change, derived is_revenue_generating flag
dim_customer (SCD Type 2 ready): One row per customer with SCD2 tracking columns (effective_from_date, effective_to_date, is_current). Current implementation stores latest state; can be upgraded to full SCD2 using dbt snapshots
Materialized as tables for stable FK references

4. Mart Layer — Facts

fact_order: One row per order, subscription type/tier parsed from line items, monthly value amortized for yearly plans, first/latest order flags
fact_consumption: One row per customer-course-month, aggregated from raw consumption, consumption percentage calculated, revenue eligibility flagged
fact_revenue_attribution: One row per customer-course-month, revenue attributed based on paid-course watch time percentage, instructor royalties at 20%
Materialized as tables for query performance

5. Analytics Layer

Five analytics views built on top of fact and dimension tables
Materialized as views (always reflect latest fact table state)
Ready for direct business user queries or BI tool connection

Key Design Decisions

1. Revenue Attribution Algorithm

Decision: Attribute subscription revenue to courses based on the percentage of paid-course watch time per customer per month.

Implementation:

Yearly subscriptions amortized to monthly ($150/year → $12.50/month)
Only paid-course minutes considered for percentage calculation
Free course consumption tracked but excluded from attribution
Only the latest order per customer per month used (prevents duplication)
Refund orders (negative amounts) excluded

Validation:

Attribution percentages verified to sum to exactly 1.0 per customer-month
Attributed revenue verified to match subscription monthly value per customer-month
Five dedicated singular tests validate revenue accuracy

2. One Order Per Customer Per Month

Decision: When a customer has multiple orders in the same month, use only the latest order for revenue attribution.

Reasoning:

Without this, the same consumption gets matched to multiple orders, inflating revenue
The assignment states: "Use only the latest order for each customer"
Implemented using row_number() partitioned by customer and month, ordered by date descending

3. dbt Seeds for Ingestion

Decision: Use dbt seeds instead of a custom Python ingestion script.

Reasoning:

Source data is static CSV files
Seeds are reproducible, version-controlled, and require no external tooling
The entire pipeline runs with one command: dbt build
For production, this would be replaced with Fivetran/Airbyte

4. Separate Virtual Environments

Decision: dbt and Airflow installed in separate Python virtual environments.

Reasoning:

dbt and Airflow have conflicting dependency trees
Separate venvs prevent version conflicts
Standard practice in production environments

5. Source Data Quality Handling

Decision: Clean dirty data in the staging layer rather than rejecting it.

Reasoning:

16 rows with null customer IDs → filtered out in stg_customers
2 duplicate customer IDs → deduplicated keeping highest total_spent
6 blank course names in consumption → filtered out in stg_consumption
1 refund order with negative amount → excluded from revenue attribution
86 non-subscription orders (business packs, labs) → excluded from subscription revenue
Mixed date formats → handled with conditional parsing

Scalability Considerations

Current Scale:

Metric							Volume
Customers						35,597
Orders							22,201
Monthly consumption records		31,858
Courses							48
Total seed data					~5 MB
Full pipeline runtime			~78 seconds

Expected Growth (3 years):

Metric					Current		10x Growth
Customers				35K			350K
Orders					22K			220K
Monthly consumption		32K			320K
Courses					48			200+

Scalability Strategy

Concern				Current Approach			Production at 10x
Ingestion			dbt seeds (CSV)				Fivetran/Airbyte from source systems
Database			Local PostgreSQL			BigQuery (KodeKloud's preferred)
Models				Full refresh tables			Incremental models with merge strategy
Orchestration		Manual dbt commands			Airflow DAGs with daily schedule
SCD Type 2			Current-state table			dbt snapshots with incremental tracking
Testing				50 dbt tests				dbt tests + Great Expectations + anomaly detection
Monitoring			Manual validation			Elementary or dbt Cloud for observability
Cost				Free (local)				BigQuery on-demand → flat-rate at scale

Performance at Scale

Incremental models for fact tables would reduce runtime from full-table rebuild to processing only new/changed records
Partitioning on revenue_month and order_created_at for large fact tables
Clustering on customer_key and course_key for common join patterns
Materialized analytics views for frequently queried dashboards

Data Quality & Governance

Data Quality Framework

Check Type						Implementation				Count			Failure Action
Not null						dbt schema tests			20				Fail pipeline
Unique							dbt schema tests			10				Fail pipeline
Accepted values					dbt schema tests			3				Fail pipeline
Referential integrity			dbt relationship tests		7				Fail pipeline
Attribution sums to 1			Singular test				1				Fail pipeline
Revenue ties to subscription	Singular test				1				Fail pipeline
No free courses in revenue		Singular test				1				Fail pipeline
Positive revenue				Singular test				1				Fail pipeline
Royalty = 20%					Singular test				1				Fail pipeline
Total							45 schema + 5 singular	

Data Lineage

Tool: dbt docs with dbt docs generate

Full DAG lineage from seeds → staging → dimensions → facts → analytics views
Column-level lineage traceable through SQL model definitions
Lineage diagram captured at docs/diagrams/data_model_erd.png

Data Catalog

All models documented in schema.yml files with:

Model descriptions
Column descriptions
Test definitions
Relationship mappings

Monitoring & Observability

Pipeline Monitoring

Metric							How Tracked
Pipeline success/failure		Airflow task status
Records processed per model		dbt run output (row counts)
Test pass/fail					dbt test results
Pipeline duration				Airflow task duration
Data freshness					dbt source freshness (future)

Alerting Strategy

Alert Type				Condition								Channel
Pipeline failure		Any dbt task fails after retries		Slack
Data quality			Any dbt test fails						Slack
Revenue anomaly			MRR changes > 20% month-over-month		Email
Long-running query		Pipeline exceeds 2x normal duration		Slack


Implementation

Airflow DAG includes retry logic (2 retries, 5 min delay)
Task dependency chain ensures tests run after all models complete
Staged execution: seed → staging → dimensions → facts → analytics → test

Security & Compliance

Access Control

Data Layer					Access Level		Users
Raw seed data				Read/Write			Data engineers only
Staging views				Read				Data engineers, analysts
Dimension/Fact tables		Read				Data engineers, analysts
Analytics views				Read				All business users
Airflow UI					Admin				Data engineers


Credential Management

Database credentials stored in ~/.dbt/profiles.yml (excluded from git via .gitignore)
No hardcoded credentials in code
Production: credentials managed via environment variables or secrets manager (GCP Secret Manager, AWS Secrets Manager)
Airflow connections stored in Airflow's encrypted connection store

Data Privacy

Customer IDs are numeric identifiers (no PII in the provided dataset)
Source data is anonymized production extracts
For production: implement column-level encryption for PII fields, row-level access policies for multi-tenant data

Audit Trail

Git commit history tracks all model changes
Airflow logs track all pipeline executions
dbt artifacts (manifest.json, run_results.json) capture execution metadata
created_at and updated_at audit columns on all dimension and fact tables

Cost Optimization

Current Cost (Local Development)

Component			Cost			Notes
PostgreSQL			$0				Local Homebrew install
Python / dbt		$0				Open source
Airflow				$0				Local install
Total				$0	

Estimated Production Cost (GCP)

Component					Monthly Cost		Notes
BigQuery storage			~$5					~5 GB active storage at $0.02/GB
BigQuery compute			~$25-50				On-demand pricing for daily runs
Cloud Composer (Airflow)	~$300-400			Smallest environment
Cloud Storage (raw files)	~$1					CSV archive
Total						~$330-460/month	


Cost Optimization Strategies

Partitioning: Partition fact tables by month to reduce scanned data in queries
Clustering: Cluster on customer_key and course_key for join-heavy queries
Incremental models: Process only new data instead of full refresh
Materialized views: Cache expensive analytics views that are queried frequently
BigQuery slots: Move to flat-rate pricing when query volume justifies it
Storage tiering: Archive historical data older than 2 years to cold storage
Query optimization: Avoid SELECT * in analytics views; project only needed columns

Trade-offs & Assumptions

Assumptions

Consumption data covers October 2022 only — the pipeline is designed to handle multiple months
Customer IDs in consumption data (User ID) map directly to Customer ID in customer data
Revenue attribution is based on paid-course watch time only; free courses are excluded
Instructor royalties are a flat 20% of attributed revenue
Yearly subscriptions are amortized evenly across 12 months
Business pack, lab, and study group orders are not subscription revenue and are excluded
The latest order per customer per month is the active subscription for that month
Negative order amounts represent refunds and should be excluded from revenue

Known Limitations

Single month data: MRR movement analysis (new, churned, expansion, contraction) is limited since only October 2022 consumption data is available. Churned MRR is set to 0.
No date dimension: A proper dim_date table is not implemented. Date keys use YYYYMMDD integer format.
SCD2 not fully active: dim_customer has SCD2 columns but only stores current state. Full historical tracking requires dbt snapshots with incremental data loads.
No real-time processing: Pipeline is batch-only. Real-time updates would require a streaming layer (e.g., Pub/Sub + Dataflow).
Consumption-order matching: Revenue attribution joins consumption to orders by customer and month. If a customer has no order in a consumption month, their consumption is excluded from attribution.

Alternative Approaches Considered

Approach										Decision					Reasoning
Python + Pandas ingestion						Rejected					dbt seeds are simpler for static CSVs and keep everything in one tool
Snowflake / BigQuery							Rejected for local dev		PostgreSQL is free and sufficient; architecture is portable to BigQuery
Lambda architecture (batch + streaming)			Rejected					added complexity without business need
Full SCD2 with dbt snapshots					Deferred					Requires multiple data loads over time
Custom Python test framework					Rejected					dbt's built-in testing is more maintainable, integrates with transformation layer
Star schema with aggregate tables				Accepted					Simplifies queries, improves performance, follows Kimball best practices


Glossary

Term			Definition
MRR				Monthly Recurring Revenue — total subscription revenue recognized in a month
ARR				Annual Recurring Revenue — MRR multiplied by 12
ARPU			Average Revenue Per User — MRR divided by total paying customers
SCD				Slowly Changing Dimension — technique for tracking historical changes in dimension data
SCD1			Type 1 SCD — overwrites old values with new (no history)
SCD2			Type 2 SCD — creates new rows for changes, tracking effective dates
Attribution		The process of allocating subscription revenue to individual courses based on consumption
Royalty			Payment to course instructors — 20% of attributed course revenue
Quick Ratio		SaaS health metric — (New MRR + Expansion MRR) / (Churned MRR + Contraction MRR). Values above 4.0 indicate healthy growth
dbt				Data Build Tool — SQL-based transformation framework
DAG				Directed Acyclic Graph — execution dependency chain in Airflow or dbt
Idempotent		A pipeline that produces the same result regardless of how many times it runs

References
https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/
https://docs.getdbt.com/guides/best-practices
https://www.saastr.com/saastr-podcast-149-with-tomasz-tunguz-why-net-dollar-retention-is-the-most-important-metric-for-saas-companies/
https://www.getdbt.com/blog/future-of-the-modern-data-stack/
https://cloud.google.com/bigquery/docs/best-practices

