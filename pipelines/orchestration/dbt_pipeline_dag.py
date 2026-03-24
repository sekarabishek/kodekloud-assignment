"""
Airflow DAG for KodeKloud Data Pipeline
Orchestrates dbt seed, run, and test commands
"""

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator

DBT_PROJECT_DIR = "~/kodekloud_assignment"
DBT_VENV_ACTIVATE = "source ~/data-stack/dbt-venv/bin/activate"

default_args = {
    "owner": "data-platform",
    "depends_on_past": False,
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="kk_data_pipeline",
    default_args=default_args,
    description="KodeKloud dbt pipeline: seed, run, test",
    schedule_interval="@daily",
    start_date=datetime(2022, 10, 1),
    catchup=False,
    tags=["dbt", "kodekloud", "data-platform"],
) as dag:

    dbt_seed = BashOperator(
        task_id="dbt_seed",
        bash_command=f"{DBT_VENV_ACTIVATE} && cd {DBT_PROJECT_DIR} && dbt seed --full-refresh",
    )

    dbt_run_staging = BashOperator(
        task_id="dbt_run_staging",
        bash_command=f"{DBT_VENV_ACTIVATE} && cd {DBT_PROJECT_DIR} && dbt run --select models/staging",
    )

    dbt_run_dimensions = BashOperator(
        task_id="dbt_run_dimensions",
        bash_command=f"{DBT_VENV_ACTIVATE} && cd {DBT_PROJECT_DIR} && dbt run --select models/marts/dimensions",
    )

    dbt_run_facts = BashOperator(
        task_id="dbt_run_facts",
        bash_command=f"{DBT_VENV_ACTIVATE} && cd {DBT_PROJECT_DIR} && dbt run --select models/marts/facts",
    )

    dbt_run_analytics = BashOperator(
        task_id="dbt_run_analytics",
        bash_command=f"{DBT_VENV_ACTIVATE} && cd {DBT_PROJECT_DIR} && dbt run --select models/marts/analytics_views",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"{DBT_VENV_ACTIVATE} && cd {DBT_PROJECT_DIR} && dbt test",
    )

    # Task dependencies
    dbt_seed >> dbt_run_staging >> dbt_run_dimensions >> dbt_run_facts >> dbt_run_analytics >> dbt_test
