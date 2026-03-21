# AWS Well-Architected Architecture Improvement Plan

## Purpose

This document maps the current Event Tracking Platform architecture to AWS Well-Architected pillars and defines concrete improvements to increase reliability, security, operational excellence, performance efficiency, and cost efficiency.

## Scope

- Runtime and deployment architecture
- Data pipeline orchestration and recovery paths
- Security boundaries and governance controls
- Observability, resilience, and scaling posture
- Cost controls and workload right-sizing

## Pillar-by-pillar improvements

### 1) Operational Excellence

Current strengths:

- ADR-driven architecture change history
- Environment overlays and Helm values per environment
- Local runbooks for Minikube and Docker Compose

Gaps:

- No standard service-level objectives (SLOs) for ingestion, orchestration, and serving
- Limited automated post-deploy verification gates tied to pipeline health

Improvements:

- Define SLOs and error budgets for key flows:
  - Kafka ingest availability
  - Airflow orchestration success rate
  - dbt model freshness and completion latency
  - serving API p95 latency
- Add continuous verification pipeline in CI/CD:
  - schema compatibility checks
  - connector health checks
  - Airflow DAG parse and trigger smoke checks
- Standardize incident playbooks for top failure modes:
  - Kafka lag growth
  - dbt run failures
  - Snowflake load lag

### 2) Security

Current strengths:

- Namespace-scoped tenancy and network policy guardrails
- Environment-level separation strategy

Gaps:

- Security posture not explicitly mapped to least-privilege IAM and secret rotation controls
- Encryption and key-management controls not documented as architecture requirements

Improvements:

- Enforce least-privilege IAM roles for each runtime component (Airflow, Connect, Flink, APIs).
- Move all runtime secrets to managed secret stores and enable rotation policies.
- Require encryption-in-transit and encryption-at-rest controls across Kafka, object storage, Snowflake, and Elasticsearch integrations.
- Add supply-chain controls:
  - image signing/verification
  - dependency scanning gates
  - SBOM generation for deployable artifacts

### 3) Reliability

Current strengths:

- Dead-letter strategy for malformed records
- Explicit readiness gating before orchestration trigger

Gaps:

- Multi-AZ/region recovery strategy and RTO/RPO targets not formalized
- Backpressure and retry behavior not consistently standardized across all components

Improvements:

- Define target RTO/RPO for each domain:
  - event backbone
  - semantic layer pipelines
  - serving APIs
- Standardize retries, timeouts, and circuit-breaking defaults for orchestration API and downstream calls.
- Introduce resilience tests in staging:
  - broker outage simulation
  - Snowflake transient failure injection
  - connector sink throttling tests
- Add replayability guarantees:
  - documented checkpoint and offset recovery procedures
  - controlled backfill runbooks per DAG

### 4) Performance Efficiency

Current strengths:

- Decoupled streaming and sink integration design
- Layered dbt model structure

Gaps:

- Workload sizing and autoscaling targets are not defined by empirical load profiles
- Some orchestration paths were historically serial where safe parallelism exists

Improvements:

- Establish per-component capacity baselines (dev, QA, staging, prod):
  - Kafka partitions and consumer concurrency
  - Flink task slots and checkpoint cadence
  - Airflow worker concurrency and queue policies
  - dbt model build parallelism and warehouse sizing
- Introduce periodic load testing for peak and burst scenarios.
- Maintain performance budgets (end-to-end pipeline latency targets) and enforce alerting on breach.

### 5) Cost Optimization

Current strengths:

- Environment-specific Helm values with reduced QA sizing
- Optional local modes to reduce cloud development spend

Gaps:

- No formalized cost observability and per-domain cost attribution model
- No explicit lifecycle policies for data retention tiers

Improvements:

- Define cost tags and ownership per workload domain (platform, customer analytics, internal tracking).
- Add cost dashboards and monthly review process for:
  - compute spend
  - Snowflake warehouse consumption
  - storage and retention growth
- Apply storage lifecycle policies:
  - hot/warm/cold retention strategy for raw and derived datasets
  - index lifecycle management for Elasticsearch operational data
- Implement scale-to-zero or low-footprint schedules for non-production workloads where possible.

### 6) Sustainability

Current strengths:

- Shared platform approach reduces duplicated tooling and runtime sprawl

Gaps:

- Sustainability controls are not tracked as architecture objectives

Improvements:

- Track utilization efficiency and idle runtime windows in non-production environments.
- Prefer managed services and right-sized instance classes where utilization is low or bursty.
- Add periodic architecture review to remove redundant pipelines and stale data products.

## Prioritized implementation roadmap

### 0-30 days

- Define SLOs and alert thresholds for ingestion, orchestration, and semantic layer.
- Add architecture controls baseline checklist to CI/CD (lint, policy, DAG parse, schema checks).
- Document RTO/RPO targets and owner assignments.

### 31-60 days

- Implement secret rotation and least-privilege role hardening.
- Enable cost and utilization dashboards by domain.
- Run staging resilience drills and capture action items.

### 61-90 days

- Implement automated failover and replay drills for critical data paths.
- Enforce performance budgets and regression detection in release gates.
- Apply storage retention and lifecycle policies for Snowflake, object storage, and Elasticsearch.

## Measurable outcomes

- Orchestration success rate >= 99.5% per 30-day window.
- End-to-end analytics pipeline freshness within defined SLO for >= 95% of runs.
- Mean time to detect (MTTD) and mean time to recover (MTTR) reduced quarter-over-quarter.
- Monthly cloud and warehouse cost variance within agreed budget threshold.

## Related documents

- [system-architecture.md](system-architecture.md)
- [deployment-architecture.md](deployment-architecture.md)
- [deployment-runtime-topology.md](deployment-runtime-topology.md)
- [../adr/README.md](../adr/README.md)
- [../adr/0008-establish-platform-security-baseline-and-secrets-governance.md](../adr/0008-establish-platform-security-baseline-and-secrets-governance.md)
- [../adr/0009-define-reliability-slos-and-recovery-objectives.md](../adr/0009-define-reliability-slos-and-recovery-objectives.md)
- [../adr/0010-implement-cost-and-utilization-governance.md](../adr/0010-implement-cost-and-utilization-governance.md)
