# Kubernetes Base Manifests

This directory contains cluster-level baseline manifests shared across environments.

Use overlays for environment-specific namespace resources and namespaced policies.

## Included Baseline Objects

- Read-only `ClusterRole` for platform observability and diagnostics

## Apply

```bash
kubectl apply -k infra/kubernetes/base
```
