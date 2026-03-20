# Platform Use Cases

## Primary Consumers

The consolidated platform serves two primary categories of use case:

1. Customer-facing analytics
2. Internal operational mail tracking

Both should share a common ingestion, quality, and lineage foundation, while allowing different serving patterns, access controls, and latency expectations.

## Customer-Facing Analytics

Typical goals:

- Expose delivery and engagement analytics to customers
- Power dashboards, scheduled reports, and embedded analytics
- Provide stable datasets for Tableau dashboards and reporting extracts
- Support tenant-aware filtering, aggregation, and historical trend analysis
- Provide stable, curated metrics with strong semantic definitions

Design implications:

- Prioritize well-defined business entities and metric contracts
- Maintain curated marts in the warehouse for reporting workloads
- Publish customer-safe lakehouse assets that business intelligence tools such as Tableau can query reliably
- Enforce tenant isolation and externally consumable SLAs
- Version event and API contracts carefully to avoid downstream breakage

## Internal Operational Mail Tracking

Typical goals:

- Track message lifecycle events across ingestion, enrichment, dispatch, delivery, and failure handling
- Surface operational bottlenecks, retries, and exceptions quickly
- Support support-team investigations and internal monitoring workflows
- Enable near-real-time visibility into mail processing state
- Drive Kibana real-time dashboards over Elasticsearch-backed operational documents

Design implications:

- Preserve fine-grained event history and correlation identifiers
- Support lower-latency views for operational diagnosis
- Store searchable operational records for investigation workflows
- Capture CDC and system-generated events alongside customer-facing business events
- Support DynamoDB stream-driven event production and Elasticsearch indexing for sub-minute operational visibility

## Shared Platform Requirements

- Canonical event contracts that support both analytical and operational consumers
- Streaming-first ingestion with replay support
- Clear lineage from source systems through derived models
- Separation between raw, refined, and consumer-specific datasets
- Access-control boundaries between internal operations and customer-visible outputs
- Observability for pipeline health, lag, failures, and data quality

## Repository Mapping

- [shared/contracts/events](../../shared/contracts/events): Canonical event definitions and envelopes
- [platform/kafka](../../platform/kafka): Topics, connectors, and schemas for shared event transport
- [platform/flink](../../platform/flink): Real-time enrichment, normalization, and routing logic
- [platform/dbt](../../platform/dbt): Curated warehouse models for analytics and internal reporting
- [storage/elasticsearch](../../storage/elasticsearch): Search-oriented operational views for investigation workflows
- [services/orchestration-api](../../services/orchestration-api): API-driven orchestration surface for Spark and dbt workflows
- [services/canonical-lakehouse-consumer](../../services/canonical-lakehouse-consumer): Customer analytics ingestion into Iceberg/S3 lakehouse tables
