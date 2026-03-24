# TODO.md

## What I Would Build Next

This document outlines improvements and features that would be added with more time.

---

## High Priority

### 1. Full SCD Type 2 for dim_customer
- Implement using dbt snapshots with `check_cols` or `timestamp` strategy
- Track historical changes to customer status and total_spent
- Currently dim_customer has SCD2 columns but only stores current state

### 2. Incremental Models
- Convert fact_order, fact_consumption, and fact_revenue_attribution to incremental
- Use `merge` strategy with appropriate unique keys
- Critical for production scale with millions of rows

### 3. Airflow DAG Deployment
- DAG file exists at `pipelines/orchestration/dbt_pipeline_dag.py`
- Deploy to Airflow and test end-to-end scheduled execution
- Add Slack alerting on task failures

### 4. Date Dimension
- Create a proper dim_date table for time-series analysis
- Include fiscal periods, holidays, weekday flags
- Replace current date_key integer with FK to dim_date

---

## Medium Priority

### 5. Additional Data Quality Tests
- Anomaly detection for sudden spikes in consumption or revenue
- Row count trend monitoring between runs
- Source data freshness checks using dbt source freshness

### 6. Customer Cohort Analysis
- Group customers by first order month
- Track retention and revenue by cohort over time
- Useful for understanding customer lifetime value trends

### 7. Revenue Waterfall Analysis
- Break down MRR changes into new, expansion, contraction, churned
- Currently churned_mrr is a placeholder (set to 0)
- Requires comparing consecutive months with a full outer join

### 8. Docker Containerization
- Create Dockerfile for portable local development
- Include PostgreSQL, dbt, and Airflow in docker-compose
- Remove dependency on local Homebrew installations

---

## Low Priority / Nice to Have

### 9. CI/CD Pipeline
- GitHub Actions workflow running dbt build on every pull request
- Block merge if any test fails
- Outlined in DEPLOYMENT.md but not yet implemented

### 10. dbt Metrics Layer
- Define business metrics (MRR, ARR, ARPU) using dbt metrics
- Enable consistent metric definitions across analytics tools

### 11. Predictive Churn Indicators
- Add features to dim_customer for churn prediction
- Days since last order, order frequency, consumption trend
- Could feed into a simple ML model

### 12. Non-Subscription Revenue Handling
- 86 orders (business packs, labs, study groups) are currently excluded
- Design a separate revenue model for these product types
- Attribute business pack revenue across team members

### 13. Multi-Month Consumption Data
- Current data only covers October 2022
- Pipeline is designed to handle multiple months
- Would enable month-over-month trend analysis and proper MRR movement tracking

---

## Technical Debt

- Remove unused `models/intermediate/` and `snapshots/` configuration warnings from dbt_project.yml
- Add dbt model descriptions to all schema.yml files
- Pin dbt package versions in packages.yml
- Add pre-commit hooks for SQL linting (sqlfluff)
