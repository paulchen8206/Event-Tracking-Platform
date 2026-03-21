# Event Tracking Platform Event Taxonomy

## Purpose

This taxonomy defines a shared event language for the consolidated platform so both customer-facing analytics and internal operational mail tracking can consume the same underlying lifecycle data.

The goal is not to force identical downstream models. The goal is to standardize upstream event semantics, identifiers, and timestamps so different consumers can derive fit-for-purpose views from the same source of truth.

## Design Principles

- Use a canonical event envelope for all emitted events
- Separate business events from platform and operational events
- Preserve correlation identifiers across the full message lifecycle
- Capture enough granularity for operational diagnosis without overloading customer-facing marts
- Favor additive schema evolution over breaking changes

## Canonical Event Envelope

Every event should carry a common envelope, regardless of source system:

- `event_id`: globally unique event identifier
- `event_type`: lifecycle or domain event name
- `event_version`: schema version for the payload
- `event_time`: timestamp when the event occurred
- `ingested_at`: timestamp when the platform received the event
- `source_system`: system or service that emitted the event
- `tenant_id`: customer or account identifier when applicable
- `message_id`: stable mail or communication identifier
- `correlation_id`: identifier spanning multi-step workflows
- `trace_id`: distributed tracing identifier when available
- `actor_type`: user, system, scheduler, provider, or service
- `payload`: event-specific attributes

## Event Families

### 1. Intake Events

Events that represent entry into the platform or initial customer interaction.

Examples:

- `mail.requested`
- `mail.accepted`
- `mail.rejected`
- `mail.scheduled`

Primary consumers:

- Customer analytics for volume, request trends, and acceptance rates
- Internal operations for validation failures and queue intake issues

### 2. Enrichment Events

Events that represent normalization, enrichment, routing, and rule evaluation.

Examples:

- `mail.normalized`
- `mail.enriched`
- `mail.classified`
- `mail.routed`

Primary consumers:

- Internal operations for workflow tracing and enrichment health
- Customer analytics when enrichment affects reportable business dimensions

### 3. Dispatch Events

Events that capture handoff to mail providers or downstream delivery systems.

Examples:

- `mail.dispatched`
- `mail.dispatch_failed`
- `mail.retry_scheduled`
- `mail.retry_exhausted`

Primary consumers:

- Customer analytics for sent counts and dispatch outcomes
- Internal operations for provider reliability and retry management

### 4. Delivery Outcome Events

Events that capture provider-confirmed delivery state.

Examples:

- `mail.delivered`
- `mail.bounced`
- `mail.deferred`
- `mail.dropped`

Primary consumers:

- Customer analytics for delivery performance and cohort reporting
- Internal operations for failure root-cause analysis

### 5. Engagement Events

Events that reflect recipient interaction and post-delivery behavior.

Examples:

- `mail.opened`
- `mail.clicked`
- `mail.unsubscribed`
- `mail.complained`

Primary consumers:

- Customer analytics as core behavioral and campaign metrics
- Internal operations in limited cases for abuse detection or deliverability monitoring

### 6. Platform Health Events

Events emitted by the pipeline and platform itself rather than by the mail business process.

Examples:

- `pipeline.lag_detected`
- `pipeline.job_failed`
- `pipeline.job_recovered`
- `connector.cdc_gap_detected`

Primary consumers:

- Internal operations and platform engineering only

## Mail Lifecycle Stages

Recommended lifecycle progression for a single `message_id`:

1. Requested
2. Accepted or Rejected
3. Normalized and Enriched
4. Routed
5. Dispatched
6. Delivered, Deferred, Bounced, or Dropped
7. Opened, Clicked, Unsubscribed, or Complained

Not every message will traverse every stage. The warehouse and operational serving layers should treat lifecycle state as a time-ordered event stream, not a fixed set of columns with guaranteed completion.

## Consumer Modeling Guidance

### Customer-Facing Analytics

- Prefer curated metrics derived from validated lifecycle milestones
- Use shared dimensions such as tenant, campaign, channel, template, and provider
- Hide internal-only troubleshooting attributes from customer marts unless explicitly productized

### Internal Mail Tracking

- Preserve more granular state transitions and error details
- Keep operational identifiers searchable
- Support low-latency views of the latest known state and full audit history

## Repository Mapping

- [../../shared/contracts/events/](../../shared/contracts/events/): schema contracts for event envelopes and event families
- [../../platform/kafka/topics/](../../platform/kafka/topics/): topic definitions by lifecycle or domain boundary
- [../../platform/flink/jobs/](../../platform/flink/jobs/): normalization, enrichment, correlation, and routing logic
- [../../platform/dbt/models/marts/shared/](../../platform/dbt/models/marts/shared/): shared conformed dimensions and lifecycle facts
- [../../platform/dbt/models/marts/customer_analytics/](../../platform/dbt/models/marts/customer_analytics/): externally oriented metrics and reporting marts
- [../../platform/dbt/models/marts/internal_mail_tracking/](../../platform/dbt/models/marts/internal_mail_tracking/): operational audit, SLA, and workflow monitoring marts
- [../../storage/elasticsearch/](../../storage/elasticsearch/): searchable operational projections for support and investigation use cases

## Related documents

- [use-cases.md](use-cases.md)
- [../architecture/system-architecture.md](../architecture/system-architecture.md)
