# Elasticsearch Assets

This directory contains index templates, ingest pipelines, and Kibana starter assets for internal operational dashboards.

## Local Development Setup

Start Elasticsearch and Kibana using the `dev-observability` Compose profile, then run the bootstrap steps:

```bash
make dev-observability-up   # starts Elasticsearch (9200) and Kibana (5601)
make dev-es-setup           # registers ingest pipeline + applies index templates
```

Register the Kafka Connect sink connectors next (see `platform/kafka/connect/README.md`), then import Kibana dashboards:

```bash
make dev-kibana-import
```

Open Kibana at http://localhost:5601.

## Manual Setup Steps

Run these in order. The ingest pipeline must be registered before the index template, as the template references it via `index.default_pipeline`.

### 1. Register the ingest pipeline

```bash
curl -sS -X PUT \
  http://localhost:9200/_ingest/pipeline/internal-mail-tracking-pipeline \
  -H 'Content-Type: application/json' \
  --data @storage/elasticsearch/ingest-pipelines/internal-mail-tracking-pipeline.json
```

The pipeline normalizes `dashboard_ts` to `@timestamp` and tags documents with `dashboard_source`.

### 2. Apply index templates

```bash
curl -sS -X PUT \
  http://localhost:9200/_index_template/internal-mail-tracking-template \
  -H 'Content-Type: application/json' \
  --data @storage/elasticsearch/index-templates/internal-mail-tracking-template.json

curl -sS -X PUT \
  http://localhost:9200/_index_template/internal-mail-tracking-deadletter-template \
  -H 'Content-Type: application/json' \
  --data @storage/elasticsearch/index-templates/internal-mail-tracking-deadletter-template.json
```

The main template sets `index.default_pipeline` to automatically invoke the normalization pipeline on every indexed document.

### 3. Register Kafka Connect sink connectors

See `platform/kafka/connect/README.md`.

### 4. Import Kibana dashboards

Use the Kibana Saved Objects import UI or the API:

```bash
# Operational tracking dashboard (internal-mail-tracking*)
curl -sS -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  -F file=@storage/elasticsearch/kibana/internal-mail-tracking-operational-dashboard.json

# Dead-letter monitoring dashboard
curl -sS -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  -F file=@storage/elasticsearch/kibana/internal-mail-tracking-deadletter-dashboard.json
```

## Directory Layout

- `index-templates/`: Elasticsearch index templates for tracking and dead-letter indices
- `ingest-pipelines/`: Normalization pipeline that maps `dashboard_ts` → `@timestamp`
- `kibana/`: Starter dashboard and data-view definitions
