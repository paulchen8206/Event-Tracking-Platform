package com.eventtracking.cdc;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Properties;
import java.util.UUID;

public class DebeziumPostgresCdcProducer {
    private static final Logger LOGGER = LoggerFactory.getLogger(DebeziumPostgresCdcProducer.class);
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    public static void main(String[] args) throws Exception {
        String bootstrapServers = envOrDefault("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092");
        String sourceTopic = envOrDefault("CDC_SOURCE_TOPIC", "dbz.postgres.mail.public.mail_events");
        String targetTopic = envOrDefault("CDC_TARGET_TOPIC", "evt.mail.lifecycle.raw");
        String groupId = envOrDefault("CDC_CONSUMER_GROUP", "cdc-bridge-producer");

        try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(buildConsumerConfig(bootstrapServers, groupId));
             KafkaProducer<String, String> producer = new KafkaProducer<>(buildProducerConfig(bootstrapServers))) {

            consumer.subscribe(List.of(sourceTopic));
            LOGGER.info("Consuming Debezium CDC from {} and producing canonical events to {}", sourceTopic, targetTopic);

            while (true) {
                ConsumerRecords<String, String> records = consumer.poll(Duration.ofSeconds(1));
                for (ConsumerRecord<String, String> record : records) {
                    String envelope = mapDebeziumRecordToCanonicalJson(record.value());
                    if (envelope == null) {
                        continue;
                    }

                    String messageId = OBJECT_MAPPER.readTree(envelope).path("message_id").asText(UUID.randomUUID().toString());
                    producer.send(new ProducerRecord<>(targetTopic, messageId, envelope));
                }
                producer.flush();
                consumer.commitSync();
            }
        }
    }

    private static Properties buildConsumerConfig(String bootstrapServers, String groupId) {
        Properties props = new Properties();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "false");
        return props;
    }

    private static Properties buildProducerConfig(String bootstrapServers) {
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        return props;
    }

    private static String mapDebeziumRecordToCanonicalJson(String rawDebeziumJson) {
        try {
            JsonNode root = OBJECT_MAPPER.readTree(rawDebeziumJson);
            JsonNode payload = root.path("payload");
            if (payload.isMissingNode() || payload.isNull()) {
                LOGGER.warn("Skipping CDC record with missing payload");
                return null;
            }

            JsonNode source = payload.path("source");
            JsonNode after = payload.path("after");
            JsonNode before = payload.path("before");
            JsonNode rowNode = !after.isMissingNode() && !after.isNull() ? after : before;
            if (rowNode.isMissingNode() || rowNode.isNull()) {
                LOGGER.warn("Skipping CDC record with missing row payload");
                return null;
            }

            String operation = payload.path("op").asText("u");
            String eventType = switch (operation) {
                case "c", "r" -> "mail.requested";
                case "u" -> "mail.updated";
                case "d" -> "mail.deleted";
                default -> "mail.unknown";
            };

            long tsMs = payload.path("ts_ms").asLong(Instant.now().toEpochMilli());
            String messageId = textOrDefault(rowNode, "message_id", UUID.randomUUID().toString());
            String tenantId = textOrNull(rowNode, "tenant_id");
            String sourceSystem = source.path("db").asText("postgres");
            String table = source.path("table").asText("unknown");
            String correlationId = source.path("txId").asText(messageId);

            return OBJECT_MAPPER.createObjectNode()
                    .put("event_id", UUID.randomUUID().toString())
                    .put("event_type", eventType)
                    .put("event_version", "1.0.0")
                    .put("event_time", tsMs)
                    .put("ingested_at", Instant.now().toEpochMilli())
                    .put("source_system", sourceSystem + "." + table)
                    .put("tenant_id", tenantId)
                    .put("message_id", messageId)
                    .put("correlation_id", correlationId)
                    .put("trace_id", textOrNull(rowNode, "trace_id"))
                    .put("actor_type", "service")
                    .put("payload", OBJECT_MAPPER.writeValueAsString(rowNode))
                    .toString();
        } catch (Exception exception) {
            LOGGER.error("Failed to map Debezium CDC payload", exception);
            return null;
        }
    }

    private static String envOrDefault(String key, String fallback) {
        String value = System.getenv(key);
        return value == null || value.isBlank() ? fallback : value;
    }

    private static String textOrDefault(JsonNode node, String field, String fallback) {
        JsonNode value = node.path(field);
        if (value.isMissingNode() || value.isNull()) {
            return fallback;
        }
        String text = value.asText();
        return text == null || text.isBlank() ? fallback : text;
    }

    private static String textOrNull(JsonNode node, String field) {
        JsonNode value = node.path(field);
        if (value.isMissingNode() || value.isNull()) {
            return null;
        }
        String text = value.asText();
        return text == null || text.isBlank() ? null : text;
    }
}