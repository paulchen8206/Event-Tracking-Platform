# Airflow DAG Orchestration Workflows

## Purpose

This page contains the canonical DAG orchestration diagrams for the local and shared Airflow workflows.

## End-to-end workflow diagram

```mermaid
flowchart LR
    R[spark_dbt_pipeline_readiness_gate] --> O[spark_dbt_pipeline_orchestrator]
    O --> S[spark apps]
    O --> D[dbt customer and internal builds]
    S --> L[S3 + Iceberg]
    D --> W[Snowflake semantic tables]
    L --> W
    I[dbt_semantic_layer_pipeline] --> W
```

## Cross-DAG orchestration

```mermaid
flowchart TD
    A[spark_dbt_pipeline_readiness_gate] --> B[wait_for_kafka_ready]
    A --> C[wait_for_s3_ready]
    A --> D[wait_for_orchestration_api_ready]
    B --> E[trigger_spark_dbt_pipeline_orchestrator]
    C --> E
    D --> E

    E -. triggers .-> F[spark_dbt_pipeline_orchestrator]

    G[dbt_semantic_layer_pipeline]:::standalone

    classDef standalone stroke-dasharray: 6 4
```

## Spark plus dbt orchestration DAG

```mermaid
flowchart LR
    S[start] --> SA[spark_apps.run_canonical_lakehouse_refresh]
    SA --> SB[spark_apps.run_operational_mail_tracking_projection]
    SB --> D1[dbt_transformations.dbt_deps]
    D1 --> D2[dbt_transformations.dbt_debug]
    D2 --> D3[dbt_transformations.dbt_build_customer]
    D2 --> D4[dbt_transformations.dbt_build_internal]
    D3 --> D5[dbt_transformations.dbt_builds_complete]
    D4 --> D5
    D5 --> E[end]
```

## dbt semantic layer DAG (isolated)

```mermaid
flowchart LR
    S[start] --> A[dbt_semantic_layer_pipeline.dbt_deps]
    A --> B[dbt_semantic_layer_pipeline.dbt_debug]
    B --> C[dbt_semantic_layer_pipeline.dbt_build_source]
    C --> D[dbt_semantic_layer_pipeline.dbt_build_staging]
    D --> E[dbt_semantic_layer_pipeline.dbt_build_intermediate]
    E --> F[dbt_semantic_layer_pipeline.dbt_build_marts]
    F --> G[end]
```

## Related documents

- [platform/airflow/README.md](../../platform/airflow/README.md)
- [docs/architecture/system-architecture.md](../architecture/system-architecture.md)
- [docs/diagrams/platform-architecture.md](platform-architecture.md)
