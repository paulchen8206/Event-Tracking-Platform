# Local Development Runbook (Docker Compose)

## Purpose

This runbook describes the pure Docker Compose development option for teams that want fast local iteration without Kubernetes pods.

## Decision matrix

Canonical option-selection guidance is maintained in [../architecture/deployment-architecture.md](../architecture/deployment-architecture.md). The table below is a quick local summary.

| Use case | Recommended option | Why |
| --- | --- | --- |
| Validate Kubernetes namespaces, RBAC, and NetworkPolicies | Minikube with pods | Requires Kubernetes runtime and overlays |
| Test deployment overlays before staging/production promotion | Minikube with pods | Closest parity with shared environment deployment model |
| Fast topic/schema/connector iteration on constrained laptop | Pure Docker Compose | Lower local resource footprint and faster startup |
| Kafka Connect and Schema Registry integration only | Pure Docker Compose | Minimal setup path for event backbone workflows |
| Quick smoke tests for connector registration and topic plumbing | Pure Docker Compose | Short feedback loop without cluster bootstrap overhead |

If your goal includes Kubernetes parity, use [local-dev-minikube.md](local-dev-minikube.md). If your goal is lightweight local integration speed, use this runbook.

## Scope

This option focuses on local event backbone services currently defined in Compose:

- Kafka broker
- Schema Registry
- Kafka UI
- Kafka Connect
- Optional synthetic CDC and mail-tracking event producers for local traffic generation only

For Kubernetes pod and namespace parity testing, use [local-dev-minikube.md](local-dev-minikube.md) instead.

## Prerequisites

- Docker Desktop running
- Python 3 available (used internally by `make dev-bootstrap`)

## Step 1 — Start the local stack

```bash
make dev-stack-up
```

Starts the base Kafka broker, Schema Registry, Kafka UI, Kafka Connect, and all optional profiles (producers, Flink UI, dbt, lakehouse, Airflow).

## Step 2 — Bootstrap topics and schemas

```bash
make dev-bootstrap
```

Installs Python dependencies, creates all Kafka topics, and registers Avro schemas in Schema Registry. Run once after `dev-stack-up` or whenever topics/schemas are reset.

> **One-command shortcut:** `make dev-pipeline-smoke` combines steps 1, 2, and 3 into a single command and then prints step-by-step Flink submission instructions.

## Step 3 — Start synthetic event producers

```bash
make dev-producers-up
make dev-producers-logs   # optional: tail producer container logs
```

Two producer services start:

- `cdc-event-producer` — emits synthetic Debezium-style CDC events to `dbz.postgres.mail.public.mail_events`
- `mail-tracking-event-producer` — emits synthetic operational tracking events to `evt.mail.operational.raw`

Both wait for their required source topic before publishing. You can tune throughput with environment variables before `make dev-producers-up`:

- `CDC_EVENTS_PER_SECOND`, `CDC_EVENT_COUNT`, `CDC_BATCH_INTERVAL_MS`, `CDC_TENANT_COUNT`
- `MAIL_TRACKING_EVENTS_PER_SECOND`, `MAIL_TRACKING_EVENT_COUNT`, `MAIL_TRACKING_BATCH_INTERVAL_MS`, `MAIL_TRACKING_TENANT_COUNT`

Example:

```bash
CDC_EVENTS_PER_SECOND=100 MAIL_TRACKING_EVENTS_PER_SECOND=20 make dev-producers-up
```

## Step 4 — Run the CDC bridge (optional)

The CDC bridge consumes Debezium-style events from `dbz.postgres.mail.public.mail_events` and produces canonical events to `evt.mail.lifecycle.raw`. Run it in a dedicated terminal — it stays running until interrupted.

```bash
make dev-cdc-bridge
```

This step is only required when testing the CDC → mail lifecycle path. Skip it if you only need the operational tracking path.

## Step 5 — Submit Flink jobs

The Flink UI must be running before submitting jobs. `dev-flink-mail-router` and `dev-flink-ops-router` each depend on it, so the cluster starts automatically:

```bash
# Terminal 1 — mail lifecycle router (dbz/CDC → evt.mail.internal.tracking + analytics)
make dev-flink-mail-router

# Terminal 2 — operational tracking router (evt.mail.operational.raw → evt.mail.internal.tracking.dashboard)
make dev-flink-ops-router
```

Or submit both in one command:

```bash
make dev-flink-all
```

Inspect running jobs:

```bash
make dev-flink-jobs
```

Open the Flink dashboard at <http://localhost:8088> to monitor job state, backpressure, and throughput.

## Step 6 — Inspect routed topics

Print the last few messages from each output topic without running a full consumer:

