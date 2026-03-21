# Event Tracking Platform Repository

A streaming-first repository structure for a data platform aligned to this stack:

- Kafka and CDC for event ingestion
- Apache Flink for stream processing
- Airflow for orchestration
- dbt for warehouse transformations
- Snowflake as the primary analytical warehouse
- PostgreSQL for transactional and operational data
- Elasticsearch for search-oriented and document-style workloads
- Kubernetes, Docker, and CI/CD for deployment and operations

The platform is intended to support two broad consumer groups:

- Customer-facing analytics products and reporting experiences
- Internal operational mail-tracking and workflow monitoring

## Tech Stack

- Application framework: Java Spring Boot
- Runtime and packaging: Java 17, Python 3, Maven
- Workflow orchestration: Apache Airflow
- Streaming and messaging: Apache Kafka, Kafka Connect, Schema Registry
- Stream processing: Apache Flink
- Lakehouse and analytics processing: Apache Spark Structured Streaming, Apache Iceberg
- Transformation and semantic modeling: dbt
- Data warehouse: Snowflake
- Operational datastore and CDC source: PostgreSQL, Debezium-style CDC patterns
- Search and operational dashboards: Elasticsearch, Kibana
- Object storage (local dev): MinIO (S3-compatible)
- Infrastructure and deployment: Docker Compose, Kubernetes, Helm

## License announcement

This repository currently does not include an open-source license file.

Unless and until a LICENSE file is added, all rights are reserved by the repository owner.

## Repository layout

```text
.
├── docs/                    # Architecture, ADRs, diagrams, runbooks, product notes
├── infra/                   # Docker, Helm, and Kubernetes manifests
├── platform/                # Core platform components: Kafka, Flink, Airflow, dbt
├── scripts/                 # Bootstrap, local development, and release scripts
├── services/                # Operational and data application services
├── shared/                  # Reusable contracts
└── storage/                 # Search and dashboard assets
```

## Top-Level Responsibilities

### docs/

- `architecture/`: System design docs and integration boundaries
- `adr/`: Architecture decision records
- `diagrams/`: Data flow, deployment, and lineage diagrams
- `runbooks/`: Operational procedures and incident response
- `product/`: Event taxonomy, analytics requirements, operational use cases, and stakeholder notes

### infra/

- `docker/`: Base images and local container definitions
- `helm/`: Helm charts and environment values for staging/production Kubernetes deployments
- `kubernetes/`: Base manifests and environment overlays

### platform/

- `kafka/`: Topic definitions, connector configs, and schema artifacts
- `flink/`: Streaming jobs, shared code, and SQL pipelines
- `airflow/`: DAGs, plugins, and supporting assets
- `dbt/`: Staging, intermediate, and mart models plus tests and macros
  - `models/marts/shared/`: Reusable conformed dimensions and shared facts
  - `models/marts/customer_analytics/`: Customer-facing reporting and product analytics models
  - `models/marts/internal_mail_tracking/`: Internal operational monitoring and mail-tracking models

### services/

- `cdc-consumer/`: CDC normalization and routing service
- `canonical-lakehouse-consumer/`: Spring Boot + Spark consumer that lands customer-facing analytics events in Iceberg on S3 for Tableau reporting and dashboards
- `dynamodb-mail-tracking-producer/`: AWS Lambda producer that turns DynamoDB stream changes into Kafka operational mail tracking events
- `event-producers/`: Dev-only Java Docker Compose utility that generates synthetic CDC and mail-tracking events for local pipeline testing

### storage/

- `elasticsearch/`: Index templates and ingest pipelines
- `snowflake/`: Schema DDL and data seeding scripts for Snowflake source tables in local and dev environments

### shared/

- `contracts/`: Event schemas and API contracts

## Documentation start here

- [docs/README.md](docs/README.md): central documentation index and writing standards
- [docs/architecture/system-architecture.md](docs/architecture/system-architecture.md): logical architecture and layer responsibilities
- [docs/architecture/deployment-architecture.md](docs/architecture/deployment-architecture.md): deployment model across local and shared environments
- [docs/architecture/deployment-runtime-topology.md](docs/architecture/deployment-runtime-topology.md): runtime placement and environment deltas
- [docs/adr/README.md](docs/adr/README.md): architecture decision records and reading order
- [docs/runbooks/local-dev-minikube.md](docs/runbooks/local-dev-minikube.md): Kubernetes-focused local development path
- [docs/runbooks/local-dev-docker-compose.md](docs/runbooks/local-dev-docker-compose.md): lightweight local development path

## Core implementation entrypoints

- Contracts and taxonomy: [shared/contracts/events/README.md](shared/contracts/events/README.md), [docs/product/event-taxonomy.md](docs/product/event-taxonomy.md)
- Kafka topics and connectors: [platform/kafka/README.md](platform/kafka/README.md), [platform/kafka/connect/README.md](platform/kafka/connect/README.md)
- Stream processing: [platform/flink/jobs/README.md](platform/flink/jobs/README.md)
- Orchestration: [platform/airflow/README.md](platform/airflow/README.md)
- Warehouse modeling: [platform/dbt/README.md](platform/dbt/README.md), [storage/snowflake/README.md](storage/snowflake/README.md)
- Operational search and dashboards: [storage/elasticsearch/README.md](storage/elasticsearch/README.md), [storage/elasticsearch/kibana/README.md](storage/elasticsearch/kibana/README.md)
- Infrastructure deployment: [infra/helm/README.md](infra/helm/README.md), [infra/kubernetes/base/README.md](infra/kubernetes/base/README.md)

## How To Use This Structure

1. Put product and event-model decisions under `docs/` before building pipelines.
2. Keep infrastructure definitions in `infra/` and application logic in `platform/` or `services/`.
3. Treat `shared/contracts/` as the source of truth for schemas used by Kafka, APIs, and warehouse layers.
4. Keep warehouse logic split between raw ingestion, transformation, and serving concerns.
5. Model downstream consumers early so customer analytics and internal operations can share core events without forcing identical serving models.
6. Add language-specific build files inside each service or platform component when implementation starts.

## Likely Next Additions

- Monorepo toolchain setup for Python, Java, or mixed-language builds
- Local development stack hardening for repeatable smoke tests and observability
- CI pipelines and release automation workflows
- Base Terraform module definitions and environment variable conventions
