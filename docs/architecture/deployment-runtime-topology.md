# Event Tracking Platform Runtime Topology

## Purpose

This document complements [deployment-architecture.md](deployment-architecture.md) by defining runtime placement details: namespace topology, component placement, network boundaries, and promotion flow across environments.

## Runtime Topology Diagram

```mermaid
flowchart LR
    subgraph Cluster[Environment Cluster]
        subgraph NSK[<env>-platform-kafka]
            KAFKA[Kafka Brokers]
            SR[Schema Registry]
            KCONNECT[Kafka Connect]
        end

        subgraph NSF[<env>-platform-flink]
            FJM[JobManager]
            FTM[TaskManagers]
        end

        subgraph NSA[<env>-app-ingestion-api]
            ING[Ingestion API]
        end

        subgraph NSS[<env>-app-serving-api]
            SVCAPI[Serving API]
        end

        subgraph NSO[<env>-ops-observability]
            O11Y[Observability Stack]
        end

        subgraph NSD[<env>-data-airflow]
            AIRFLOW[Airflow DAGs]
            SPARK[Spark Lakehouse Consumer]
            DBT[dbt Semantic Layer]
        end
    end

    ING --> KAFKA
    KAFKA --> FJM
    FTM --> KAFKA
    KCONNECT --> KAFKA
    KCONNECT --> ES[(Elasticsearch)]
    KAFKA --> SPARK
    SPARK --> S3[(S3/Iceberg)]
    S3 --> SNOW[(Snowflake)]
    AIRFLOW --> SPARK
    AIRFLOW --> DBT
    DBT --> SNOW
    SVCAPI --> SNOW
    SVCAPI --> ES
    O11Y -. metrics/logs .-> KAFKA
    O11Y -. metrics/logs .-> FJM
```

## Configuration Diagram (dev vs production)

```mermaid
flowchart LR
    subgraph DEV[dev configuration]
        D_K8S[Minikube or shared dev Kubernetes]
        D_SIZING[Low to moderate resource profile]
        D_SEC[Baseline guardrails and smoke checks]
        D_DEPLOY[Overlay-driven deploy and fast iteration]
    end

    subgraph PROD[production configuration]
        P_K8S[Dedicated/isolated Kubernetes boundary]
        P_SIZING[HA and scale-oriented resource profile]
        P_SEC[TLS, strict RBAC, NetworkPolicy, PDB, HPA]
        P_DEPLOY[Helm release gates, rollback and health checks]
    end

    D_K8S --> P_K8S
    D_SIZING --> P_SIZING
    D_SEC --> P_SEC
    D_DEPLOY --> P_DEPLOY
```

### Configuration focus areas

| Area | dev | production |
| --- | --- | --- |
| Cluster posture | local/shared and iteration-focused | isolated and reliability-focused |
| Capacity strategy | minimal to moderate sizing | HA sizing with resiliency headroom |
| Security baseline | namespace guardrails and baseline policies | strict policy enforcement with production hardening |
| Deployment controls | rapid overlay updates and smoke validation | gated Helm releases with rollback procedures |
| Observability | developer troubleshooting visibility | SLO-driven monitoring and incident response |

## Environment delta summary

The runtime wiring stays consistent across environments; only sizing, management model, and operability controls change.

| Environment | Runtime model | Helm profile | Sizing posture | Security/operability posture |
| --- | --- | --- | --- | --- |
| dev | Local Minikube or shared dev cluster | optional overlays, baseline values | minimal to moderate | namespace guardrails and smoke checks |
| QA | Shared Kubernetes cluster | qa values | minimal (production-like topology) | promotion validation gates |
| staging | Shared Kubernetes cluster | stg values | moderate | pre-production validation and approval gate |
| production | Dedicated/isolated cluster boundary | prod values | scaled/HA | ingress TLS, HPA, PDB, NetworkPolicy, rollback controls |

Naming note: this document uses `staging` in prose and topology labels; Helm values and some namespace/release identifiers use the `stg` shorthand.

Use [deployment-architecture.md](deployment-architecture.md) for deployment options and this document's runtime topology diagram for communication flow.

