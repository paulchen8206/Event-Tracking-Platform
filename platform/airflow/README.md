# Airflow orchestration guide

## Purpose

This guide describes how Airflow orchestrates Spark and dbt through the wrapper API layer with explicit dependency ordering.

## DAG catalog

- `dags/spark_dbt_dependency_orchestrator.py`
  - Calls the Spark/dbt wrapper API layer instead of shelling out directly to runtime commands
  - Runs configured Spark app invocations first
  - Runs dbt dependency install, connectivity validation, and model builds after Spark completion
  - Enforces explicit Spark -> dbt dependency chain
- `dags/spark_dbt_readiness_gate.py`
  - Waits for Kafka, S3, and orchestration API readiness sensors
  - Triggers `spark_dbt_dependency_orchestrator` only after upstream dependencies are reachable

## Configuration

Wrapper API settings:

- `ORCHESTRATION_API_BASE_URL` (default `http://orchestration-api:8088`)
- `WRAPPER_API_TIMEOUT_SECONDS` (default `300`)

dbt settings:

- `DBT_PROJECT_DIR` (default `/opt/airflow/platform/dbt`)
- `DBT_PROFILES_DIR` (default `/opt/airflow/platform/dbt`)
- `DBT_TARGET` (default `dev`)
- `DBT_CUSTOMER_SELECT` (default `staging.customer_analytics+ marts.customer_analytics`)
- `DBT_INTERNAL_SELECT` (default `marts.internal_mail_tracking`)

Readiness gate settings:

- `ORCHESTRATION_TRIGGER_DAG_ID` (default `spark_dbt_dependency_orchestrator`)
- `KAFKA_BOOTSTRAP_SERVERS` (default `localhost:9092`)
- `S3_ENDPOINT` (default `http://localhost:9000`)
- `S3_HEALTHCHECK_URL` (optional explicit health endpoint)

Wrapper service runtime settings (set on the API service):

- `SPARK_APP_CANONICAL_COMMAND`
- `SPARK_APP_OPS_COMMAND`
- `DBT_PROJECT_DIR`
- `DBT_PROFILES_DIR`
- `DBT_TARGET`

## Workflow

Set wrapper service commands to match your runtime (spark-submit, Kubernetes job trigger, or wrapper scripts), for example:

```bash
export SPARK_APP_CANONICAL_COMMAND="cd /opt/airflow/services/canonical-lakehouse-consumer && java -jar target/canonical-lakehouse-consumer-0.1.0-SNAPSHOT.jar"
export SPARK_APP_OPS_COMMAND="echo 'No-op placeholder for internal Spark projection app'"
```

Then the scheduled readiness DAG runs:

1. `wait_for_kafka_ready`
2. `wait_for_s3_ready`
3. `wait_for_orchestration_api_ready`
4. trigger `spark_dbt_dependency_orchestrator`

Then the orchestration DAG runs:

1. `spark_apps.*`
2. `dbt_transformations.dbt_deps`
3. `dbt_transformations.dbt_debug`
4. `dbt_transformations.dbt_build_customer`
5. `dbt_transformations.dbt_build_internal`

## Scheduling model

- `spark_dbt_readiness_gate` is the scheduled DAG (`0 * * * *`)
- `spark_dbt_dependency_orchestrator` is trigger-only (`schedule=None`)
