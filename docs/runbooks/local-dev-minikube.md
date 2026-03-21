# Local Development Runbook (Minikube Docker Driver)

## Purpose

This runbook provisions a local Kubernetes development environment for this repository using Minikube on top of Docker.

## Decision matrix

Canonical option-selection guidance is maintained in [../architecture/deployment-architecture.md](../architecture/deployment-architecture.md). The table below is a quick local summary.

| Use case | Recommended option | Why |
| --- | --- | --- |
| Validate Kubernetes namespaces, RBAC, and NetworkPolicies | Minikube with pods | Mirrors cluster-level controls and overlay behavior |
| Test deployment overlays before staging/production promotion | Minikube with pods | Uses the same kustomize assets and environment conventions |
| Debug pod scheduling or service-to-service communication | Minikube with pods | Exposes Kubernetes runtime behavior directly |
| Fast topic/schema/connector iteration on constrained laptop | Pure Docker Compose | Lower local resource footprint and faster startup |
| Kafka Connect and Schema Registry integration only | Pure Docker Compose | Minimal setup path for event backbone workflows |

If your goal includes Kubernetes parity, use Minikube. If your goal is lightweight local integration speed, use pure Docker Compose.

## Scope

This runbook covers local Kubernetes bootstrap, environment overlay apply, verification, and cleanup for the development profile.

For a lightweight local option without Kubernetes pod scheduling, use [local-dev-docker-compose.md](local-dev-docker-compose.md).

## Prerequisites

- Docker Desktop running
- Minikube installed
- kubectl installed

macOS installation example:

```bash
brew install minikube kubectl
```

## Bootstrap

From repository root:

```bash
scripts/dev/setup_minikube_docker.sh
```

Optional tuning:

```bash
scripts/dev/setup_minikube_docker.sh --profile etp-dev --cpus 6 --memory 12288 --disk-size 60g
scripts/dev/setup_minikube_docker.sh --skip-overlay-apply
```

What the setup script does:

- Starts a Minikube cluster with Docker driver
- Switches kubectl context to the profile
- Enables ingress and metrics-server addons
- Applies `infra/kubernetes/base` and `infra/kubernetes/overlays/dev`

## Verify

```bash
kubectl config current-context
kubectl get nodes
kubectl get ns | grep dev-
kubectl get networkpolicy -A
```

## Clean up

```bash
scripts/dev/delete_minikube_docker.sh
scripts/dev/delete_minikube_docker.sh --profile etp-dev
```

## Notes

- If Docker is not running, setup fails fast with a clear message.
- If your machine is resource constrained, lower CPU and memory values.
- The profile defaults to `etp-dev` to avoid colliding with a default Minikube profile.

## Related documents

- [local-dev-docker-compose.md](local-dev-docker-compose.md)
- [../../infra/kubernetes/base/README.md](../../infra/kubernetes/base/README.md)
- [../../infra/kubernetes/overlays/dev/README.md](../../infra/kubernetes/overlays/dev/README.md)
