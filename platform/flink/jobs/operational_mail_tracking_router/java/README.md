# Operational Mail Tracking Router

Java Flink job that consumes operational mail tracking events from Kafka, enriches them for dashboard use, and republishes to internal Kafka topics. Elasticsearch indexing is handled downstream by Kafka Connect for loose coupling.

## Flow

- Source topic: `evt.mail.operational.raw`
- Internal tracking topic: `evt.mail.internal.tracking`
- Dashboard topic: `evt.mail.internal.tracking.dashboard`
- Elasticsearch sink: Kafka Connect consumes `evt.mail.internal.tracking.dashboard` and writes to `internal-mail-tracking`

## Build

```bash
cd platform/flink/jobs/operational_mail_tracking_router/java
mvn -q -DskipTests package
```

## Runtime Environment Variables

- `KAFKA_BOOTSTRAP_SERVERS`
- `FLINK_OPS_SOURCE_TOPIC`
- `FLINK_OPS_TRACKING_TOPIC`
- `FLINK_OPS_DASHBOARD_TOPIC`
