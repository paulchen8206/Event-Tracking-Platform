# Helm deployment assets

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

Deploy QA:

```bash
helm upgrade --install etp-platform-qa infra/helm/charts/platform \
  -n qa-platform --create-namespace \
  -f infra/helm/values/qa/platform-values.yaml
```

Deploy staging:

```bash
helm upgrade --install etp-platform-stg infra/helm/charts/platform \
  -n stg-platform --create-namespace \
  -f infra/helm/values/stg/platform-values.yaml
```

Deploy production:

```bash
helm upgrade --install etp-platform-prod infra/helm/charts/platform \
  -n prod-platform --create-namespace \
  -f infra/helm/values/prod/platform-values.yaml
```

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
