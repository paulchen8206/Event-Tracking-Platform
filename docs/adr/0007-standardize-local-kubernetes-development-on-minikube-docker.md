# ADR 0007: Standardize Local Kubernetes Development on Minikube Docker

- Status: Accepted
- Date: 2026-03-19
- Deciders: Data Platform and Engineering Team
- Technical Story: Provide a repeatable local Kubernetes developer environment aligned with repository overlays and guardrails.

## Context

The repository includes Kubernetes base and environment overlays. To reduce onboarding friction and improve parity for integration testing, developers need a standardized local Kubernetes runtime.

Requirements:

- Works on macOS developer machines with Docker Desktop
- Reuses existing kustomize base and dev overlay resources
- Includes practical defaults and fast bootstrap/teardown scripts

## Decision

We standardize local Kubernetes development on Minikube using the Docker driver.

### 1. Default local profile

- Profile: `etp-dev`
- Driver: `docker`
- Baseline resources: configurable CPU/memory/disk with practical defaults

### 2. Bootstrap flow

- Start Minikube profile
- Set current kubectl context to profile
- Enable ingress and metrics-server addons
- Apply `infra/kubernetes/base` + `infra/kubernetes/overlays/dev`

### 3. Teardown flow

- Provide profile-scoped deletion command/script
- Keep cluster lifecycle explicit and developer-controlled

## Consequences

### Positive

- Fast and repeatable local cluster setup for contributors
- Better confidence in overlay correctness before shared-environment deploys
- Shared local conventions for troubleshooting and demos

### Trade-offs

- Docker Desktop resource limits can block default sizing
- Minikube behavior can differ from managed production clusters
- Addon startup time increases local bootstrap duration

### Risks and Mitigations

- Risk: Local machine constraints cause setup failure
  - Mitigation: Provide tunable resource flags and clear failure messages
- Risk: Context confusion with existing clusters
  - Mitigation: Use dedicated profile name and explicit context switch
- Risk: Inconsistent local environments across team
  - Mitigation: Maintain runbook and scripts as repository-standard tooling

## Scope Boundaries

This ADR does not define:

- Production cluster provisioning approach
- Multi-node local cluster requirements
- Local emulation of all managed cloud dependencies

These remain separate infrastructure and environment decisions.

## Implementation Notes

- Bootstrap script: `scripts/dev/setup_minikube_docker.sh`
- Teardown script: `scripts/dev/delete_minikube_docker.sh`
- Overlay apply script reuse: `scripts/dev/apply_k8s_overlay.sh`
- Runbook: `docs/runbooks/local-dev-minikube.md`
