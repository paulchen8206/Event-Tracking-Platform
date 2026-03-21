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
    DBT_INTERMEDIATE_SELECT,
    DBT_MARTS_SELECT,
    DBT_SOURCE_SELECT,
    DBT_STAGING_SELECT,
    DBT_TARGET,
    ORCHESTRATION_API_BASE_URL,
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
    dag_id="dbt_semantic_layer_pipeline",
    default_args=default_args,
    description="Runs dbt semantic-layer pipeline in order: source -> staging -> intermediate -> marts.",
    schedule=None,
    start_date=datetime(2026, 3, 20),
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "orchestration", "semantic-layer"],
) as dag:
    start = EmptyOperator(task_id="start")
    end = EmptyOperator(task_id="end")

    with TaskGroup(
        group_id="dbt_semantic_layer_pipeline", tooltip="Run dbt semantic-layer transformations"
    ) as dbt_semantic_group:
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

        dbt_build_source = PythonOperator(
            task_id="dbt_build_source",
            python_callable=_post_json,
            op_kwargs={
                "path": "/v1/dbt/runs",
                "payload": {
                    "command": "build",
                    "target": DBT_TARGET,
                    "select": DBT_SOURCE_SELECT,
                },
            },
            execution_timeout=timedelta(minutes=20),
        )

        dbt_build_staging = PythonOperator(
            task_id="dbt_build_staging",
            python_callable=_post_json,
            op_kwargs={
                "path": "/v1/dbt/runs",
                "payload": {
                    "command": "build",
                    "target": DBT_TARGET,
                    "select": DBT_STAGING_SELECT,
                },
            },
            execution_timeout=timedelta(minutes=30),
        )

        dbt_build_intermediate = PythonOperator(
            task_id="dbt_build_intermediate",
            python_callable=_post_json,
            op_kwargs={
                "path": "/v1/dbt/runs",
                "payload": {
                    "command": "build",
                    "target": DBT_TARGET,
                    "select": DBT_INTERMEDIATE_SELECT,
                },
            },
            execution_timeout=timedelta(minutes=30),
        )

        dbt_build_marts = PythonOperator(
            task_id="dbt_build_marts",
            python_callable=_post_json,
            op_kwargs={
                "path": "/v1/dbt/runs",
                "payload": {
                    "command": "build",
                    "target": DBT_TARGET,
                    "select": DBT_MARTS_SELECT,
                },
            },
            execution_timeout=timedelta(minutes=60),
        )

        chain(
            dbt_deps,
            dbt_debug,
            dbt_build_source,
            dbt_build_staging,
            dbt_build_intermediate,
            dbt_build_marts,
        )

    chain(start, dbt_semantic_group, end)
