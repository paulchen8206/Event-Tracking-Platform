# DynamoDB Mail Tracking Producer

AWS Lambda function that consumes DynamoDB Streams records for internal operational mail tracking and produces real-time events into Kafka.

## Flow

- Source: DynamoDB Streams on a mail-tracking table
- Trigger: AWS Lambda event source mapping
- Kafka topic: `evt.mail.operational.raw`
- Output encoding: Avro with Schema Registry wire format

## Required Environment Variables

- `KAFKA_BOOTSTRAP_SERVERS`
- `KAFKA_TOPIC` (default `evt.mail.operational.raw`)
- `KAFKA_SCHEMA_ID` (Schema Registry ID for `evt.mail.operational.raw-value`)

## Notes

- The function assumes the DynamoDB stream image contains fields like `message_id`, `status`, `processing_stage`, `mailbox_id`, and optional `tenant_id`.
- For production, replace the hard-coded schema ID usage with a Schema Registry lookup or deployment-time injection.
