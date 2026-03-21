# Canonical Lakehouse Consumer Service

Spring Boot application that starts a Spark Structured Streaming job to consume customer-facing analytics events from Kafka and write Tableau-ready Iceberg assets on S3 lakehouse storage.

## What it does

- Reads from the customer analytics Kafka topic by default (`evt.mail.customer.analytics`)
- Parses customer-safe event records into a raw landing Iceberg table
- Creates Tableau-serving dimension and fact Iceberg tables if missing
- Refreshes Tableau-friendly assets on each micro-batch from the landing layer
- Produces a reporting-oriented daily fact table and lightweight dimensions for tenants and event types

## Intended consumers

- Customer-facing analytics dashboards
- Tableau reporting datasets and scheduled extracts
- Tenant-scoped delivery and engagement reporting

## Output tables

- Landing table: `lakehouse.customer_analytics.tableau_reporting_events`
- Tenant dimension: `lakehouse.customer_analytics.dim_customer_tenant`
- Event-type dimension: `lakehouse.customer_analytics.dim_customer_event_type`
- Daily Tableau fact: `lakehouse.customer_analytics.fct_tableau_daily_customer_delivery`

## Build

```bash
cd services/canonical-lakehouse-consumer
mvn -q -DskipTests package
```

## Run

```bash
java -jar target/canonical-lakehouse-consumer-0.1.0-SNAPSHOT.jar
```

## Important environment variables

- `KAFKA_BOOTSTRAP_SERVERS`
- `CANONICAL_KAFKA_TOPIC`
- `KAFKA_STARTING_OFFSETS`
- `ICEBERG_CATALOG`
- `ICEBERG_NAMESPACE`
- `ICEBERG_TABLE`
- `ICEBERG_WAREHOUSE` (example `s3a://event-tracking-lakehouse/warehouse`)
- `SPARK_CHECKPOINT_LOCATION`
- `TABLEAU_TENANT_DIM_TABLE`
- `TABLEAU_EVENT_TYPE_DIM_TABLE`
- `TABLEAU_DAILY_FACT_TABLE`
- `S3_ENDPOINT` (required for MinIO or custom S3 endpoint)
- `S3_ACCESS_KEY`
- `S3_SECRET_KEY`
- `S3_PATH_STYLE_ACCESS`

## Notes

- Default Iceberg target is `lakehouse.customer_analytics.tableau_reporting_events`.
- The service maintains both a raw landing table and Tableau-facing derived Iceberg tables.
- This starter assumes the Kafka value is a JSON record. If the upstream customer analytics topic is Avro-encoded, add Schema Registry-aware decoding before `from_json`.
- If you need to consume the broader canonical topic instead of the customer analytics projection, override `CANONICAL_KAFKA_TOPIC`.
- Downstream dbt models in `platform/dbt/` should read these Iceberg tables through Snowflake and materialize Tableau semantic models before BI consumption.
