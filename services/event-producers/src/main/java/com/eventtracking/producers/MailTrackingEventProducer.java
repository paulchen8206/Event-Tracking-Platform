package com.eventtracking.producers;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Properties;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Synthetic DynamoDB operational mail tracking event producer.
 *
 * <p>Produces events toward the topic that {@code OperationalMailTrackingRouterJob} consumes.
 * The generated records mirror what an AWS DynamoDB Streams Lambda bridge would emit after
 * normalising a DynamoDB change image into the platform's canonical JSON shape.
 *
 * <p>Each record is a plain JSON string (no Avro — the Flink job uses {@code SimpleStringSchema})
 * containing all the fields the router expects at the top level, plus an inline {@code payload_json}
 * object carrying the operational detail fields.
 *
 * <p>Environment variables:
 * <ul>
 *   <li>{@code KAFKA_BOOTSTRAP_SERVERS} — default {@code localhost:9092}</li>
 *   <li>{@code MAIL_TRACKING_TARGET_TOPIC} — default {@code evt.mail.operational.raw}</li>
 *   <li>{@code EVENT_COUNT} — number of events to emit, default {@code 100}</li>
 *   <li>{@code EVENTS_PER_SECOND} — target throughput, default {@code 10}</li>
 *   <li>{@code TENANT_COUNT} — simulated tenant pool size, default {@code 5}</li>
 * </ul>
 */
public class MailTrackingEventProducer {

    private static final Logger LOG = LoggerFactory.getLogger(MailTrackingEventProducer.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final Random RANDOM = new Random();

    private static final List<String> EVENT_TYPES = List.of(
            "mail.operational.status_changed",
            "mail.operational.status_changed",
            "mail.operational.status_changed",
            "mail.operational.delivery_attempted",
            "mail.operational.bounce_received",
            "mail.operational.complaint_received"
    );

    private static final List<String> STATUSES = List.of(
            "queued", "dispatched", "delivered",
            "deferred", "bounced", "failed", "complained"
    );

    private static final List<String> PROCESSING_STAGES = List.of(
            "ingestion", "routing", "delivery", "post-delivery", "retry"
    );

    private static final List<String> PROVIDERS = Arrays.asList(
            "sendgrid", "mailgun", "ses", "postmark", null
    );

    private static final List<String> ERROR_CODES = Arrays.asList(
            null, null, null, null,                     // most events have no error
            "550", "421", "452", "smtp_timeout"         // realistic SMTP error codes
    );

    public void run(String bootstrapServers, String topic, int eventCount,
                    int eventsPerSecond, int tenantCount) throws Exception {
        LOG.info("Mail-tracking producer starting — topic={} count={} rps={}", topic, eventCount, eventsPerSecond);

        long delayMs = eventsPerSecond > 0 ? 1000L / eventsPerSecond : 0;
        AtomicInteger sent = new AtomicInteger(0);

        try (KafkaProducer<String, String> producer = new KafkaProducer<>(buildProducerConfig(bootstrapServers))) {
            for (int i = 0; i < eventCount; i++) {
                String messageId = "msg-" + UUID.randomUUID();
                String tenantId = "tenant-" + (1 + RANDOM.nextInt(tenantCount));
                String record = buildTrackingEvent(messageId, tenantId);

                producer.send(new ProducerRecord<>(topic, messageId, record), (meta, ex) -> {
                    if (ex != null) {
                        LOG.error("Failed to send mail-tracking event", ex);
                    } else {
                        int n = sent.incrementAndGet();
                        if (n % 100 == 0) {
                            LOG.info("Mail-tracking: sent {} events to {}", n, meta.topic());
                        }
                    }
                });

                if (delayMs > 0) {
                    Thread.sleep(delayMs);
                }
            }
            producer.flush();
        }

        LOG.info("Mail-tracking producer finished — {} events sent to {}", sent.get(), topic);
    }

    private String buildTrackingEvent(String messageId, String tenantId) throws Exception {
        long nowMs = Instant.now().toEpochMilli();
        String eventId = UUID.randomUUID().toString();
        String correlationId = "corr-" + UUID.randomUUID();
        String mailboxId = "mbox-" + RANDOM.nextInt(1000);
        String status = STATUSES.get(RANDOM.nextInt(STATUSES.size()));
        String processingStage = PROCESSING_STAGES.get(RANDOM.nextInt(PROCESSING_STAGES.size()));
        String provider = PROVIDERS.get(RANDOM.nextInt(PROVIDERS.size()));
        String errorCode = ERROR_CODES.get(RANDOM.nextInt(ERROR_CODES.size()));
        String eventType = EVENT_TYPES.get(RANDOM.nextInt(EVENT_TYPES.size()));

        // Inner payload mirrors the DynamoDB item image
        ObjectNode payloadInner = MAPPER.createObjectNode()
                .put("status", status)
                .put("mailbox_id", mailboxId)
                .put("processing_stage", processingStage);
        if (provider != null) {
            payloadInner.put("provider", provider);
        }
        if (errorCode != null) {
            payloadInner.put("error_code", errorCode);
            payloadInner.put("error_message", resolveErrorMessage(errorCode));
        }
        payloadInner.put("dynamodb_sequence_number", String.valueOf(RANDOM.nextLong(1_000_000_000L)));
        payloadInner.put("stream_view_type", "NEW_AND_OLD_IMAGES");

        // Top-level event envelope — must have message_id for the Flink router to pass it through
        ObjectNode event = MAPPER.createObjectNode()
                .put("event_id", eventId)
                .put("event_type", eventType)
                .put("event_version", "1.0.0")
                .put("source_system", "dynamodb.mail_tracking")
                .put("tenant_id", tenantId)
                .put("message_id", messageId)
                .put("correlation_id", correlationId)
                .put("trace_id", "trace-" + UUID.randomUUID())
                .put("actor_type", "service")
                .put("event_time", nowMs)
                // Top-level convenience fields (router reads these first, falls back to payload_json)
                .put("status", status)
                .put("mailbox_id", mailboxId)
                .put("processing_stage", processingStage);
        if (provider != null) {
            event.put("provider", provider);
        }
        if (errorCode != null) {
            event.put("error_code", errorCode);
            event.put("error_message", resolveErrorMessage(errorCode));
        }
        // Nested payload as a JSON string (matches how DynamoDB bridge serialises it)
        event.put("payload_json", MAPPER.writeValueAsString(payloadInner));

        return MAPPER.writeValueAsString(event);
    }

    private static String resolveErrorMessage(String code) {
        return switch (code) {
            case "550" -> "Requested action not taken: mailbox unavailable";
            case "421" -> "Service not available, closing transmission channel";
            case "452" -> "Requested action not taken: insufficient system storage";
            case "smtp_timeout" -> "SMTP connection timed out during DATA phase";
            default -> "Unknown delivery error";
        };
    }

    private Properties buildProducerConfig(String bootstrapServers) {
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.RETRIES_CONFIG, "3");
        props.put(ProducerConfig.LINGER_MS_CONFIG, "5");
        props.put(ProducerConfig.BATCH_SIZE_CONFIG, "16384");
        return props;
    }
}
