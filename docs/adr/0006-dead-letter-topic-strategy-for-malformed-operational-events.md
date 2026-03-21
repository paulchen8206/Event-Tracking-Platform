# ADR 0006: Dead-Letter Topic Strategy for Malformed Operational Events

- Status: Accepted
- Date: 2026-03-19
- Deciders: Data Platform and Engineering Team
- Technical Story: Isolate malformed dashboard records so connector errors do not block normal Elasticsearch indexing.

## Context

After decoupling sink delivery via Kafka Connect (ADR 0005), malformed records can still fail indexing. Logging-only error handling is insufficient for incident response and forensic analysis because problematic records are not retained as first-class data artifacts.

The platform needs:

- Non-blocking handling for malformed events
- Durable retention of failed sink records
- Clear troubleshooting path in Elasticsearch/Kibana

## Decision

We will route malformed connector records to a dedicated dead-letter Kafka topic and sink those records into a dedicated Elasticsearch index.

### 1. Dead-letter path

- Main connector consumes `evt.mail.internal.tracking.dashboard`
- On connector write errors, records are routed to `evt.mail.internal.tracking.dashboard.dlq`
- Dead-letter connector consumes DLQ topic and writes to `internal-mail-tracking-deadletter`

### 2. Dead-letter record shape

Dead-letter records preserve:

- Raw payload value
- Kafka topic, partition, offset metadata
- Kafka timestamp for timeline analysis

### 3. Operations and observability

- Retain dead-letter topic for short-to-medium investigation window (14d default)
- Provide Kibana dashboard assets for dead-letter monitoring
- Include smoke test coverage for malformed-record routing and index verification

## Consequences

### Positive

- Failed records are preserved and searchable
- Main connector pipeline remains available during malformed input spikes
- Faster root-cause analysis through metadata-rich dead-letter documents

### Trade-offs

- Additional storage and operational overhead for DLQ topic/index
- Extra connector component and dashboard maintenance
- Potential noise if upstream quality issues are frequent

### Risks and Mitigations

- Risk: DLQ growth masks chronic upstream contract violations
  - Mitigation: Set DLQ volume alerts and enforce producer contract validation
- Risk: Dead-letter index mappings become stale
  - Mitigation: Version and apply dead-letter index templates with connector rollout
- Risk: Sensitive payloads leak into dead-letter index
  - Mitigation: Apply field-level redaction and access controls in operational environments

## Scope Boundaries

This ADR does not define:

- Automated replay workflows from DLQ back into primary stream
- Data retention policy exceptions for legal/compliance use cases
- Long-term archive process for dead-letter records

These are follow-up operations and governance decisions.

## Implementation Notes

- Main and dead-letter connectors: `platform/kafka/connect/elasticsearch/`
- DLQ topic contract and retention: `platform/kafka/topics/topic-map.yaml`
- Dead-letter index template: `storage/elasticsearch/index-templates/internal-mail-tracking-deadletter-template.json`
- Kibana starter dashboard: `storage/elasticsearch/kibana/internal-mail-tracking-deadletter-dashboard.json`
- End-to-end verification script: `scripts/dev/smoke_test_kafka_connect_dlq.sh`
