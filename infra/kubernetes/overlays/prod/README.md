# Production Overlay

This overlay contains production namespace and baseline guardrails:

- Namespace naming aligned with ADR 0002
- Default deny network policies with DNS egress allowance
- Resource quotas and default container limits

Apply with:

```bash
kubectl apply -k infra/kubernetes/overlays/prod
```
