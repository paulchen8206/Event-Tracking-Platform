# Event Tracking Platform Documentation Index

## Purpose

This index organizes architecture, product, runbook, and ADR documentation for the Event Tracking Platform.

## Sections

- [architecture](architecture): system and deployment architecture guidance
- [adr](adr): architecture decision records with status and rationale
- [diagrams](diagrams): high-level visual reference pages that link to canonical architecture docs
- [product](product): taxonomy, use cases, and consumer requirements
- [runbooks](runbooks): operational procedures for setup and troubleshooting

## Structure-first navigation

- Platform and runtime design: [architecture/system-architecture.md](architecture/system-architecture.md)
- Environment and deployment topology: [architecture/deployment-architecture.md](architecture/deployment-architecture.md) and [architecture/deployment-runtime-topology.md](architecture/deployment-runtime-topology.md)
- Decision history and governance: [adr/README.md](adr/README.md)
- Operational procedures: [runbooks/local-dev-minikube.md](runbooks/local-dev-minikube.md), [runbooks/local-dev-docker-compose.md](runbooks/local-dev-docker-compose.md), [runbooks/prod-rollback-healthcheck.md](runbooks/prod-rollback-healthcheck.md)

## Diagram references

- [diagrams/platform-architecture.md](diagrams/platform-architecture.md): high-level end-to-end platform view
- [diagrams/airflow-dag-orchestration.md](diagrams/airflow-dag-orchestration.md): Airflow DAG-level orchestration and trigger flow
- [architecture/deployment-runtime-topology.md](architecture/deployment-runtime-topology.md): runtime topology plus dev-vs-production configuration diagram

## Recommended Reading Order

1. [architecture/system-architecture.md](architecture/system-architecture.md)
2. [architecture/aws-well-architected-improvement-plan.md](architecture/aws-well-architected-improvement-plan.md)
3. [architecture/deployment-architecture.md](architecture/deployment-architecture.md)
4. [architecture/deployment-runtime-topology.md](architecture/deployment-runtime-topology.md)
5. [architecture/spring-boot-framework-and-patterns.md](architecture/spring-boot-framework-and-patterns.md)
6. [adr/README.md](adr/README.md)
7. [runbooks/local-dev-minikube.md](runbooks/local-dev-minikube.md)
8. [runbooks/local-dev-docker-compose.md](runbooks/local-dev-docker-compose.md)
9. [runbooks/prod-rollback-healthcheck.md](runbooks/prod-rollback-healthcheck.md)

ADR sequencing and lifecycle workflow are maintained in [adr/README.md](adr/README.md).

## Writing Style Standard

Use the following section pattern for new markdown docs when applicable:

1. Purpose
2. Scope or Context
3. Configuration or Inputs
4. Workflow or Procedures
5. Validation or Operability Notes
6. Related documents

Style rules:

- Use concise, direct sentences
- Prefer sentence-case headings. Keep formal names and acronym-heavy titles as-is.
- Keep bullets action-oriented
- Use fenced code blocks for runnable commands
- Keep one trailing newline and avoid multiple consecutive blank lines
