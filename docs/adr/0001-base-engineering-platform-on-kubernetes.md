# ADR 0001: Base Engineering Platform on Kubernetes in Public Cloud

- Status: Accepted
- Date: 2026-03-19
- Deciders: Data Platform and Engineering Team
- Technical Story: Establish a production-ready base architecture for streaming and operational analytics workloads.

## Context

The platform must support event ingestion, CDC processing, real-time stream processing, and downstream data serving for both customer-facing analytics and internal operational tracking.

Key requirements include:

- A consistent deployment model for platform infrastructure and applications
- Scalable and resilient streaming backbone
- Stateful stream processing for event enrichment and routing
- Durable storage for raw and processed data
- Operational compatibility with container-first engineering workflows

The team needs a base architecture that works across public cloud providers while keeping application-level portability.

## Decision

We will use a Kubernetes-based engineering platform deployed in a public cloud as the default runtime foundation.

### 1. Deployment and Runtime Model

- All platform components and applications are packaged as Docker container images.
- Deployments run on Kubernetes using environment overlays (dev, staging, prod).
- Infrastructure and platform resources are managed as code (Terraform and Kubernetes manifests).

### 2. Streaming and Processing Foundation

- Kafka is the core event streaming cluster for transport, replay, and decoupling.
- Flink is the primary stream processing engine for normalization, enrichment, and routing.
- Flink applications consume external and CDC-driven topics, then emit canonical and internal topics.

### 3. Persistent Data Layer

- S3 (or cloud-equivalent object storage) is used for durable raw data landing, replay artifacts, and archival.
- PostgreSQL is used for transactional and operational relational workloads.
- MySQL is supported as an additional source or service database where needed by upstream systems.

### 4. Kubernetes Placement

- Kafka infrastructure and Flink infrastructure are deployed on Kubernetes.
- Kafka/Flink applications and supporting services are deployed as Kubernetes workloads.
- Stateful components use persistent volumes or cloud-managed storage integrations.

## Consequences

### Positive

- Unified operational model across infrastructure and applications
- Strong portability across public cloud providers
- Consistent CI/CD and rollback patterns for all deployable units
- Clear separation of concerns between transport (Kafka), processing (Flink), and persistence (S3 and relational stores)

### Trade-offs

- Higher operational complexity for stateful systems on Kubernetes
- Need for robust observability and SRE practices for Kafka and Flink clusters
- Cost and performance tuning required for storage, compute, and networking at scale

### Risks and Mitigations

- Risk: Stateful workload instability during upgrades
  - Mitigation: Use rolling upgrade policies, compatibility checks, and staged environment promotion
- Risk: Data contract drift across producers and consumers
  - Mitigation: Enforce schema registry governance and contract validation in CI
- Risk: Cloud resource sprawl and cost growth
  - Mitigation: Standardize autoscaling policies, quotas, and resource tagging

## Scope Boundaries

This ADR defines the base platform architecture only. It does not finalize:

- Vendor-specific managed service selections
- Detailed security control implementation
- Exact tenancy and namespace strategy
- Detailed backup, retention, and disaster recovery policy values

These items will be captured in follow-up ADRs.

## Implementation Notes

- Refer to [platform-architecture.md](../diagrams/platform-architecture.md) for the current logical flow.
- Use [topic-map.yaml](../../platform/kafka/topics/topic-map.yaml) as the source for Kafka topic intent and ownership.
- Use [docker-compose.kafka.yml](../../infra/docker/docker-compose.kafka.yml) only for local development, not production deployment.
