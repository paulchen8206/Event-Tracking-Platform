# Architecture Decision Records (ADR) Index

This directory tracks major architecture and operations decisions for the Event Tracking Platform.

## ADR Index

| ADR | Title | Status | Date | Scope |
| --- | --- | --- | --- | --- |
| [0001](0001-base-engineering-platform-on-kubernetes.md) | Base Engineering Platform on Kubernetes in Public Cloud | Accepted | 2026-03-19 | Base runtime architecture |
| [0002](0002-kubernetes-namespace-and-tenancy-strategy.md) | Kubernetes Namespace and Tenancy Strategy | Accepted | 2026-03-19 | Namespace, tenancy, and policy boundaries |
| [0003](0003-managed-vs-self-hosted-kafka-flink.md) | Managed vs Self-Hosted Kafka and Flink on Public Cloud | Accepted | 2026-03-19 | Runtime operating model |
| [0004](0004-deploy-airflow-workloads-as-kubernetes-pods.md) | Deploy Airflow Workloads as Kubernetes Pods | Accepted | 2026-03-19 | Kubernetes runtime standardization for orchestration |
| [0005](0005-decouple-stream-processing-and-search-sinks-with-kafka-connect.md) | Decouple Stream Processing and Search Sinks with Kafka Connect | Accepted | 2026-03-19 | Flink/Kafka Connect sink boundary |
| [0006](0006-dead-letter-topic-strategy-for-malformed-operational-events.md) | Dead-Letter Topic Strategy for Malformed Operational Events | Accepted | 2026-03-19 | Error isolation and dead-letter handling |
| [0007](0007-standardize-local-kubernetes-development-on-minikube-docker.md) | Standardize Local Kubernetes Development on Minikube Docker | Accepted | 2026-03-19 | Local developer environment standard |
| [0008](0008-establish-platform-security-baseline-and-secrets-governance.md) | Establish Platform Security Baseline and Secrets Governance | Proposed | 2026-03-20 | Security baseline and secret-management controls |
| [0009](0009-define-reliability-slos-and-recovery-objectives.md) | Define Reliability SLOs and Recovery Objectives | Proposed | 2026-03-20 | Reliability objectives and recovery standards |
| [0010](0010-implement-cost-and-utilization-governance.md) | Implement Cost and Utilization Governance | Proposed | 2026-03-20 | Cost attribution, lifecycle, and efficiency controls |

## Top-down design reading order

1. Foundation and boundaries: 0001 -> 0002 -> 0003
2. Orchestration runtime model: 0004
3. Data-flow integration patterns: 0005 -> 0006
4. Developer environment standardization: 0007
5. Cross-cutting architecture governance: 0008 -> 0009 -> 0010

## ADR lifecycle workflow

### Status definitions

- Proposed: Candidate decision under review; not yet mandatory for implementation.
- Accepted: Approved decision; required baseline for implementation and operations.
- Superseded: Replaced by one or more newer ADRs; kept for historical traceability.
- Rejected: Considered and intentionally not adopted; retained to avoid re-litigating the same option set.

### Transition criteria

Proposed -> Accepted:

- Problem statement and scope boundaries are clearly documented.
- Trade-offs and risks are explicitly captured.
- Affected teams confirm ownership and implementation path.
- Related architecture docs and runbooks are updated or scheduled.

Accepted -> Superseded:

- New ADR explicitly references the prior ADR in context/decision or consequences.
- Prior ADR status is updated to Superseded.
- ADR index and related architecture documents are updated in the same change set.

Proposed -> Rejected:

- Alternative selected or decision no longer applicable.
- Rejection rationale documented with objective constraints.

### Governance rules

- Every material architecture change must reference an ADR (new or existing).
- Status changes must be done via pull request with at least one reviewer from the platform team.
- ADR updates should be atomic with documentation updates (architecture, runbooks, diagrams) when behavior changes.
- Do not delete old ADR files; preserve chronological decision history.

## Conventions

- Naming: `NNNN-short-kebab-case-title.md`
- Header includes status, date, deciders, and technical story
- Prefer one architectural decision per ADR
- Superseded or deprecated ADRs should remain in the log with updated status
