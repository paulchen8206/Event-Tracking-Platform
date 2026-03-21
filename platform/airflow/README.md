# Airflow Orchestration Guide

## Purpose

This guide describes how Airflow orchestrates Spark and dbt through the wrapper API layer with explicit dependency ordering.

## DAG catalog

- `dags/spark_dbt_pipeline_orchestrator.py`
  - Calls the Spark/dbt wrapper API layer instead of shelling out directly to runtime commands
  - Runs configured Spark app invocations first
  - Runs dbt dependency install, connectivity validation, and model builds after Spark completion
  - Enforces explicit Spark -> dbt dependency chain
- `dags/dbt_semantic_layer_pipeline.py`
  - Calls the dbt wrapper API only (no Spark dependency)
  - Runs dbt in strict layer sequence: source -> staging -> intermediate -> marts
  - Useful when you need deterministic semantic-layer progression independent of Spark runs
- `dags/spark_dbt_pipeline_readiness_gate.py`
  - Waits for Kafka, S3, and orchestration API readiness sensors
  - Triggers `spark_dbt_pipeline_orchestrator` only after upstream dependencies are reachable

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
- `DBT_SOURCE_SELECT` (default `source:iceberg_customer_analytics`)
- `DBT_STAGING_SELECT` (default `staging.customer_analytics`)
- `DBT_INTERMEDIATE_SELECT` (default `intermediate.customer_analytics`)
- `DBT_MARTS_SELECT` (default `marts.customer_analytics marts.internal_mail_tracking`)

Readiness gate settings:

- `ORCHESTRATION_TRIGGER_DAG_ID` (default `spark_dbt_pipeline_orchestrator`)
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

1. `wait_for_kafka_ready`, `wait_for_s3_ready`, and `wait_for_orchestration_api_ready` in parallel
2. trigger `spark_dbt_pipeline_orchestrator` once all three checks pass

Then the orchestration DAG runs:

1. `spark_apps.*`
2. `dbt_transformations.dbt_deps`
3. `dbt_transformations.dbt_debug`
4. `dbt_transformations.dbt_build_customer` and `dbt_transformations.dbt_build_internal` in parallel
5. `dbt_transformations.dbt_builds_complete`

Then the layer DAG runs:

1. `dbt_semantic_layer_pipeline.dbt_deps`
2. `dbt_semantic_layer_pipeline.dbt_debug`
3. `dbt_semantic_layer_pipeline.dbt_build_source`
4. `dbt_semantic_layer_pipeline.dbt_build_staging`
5. `dbt_semantic_layer_pipeline.dbt_build_intermediate`
6. `dbt_semantic_layer_pipeline.dbt_build_marts`

## DAG orchestration diagrams

Canonical DAG flow diagrams are maintained in:

- [docs/diagrams/airflow-dag-orchestration.md](../../docs/diagrams/airflow-dag-orchestration.md)

## Scheduling model

- `spark_dbt_pipeline_readiness_gate` is the scheduled DAG (`0 * * * *`)
- `spark_dbt_pipeline_orchestrator` is trigger-only (`schedule=None`)
- `dbt_semantic_layer_pipeline` is trigger-only (`schedule=None`)

## Local Airflow deployment via Docker Compose

Start local Airflow with DAGs from this folder mounted into the container:

```bash
make dev-airflow-up
```

Then open `http://localhost:8090` and trigger either:

- `spark_dbt_pipeline_orchestrator`
- `dbt_semantic_layer_pipeline`

Stop local Airflow:

```bash
make dev-airflow-down
```

## Trigger examples

From repository root, trigger DAGs through the Airflow CLI inside the container:

```bash
# Trigger readiness gate (scheduled DAG can also be run manually)
docker compose -f infra/docker/docker-compose.kafka.yml --profile dev-airflow \
  exec -T airflow airflow dags trigger spark_dbt_pipeline_readiness_gate

# Trigger Spark + dbt orchestrator directly
docker compose -f infra/docker/docker-compose.kafka.yml --profile dev-airflow \
  exec -T airflow airflow dags trigger spark_dbt_pipeline_orchestrator

# Trigger isolated dbt semantic pipeline
docker compose -f infra/docker/docker-compose.kafka.yml --profile dev-airflow \
  exec -T airflow airflow dags trigger dbt_semantic_layer_pipeline
```

Trigger with a custom run id and JSON conf:

```bash
docker compose -f infra/docker/docker-compose.kafka.yml --profile dev-airflow \
  exec -T airflow airflow dags trigger dbt_semantic_layer_pipeline \
  --run-id manual__dbt_semantic_layer_pipeline__001 \
  --conf '{"reason":"backfill-validation","initiator":"local-dev"}'
```

List DAGs and recent runs:

```bash
docker compose -f infra/docker/docker-compose.kafka.yml --profile dev-airflow \
  exec -T airflow airflow dags list

docker compose -f infra/docker/docker-compose.kafka.yml --profile dev-airflow \
  exec -T airflow airflow dags list-runs -d dbt_semantic_layer_pipeline --no-backfill
```

## Troubleshooting

### DAG does not appear in Airflow UI

- Check container health and logs:

```bash
docker compose -f infra/docker/docker-compose.kafka.yml --profile dev-airflow ps airflow
docker compose -f infra/docker/docker-compose.kafka.yml --profile dev-airflow logs --tail=200 airflow
```

- Check whether DAG parsing succeeded:

```bash
docker compose -f infra/docker/docker-compose.kafka.yml --profile dev-airflow \
  exec -T airflow airflow dags list
```

### Triggered DAG fails quickly on API call tasks

- Verify wrapper API endpoint is reachable from Airflow container:

```bash
docker compose -f infra/docker/docker-compose.kafka.yml --profile dev-airflow \
  exec -T airflow python -c "import urllib.request;print(urllib.request.urlopen('http://orchestration-api:8088/health', timeout=5).read().decode())"
```

- If you run API outside Docker network, override `ORCHESTRATION_API_BASE_URL` to a reachable host.

### dbt tasks fail in orchestrated DAGs

- Confirm dbt runtime settings and target values consumed by the wrapper API:
  - `DBT_PROJECT_DIR`
  - `DBT_PROFILES_DIR`
  - `DBT_TARGET`
- Validate credentials and connectivity with a direct dbt debug run in your dbt runtime path.

### Readiness gate never triggers orchestrator

- Check each sensor input quickly:
  - Kafka endpoint in `KAFKA_BOOTSTRAP_SERVERS`
  - S3 endpoint in `S3_ENDPOINT` or explicit `S3_HEALTHCHECK_URL`
  - wrapper API in `ORCHESTRATION_API_BASE_URL`
- Confirm `ORCHESTRATION_TRIGGER_DAG_ID` matches `spark_dbt_pipeline_orchestrator`.
