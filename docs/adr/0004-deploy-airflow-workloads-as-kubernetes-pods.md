# ADR 0004: Deploy Airflow Workloads as Kubernetes Pods

- Status: Accepted
- Date: 2026-03-19
- Deciders: Data Platform and Engineering Team
- Technical Story: Standardize orchestration runtime by running Airflow components as Kubernetes workloads.

## Context

The platform relies on Airflow for orchestration of transformation and data-quality workflows. Existing architecture decisions already establish Kubernetes as the primary runtime platform and define namespace boundaries for data workloads.

To align operations, deployment controls, and environment promotion across platform services, Airflow runtime components should use the same Kubernetes delivery model as other core workloads.

Requirements:

- Environment-consistent deployment model across dev, staging, and prod
- Namespace and policy alignment with ADR 0002
- Operational scaling and resilience controls for scheduler and workers
- Integration with existing secrets, metrics, and CI/CD promotion flow

## Decision

We will deploy Airflow components as Kubernetes pods in the data namespace for each environment.

### 1. Runtime placement

- Namespace: `<env>-data-airflow`
- Core components deployed as Kubernetes workloads:
  - scheduler
  - webserver
  - triggerer (if enabled)
  - workers/executors per selected Airflow executor mode

### 2. Environment model

- Development: lightweight Airflow deployment profile for faster feedback
- Staging: production-like profile with representative configuration
- Production: hardened profile with HA and operational guardrails

### 3. Deployment and promotion

- Airflow images and configuration are versioned and promoted as immutable artifacts
- Environment-specific differences are expressed in Kubernetes overlays
- DAG code rollout follows the same gated promotion flow as other deployables

### 4. Security and policy

- Namespace-scoped RBAC and service accounts
- Default-deny network policy posture with explicit outbound allow-lists
- Secrets managed per environment namespace (no cross-namespace sharing)

## Consequences

### Positive

- Consistent operational model with the rest of the platform
- Improved parity across environments for orchestration behavior
- Better integration with existing Kubernetes observability and policy controls
- Simplified runbook alignment for deployment and rollback

### Trade-offs

- Additional Kubernetes operational complexity for Airflow stateful dependencies
- Executor and worker sizing requires environment-specific tuning
- DAG and plugin packaging must be standardized to avoid drift

### Risks and Mitigations

- Risk: Scheduler instability or DAG backlog under peak load
  - Mitigation: Separate resource classes for scheduler and workers, plus autoscaling controls
- Risk: Environment drift in Airflow config and plugins
  - Mitigation: Pin image versions and config through overlays and CI checks
- Risk: Secret/config sprawl across namespaces
  - Mitigation: Enforce naming conventions and centralized secret management policy

## Scope Boundaries

This ADR does not define:

- Specific executor choice (Celery, KubernetesExecutor, or hybrid)
- Helm/operator packaging standard
- Metadata database hosting strategy for production
- Detailed SLOs and alert thresholds

These are addressed in follow-up operations ADRs.

## Implementation Notes

- Namespace topology reference: `docs/architecture/deployment-runtime-topology.md`
- Existing namespace convention includes `dev-data-airflow`, `staging-data-airflow`, `prod-data-airflow`
- Overlay structure: `infra/kubernetes/overlays/`
- Local validation environment: `scripts/dev/setup_minikube_docker.sh`
