# Kafka Connect Assets

Connector definitions that bridge internal Kafka topics to downstream systems.

## Realtime Elasticsearch sink

- Connector file: `elasticsearch/internal-mail-tracking-sink.json`
- Source topic: `evt.mail.internal.tracking.dashboard`
- Destination index: `internal-mail-tracking`
- DLQ topic for malformed records: `evt.mail.internal.tracking.dashboard.dlq`

Register the connector against a running Kafka Connect worker:

```bash
curl -sS -X PUT \
  http://localhost:8083/connectors/internal-mail-tracking-elasticsearch-sink/config \
  -H 'Content-Type: application/json' \
  --data @platform/kafka/connect/elasticsearch/internal-mail-tracking-sink.json
```

Check connector status:

```bash
curl -sS http://localhost:8083/connectors/internal-mail-tracking-elasticsearch-sink/status
```

## Dead-letter Elasticsearch sink

- Connector file: `elasticsearch/internal-mail-tracking-deadletter-sink.json`
- Source topic: `evt.mail.internal.tracking.dashboard.dlq`
- Destination index: `internal-mail-tracking-deadletter`
- Recommended index template: `storage/elasticsearch/index-templates/internal-mail-tracking-deadletter-template.json`
- Kibana starter dashboard: `storage/elasticsearch/kibana/internal-mail-tracking-deadletter-dashboard.json`

Register the dead-letter connector:

```bash
curl -sS -X PUT \
  http://localhost:8083/connectors/internal-mail-tracking-deadletter-elasticsearch-sink/config \
  -H 'Content-Type: application/json' \
  --data @platform/kafka/connect/elasticsearch/internal-mail-tracking-deadletter-sink.json
```

Check dead-letter connector status:

```bash
curl -sS http://localhost:8083/connectors/internal-mail-tracking-deadletter-elasticsearch-sink/status
```

## Smoke test

Run the end-to-end dead-letter smoke test to register both connectors, publish a malformed record, and verify it lands in Elasticsearch:

```bash
scripts/dev/smoke_test_kafka_connect_dlq.sh
```

Optional environment variables:

- `CONNECT_URL` (default `http://localhost:8083`)
- `ELASTICSEARCH_URL` (default `http://localhost:9200`)
- `KAFKA_CONTAINER` (default `etp-kafka`)

## Related documents

- [platform/kafka/README.md](../README.md)
- [docs/runbooks/local-dev-docker-compose.md](../../../docs/runbooks/local-dev-docker-compose.md)
