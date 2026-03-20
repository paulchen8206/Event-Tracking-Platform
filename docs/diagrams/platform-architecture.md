# Platform Architecture

## Overview

This page keeps a single high-level diagram for fast orientation. Detailed architecture and environment-specific diagrams are maintained in system and deployment architecture docs.

## System Diagram

```mermaid
flowchart LR
    subgraph Sources
        APP[Application APIs]
        DB[(PostgreSQL)]
        EXT[External Mail Providers]
    end

    subgraph Ingestion
        API[Ingestion API]
        CDC[CDC Connectors]
        KAFKA[(Kafka Topics)]
    end

    subgraph StreamProcessing
        FLINK[Flink Jobs]
        SCHEMA[Shared Event Contracts]
        KINT[(Internal Kafka Topics)]
        KCAN[(evt.mail.customer.analytics)]
    end

    subgraph LakehouseProcessing
        SPARK[Canonical Lakehouse Consumer
Spark Structured Streaming]
        S3[(S3 + Iceberg)]
    end

    subgraph Integration
        KCONN[Kafka Connect Sinks]
    end

    subgraph Orchestration
        AIRFLOW[Airflow DAGs]
        DBT[dbt Semantic Layer]
    end

    subgraph Serving
        SNOW[(Snowflake)]
        ES[(Elasticsearch)]
        KIBANA[Kibana Dashboards]
        SAPI[Serving API]
    end

    subgraph Consumers
        CUST[Customer Analytics]
        OPS[Internal Mail Tracking\n Operations Team]
    end

    APP --> API
    DB --> CDC
    EXT --> API
    API --> KAFKA
    CDC --> KAFKA
    KAFKA --> FLINK
    SCHEMA --> API
    SCHEMA --> CDC
    SCHEMA --> FLINK
    FLINK --> KINT
    FLINK --> KCAN
    KINT --> KCONN
    KCONN --> ES
    ES --> KIBANA
    KIBANA --> OPS
    KCAN --> SPARK
    SPARK --> S3
    S3 --> SNOW
    AIRFLOW --> SPARK
    AIRFLOW --> DBT
    DBT --> SNOW
    KAFKA -. replay/backfill .-> AIRFLOW
    SNOW --> SAPI
    ES --> SAPI
    SNOW --> CUST
    SAPI --> CUST
    SAPI --> OPS
```

## Notes

- Ingestion and CDC publish into Kafka as the shared event backbone.
- Flink publishes internal Kafka topics; Kafka Connect handles Elasticsearch sink delivery.
- Snowflake and Elasticsearch remain consumer-specific serving stores.
- Use system architecture and deployment docs for detailed flow and runtime topology.

## Repository Mapping

- `platform/kafka/`: transport, schemas, and connector configuration
- `platform/flink/`: stream processing and real-time projections
- `platform/airflow/`: orchestration and dependency scheduling
- `platform/dbt/`: warehouse transformation layers
- `storage/snowflake/`: warehouse DDL and procedural objects
- `storage/elasticsearch/`: operational search configuration
