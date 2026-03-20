# Documentation Index

## Purpose

This index organizes architecture, product, runbook, and ADR documentation for the Event Tracking Platform.

## Sections

- [architecture](architecture): system and deployment architecture guidance
- [adr](adr): architecture decision records with status and rationale
- [diagrams](diagrams): high-level visual reference pages that link to canonical architecture docs
- [product](product): taxonomy, use cases, and consumer requirements
- [runbooks](runbooks): operational procedures for setup and troubleshooting

## Recommended Reading Order

1. [architecture/system-architecture.md](architecture/system-architecture.md)
2. [architecture/deployment-architecture.md](architecture/deployment-architecture.md)
3. [architecture/deployment-runtime-topology.md](architecture/deployment-runtime-topology.md)
4. [architecture/spring-boot-framework-and-patterns.md](architecture/spring-boot-framework-and-patterns.md)
5. [adr/README.md](adr/README.md)
6. [runbooks/local-dev-minikube.md](runbooks/local-dev-minikube.md)
7. [runbooks/local-dev-docker-compose.md](runbooks/local-dev-docker-compose.md)
8. [runbooks/prod-rollback-healthcheck.md](runbooks/prod-rollback-healthcheck.md)

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
- Prefer sentence-case headings
- Keep bullets action-oriented
- Use fenced code blocks for runnable commands
- Keep one trailing newline and avoid multiple consecutive blank lines
