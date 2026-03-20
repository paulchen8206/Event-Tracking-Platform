# Event Tracking Platform

A starter repository structure for a streaming-first data platform aligned to this stack:

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

## Core Product Documents

- [docs/README.md](docs/README.md): Documentation index and writing style standard
- [docs/product/use-cases.md](docs/product/use-cases.md): Primary consumer groups and platform expectations
- [docs/product/event-taxonomy.md](docs/product/event-taxonomy.md): Shared event model and mail lifecycle taxonomy
- [docs/diagrams/platform-architecture.md](docs/diagrams/platform-architecture.md): End-to-end system view and data flow diagram
- [docs/architecture/system-architecture.md](docs/architecture/system-architecture.md): Current target architecture with component responsibilities and decoupled sink flows
- [docs/architecture/deployment-architecture.md](docs/architecture/deployment-architecture.md): Deployment-focused architecture for local Minikube and shared dev/QA/staging/production environments
- [docs/architecture/deployment-runtime-topology.md](docs/architecture/deployment-runtime-topology.md): Namespace-level runtime placement, network boundaries, and environment promotion topology
- [docs/architecture/spring-boot-framework-and-patterns.md](docs/architecture/spring-boot-framework-and-patterns.md): Spring Boot framework baseline, design patterns, and workflow/pipeline diagrams
- [docs/adr/README.md](docs/adr/README.md): ADR index and conventions for tracking architecture decisions

## Starter Assets

- `shared/contracts/events/`: Initial JSON Schema contracts for canonical events
- `platform/kafka/topics/topic-map.yaml`: First-pass topic taxonomy and ownership map
- `platform/kafka/schemas/avro/`: Avro transport schemas registered in Schema Registry
- `scripts/bootstrap/kafka_bootstrap.py`: Python CLI to create Kafka topics and register Avro schemas
- `scripts/bootstrap/schema_registry_maintainer.py`: Python CLI to maintain canonical schema subjects in Schema Registry
- `infra/docker/docker-compose.kafka.yml`: Local Kafka, Schema Registry, and Kafka UI stack
- `platform/flink/sql/mail_lifecycle_router.sql`: Starter Flink SQL pipeline skeleton
- `platform/flink/jobs/mail_lifecycle_router/java/`: Java Flink job that routes raw events into internal Kafka topics
- `platform/flink/jobs/operational_mail_tracking_router/java/`: Java Flink job that streams DynamoDB-originated operational tracking events into internal Kafka topics for decoupled downstream sinks
- `platform/airflow/dags/spark_dbt_dependency_orchestrator.py`: Python Airflow DAG that orchestrates Spark and dbt execution through the wrapper API layer with explicit dependencies
- `platform/airflow/dags/spark_dbt_readiness_gate.py`: Python Airflow sensor DAG that gates orchestration on Kafka/S3/API readiness before triggering Spark + dbt workflows
- `platform/airflow/include/pipeline_config.py`: Shared Python config module for Spark and dbt command configuration in Airflow
- `services/orchestration-api/`: FastAPI wrapper API layer exposing Spark/dbt invocation endpoints to decouple execution from Airflow DAG internals
- `services/cdc-consumer/`: Java Debezium CDC bridge producer for PostgreSQL source topics
- `services/canonical-lakehouse-consumer/`: Spring Boot Spark streaming app for customer-facing analytics topic to Iceberg/S3 lakehouse ingestion
- `platform/kafka/connect/elasticsearch/internal-mail-tracking-sink.json` and `platform/kafka/connect/elasticsearch/internal-mail-tracking-deadletter-sink.json`: Kafka Connect sink definitions for operational dashboard indexing and dead-letter isolation
- `storage/elasticsearch/index-templates/`, `storage/elasticsearch/ingest-pipelines/`, and `storage/elasticsearch/kibana/`: Elasticsearch mappings plus Kibana starter assets for operational dashboards and dead-letter monitoring
- `infra/kubernetes/base/` and `infra/kubernetes/overlays/*/`: Namespace and policy skeletons for dev/staging/production
- `infra/helm/charts/platform/`: Complete Helm chart for platform pod deployments
- `infra/helm/README.md`: Helm deployment model and commands for QA/staging/production Kubernetes releases
- `infra/helm/values/qa/platform-values.yaml`: QA Helm values using production-like pod topology with minimal pod configuration
- `infra/helm/values/stg/platform-values.yaml`: Staging Helm values similar to production with moderate pod sizing
- `infra/helm/values/prod/platform-values.yaml`: Production Helm values baseline with higher scale and resiliency settings
- `scripts/dev/apply_k8s_overlay.sh`: Apply Kubernetes base and one selected overlay, with dry-run and preflight policy checks
- `scripts/dev/setup_minikube_docker.sh` and `scripts/dev/delete_minikube_docker.sh`: Local Minikube (Docker driver) bootstrap and teardown scripts
- `docs/runbooks/local-dev-minikube.md`: End-to-end runbook for local Kubernetes environment setup on macOS/Linux
- `docs/runbooks/local-dev-docker-compose.md`: Pure Docker Compose runbook for lightweight local Kafka and connector workflows
- `docs/runbooks/prod-rollback-healthcheck.md`: Production runbook for post-deploy validation, rollback execution, and resiliency checks
- `platform/dbt/models/marts/*/schema.yml`: Starter model definitions and tests for each mart layer
- `platform/dbt/models/staging/customer_analytics/` and `platform/dbt/models/intermediate/customer_analytics/`: Snowflake semantic layer on top of Iceberg-backed customer analytics tables for Tableau
- `platform/dbt/profiles.example.yml`: Example Snowflake dbt profile for semantic-layer deployment across dev/staging/production
- `platform/dbt/packages.yml`: dbt utility packages used for semantic-layer tests and helpers
- `storage/snowflake/schemas/sf_tuts_customer_analytics_sources.sql`: Idempotent DDL bootstrap for the Snowflake source schema and all four source tables in local dev
- `storage/snowflake/schemas/sf_tuts_customer_analytics_seed_data.sql`: Small sample dataset (6 rows) for smoke-testing the dbt semantic layer
- `storage/snowflake/schemas/sf_tuts_customer_analytics_generate_large_data.sql`: Large synthetic data generator (12 000+ rows, 80 tenants, 45-day window) for realistic Tableau dashboard testing; run via `make dev-dbt-seed-large`
- `.env.example`: Template for local Snowflake credentials loaded by the dbt Docker Compose service

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
