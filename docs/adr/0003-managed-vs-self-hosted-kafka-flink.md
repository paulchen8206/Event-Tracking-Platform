# ADR 0003: Managed vs Self-Hosted Kafka and Flink on Public Cloud

- Status: Accepted
- Date: 2026-03-19
- Deciders: Data Platform and Engineering Team
- Technical Story: Select an operating model for Kafka and Flink that balances delivery speed, reliability, portability, and cost control.

## Context

ADR 0001 selected Kubernetes on public cloud as the base platform, and ADR 0002 defined namespace and tenancy strategy. The remaining question is whether Kafka and Flink should be operated fully in-cluster (self-hosted) or consumed as managed services.

The platform must support:

- Reliable event streaming and stateful stream processing
- Strong operational posture for availability and upgrades
- Controlled cost growth as throughput increases
- Practical portability across cloud providers
- Fast environment setup for development and production

## Decision

We adopt a hybrid operating model:

- Production and business-critical staging use managed Kafka and managed Flink where available.
- Development and selected non-critical environments use Kubernetes-hosted components for cost control and feature experimentation.

This preserves delivery velocity and operational maturity in production while retaining architecture portability and lower-cost development options.

## Rationale

### Why not full self-hosted everywhere

- Kafka and Flink are stateful systems with non-trivial operational complexity.
- Cluster upgrades, failure recovery, and performance tuning require significant SRE bandwidth.
- Production reliability targets are easier to meet with managed offerings and support guarantees.

### Why not fully managed everywhere

- Some environments need lower-cost, flexible experimentation.
- Team workflows benefit from local and in-cluster reproducibility.
- Full dependence on managed capabilities can increase lock-in and reduce migration flexibility.

### Why hybrid

- Managed in production optimizes reliability and operational efficiency.
- Self-hosted in dev/staging subsets preserves portability and engineering control.
- Shared contracts, topics, and application code remain environment-agnostic.

## Consequences

### Positive

- Reduced production operational burden for stateful services
- Better SLA posture for Kafka/Flink critical paths
- Faster onboarding in development with local or in-cluster self-hosted stacks
- Clear migration path if provider or cost constraints change

### Trade-offs

- Two runtime modes require strict configuration discipline
- Potential behavior drift between managed and self-hosted environments
- Additional work to keep IaC and runbooks aligned across modes

### Risks and Mitigations

- Risk: Environment drift across managed and self-hosted clusters
  - Mitigation: Shared contract tests, topic conformance checks, and deployment validation gates
- Risk: Hidden managed-service constraints (limits, quotas, feature differences)
  - Mitigation: Explicit compatibility matrix and pre-production load validation
- Risk: Cost surprises in managed production
  - Mitigation: Budget alerts, throughput forecasting, and retention policy reviews

## Decision Details

### Production default

- Kafka: managed service (provider-native or vendor-managed)
- Flink: managed service where feasible, otherwise dedicated production-grade operator with strict SRE controls

### Non-production default

- Use Kubernetes-hosted Kafka/Flink for developer productivity and integration testing
- Continue supporting Docker-based local stack for fast feedback loops

### Non-negotiables across all modes

- Canonical schema governance via Schema Registry
- Topic naming and retention policy conformance
- Immutable image artifacts and promotion-based deployment
- Consistent observability standards (logs, metrics, tracing, alerts)

## Scope Boundaries

This ADR does not finalize:

- Specific cloud vendor service choice
- Procurement or commercial contract terms
- Exact SLO targets and paging policies
- Detailed backup and restore implementation procedures

These are defined in platform operations and reliability ADRs.

## Implementation Notes

- Keep local stack definitions in [docker-compose.kafka.yml](../../infra/docker/docker-compose.kafka.yml).
- Use [topic-map.yaml](../../platform/kafka/topics/topic-map.yaml) and schema mappings as the environment-neutral contract source.
- Keep Flink application packaging and deployment artifacts under [platform/flink/jobs/mail_lifecycle_router/java](../../platform/flink/jobs/mail_lifecycle_router/java).
