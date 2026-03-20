# Java Flink Router Example

This module contains a Java Flink DataStream job that consumes one Kafka topic and routes records into internal Kafka topics.

## Flow

- Input topic: `evt.mail.lifecycle.raw`
- Internal tracking sink: `evt.mail.internal.tracking`
- Customer analytics sink: `evt.mail.customer.analytics`
- Health sink: `evt.platform.health`

## Build

Run from this directory:

```bash
mvn -q -DskipTests package
```

## Run

Run with your preferred Flink runtime, for example by submitting the shaded jar:

```bash
flink run target/mail-lifecycle-router-flink-0.1.0-SNAPSHOT.jar
```

Override topics and broker by environment variables:

- `KAFKA_BOOTSTRAP_SERVERS`
- `FLINK_SOURCE_TOPIC`
- `FLINK_INTERNAL_TOPIC`
- `FLINK_CUSTOMER_TOPIC`
- `FLINK_HEALTH_TOPIC`
