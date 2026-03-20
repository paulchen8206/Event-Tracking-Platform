# Flink Jobs

This directory holds deployable Flink jobs and job-specific metadata.

Starter job:

- `mail_lifecycle_router/`: normalizes raw lifecycle events, validates contracts, and fans out to customer-safe and internal-operational streams
- `operational_mail_tracking_router/`: consumes DynamoDB-originated operational mail tracking events and republishes internal tracking and dashboard streams for downstream Kafka Connect Elasticsearch sinking
