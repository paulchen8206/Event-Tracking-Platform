package com.eventtracking.flink.ops;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.ProcessFunction;
import org.apache.flink.util.Collector;

public class OperationalMailTrackingRouterJob {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

  public static void main(String[] args) throws Exception {
    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

    String bootstrapServers = envOrDefault("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092");
    String sourceTopic = envOrDefault("FLINK_OPS_SOURCE_TOPIC", "evt.mail.operational.raw");
    String trackingTopic = envOrDefault("FLINK_OPS_TRACKING_TOPIC", "evt.mail.internal.tracking");
    String dashboardTopic =
        envOrDefault("FLINK_OPS_DASHBOARD_TOPIC", "evt.mail.internal.tracking.dashboard");

    KafkaSource<String> source =
        KafkaSource.<String>builder()
            .setBootstrapServers(bootstrapServers)
            .setTopics(sourceTopic)
            .setGroupId("ops-mail-tracking-router")
            .setValueOnlyDeserializer(new SimpleStringSchema())
            .setStartingOffsets(OffsetsInitializer.earliest())
            .build();

    DataStream<String> raw =
        env.fromSource(source, WatermarkStrategy.noWatermarks(), "operational-mail-raw-source");

    DataStream<String> normalized =
        raw.process(
            new ProcessFunction<>() {
              @Override
              public void processElement(
                  String value, ProcessFunction<String, String>.Context ctx, Collector<String> out)
                  throws Exception {
                JsonNode root = OBJECT_MAPPER.readTree(value);
                if (root.path("message_id").asText("").isBlank()) {
                  return;
                }

                JsonNode payloadNode = root.path("payload_json");
                JsonNode parsedPayload =
                    payloadNode.isTextual()
                        ? OBJECT_MAPPER.readTree(payloadNode.asText("{}"))
                        : payloadNode;

                String enriched =
                    OBJECT_MAPPER
                        .createObjectNode()
                        .put("event_id", root.path("event_id").asText())
                        .put(
                            "event_type",
                            root.path("event_type").asText("mail.operational.status_changed"))
                        .put("event_version", root.path("event_version").asText("1.0.0"))
                        .put(
                            "source_system",
                            root.path("source_system").asText("dynamodb.mail_tracking"))
                        .put("tenant_id", root.path("tenant_id").asText(null))
                        .put("message_id", root.path("message_id").asText())
                        .put(
                            "correlation_id",
                            root.path("correlation_id").asText(root.path("message_id").asText()))
                        .put(
                            "status",
                            root.path("status")
                                .asText(parsedPayload.path("status").asText("unknown")))
                        .put(
                            "mailbox_id",
                            root.path("mailbox_id")
                                .asText(parsedPayload.path("mailbox_id").asText("unknown")))
                        .put(
                            "processing_stage",
                            root.path("processing_stage")
                                .asText(parsedPayload.path("processing_stage").asText("unknown")))
                        .put(
                            "provider",
                            root.path("provider")
                                .asText(parsedPayload.path("provider").asText(null)))
                        .put(
                            "error_code",
                            root.path("error_code")
                                .asText(parsedPayload.path("error_code").asText(null)))
                        .put(
                            "error_message",
                            root.path("error_message")
                                .asText(parsedPayload.path("error_message").asText(null)))
                        .put(
                            "event_time",
                            root.path("event_time").asLong(Instant.now().toEpochMilli()))
                        .put("dashboard_ts", Instant.now().toString())
                        .toString();

                out.collect(enriched);
              }
            });

    KafkaSink<String> trackingSink =
        KafkaSink.<String>builder()
            .setBootstrapServers(bootstrapServers)
            .setRecordSerializer(
                KafkaRecordSerializationSchema.builder()
                    .setTopic(trackingTopic)
                    .setValueSerializationSchema(new SimpleStringSchema())
                    .build())
            .build();

    KafkaSink<String> dashboardSink =
        KafkaSink.<String>builder()
            .setBootstrapServers(bootstrapServers)
            .setRecordSerializer(
                KafkaRecordSerializationSchema.builder()
                    .setTopic(dashboardTopic)
                    .setValueSerializationSchema(new SimpleStringSchema())
                    .build())
            .build();

    normalized.sinkTo(trackingSink).name("ops-tracking-kafka-sink");
    normalized.sinkTo(dashboardSink).name("ops-dashboard-kafka-sink");

    // Flink 2.0: ensure worker threads deserialize user operators with the correct classloader
    Thread.currentThread()
        .setContextClassLoader(OperationalMailTrackingRouterJob.class.getClassLoader());
    env.execute("operational-mail-tracking-router");
  }

  private static String envOrDefault(String key, String fallback) {
    String value = System.getenv(key);
    return value == null || value.isBlank() ? fallback : value;
  }
}
