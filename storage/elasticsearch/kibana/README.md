# Kibana Assets

Starter saved-object assets for operational dashboards.

## Internal Mail Tracking Dead-Letter Dashboard

- Data view index pattern: `internal-mail-tracking-deadletter*`
- Time field: `kafka_timestamp`
- Dashboard file: `internal-mail-tracking-deadletter-dashboard.json`

The dashboard JSON is a starter payload containing:

- Data view definition for dead-letter index documents
- A line chart for dead-letter event volume over time
- A table for top Kafka partitions producing malformed records

## Import Notes

Use Kibana Saved Objects import UI or API to load these objects, then adjust panel settings for your Kibana version.

Example import API call (requires `kbn-xsrf` header):

```bash
curl -sS -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  -F file=@/path/to/export.ndjson
```

If your deployment requires NDJSON, convert the exported objects in `internal-mail-tracking-deadletter-dashboard.json` to one object per line.
