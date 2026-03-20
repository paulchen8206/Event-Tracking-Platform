from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.models.baseoperator import chain
from airflow.operators.empty import EmptyOperator
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup

DAGS_DIR = Path(__file__).resolve().parent
INCLUDE_DIR = DAGS_DIR.parent / "include"
if str(INCLUDE_DIR) not in sys.path:
    sys.path.append(str(INCLUDE_DIR))

from pipeline_config import (  # noqa: E402
    DBT_CUSTOMER_SELECT,
    DBT_INTERNAL_SELECT,
    DBT_TARGET,
    ORCHESTRATION_API_BASE_URL,
    SPARK_APPS,
    WRAPPER_API_TIMEOUT_SECONDS,
)


default_args = {
    "owner": "data-platform",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}


def _post_json(path: str, payload: dict[str, object]) -> None:
    url = f"{ORCHESTRATION_API_BASE_URL.rstrip('/')}/{path.lstrip('/')}"
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(request, timeout=WRAPPER_API_TIMEOUT_SECONDS) as response:  # noqa: S310
            if response.status >= 300:
                raise RuntimeError(f"API request failed for {url} with status={response.status}")
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"API request failed for {url} with status={exc.code}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"API request failed for {url}: {exc.reason}") from exc


with DAG(
    dag_id="spark_dbt_dependency_orchestrator",
    default_args=default_args,
    description="Runs Spark apps and dbt transformations with explicit dependencies.",
    schedule=None,
    start_date=datetime(2026, 3, 19),
    catchup=False,
    max_active_runs=1,
    tags=["spark", "dbt", "orchestration"],
) as dag:
    start = EmptyOperator(task_id="start")
    end = EmptyOperator(task_id="end")

    with TaskGroup(group_id="spark_apps", tooltip="Run Spark application workloads") as spark_apps_group:
        for app in SPARK_APPS:
            PythonOperator(
                task_id=f"run_{app.app_id}",
                python_callable=_post_json,
                op_kwargs={
                    "path": f"/v1/spark/jobs/{app.app_id}/runs",
                    "payload": {"arguments": []},
                },
                execution_timeout=timedelta(minutes=45),
            )

    with TaskGroup(group_id="dbt_transformations", tooltip="Run dbt transformations") as dbt_group:
        dbt_deps = PythonOperator(
            task_id="dbt_deps",
            python_callable=_post_json,
            op_kwargs={"path": "/v1/dbt/runs", "payload": {"command": "deps", "target": DBT_TARGET}},
            execution_timeout=timedelta(minutes=15),
        )

        dbt_debug = PythonOperator(
            task_id="dbt_debug",
            python_callable=_post_json,
            op_kwargs={"path": "/v1/dbt/runs", "payload": {"command": "debug", "target": DBT_TARGET}},
            execution_timeout=timedelta(minutes=15),
        )

        dbt_build_customer = PythonOperator(
            task_id="dbt_build_customer",
            python_callable=_post_json,
            op_kwargs={
                "path": "/v1/dbt/runs",
                "payload": {
                    "command": "build",
                    "target": DBT_TARGET,
                    "select": DBT_CUSTOMER_SELECT,
                },
            },
            execution_timeout=timedelta(minutes=60),
        )

        dbt_build_internal = PythonOperator(
            task_id="dbt_build_internal",
            python_callable=_post_json,
            op_kwargs={
                "path": "/v1/dbt/runs",
                "payload": {
                    "command": "build",
                    "target": DBT_TARGET,
                    "select": DBT_INTERNAL_SELECT,
                },
            },
            execution_timeout=timedelta(minutes=60),
        )

        chain(dbt_deps, dbt_debug, dbt_build_customer, dbt_build_internal)

    chain(start, spark_apps_group, dbt_group, end)
