package com.eventtracking.producers;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.time.Instant;
import java.util.List;
import java.util.Properties;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Synthetic Debezium PostgreSQL CDC producer.
 *
 * <p>Produces change event envelopes toward the topic that {@code DebeziumPostgresCdcProducer}
 * consumes. The generated payloads match the Debezium PostgreSQL connector wire format, allowing
 * the full CDC → lifecycle-raw pipeline to run locally without a real Postgres instance or Debezium
 * deployment.
 *
 * <p>Envelope shape:
 *
 * <pre>
 * {
 *   "payload": {
 *     "op": "c" | "u" | "d",
 *     "ts_ms": &lt;epoch-ms&gt;,
 *     "source": { "db": "mail", "table": "mail_events", "txId": "&lt;uuid&gt;", "schema": "public" },
 *     "before": null | { ... },
 *     "after":  { "message_id": "...", "tenant_id": "...", "trace_id": "...", ... }
 *   }
 * }
 * </pre>
 *
 * <p>Environment variables:
 *
 * <ul>
 *   <li>{@code KAFKA_BOOTSTRAP_SERVERS} — default {@code localhost:9092}
 *   <li>{@code CDC_TARGET_TOPIC} — default {@code dbz.postgres.mail.public.mail_events}
 *   <li>{@code EVENT_COUNT} — number of events to emit, default {@code 100}
 *   <li>{@code EVENTS_PER_SECOND} — target throughput, default {@code 10}
 *   <li>{@code TENANT_COUNT} — simulated tenant pool size, default {@code 5}
 * </ul>
 */
public class CdcEventProducer {

  private static final Logger LOG = LoggerFactory.getLogger(CdcEventProducer.class);
  private static final ObjectMapper MAPPER = new ObjectMapper();
  private static final Random RANDOM = new Random();

  // 70 % inserts, 25 % updates, 5 % deletes — realistic CDC distribution
  private static final List<String> OPS =
      List.of("c", "c", "c", "c", "c", "c", "c", "u", "u", "u", "u", "u", "d");

  private static final List<String> STATUSES =
      List.of(
          "requested",
          "queued",
          "dispatched",
          "delivered",
          "opened",
          "clicked",
          "bounced",
          "failed");

  private static final List<String> PROVIDERS = List.of("sendgrid", "mailgun", "ses", "postmark");

  public void run(
      String bootstrapServers, String topic, int eventCount, int eventsPerSecond, int tenantCount)
      throws Exception {
    LOG.info(
        "CDC producer starting — topic={} count={} rps={}", topic, eventCount, eventsPerSecond);

    long delayMs = eventsPerSecond > 0 ? 1000L / eventsPerSecond : 0;
    AtomicInteger sent = new AtomicInteger(0);

    try (KafkaProducer<String, String> producer =
        new KafkaProducer<>(buildProducerConfig(bootstrapServers))) {
      for (int i = 0; i < eventCount; i++) {
        String messageId = "msg-" + UUID.randomUUID();
        String tenantId = "tenant-" + (1 + RANDOM.nextInt(tenantCount));
        String payload = buildCdcEnvelope(messageId, tenantId);

        producer.send(
            new ProducerRecord<>(topic, messageId, payload),
            (meta, ex) -> {
              if (ex != null) {
                LOG.error("Failed to send CDC event", ex);
              } else {
                int n = sent.incrementAndGet();
                if (n % 100 == 0) {
                  LOG.info("CDC: sent {} events to {}", n, meta.topic());
                }
              }
            });

        if (delayMs > 0) {
          Thread.sleep(delayMs);
        }
      }
      producer.flush();
    }

    LOG.info("CDC producer finished — {} events sent to {}", sent.get(), topic);
  }

  private String buildCdcEnvelope(String messageId, String tenantId) throws Exception {
    String op = OPS.get(RANDOM.nextInt(OPS.size()));
    long nowMs = Instant.now().toEpochMilli();
    String txId = UUID.randomUUID().toString();

    ObjectNode source =
        MAPPER
            .createObjectNode()
            .put("db", "mail")
            .put("schema", "public")
            .put("table", "mail_events")
            .put("txId", txId);

    ObjectNode row =
        MAPPER
            .createObjectNode()
            .put("message_id", messageId)
            .put("tenant_id", tenantId)
            .put("trace_id", "trace-" + UUID.randomUUID())
            .put("status", STATUSES.get(RANDOM.nextInt(STATUSES.size())))
            .put("provider", PROVIDERS.get(RANDOM.nextInt(PROVIDERS.size())))
            .put("created_at", nowMs)
            .put("updated_at", nowMs);

    ObjectNode payloadNode = MAPPER.createObjectNode().put("op", op).put("ts_ms", nowMs);
    payloadNode.set("source", source);

    // For deletes "after" is null and "before" holds the last known row state
    if ("d".equals(op)) {
      payloadNode.putNull("after");
      payloadNode.set("before", row);
    } else {
      payloadNode.putNull("before");
      payloadNode.set("after", row);
    }

    ObjectNode envelope = MAPPER.createObjectNode();
    envelope.set("payload", payloadNode);
    return MAPPER.writeValueAsString(envelope);
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
