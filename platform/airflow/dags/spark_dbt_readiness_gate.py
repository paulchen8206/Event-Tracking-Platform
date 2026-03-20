from __future__ import annotations

import socket
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import urlparse

from airflow import DAG
from airflow.models.baseoperator import chain
from airflow.operators.empty import EmptyOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.sensors.python import PythonSensor

DAGS_DIR = Path(__file__).resolve().parent
INCLUDE_DIR = DAGS_DIR.parent / "include"
if str(INCLUDE_DIR) not in sys.path:
    sys.path.append(str(INCLUDE_DIR))

from pipeline_config import (  # noqa: E402
    KAFKA_BOOTSTRAP_SERVERS,
    ORCHESTRATION_TRIGGER_DAG_ID,
    ORCHESTRATION_API_BASE_URL,
    S3_ENDPOINT,
    S3_HEALTHCHECK_URL,
)


def _extract_host_port(endpoint: str, default_port: int) -> tuple[str, int]:
    if "://" in endpoint:
        parsed = urlparse(endpoint)
        host = parsed.hostname or ""
        port = parsed.port or default_port
        return host, port

    if ":" in endpoint:
        host, port_str = endpoint.rsplit(":", 1)
        return host.strip(), int(port_str)

    return endpoint.strip(), default_port


def _can_connect(host: str, port: int, timeout_seconds: int = 5) -> bool:
    if not host:
        return False

    try:
        with socket.create_connection((host, port), timeout=timeout_seconds):
            return True
    except OSError:
        return False


def is_kafka_ready() -> bool:
    first_bootstrap = KAFKA_BOOTSTRAP_SERVERS.split(",", 1)[0].strip()
    host, port = _extract_host_port(first_bootstrap, 9092)
    return _can_connect(host, port)


def is_s3_ready() -> bool:
    if S3_HEALTHCHECK_URL:
        try:
            request = urllib.request.Request(S3_HEALTHCHECK_URL, method="GET")
            with urllib.request.urlopen(request, timeout=5) as response:  # noqa: S310
                return 200 <= response.status < 500
        except (urllib.error.URLError, TimeoutError, OSError):
            return False

    host, port = _extract_host_port(S3_ENDPOINT, 443)
    return _can_connect(host, port)


def is_orchestration_api_ready() -> bool:
    health_url = f"{ORCHESTRATION_API_BASE_URL.rstrip('/')}/health"
    try:
        request = urllib.request.Request(health_url, method="GET")
        with urllib.request.urlopen(request, timeout=5) as response:  # noqa: S310
            return 200 <= response.status < 300
    except (urllib.error.URLError, TimeoutError, OSError):
        return False


default_args = {
    "owner": "data-platform",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}


with DAG(
    dag_id="spark_dbt_readiness_gate",
    default_args=default_args,
    description="Blocks orchestration until Kafka and S3 upstream dependencies are reachable.",
    schedule="0 * * * *",
    start_date=datetime(2026, 3, 19),
    catchup=False,
    max_active_runs=1,
    tags=["spark", "dbt", "readiness", "sensor"],
) as dag:
    start = EmptyOperator(task_id="start")

    kafka_ready = PythonSensor(
        task_id="wait_for_kafka_ready",
        python_callable=is_kafka_ready,
        timeout=30 * 60,
        poke_interval=30,
        mode="reschedule",
    )

    s3_ready = PythonSensor(
        task_id="wait_for_s3_ready",
        python_callable=is_s3_ready,
        timeout=30 * 60,
        poke_interval=30,
        mode="reschedule",
    )

    orchestration_api_ready = PythonSensor(
        task_id="wait_for_orchestration_api_ready",
        python_callable=is_orchestration_api_ready,
        timeout=30 * 60,
        poke_interval=30,
        mode="reschedule",
    )

    trigger_orchestration = TriggerDagRunOperator(
        task_id="trigger_spark_dbt_dependency_orchestrator",
        trigger_dag_id=ORCHESTRATION_TRIGGER_DAG_ID,
        wait_for_completion=False,
        reset_dag_run=False,
    )

    end = EmptyOperator(task_id="end")

    chain(start, kafka_ready, s3_ready, orchestration_api_ready, trigger_orchestration, end)
