# CI/CD automation, production rollback, and health-check runbook

## Purpose

Provide standard procedures for automated CI/CD deployment across dev, QA, staging, and production, plus production health validation and controlled rollback.

## Scope

Applies to Helm-managed releases of the platform chart in:

- `dev-platform`
- `qa-platform`
- `stg-platform`
- `prod-platform`

## Inputs

- Kubernetes context targeting all deployment clusters
- Helm v3 CLI access
- Release names:
  - `etp-platform-dev`
  - `etp-platform-qa`
  - `etp-platform-stg`
  - `etp-platform-prod`
- Values files:
  - `infra/helm/values/qa/platform-values.yaml` (reuse as baseline for dev if no dedicated dev values file exists)
  - `infra/helm/values/stg/platform-values.yaml`
  - `infra/helm/values/prod/platform-values.yaml`

## Workflow

### 1. CI pipeline (commit and pull-request automation)

Run these jobs automatically for every PR and target branch:

1. Validate chart renderability:

```bash
helm template etp-platform-dev infra/helm/charts/platform -f infra/helm/values/qa/platform-values.yaml > /tmp/etp-dev.yaml
helm template etp-platform-qa infra/helm/charts/platform -f infra/helm/values/qa/platform-values.yaml > /tmp/etp-qa.yaml
helm template etp-platform-stg infra/helm/charts/platform -f infra/helm/values/stg/platform-values.yaml > /tmp/etp-stg.yaml
helm template etp-platform-prod infra/helm/charts/platform -f infra/helm/values/prod/platform-values.yaml > /tmp/etp-prod.yaml
```

1. Validate workload health invariants from rendered manifests:

```bash
grep -n "kind: HorizontalPodAutoscaler" /tmp/etp-prod.yaml
grep -n "kind: PodDisruptionBudget" /tmp/etp-prod.yaml
grep -n "kind: NetworkPolicy" /tmp/etp-prod.yaml
grep -n "kind: Ingress" /tmp/etp-prod.yaml
```

1. Block merge when any command exits non-zero.

### 2. CD pipeline (environment promotion automation)

Promote in this strict order with stage-specific gates:

Deployment command baseline is maintained in [infra/helm/README.md](../../infra/helm/README.md).

1. Dev auto-deploy on merge to main:

```bash
helm upgrade --install etp-platform-dev infra/helm/charts/platform \
  -n dev-platform --create-namespace \
  -f infra/helm/values/qa/platform-values.yaml \
  --wait --timeout 10m
```

1. QA auto-deploy after dev health checks pass:

```bash
helm upgrade --install etp-platform-qa infra/helm/charts/platform \
  -n qa-platform --create-namespace \
  -f infra/helm/values/qa/platform-values.yaml \
  --wait --timeout 10m
```

1. Staging deploy with manual approval and QA sign-off:

```bash
helm upgrade --install etp-platform-stg infra/helm/charts/platform \
  -n stg-platform --create-namespace \
  -f infra/helm/values/stg/platform-values.yaml \
  --wait --timeout 10m
```

1. Production deploy with change-window approval and staging verification evidence:

```bash
helm upgrade --install etp-platform-prod infra/helm/charts/platform \
  -n prod-platform --create-namespace \
  -f infra/helm/values/prod/platform-values.yaml \
  --wait --timeout 10m
```

### 3. Automated post-deploy health checks by environment

Run immediately after each deploy job:

```bash
kubectl get deploy,po,svc,ingress -n <NAMESPACE> -l app.kubernetes.io/instance=<RELEASE_NAME>
kubectl get hpa,pdb,networkpolicy -n <NAMESPACE>
kubectl get events -n <NAMESPACE> --sort-by=.lastTimestamp | tail -n 30
```

Fail the pipeline if rollout status does not complete within timeout:

```bash
kubectl rollout status deploy/<DEPLOYMENT_NAME> -n <NAMESPACE> --timeout=180s
```

### 4. Automated rollback trigger policy

Trigger rollback automatically for production when either condition is met:

1. One or more critical deployments fail rollout status checks after retry budget is exhausted.
2. Application SLO breach is sustained for 10 minutes post-deploy.

Rollback command:

```bash
helm rollback etp-platform-prod <REVISION> -n prod-platform --wait --timeout 10m
```

After rollback, re-run the post-deploy health checks and attach command output to incident records.

### 5. Capture production release and pod status

```bash
helm list -n prod-platform
helm history etp-platform-prod -n prod-platform
kubectl get deploy,po,svc,ingress -n prod-platform -l app.kubernetes.io/instance=etp-platform-prod
```

### 6. Run immediate production health checks

```bash
kubectl get events -n prod-platform --sort-by=.lastTimestamp | tail -n 30
kubectl rollout status deploy/etp-platform-prod-ingestionapi -n prod-platform --timeout=180s
kubectl rollout status deploy/etp-platform-prod-servingapi -n prod-platform --timeout=180s
kubectl rollout status deploy/etp-platform-prod-kafkaconnect -n prod-platform --timeout=180s
kubectl rollout status deploy/etp-platform-prod-observability -n prod-platform --timeout=180s
kubectl rollout status deploy/etp-platform-prod-airflow-webserver -n prod-platform --timeout=180s
kubectl rollout status deploy/etp-platform-prod-airflow-scheduler -n prod-platform --timeout=180s
kubectl rollout status deploy/etp-platform-prod-airflow-worker -n prod-platform --timeout=180s
```

### 7. Validate production ingress and TLS

```bash
kubectl get ingress -n prod-platform
kubectl describe ingress etp-platform-prod-ingestionapi -n prod-platform
kubectl describe ingress etp-platform-prod-servingapi -n prod-platform
kubectl describe ingress etp-platform-prod-airflow-webserver -n prod-platform
kubectl get certificate -n prod-platform
```

### 8. Validate production autoscaling and disruption protections

```bash
kubectl get hpa -n prod-platform
kubectl get pdb -n prod-platform
kubectl get networkpolicy -n prod-platform
```

### 9. Roll back production when required

Identify previous stable revision from history and run:

```bash
helm rollback etp-platform-prod <REVISION> -n prod-platform --wait --timeout 10m
```

Re-run steps 5-8 after rollback completes.

## Operability notes

- Trigger rollback for sustained error rates, widespread pod crash loops, or failed rollout completion.
- Prefer rollback over in-place hot fixes during active incidents.
- Record deployed revision, rollback revision, incident start/end times, and primary symptom in your incident timeline.
- Keep CD gates strict: dev and QA automatic, staging and production approval-gated.
- Store CI/CD artifacts for every environment promotion (render output, rollout checks, and rollback evidence).

## Related documents

- [infra/helm/README.md](../../infra/helm/README.md)
- [docs/architecture/deployment-architecture.md](../architecture/deployment-architecture.md)
- [docs/architecture/deployment-runtime-topology.md](../architecture/deployment-runtime-topology.md)
