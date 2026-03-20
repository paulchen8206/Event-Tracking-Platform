# Kibana Assets

Starter saved-object assets for operational dashboards.

## Internal Mail Tracking Operational Dashboard

- Data view index pattern: `internal-mail-tracking*`
- Time field: `@timestamp` (populated by the `internal-mail-tracking-pipeline` ingest pipeline)
- Dashboard file: `internal-mail-tracking-operational-dashboard.json`

The dashboard JSON is a starter payload containing:

- Data view definition for the main operational tracking index
- Area chart for event volume over time
- Bar chart for event type distribution
- Pie chart for delivery status breakdown
- Bar chart for top active tenants (by event count)
- Recent events data table (timestamp, type, tenant, message ID, status, provider, processing stage)

## Internal Mail Tracking Dead-Letter Dashboard

- Data view index pattern: `internal-mail-tracking-deadletter*`
- Time field: `kafka_timestamp`
- Dashboard file: `internal-mail-tracking-deadletter-dashboard.json`

The dashboard JSON is a starter payload containing:

- Data view definition for dead-letter index documents
- A line chart for dead-letter event volume over time
- A table for top Kafka partitions producing malformed records

## Import Notes

Use `make dev-kibana-import` to import both dashboards in one command, or import individually with the Saved Objects API:

```bash
curl -sS -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  -F file=@storage/elasticsearch/kibana/internal-mail-tracking-operational-dashboard.json

curl -sS -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  -F file=@storage/elasticsearch/kibana/internal-mail-tracking-deadletter-dashboard.json
```

Kibana version note: starter assets target Kibana 8.x saved object format. Adjust `migrationVersion` fields if deploying against a different major version.
