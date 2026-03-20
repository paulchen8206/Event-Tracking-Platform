# Event Contracts

This directory holds canonical event schemas used across ingestion, streaming, warehousing, and serving layers.

Initial assets:

- `envelope.schema.json`: common envelope shared by all events
- `mail.requested.schema.json`: request acceptance into the mail lifecycle
- `mail.delivered.schema.json`: successful delivery outcome event
- `pipeline.job_failed.schema.json`: internal platform failure event

Recommended evolution rules:

1. Additive changes only within an existing `event_version`
2. Breaking changes require a new `event_version`
3. Keep `event_type`, `message_id`, and `correlation_id` stable across the full lifecycle
