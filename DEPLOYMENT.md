# DEPLOYMENT.md

## Deployment Strategy

This document describes the deployment approach for promoting this pipeline from development to production.

---

## Environments

| Environment | Purpose | Database | Refresh |
|-------------|---------|----------|---------|
| dev | Local development and testing | Local PostgreSQL | Manual (dbt build) |
| staging | Pre-production validation | Cloud PostgreSQL or BigQuery | Scheduled via Airflow |
| prod | Production analytics | Cloud PostgreSQL or BigQuery | Scheduled via Airflow |

---

## CI/CD Approach

### Recommended Pipeline

```
Developer pushes code
        |
        v
GitHub Actions triggered
        |
        +-- dbt build --target dev (run + test)
        |
        +-- If all tests pass:
        |       |
        |       v
        |   Merge to main
        |       |
        |       v
        |   Deploy to staging
        |       |
        |       v
        |   dbt build --target staging
        |       |
        |       v
        |   Manual approval
        |       |
        |       v
        |   Deploy to prod
        |       |
        |       v
        |   dbt build --target prod
        |
        +-- If tests fail:
                |
                v
            Block merge, notify developer
```

### GitHub Actions Example

```yaml
name: dbt CI
on:
  pull_request:
    branches: [main]

jobs:
  dbt-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_DB: assignment_db
          POSTGRES_USER: assignment_user
          POSTGRES_PASSWORD: assignment_password
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install dbt-postgres
      - run: |
          mkdir -p ~/.dbt
          cat > ~/.dbt/profiles.yml <<PROFILE
          kk_assignment:
            target: ci
            outputs:
              ci:
                type: postgres
                host: localhost
                user: assignment_user
                password: assignment_password
                port: 5432
                dbname: assignment_db
                schema: public
                threads: 4
          PROFILE
      - run: dbt build
```

---

## Airflow Orchestration

### DAG Structure

```python
# dags/kk_pipeline.py
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-platform',
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'kk_data_pipeline',
    default_args=default_args,
    schedule_interval='@daily',
    start_date=datetime(2022, 10, 1),
    catchup=False,
) as dag:

    seed = BashOperator(
        task_id='dbt_seed',
        bash_command='cd ~/kodekloud_assignment && dbt seed',
    )

    run = BashOperator(
        task_id='dbt_run',
        bash_command='cd ~/kodekloud_assignment && dbt run',
    )

    test = BashOperator(
        task_id='dbt_test',
        bash_command='cd ~/kodekloud_assignment && dbt test',
    )

    seed >> run >> test
```

### Schedule

| Task | Frequency | Time |
|------|-----------|------|
| dbt seed | Daily (or on new data arrival) | 02:00 UTC |
| dbt run | Daily | 02:15 UTC |
| dbt test | Daily (after run) | 02:30 UTC |

---

## Environment Configuration

### Profile per Environment

Add multiple targets in ~/.dbt/profiles.yml:

```yaml
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

    staging:
      type: postgres
      host: staging-db-host
      user: "{{ env_var('DBT_USER') }}"
      password: "{{ env_var('DBT_PASSWORD') }}"
      port: 5432
      dbname: assignment_db
      schema: staging
      threads: 4

    prod:
      type: postgres
      host: prod-db-host
      user: "{{ env_var('DBT_USER') }}"
      password: "{{ env_var('DBT_PASSWORD') }}"
      port: 5432
      dbname: assignment_db
      schema: prod
      threads: 8
```

Run against a specific environment:

```bash
dbt build --target staging
dbt build --target prod
```

---

## Rollback Procedures

### If a dbt run fails in production

1. Check logs for the failing model:

```bash
dbt run --select <failed_model> --target prod
```

2. If the failure corrupts a table, re-run with full refresh:

```bash
dbt run --select <failed_model> --full-refresh --target prod
```

3. If a full rollback is needed, re-run the entire pipeline:

```bash
dbt build --full-refresh --target prod
```

### If a seed data issue is found

1. Fix the CSV in the seeds/ folder

2. Re-run seeds with full refresh:

```bash
dbt seed --full-refresh --target prod
```

3. Rebuild downstream models:

```bash
dbt run --target prod
```

---

## Scaling Considerations

| Current State | Production Scale | Recommended Change |
|---------------|------------------|-------------------|
| dbt seeds (CSV) | Real-time source systems | Fivetran/Airbyte for ingestion |
| Local PostgreSQL | Cloud data warehouse | BigQuery or Snowflake |
| Full refresh models | Millions of rows | Incremental models with merge strategy |
| Manual dbt commands | Scheduled runs | Airflow DAGs with alerting |
| Single schema | Multi-environment | Separate dev/staging/prod schemas |
| No monitoring | Pipeline observability | Elementary or dbt Cloud for monitoring |

---

## Monitoring and Alerting

### Recommended Setup

1. **dbt test failures** trigger Slack alerts via Airflow
2. **Row count anomalies** detected by custom dbt tests
3. **Pipeline duration tracking** via Airflow task metrics
4. **Data freshness checks** using dbt source freshness

### Example Freshness Check

```yaml
# models/staging/sources.yml
sources:
  - name: raw
    freshness:
      warn_after: {count: 24, period: hour}
      error_after: {count: 48, period: hour}
    loaded_at_field: updated_at
```

---

## Security

- Database credentials are stored in environment variables, not in code
- ~/.dbt/profiles.yml is excluded from version control via .gitignore
- Production credentials should be managed via a secrets manager (AWS Secrets Manager, GCP Secret Manager, or HashiCorp Vault)
- Database users should have least-privilege access per environment
