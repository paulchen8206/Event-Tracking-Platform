# ADR 0010: Implement Cost and Utilization Governance

- Status: Proposed
- Date: 2026-03-20
- Deciders: Data Platform and Engineering Team
- Technical Story: Introduce systematic cost governance and utilization controls across platform workloads and data stores.

## Context

The platform already differentiates environment sizing and supports lightweight local modes, but cost governance is not yet treated as a first-class architecture concern.

Current gaps:

- No common cost attribution model by domain/team/workload
- No regular cost review cadence tied to architecture decisions
- No formal retention and lifecycle strategy for raw and derived data

As workloads scale, missing governance increases risk of unmanaged spend growth and inefficient resource usage.

## Decision

We will implement cost and utilization governance as an architecture-level operating requirement.

### 1. Cost attribution and ownership

- Define mandatory tagging/labeling standards for platform resources.
- Assign cost ownership per domain (platform, customer analytics, internal tracking).
- Track unit-cost indicators for key workloads where applicable.

### 2. Cost observability and review cadence

- Publish cost and utilization dashboards for compute, storage, and warehouse consumption.
- Establish monthly architecture-finops review with action tracking.

### 3. Data lifecycle controls

- Define hot/warm/cold retention tiers for event and analytics datasets.
- Apply lifecycle/retention controls for object storage and Elasticsearch operational indices.
- Define Snowflake storage and warehouse usage guardrails for non-production workloads.

### 4. Environment efficiency controls

- Apply scale-down schedules or low-footprint defaults where possible in non-production.
- Tune default resource requests and limits from observed utilization baselines.

## Consequences

### Positive

- Better spend predictability and budget control.
- Improved resource efficiency without sacrificing required performance.
- Faster identification of waste and anomalous consumption trends.

### Trade-offs

- Additional governance process and reporting overhead.
- Need for cross-team coordination on ownership boundaries.

### Risks and Mitigations

- Risk: Over-optimization can reduce reliability headroom
  - Mitigation: enforce reliability/SLO guardrails before applying cost reductions
- Risk: Tagging inconsistency reduces attribution quality
  - Mitigation: CI policy checks for required metadata on deployable resources

## Scope Boundaries

This ADR does not define:

- Financial approval workflow design
- Contracting or procurement strategy
- Vendor-specific billing integration details

## Implementation Notes

- Cost roadmap and milestones are tracked in: `docs/architecture/aws-well-architected-improvement-plan.md`
- Environment model and sizing context: `docs/architecture/deployment-runtime-topology.md`
