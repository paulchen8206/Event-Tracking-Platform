# ADR 0005: Decouple Stream Processing and Search Sinks with Kafka Connect

- Status: Accepted
- Date: 2026-03-19
- Deciders: Data Platform and Engineering Team
- Technical Story: Reduce coupling between Flink processing logic and Elasticsearch sink operations for internal operational tracking.

## Context

The operational mail tracking pipeline originally routed events in Flink and also wrote directly from Flink into Elasticsearch. This created tight coupling between stream-processing deployment and search-index sink behavior.

Observed problems with direct Flink-to-Elasticsearch sinking:

- Connector and sink retries are tied to Flink job lifecycle
- Elasticsearch operational concerns (mapping, retries, backpressure) leak into Flink app code and dependencies
- Sink changes require Flink redeployments even when transformation logic is unchanged
- Harder separation of responsibilities between stream processing and integration delivery

Recent implementation changes introduced internal Kafka topics for dashboard-oriented events and Kafka Connect sink connectors.

## Decision

We will decouple stream processing from Elasticsearch writes by introducing internal Kafka sink topics and Kafka Connect Elasticsearch sink connectors.

### 1. Flink responsibilities

- Consume source topic `evt.mail.operational.raw`
- Normalize and enrich records
- Publish to internal topics:
  - `evt.mail.internal.tracking`
  - `evt.mail.internal.tracking.dashboard`

### 2. Kafka Connect responsibilities

- Consume `evt.mail.internal.tracking.dashboard`
- Sink records to Elasticsearch index `internal-mail-tracking`
- Handle sink-side retries and error routing independently of Flink runtime

### 3. Contract boundaries

- Flink owns event-shape transformation
- Kafka topics define handoff boundaries
- Kafka Connect owns destination integration behavior

## Consequences

### Positive

- Clear separation of concerns between processing and sink integration
- Faster operational changes for Elasticsearch sink without Flink redeploy
- Reduced Flink dependency surface and simpler job packaging
- Better scalability for sink throughput via connector task tuning

### Trade-offs

- Additional component to operate (Kafka Connect)
- Extra topic retention and monitoring requirements
- Need to keep sink connector configs versioned and reviewed

### Risks and Mitigations

- Risk: Dashboard topic schema drift impacts sink behavior
  - Mitigation: Keep event-contract review in PR and validate connector integration in smoke tests
- Risk: Connector misconfiguration creates silent sink lag
  - Mitigation: Monitor connector task state, lag metrics, and dead-letter volume alerts
- Risk: Increased end-to-end latency due to additional hop
  - Mitigation: Tune connector batching and task parallelism based on latency SLO

## Scope Boundaries

This ADR does not define:

- Production HA topology for Kafka Connect clusters
- Full SLOs and alert thresholds for connector operations
- Managed-vs-self-hosted Kafka Connect production placement

These are captured in future operations ADRs.

## Implementation Notes

- Flink job updates: `platform/flink/jobs/operational_mail_tracking_router/java`
- Topic taxonomy updates: `platform/kafka/topics/topic-map.yaml`
- Connector definitions: `platform/kafka/connect/elasticsearch/`
- Local stack includes Kafka Connect: `infra/docker/docker-compose.kafka.yml`
