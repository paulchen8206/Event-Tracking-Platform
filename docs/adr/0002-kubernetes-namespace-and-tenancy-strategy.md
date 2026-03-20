# ADR 0002: Kubernetes Namespace and Tenancy Strategy

- Status: Accepted
- Date: 2026-03-19
- Deciders: Data Platform and Engineering Team
- Technical Story: Define namespace boundaries, tenancy isolation, and environment promotion model on Kubernetes.

## Context

ADR 0001 established Kubernetes on public cloud as the base engineering platform. The next architectural decision is how to structure namespaces and tenancy boundaries so platform and application teams can deploy safely at scale.

The platform must support:

- Multiple environments (dev, staging, prod)
- Shared platform infrastructure (Kafka, Flink, observability)
- Multiple application and data workloads with different blast-radius requirements
- Clear access boundaries for internal-only and customer-facing systems

Without a consistent namespace strategy, operational risk increases through accidental cross-environment access, over-permissive RBAC, and hard-to-audit ownership.

## Decision

We will use an environment-first, domain-segmented namespace strategy.

### 1. Cluster and Environment Model

- Production runs in a dedicated Kubernetes cluster.
- Non-production can run in a shared cluster with strict namespace and policy isolation.
- Every workload is deployed with explicit environment overlays (`dev`, `staging`, `prod`).

### 2. Namespace Convention

Namespaces follow this naming pattern:

`<environment>-<domain>-<workload>`

Examples:

- `prod-platform-kafka`
- `prod-platform-flink`
- `prod-data-airflow`
- `prod-app-ingestion-api`
- `staging-app-serving-api`

### 3. Domain Boundaries

- `platform`: shared runtime infrastructure (Kafka, Flink operator/runtime, schema registry, shared ingress components)
- `data`: orchestration and transformation workloads (Airflow, dbt runners, data quality jobs)
- `app`: product and integration services (ingestion API, serving API, CDC bridge)
- `ops`: observability and operational control plane components

### 4. Tenancy and Security Isolation

- Tenant-level isolation is enforced at data and application layers, not by creating one namespace per tenant.
- Namespace-level RBAC restricts write access by owning team and environment.
- NetworkPolicies default to deny and allow only explicit service-to-service paths.
- Secrets are scoped to namespace and environment; cross-namespace secret sharing is prohibited.

### 5. Stateful Workloads

- Kafka and Flink stateful workloads run in dedicated platform namespaces with dedicated storage classes.
- Application services run in app namespaces and must not mount platform state volumes.
- Persistent volumes must include retention class and backup policy labels.

### 6. Deployment and Promotion

- CI pipelines deploy to `dev` first, then `staging`, then `prod` with approval gates.
- Promotions occur by immutable artifact version, not by rebuilding images per environment.
- Namespace quotas and limit ranges are mandatory in all environments.

## Consequences

### Positive

- Clear ownership and blast-radius boundaries
- Improved auditability of changes and access controls
- Repeatable deployment model across infrastructure and applications
- Better compatibility with GitOps and policy-as-code workflows

### Trade-offs

- More namespaces and policy objects to manage
- Additional upfront effort for RBAC and network policy definitions
- Need for tooling to enforce naming and policy consistency

### Risks and Mitigations

- Risk: Namespace sprawl and inconsistent conventions
  - Mitigation: Enforce naming and labels through admission policy and CI checks
- Risk: Overly broad service-to-service access
  - Mitigation: Default-deny NetworkPolicies and periodic policy review
- Risk: Environment drift between staging and production
  - Mitigation: Use the same manifests with overlay-only differences and automated drift detection

## Scope Boundaries

This ADR does not define:

- Exact RBAC role bindings per team
- Vendor-specific identity integration
- Detailed disaster recovery runbooks
- Per-application autoscaling thresholds

These will be addressed in follow-up operational and security ADRs.

## Implementation Notes

- Align overlays under `infra/kubernetes/overlays/dev`, `infra/kubernetes/overlays/staging`, and `infra/kubernetes/overlays/prod`.
- Keep shared platform manifests under `infra/kubernetes/base` and apply environment-specific overlays.
- Apply resource labeling standards for ownership, environment, cost center, and data classification.
