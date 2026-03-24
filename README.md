# KodeKloud Senior Data Engineer Assignment

## Assignment Overview

**Candidate:** Abishek S
**Technology Stack:** dbt Core + PostgreSQL + Airflow
**Approach:** dbt-first pipeline with seeds for ingestion, SQL-based transformations, and dimensional modeling

---

## Project Overview

This project implements an automated data platform for KodeKloud's revenue analytics. It replaces manual spreadsheet-based revenue analysis with a reproducible, tested, and documented data pipeline.

### What It Does

- Ingests raw CSV data (customers, orders, courses, consumption) into PostgreSQL via dbt seeds
- Cleans and standardizes source data through staging models
- Builds a dimensional data model (star schema) with SCD Type 1 and SCD Type 2 dimensions
- Implements complex revenue attribution logic based on consumption percentage
- Calculates instructor royalties at 20% of attributed revenue
- Produces analytics views for MRR/ARR tracking and course performance
- Validates data quality through 50 automated dbt tests (all passing)

### Key Metrics Produced

| Metric | October 2022 Value |
|--------|-------------------|
| Monthly Recurring Revenue (MRR) | $52,972.73 |
| Annual Recurring Revenue (ARR) | $635,672.76 |
| Total Attributed Revenue | $30,119.63 |
| Paying Customers | 1,329 |
| ARPU | $39.86 |
| Courses with Revenue | 35 |
| Instructors Earning Royalties | 13 |

---

## Quick Start

### Prerequisites

- macOS (tested on Apple Silicon)
- Homebrew
- Python 3.11
- PostgreSQL 14

See [SETUP.md](SETUP.md) for detailed installation instructions.

### 1. Clone the Repository

