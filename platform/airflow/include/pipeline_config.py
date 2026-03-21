import os
from dataclasses import dataclass


@dataclass(frozen=True)
class SparkAppConfig:
    app_id: str


def _env(name: str, default: str) -> str:
    value = os.getenv(name, "").strip()
    return value or default


# Commands are env-driven so the same DAG can run in dev/staging/prod with different executors.
SPARK_APPS = [
    SparkAppConfig(
        app_id="canonical_lakehouse_refresh",
    ),
    SparkAppConfig(
        app_id="operational_mail_tracking_projection",
    ),
]

DBT_PROJECT_DIR = _env("DBT_PROJECT_DIR", "/opt/airflow/platform/dbt")
DBT_PROFILES_DIR = _env("DBT_PROFILES_DIR", "/opt/airflow/platform/dbt")
DBT_TARGET = _env("DBT_TARGET", "dev")
DBT_CUSTOMER_SELECT = _env(
    "DBT_CUSTOMER_SELECT", "staging.customer_analytics+ marts.customer_analytics"
)
DBT_INTERNAL_SELECT = _env("DBT_INTERNAL_SELECT", "marts.internal_mail_tracking")
DBT_SOURCE_SELECT = _env("DBT_SOURCE_SELECT", "source:iceberg_customer_analytics")
DBT_STAGING_SELECT = _env("DBT_STAGING_SELECT", "staging.customer_analytics")
DBT_INTERMEDIATE_SELECT = _env("DBT_INTERMEDIATE_SELECT", "intermediate.customer_analytics")
DBT_MARTS_SELECT = _env(
    "DBT_MARTS_SELECT", "marts.customer_analytics marts.internal_mail_tracking"
)

ORCHESTRATION_TRIGGER_DAG_ID = _env(
    "ORCHESTRATION_TRIGGER_DAG_ID", "spark_dbt_pipeline_orchestrator"
)
KAFKA_BOOTSTRAP_SERVERS = _env("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
S3_ENDPOINT = _env("S3_ENDPOINT", "http://localhost:9000")
S3_HEALTHCHECK_URL = _env("S3_HEALTHCHECK_URL", "")
ORCHESTRATION_API_BASE_URL = _env("ORCHESTRATION_API_BASE_URL", "http://orchestration-api:8088")
WRAPPER_API_TIMEOUT_SECONDS = int(_env("WRAPPER_API_TIMEOUT_SECONDS", "300"))
