# Helm Deployment Guide

## Purpose

This directory holds Helm charts and environment values for shared-environment and production deployments.

## Model

- QA, staging, and production are deployed by Helm.
- QA and production use similar Kubernetes pod-based component topology.
- QA keeps minimal pod sizing for cost-efficient pre-production validation.
- Differences are limited to environment values (replicas, resources, secrets, and endpoints).

## Recommended layout

- `charts/`: service and platform charts
- `values/qa/`: QA values files (prod-like topology, minimal pod config)
- `values/stg/`: staging values files (stg profile)
- `values/prod/`: production values files

## Chart usage

Template validation:

```bash
helm template etp-platform infra/helm/charts/platform \
  -f infra/helm/values/qa/platform-values.yaml
```

Environment deployment matrix:

| Environment | Release name | Namespace | Values file |
| --- | --- | --- | --- |
| QA | `etp-platform-qa` | `qa-platform` | `infra/helm/values/qa/platform-values.yaml` |
| staging | `etp-platform-stg` | `stg-platform` | `infra/helm/values/stg/platform-values.yaml` |
| production | `etp-platform-prod` | `prod-platform` | `infra/helm/values/prod/platform-values.yaml` |

Deploy command pattern:

```bash
helm upgrade --install <RELEASE_NAME> infra/helm/charts/platform \
  -n <NAMESPACE> --create-namespace \
  -f <VALUES_FILE>
```

For promotion order, approval gates, rollback flow, and health checks, use [../../docs/runbooks/prod-rollback-healthcheck.md](../../docs/runbooks/prod-rollback-healthcheck.md).

## Production hardening

The platform chart supports production-focused controls per component and per Airflow role:

- Horizontal Pod Autoscaler (`autoscaling.*`)
- Pod Disruption Budget (`podDisruptionBudget.*`)
- Ingress (`ingress.*`)
- Ingress TLS and annotations (`ingress.tls.*`, `ingress.annotations`)
- NetworkPolicy ingress controls (`networkPolicy.*`)

The production values file enables these controls for externally accessed APIs and core runtime pods. Update ingress hosts to match your DNS and ingress controller setup.

## Related documents

- [docs/architecture/deployment-architecture.md](../../docs/architecture/deployment-architecture.md)
- [docs/architecture/deployment-runtime-topology.md](../../docs/architecture/deployment-runtime-topology.md)
- [docs/runbooks/prod-rollback-healthcheck.md](../../docs/runbooks/prod-rollback-healthcheck.md)
- [infra/kubernetes/overlays](../kubernetes/overlays)
