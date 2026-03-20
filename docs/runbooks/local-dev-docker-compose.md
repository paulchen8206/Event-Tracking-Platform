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

Notes:

- `http://localhost:8081` is Schema Registry in this Compose stack.
- The Flink Dashboard is intentionally mapped to `8088` to avoid that conflict.

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

## Related documents

- [docs/runbooks/local-dev-minikube.md](local-dev-minikube.md)
- [platform/kafka/README.md](../../platform/kafka/README.md)
- [platform/kafka/connect/README.md](../../platform/kafka/connect/README.md)
