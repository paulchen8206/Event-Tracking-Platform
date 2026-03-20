# Kafka platform assets

## Purpose

This directory contains source-of-truth assets for Kafka topic provisioning, schema registration, and connector definitions.

## Layout

- `topics/topic-map.yaml`: topic definitions, retention, partitions, and schema subject mapping
- `schemas/avro/`: Avro schemas registered in Schema Registry
- `schemas/canonical-subjects.yaml`: canonical JSON schema subjects managed as a registry layer
- `connect/`: connector definitions for CDC or downstream integration

## Workflow

Start Kafka, Schema Registry, Kafka UI, and Kafka Connect:

```bash
docker compose -f infra/docker/docker-compose.kafka.yml up -d
```

Register Kafka Connect sink connectors using the canonical commands in [platform/kafka/connect/README.md](connect/README.md).

Install the Python bootstrap dependencies:

```bash
python3 -m pip install -r scripts/bootstrap/requirements-kafka.txt
```

Create topics and register schemas:

```bash
python3 scripts/bootstrap/kafka_bootstrap.py \
  --bootstrap-servers localhost:9092 \
  --schema-registry-url http://localhost:8081
```

Sync canonical JSON schema contracts into Schema Registry:

```bash
python3 scripts/bootstrap/schema_registry_maintainer.py \
  --schema-registry-url http://localhost:8081
```

Preview the planned changes without applying them:

```bash
python3 scripts/bootstrap/kafka_bootstrap.py --dry-run
```

Preview canonical schema maintenance plan:

```bash
python3 scripts/bootstrap/schema_registry_maintainer.py --dry-run
```

## Related documents

- [platform/kafka/connect/README.md](connect/README.md)
- [docs/runbooks/local-dev-docker-compose.md](../../docs/runbooks/local-dev-docker-compose.md)
