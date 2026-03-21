# Orchestration API Service

## Purpose

This service provides a wrapper API layer that decouples Airflow from direct Spark and dbt command execution.

## Endpoints

- `GET /health`
- `POST /v1/spark/jobs/{job_id}/runs`
- `POST /v1/dbt/runs`

## Spark job IDs

- `canonical_lakehouse_refresh`
- `operational_mail_tracking_projection`

Each Spark job maps to an environment variable command:

- `SPARK_APP_CANONICAL_COMMAND`
- `SPARK_APP_OPS_COMMAND`

## dbt defaults

- `DBT_PROJECT_DIR` (default `/opt/airflow/platform/dbt`)
- `DBT_PROFILES_DIR` (default `/opt/airflow/platform/dbt`)
- `DBT_TARGET` (default `dev`)

## Local run

```bash
cd services/orchestration-api
python3 -m pip install -r requirements.txt
uvicorn src.main:app --host 0.0.0.0 --port 8088
```

## Build wheel package

```bash
python3 -m pip install build
python3 -m build --wheel --outdir ../../.tmp/artifacts/wheels .
```

The resulting wheel can be consumed during image build or environment-specific pod packaging workflows.

## Design intent

Airflow orchestrates dependency order and retries, while this API layer owns Spark/dbt process invocation details. This keeps DAG logic transport-oriented instead of shell-command oriented.
