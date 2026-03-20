# Local development with pure Docker Compose

## Purpose

This runbook describes the pure Docker Compose development option for teams that want fast local iteration without Kubernetes pods.

## Decision matrix

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
- Python 3 available for bootstrap scripts

## Bootstrap

From repository root:

```bash
make dev-stack-up
python3 -m pip install -r scripts/bootstrap/requirements-kafka.txt
python3 scripts/bootstrap/kafka_bootstrap.py --bootstrap-servers localhost:9092 --schema-registry-url http://localhost:8081
python3 scripts/bootstrap/schema_registry_maintainer.py --schema-registry-url http://localhost:8081
```

## Start synthetic dev producers

These producers are local-development only. They are not part of the Helm chart or shared environment deployments.

```bash
make dev-producers-up
make dev-producers-logs
```

The split services are:

- `cdc-event-producer`: emits synthetic Debezium-style change events to `dbz.postgres.mail.public.mail_events`
- `mail-tracking-event-producer`: emits synthetic operational tracking events to `evt.mail.operational.raw`

Both services wait for their required source topic to exist before they start publishing.
Compose health status becomes healthy after each producer writes a ready/running status marker.

You can tune each producer independently with shell environment variables before `make dev-producers-up`:

- `CDC_EVENT_COUNT`, `CDC_EVENTS_PER_SECOND`, `CDC_BATCH_INTERVAL_MS`, `CDC_TENANT_COUNT`
- `MAIL_TRACKING_EVENT_COUNT`, `MAIL_TRACKING_EVENTS_PER_SECOND`, `MAIL_TRACKING_BATCH_INTERVAL_MS`, `MAIL_TRACKING_TENANT_COUNT`

Example:

```bash
CDC_EVENTS_PER_SECOND=100 MAIL_TRACKING_EVENTS_PER_SECOND=20 make dev-producers-up
```

## Run downstream Flink jobs locally

Use separate terminals for the two long-running jobs:

```bash
make dev-flink-mail-router
make dev-flink-ops-router
```

These targets run the Java Flink jobs against `localhost:9092` so the local Compose producers and Kafka topics can drive the full routing pipeline end to end.

## Register connectors

Use the canonical connector registration commands in [platform/kafka/connect/README.md](../../platform/kafka/connect/README.md).

## Verify

```bash
docker compose -f infra/docker/docker-compose.kafka.yml ps
curl -sS http://localhost:8083/connectors | cat
```

## Monitoring UIs

Start the monitoring surfaces you need:

```bash
# Kafka UI (included in base stack)
make dev-stack-up

# Flink Dashboard (JobManager + TaskManager)
make dev-flink-ui-up

# Spark UI (from canonical lakehouse consumer)
make dev-lakehouse-up
```

Open these URLs:

- Kafka UI: http://localhost:8080
- Spark UI: http://localhost:4040
- Flink Dashboard: http://localhost:8088
- Elasticsearch: http://localhost:9200
- Kibana: http://localhost:5601

Notes:

- `http://localhost:8081` is Schema Registry in this Compose stack.
- The Flink Dashboard is intentionally mapped to `8088` to avoid that conflict.
- Elasticsearch and Kibana require the `dev-observability` profile (see section below).

You can also inspect the routed topics directly:

```bash
docker compose -f infra/docker/docker-compose.kafka.yml exec kafka kafka-console-consumer --bootstrap-server kafka:29092 --topic evt.mail.internal.tracking --from-beginning --max-messages 5
docker compose -f infra/docker/docker-compose.kafka.yml exec kafka kafka-console-consumer --bootstrap-server kafka:29092 --topic evt.mail.internal.tracking.dashboard --from-beginning --max-messages 5
docker compose -f infra/docker/docker-compose.kafka.yml exec kafka kafka-console-consumer --bootstrap-server kafka:29092 --topic evt.mail.customer.analytics --from-beginning --max-messages 5
```

## Clean up

```bash
make dev-stack-down
```

## Elasticsearch and Kibana (Operational Dashboards)

The Compose file includes a `dev-observability` profile with Elasticsearch 8.13 and Kibana 8.13. These services power the Kafka Connect → ES → Kibana operational dashboard path.

```bash
make dev-observability-up   # start Elasticsearch (9200) and Kibana (5601)
make dev-es-setup           # register ingest pipeline + apply index templates
```

Then register the Kafka Connect sink connectors (see `platform/kafka/connect/README.md`):

```bash
curl -sS -X PUT \
  http://localhost:8083/connectors/internal-mail-tracking-elasticsearch-sink/config \
  -H 'Content-Type: application/json' \
  --data @platform/kafka/connect/elasticsearch/internal-mail-tracking-sink.json

curl -sS -X PUT \
  http://localhost:8083/connectors/internal-mail-tracking-deadletter-elasticsearch-sink/config \
  -H 'Content-Type: application/json' \
  --data @platform/kafka/connect/elasticsearch/internal-mail-tracking-deadletter-sink.json
```

Import Kibana dashboards:

```bash
make dev-kibana-import
```

Open Kibana at http://localhost:5601. The **Internal Mail Tracking Operational Overview** dashboard gives real-time visibility into event volume, type distribution, tenant activity, and delivery status. The **DLQ** dashboard monitors malformed records routed through Kafka Connect dead-letter handling.

Stop the observability stack:

```bash
make dev-observability-down
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

## Related documents

- [docs/runbooks/local-dev-minikube.md](local-dev-minikube.md)
- [platform/kafka/README.md](../../platform/kafka/README.md)
- [platform/kafka/connect/README.md](../../platform/kafka/connect/README.md)