## Namespace Placement

Namespace naming follows ADR 0002:

- `<env>-platform-kafka`
- `<env>-platform-flink`
- `<env>-app-ingestion-api`
- `<env>-app-serving-api`
- `<env>-data-airflow`
- `<env>-ops-observability`

Where `<env>` is one of `dev`, `qa`, `staging`, `prod`.

## Component Placement Matrix

| Component | dev | QA | staging | production |
| --- | --- | --- | --- | --- |
| Kafka brokers | Kubernetes (self-hosted/local capable) | Managed or dedicated | Managed or dedicated | Managed or dedicated |
| Kafka Connect | Kubernetes/local compose | Kubernetes pods via Helm (minimal) | Kubernetes pods via Helm | Kubernetes pods via Helm |
| Flink runtime | Kubernetes/self-hosted | Managed or dedicated | Managed or dedicated | Managed or dedicated |
| Ingestion API | Kubernetes app namespace | Kubernetes pods via Helm (minimal) | Kubernetes pods via Helm | Kubernetes pods via Helm |
| Serving API | Kubernetes app namespace | Kubernetes pods via Helm (minimal) | Kubernetes pods via Helm | Kubernetes pods via Helm |
| Airflow/dbt runners | Kubernetes data namespace | Kubernetes pods via Helm (minimal) | Kubernetes pods via Helm | Kubernetes pods via Helm |
| Elasticsearch | External managed or dedicated | External managed or dedicated | External managed or dedicated | External managed or dedicated |
| Snowflake | External managed | External managed | External managed | External managed |

## Network and Security Boundaries

- Default deny network policy in each namespace
- Explicit allow-list rules for service-to-service traffic:
  - ingestion API -> Kafka
  - Flink -> Kafka
  - serving API -> Kafka (where required)
- Team-scoped RoleBindings per namespace
- Secrets scoped by namespace/environment

## Promotion Flow

```mermaid
flowchart LR
    DEV[dev overlay deploy] --> STG[staging overlay deploy]
    STG --> PROD[production overlay deploy]

    DEV --> QA[QA Helm deploy]
    QA --> STG

    IMG[Immutable image tag] --> DEV
    IMG --> QA
    IMG --> STG
    IMG --> PROD

    CONTRACT[Schema/topic/connector validation] --> DEV
    CONTRACT --> QA
    CONTRACT --> STG
    CONTRACT --> PROD
```

Promotion principles:

- Promote immutable artifacts, do not rebuild per environment
- Apply the same base manifests with overlay-only deltas
- Validate topic/connector/schema conformance before each promotion step
- Keep staging and production on the same Helm chart set, differing only by values files

## Local-to-Shared Parity Notes

- Local development supports two operation modes.
- Option A: Minikube with pods for namespace and policy parity
- Option B: pure Docker Compose for lightweight local integration
- Local Minikube uses the same namespace conventions and overlay assets as shared environments
- Local Docker Compose stack is used for fast Kafka ecosystem iteration, while shared environments rely on cluster-managed or managed services
- Smoke test coverage for Kafka Connect DLQ path should run before promoting connector changes

## Related documents

- [deployment-architecture.md](deployment-architecture.md)
- [system-architecture.md](system-architecture.md)
- [spring-boot-framework-and-patterns.md](spring-boot-framework-and-patterns.md)
- [../runbooks/local-dev-minikube.md](../runbooks/local-dev-minikube.md)
- [../adr/0002-kubernetes-namespace-and-tenancy-strategy.md](../adr/0002-kubernetes-namespace-and-tenancy-strategy.md)
- [../adr/0003-managed-vs-self-hosted-kafka-flink.md](../adr/0003-managed-vs-self-hosted-kafka-flink.md)
- [../adr/0005-decouple-stream-processing-and-search-sinks-with-kafka-connect.md](../adr/0005-decouple-stream-processing-and-search-sinks-with-kafka-connect.md)
- [../adr/0004-deploy-airflow-workloads-as-kubernetes-pods.md](../adr/0004-deploy-airflow-workloads-as-kubernetes-pods.md)
