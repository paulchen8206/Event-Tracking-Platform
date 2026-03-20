# Elasticsearch Assets

This directory contains index templates, ingest pipelines, and Kibana starter assets for internal operational dashboards.

## Dead-Letter Monitoring Setup

1. Apply index templates:

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

1. Register Kafka Connect sink connectors (main + dead-letter):

See `platform/kafka/connect/README.md`.

1. Import Kibana starter dashboard assets:

Use files in `storage/elasticsearch/kibana/` and import via Kibana Saved Objects UI/API.

## Directory Layout

- `index-templates/`: Elasticsearch index templates for tracking and dead-letter indices
- `ingest-pipelines/`: Optional ingest enrichment pipelines
- `kibana/`: Starter dashboard/data-view definitions