```bash
make dev-peek-tracking     # evt.mail.internal.tracking (5 messages)
make dev-peek-dashboard    # evt.mail.internal.tracking.dashboard (5 messages)
make dev-peek-analytics    # evt.mail.customer.analytics (5 messages)
```

## Step 7 — Set up observability

### One-command setup

```bash
make dev-observability-setup
```

This single target starts Elasticsearch and Kibana, registers the ingest pipeline and index templates, creates the observability indices, registers both Kafka Connect sink connectors, and imports the Kibana starter dashboards.

### Granular steps (if you need fine-grained control)

```bash
make dev-observability-up   # start Elasticsearch (9200) and Kibana (5601)
make dev-es-setup           # register ingest pipeline and apply index templates
make dev-connect-setup      # create indices and register Elasticsearch sink connectors
make dev-kibana-import      # import Kibana operational and DLQ dashboards
```

### Verify the sink path

```bash
make dev-connect-status     # connector task state
make dev-connect-health     # connector task state + Elasticsearch document counts
make dev-connect-logs       # tail Kafka Connect logs
```

### Smoke-test the DLQ path

Publishes a malformed record to the source dashboard topic and verifies it lands in the dead-letter Elasticsearch index:

```bash
make dev-connect-dlq-smoke
```

Open Kibana at <http://localhost:5601>:

- **Internal Mail Tracking Operational Overview** — event volume, type distribution, tenant activity, and delivery status
- **Internal Mail Tracking Dead-Letter Overview** — malformed records routed through Kafka Connect dead-letter handling

Stop the observability stack:

```bash
make dev-observability-down
```

## Monitoring UIs

| Service | URL | Started by |
| --- | --- | --- |
| Kafka UI | <http://localhost:8080> | `make dev-stack-up` |
| Schema Registry | <http://localhost:8081> | `make dev-stack-up` |
| Kafka Connect | <http://localhost:8083> | `make dev-stack-up` |
| Flink Dashboard | <http://localhost:8088> | `make dev-flink-ui-up` |
| Orchestration API | <http://localhost:8091> | `make dev-airflow-up` |
| Elasticsearch | <http://localhost:9200> | `make dev-observability-up` |
| Kibana | <http://localhost:5601> | `make dev-observability-up` |
| Spark UI | <http://localhost:4040> | `make dev-lakehouse-up` |
| Airflow UI | <http://localhost:8090> | `make dev-airflow-up` |

> The Flink Dashboard is mapped to port `8088` to avoid conflicting with Schema Registry on `8081`.

## Clean up

```bash
make dev-stack-down         # stop the full Compose stack
make dev-observability-down # stop Elasticsearch and Kibana only (if running separately)
```

## Canonical Lakehouse Consumer (MinIO + Iceberg)

```bash
make dev-lakehouse-smoke    # one-command: start MinIO + consumer, produce analytics events, verify Iceberg metadata
```

Or individually:

```bash
make dev-lakehouse-up       # start MinIO and the canonical-lakehouse-consumer
make dev-lakehouse-logs     # tail consumer logs
```

## dbt Semantic Layer (Snowflake)

The Compose file includes an optional `dev-dbt` profile that runs dbt against Snowflake. It is independent of the Kafka stack and can be started at any time.

Copy `.env.example` to `.env` at the repository root and fill in your Snowflake credentials before running any dbt targets.

```bash
make dev-dbt-up           # start the container
make dev-dbt-deps         # install dbt package dependencies
make dev-dbt-debug        # verify Snowflake connectivity
make dev-dbt-seed-large   # load 12 000-row synthetic data into Snowflake source tables
make dev-dbt-build        # build all staging and mart models
make dev-dbt-down         # stop the container
```

See [platform/dbt/README.md](../../platform/dbt/README.md) for full details.

## Airflow DAG Deployment (Local)

The Compose file includes an optional `dev-airflow` profile that runs Airflow with repository DAGs mounted into the container.

```bash
make dev-airflow-up     # start Airflow and deploy DAG files from platform/airflow/dags
make dev-airflow-logs   # tail Airflow logs
```

Open `http://localhost:8090` and sign in with:

- username: `admin` (or `AIRFLOW_USER`)
- password: `admin` (or `AIRFLOW_PASSWORD`)

Mounted DAG path:

- Host: `platform/airflow/dags`
- Container: `/opt/airflow/dags`

To stop Airflow:

```bash
make dev-airflow-down
```

## Related documents

- [local-dev-minikube.md](local-dev-minikube.md)
- [../../platform/kafka/connect/README.md](../../platform/kafka/connect/README.md)
- [../../platform/dbt/README.md](../../platform/dbt/README.md)
- [../../platform/airflow/README.md](../../platform/airflow/README.md)
- [../architecture/deployment-runtime-topology.md](../architecture/deployment-runtime-topology.md)
