# Event Tracking Platform Components Architecture

## Overview

This page keeps a single high-level diagram for fast orientation. Detailed architecture and environment-specific diagrams are maintained in system and deployment architecture docs.

## Components Diagram

```mermaid
flowchart TB
    subgraph Producers[Producers]
        API_APP[Application APIs]
        CDC_SRC[(PostgreSQL CDC)]
        EXT_SRC[External Mail Providers]
    end

    subgraph Backbone[Event Backbone]
        KAFKA[(Kafka Topics)]
        SR[Schema Registry]
        CONTRACTS[Shared Event Contracts]
    end

    subgraph Processing[Processing]
        FLINK[Flink Routers]
        SPARK[Canonical Lakehouse Consumer]
        S3[(S3 + Iceberg)]
    end

    subgraph Orchestration[Orchestration and Modeling]
        AIRFLOW[Airflow DAGs]
        DBT[dbt Semantic Layer]
    end

    subgraph Integration[Integration]
        KCONNECT[Kafka Connect Sinks]
    end

    subgraph Serving[Serving Stores and Interfaces]
        SNOW[(Snowflake)]
        ES[(Elasticsearch)]
        KIBANA[Kibana Dashboards]
        SAPI[Serving API]
    end

    subgraph Consumers[Consumers]
        CUST[Customer Analytics]
        OPS[Internal Operations]
    end

    API_APP --> KAFKA
    CDC_SRC --> KAFKA
    EXT_SRC --> KAFKA
    CONTRACTS --> KAFKA
    CONTRACTS --> FLINK
    CONTRACTS --> KCONNECT
    KAFKA --> FLINK
    FLINK --> KCONNECT
    FLINK --> SPARK
    KCONNECT --> ES
    SPARK --> S3
    S3 --> SNOW
    AIRFLOW --> FLINK
    AIRFLOW --> SPARK
    AIRFLOW --> DBT
    DBT --> SNOW
    SR --- KAFKA
    SNOW --> CUST
    SNOW --> SAPI
    ES --> KIBANA
    ES --> SAPI
    KIBANA --> OPS
    SAPI --> OPS
```

## Notes

- Ingestion and CDC publish into Kafka as the shared event backbone.
- Flink publishes internal Kafka topics; Kafka Connect handles Elasticsearch sink delivery.
- Snowflake and Elasticsearch remain consumer-specific serving stores.

## Repository Mapping

- [../../platform/kafka/](../../platform/kafka/): transport, schemas, and connector configuration
- [../../platform/flink/](../../platform/flink/): stream processing and real-time projections
- [../../platform/airflow/](../../platform/airflow/): orchestration and dependency scheduling
- [../../platform/dbt/](../../platform/dbt/): warehouse transformation layers
- [../../storage/snowflake/](../../storage/snowflake/): warehouse DDL and procedural objects
- [../../storage/elasticsearch/](../../storage/elasticsearch/): operational search configuration

## Related documents

- [../architecture/system-architecture.md](../architecture/system-architecture.md)
- [../architecture/deployment-architecture.md](../architecture/deployment-architecture.md)
- [../architecture/deployment-runtime-topology.md](../architecture/deployment-runtime-topology.md)
- [airflow-dag-orchestration.md](airflow-dag-orchestration.md)
