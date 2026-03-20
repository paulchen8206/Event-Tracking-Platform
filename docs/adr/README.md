# Architecture Decision Records

This directory tracks major architecture and operations decisions for the Event Tracking Platform.

## ADR Index

| ADR | Title | Status | Date | Scope |
| --- | --- | --- | --- | --- |
| [0001](0001-base-engineering-platform-on-kubernetes.md) | Base Engineering Platform on Kubernetes in Public Cloud | Accepted | 2026-03-19 | Base runtime architecture |
| [0002](0002-kubernetes-namespace-and-tenancy-strategy.md) | Kubernetes Namespace and Tenancy Strategy | Accepted | 2026-03-19 | Namespace, tenancy, and policy boundaries |
| [0003](0003-managed-vs-self-hosted-kafka-flink.md) | Managed vs Self-Hosted Kafka and Flink on Public Cloud | Accepted | 2026-03-19 | Runtime operating model |
| [0004](0004-decouple-stream-processing-and-search-sinks-with-kafka-connect.md) | Decouple Stream Processing and Search Sinks with Kafka Connect | Accepted | 2026-03-19 | Flink/Kafka Connect sink boundary |
| [0005](0005-dead-letter-topic-strategy-for-malformed-operational-events.md) | Dead-Letter Topic Strategy for Malformed Operational Events | Accepted | 2026-03-19 | Error isolation and dead-letter handling |
| [0006](0006-standardize-local-kubernetes-development-on-minikube-docker.md) | Standardize Local Kubernetes Development on Minikube Docker | Accepted | 2026-03-19 | Local developer environment standard |
| [0007](0007-deploy-airflow-workloads-as-kubernetes-pods.md) | Deploy Airflow Workloads as Kubernetes Pods | Accepted | 2026-03-19 | Kubernetes runtime standardization for orchestration |

## Conventions

- Naming: `NNNN-short-kebab-case-title.md`
- Header includes status, date, deciders, and technical story
- Prefer one architectural decision per ADR
- Superseded or deprecated ADRs should remain in the log with updated status
