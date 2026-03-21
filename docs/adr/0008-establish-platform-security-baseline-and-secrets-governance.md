# ADR 0008: Establish Platform Security Baseline and Secrets Governance

- Status: Proposed
- Date: 2026-03-20
- Deciders: Data Platform and Engineering Team
- Technical Story: Standardize security controls across runtime, data, and deployment workflows with enforceable baseline policies.

## Context

The platform already applies namespace boundaries and default-deny network policies, but core security controls are not yet consistently defined as a mandatory baseline across all components and environments.

Current risks include:

- Inconsistent least-privilege identity policies between workloads
- Secrets handled with mixed patterns and undefined rotation standards
- Missing supply-chain control gates for build artifacts
- Uneven encryption requirements for data in transit and at rest

To align with AWS Well-Architected Security pillar guidance, we need one platform-wide baseline that teams can implement and audit.

## Decision

We will adopt a mandatory security baseline and secrets governance model for all deployable workloads.

### 1. Identity and access

- Enforce least-privilege runtime identities per component.
- Separate roles by workload function (ingestion, processing, orchestration, serving).
- Prohibit shared broad-privilege service roles across domains.

### 2. Secrets governance

- Store runtime secrets in managed secret stores only.
- Enforce rotation policy and ownership for each secret class.
- Block plaintext secret material in repository and CI logs.

### 3. Encryption baseline

- Require encryption in transit for service-to-service and managed-service traffic.
- Require encryption at rest for Kafka, object storage, Snowflake, and Elasticsearch-adjacent data paths.

### 4. Supply-chain controls

- Require image scanning in CI.
- Require dependency vulnerability scanning with severity gates.
- Generate and publish SBOM artifacts for release builds.

## Consequences

### Positive

- Consistent, auditable security posture across environments.
- Reduced breach exposure from over-privileged roles and static secrets.
- Faster incident response due to clear ownership and controls.

### Trade-offs

- Additional implementation overhead in CI/CD and runtime configuration.
- Initial delivery velocity impact while teams migrate secrets and role policies.

### Risks and Mitigations

- Risk: Migration complexity across existing services
  - Mitigation: phased rollout by domain with temporary compatibility windows
- Risk: Broken runtime access due to overly strict policies
  - Mitigation: pre-production policy validation and canary release checks

## Scope Boundaries

This ADR does not define:

- Specific cloud vendor service names or account structures
- Application-level authN/authZ design for customer-facing APIs
- End-user identity federation architecture

## Implementation Notes

- Baseline controls are tracked in: `docs/architecture/aws-well-architected-improvement-plan.md`
- Existing policy foundation: `docs/adr/0002-kubernetes-namespace-and-tenancy-strategy.md`