```bash
git clone <repository-url>
cd kodekloud_assignment
2. Set Up PostgreSQL
bash
Copy code
brew services start postgresql@14
psql postgres -c "CREATE DATABASE assignment_db;"
psql postgres -c "CREATE USER assignment_user WITH PASSWORD 'assignment_password';"
psql postgres -c "GRANT ALL PRIVILEGES ON DATABASE assignment_db TO assignment_user;"
3. Configure dbt Profile
Create ~/.dbt/profiles.yml:

yaml
Copy code
kk_assignment:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: assignment_user
      password: assignment_password
      port: 5432
      dbname: assignment_db
      schema: public
      threads: 4
4. Activate Virtual Environment
bash
Copy code
source ~/data-stack/dbt-venv/bin/activate
5. Run the Full Pipeline
bash
Copy code
dbt build
This single command will:

Load all CSV data into PostgreSQL (seed)
Build staging, dimension, fact, and analytics models (run)
Execute all 50 data quality tests (test)
Expected output: PASS=65 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=65

6. Query the Results
bash
Copy code
psql -h localhost -U assignment_user -d assignment_db
sql
Copy code
-- MRR/ARR metrics
select * from public.view_monthly_mrr_arr;

-- Top 10 courses by revenue
select course_name, instructor, total_revenue, unique_students
from public.view_course_revenue_monthly
order by total_revenue desc
limit 10;

-- Instructor royalties
select instructor, sum(total_revenue) as revenue, sum(total_instructor_royalty) as royalties
from public.view_course_revenue_monthly
group by instructor
order by royalties desc;
Project Structure
graphql
Copy code
kodekloud_assignment/
├── README.md                       # This file
├── ARCHITECTURE.md                 # Architecture design and decisions
├── SETUP.md                        # Development environment setup
├── DATA_MODEL.md                   # Data model documentation
├── requirements.txt                # Python dependencies
├── .gitignore                      # Git ignore rules
├── dbt_project.yml                 # dbt project configuration
├── packages.yml                    # dbt package dependencies
│
├── seeds/                          # Raw CSV data (dbt seeds)
│   ├── customers.csv               # 35,597 customer records
│   ├── orders.csv                  # 22,201 order records
│   ├── consumption_october.csv     # 31,858 consumption records
│   └── courses.csv                 # 48 course records
│
├── models/
│   ├── staging/                    # Cleaned source data (views)
│   │   ├── schema.yml              # Staging model tests
│   │   ├── stg_customers.sql       # Mixed date format handling, dedup
│   │   ├── stg_orders.sql          # Null customer ID handling
│   │   ├── stg_courses.sql         # Type standardization
│   │   └── stg_consumption.sql     # Blank course name filtering
│   │
│   └── marts/
│       ├── schema.yml              # Mart model tests
│       ├── dimensions/
│       │   ├── dim_course.sql      # SCD Type 1
│       │   └── dim_customer.sql    # SCD Type 2 ready
│       ├── facts/
│       │   ├── fact_order.sql      # Subscription parsing
│       │   ├── fact_consumption.sql # Aggregated consumption
│       │   └── fact_revenue_attribution.sql  # Core revenue logic
│       └── analytics_views/
│           ├── view_monthly_mrr_arr.sql
│           └── view_course_revenue_monthly.sql
│
├── tests/
│   └── singular/                   # Custom revenue validation tests
│       ├── test_attribution_percentage_sums_to_one.sql
│       ├── test_attributed_revenue_matches_subscription.sql
│       ├── test_no_free_courses_in_revenue.sql
│       ├── test_positive_attributed_revenue.sql
│       └── test_royalty_equals_twenty_percent.sql
│
└── docs/
    ├── diagrams/
    ├── screenshots/
    └── sample_queries.md           # Business and validation queries
Revenue Attribution Logic
This is the core business logic of the pipeline.

How It Works
Determine monthly subscription value

Monthly plans: use face value (e.g., $35.00)
Yearly plans: amortize to monthly (e.g., $150.00 / 12 = $12.50)
Calculate consumption percentages

For each customer in a given month, sum minutes watched per paid course
Divide each course's minutes by total paid-course minutes
Free course consumption is tracked but excluded from attribution
Attribute revenue

Multiply monthly subscription value by each course's consumption percentage
This gives the attributed revenue per course per customer per month
Calculate instructor royalties

20% of attributed revenue goes to the course instructor
Example
bash
Copy code
Customer pays \$150/year → Monthly value = \$12.50

October consumption:
  Course A (PAID):  120 minutes → 120/600 = 20%
  Course B (PAID):  480 minutes → 480/600 = 80%
  Course C (FREE):  120 minutes → excluded

Revenue attribution:
  Course A: \$12.50 × 0.20 = \$2.50
  Course B: \$12.50 × 0.80 = \$10.00

Instructor royalties:
  Course A instructor: \$2.50 × 0.20 = \$0.50
  Course B instructor: \$10.00 × 0.20 = \$2.00
Edge Cases Handled
Edge Case	Resolution
Multiple orders per customer per month	Use latest order only
Negative order amounts (refunds)	Exclude from revenue attribution
Blank customer IDs in orders	Safely cast to NULL
Blank customer IDs in customer data	Filter out (16 rows)
Duplicate customer IDs	Deduplicate keeping highest total_spent
Blank course names in consumption	Filter out (6 rows)
Mixed date formats in source	Handle both DD/MM/YY and YYYY-MM-DD
Non-subscription orders (business packs, labs)	Exclude from subscription revenue (86 orders)
Data Quality
Test Summary
Category	Tests	Status
Schema tests (not_null, unique, accepted_values, relationships)	45	All passing
Revenue validation tests (singular)	5	All passing
Total	50	All passing
Key Validations
Attribution percentages sum to 1.0 per customer per month — PASS
Attributed revenue matches subscription value per customer per month — PASS
No free courses appear in revenue attribution — PASS
All attributed revenue is positive — PASS
Instructor royalty equals 20% of attributed revenue — PASS
Sample Outputs
MRR/ARR for October 2022
Month	MRR	ARR	Total Customers	ARPU
2022-10-01	$52,972.73	$635,672.76	1,329	$39.86
Top 5 Courses by Revenue
Course	Instructor	Revenue	Students
DevOps Pre-Requisite Course	Mohan	$4,194.40	307
Certification Course - Certified Administrator	Mohan	$4,045.13	277
Learning Linux Basics Course & Labs	Mohan	$3,103.14	214
Kubernetes for the Absolute Beginners	Mohan	$2,563.43	210
Certified Kubernetes Security Specialist (CKS)	Vijay	$1,779.43	113
Instructor Royalty Summary
Instructor	Total Revenue	Royalties (20%)
Mohan	$17,867.15	$3,573.43
Vijay	$3,806.25	$761.18
Aaron	$2,160.67	$432.07
Lydia	$1,174.35	$234.89
Ritin	$640.08	$128.02
Subscription Breakdown
Type	Tier	Orders
MONTHLY	STANDARD	9,472
YEARLY	PROFESSIONAL	6,317
MONTHLY	PROFESSIONAL	3,462
YEARLY	STANDARD	2,865
Unclassified (business packs, labs)	—	86
See docs/sample_queries.md for all queries.

Technology Choices
Component	Choice	Rationale
Transformation	dbt Core 1.11.7	Industry standard for SQL-based transformation, testing, and documentation
Database	PostgreSQL 14	Reliable, free, supports window functions and CTEs needed for revenue logic
Ingestion	dbt seeds	Simple and reproducible for static CSV files; version-controlled
Orchestration	Airflow 2.9.3 (installed)	Production-ready scheduler; dbt commands can be triggered via DAGs
Python	3.11	Stable, compatible with both dbt and Airflow
See ARCHITECTURE.md for detailed architecture design and trade-offs.

Documentation
Document	Description
README.md	This file — overview, quick start, sample outputs
SETUP.md	Development environment setup instructions
ARCHITECTURE.md	Architecture design, data flow, technology decisions
DATA_MODEL.md	Data model documentation with table schemas
docs/sample_queries.md	Business queries and validation queries
What I Would Build Next
If given more time, I would add:

Full SCD Type 2 for dim_customer using dbt snapshots with incremental tracking
Airflow DAG to orchestrate dbt seed, run, and test as a scheduled pipeline
Additional analytics views for customer subscription status, consumption trends, and instructor royalties
Customer cohort analysis for retention tracking
dbt docs generate for auto-generated lineage diagrams
Incremental models for fact tables to support daily refreshes at scale
Docker containerization for portable local development
CI/CD pipeline with GitHub Actions running dbt build on every push EOF
