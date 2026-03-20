# Java CDC Producer Example

This module provides a Java example that consumes Debezium-style PostgreSQL CDC events and publishes canonical Avro events into Kafka.

## Environment Variables

- `KAFKA_BOOTSTRAP_SERVERS` (default: `localhost:9092`)
- `SCHEMA_REGISTRY_URL` (default: `http://localhost:8081`)
- `CDC_SOURCE_TOPIC` (default: `dbz.postgres.mail.public.mail_events`)
- `CDC_TARGET_TOPIC` (default: `evt.mail.lifecycle.raw`)
- `CDC_CONSUMER_GROUP` (default: `cdc-bridge-producer`)

## Build

Run from this directory:

```bash
mvn -q -DskipTests package
```

## Run

```bash
java -jar target/cdc-consumer-0.1.0-SNAPSHOT.jar
```

Notes:

- The mapper is intentionally conservative and emits minimal canonical metadata.
- Adapt field extraction for your specific Debezium payload shape and table schema.
