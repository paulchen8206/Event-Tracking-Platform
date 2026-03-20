package com.eventtracking.flink;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.Set;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.datastream.SingleOutputStreamOperator;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.ProcessFunction;
import org.apache.flink.util.Collector;
import org.apache.flink.util.OutputTag;

public class MailLifecycleRouterJob {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
  private static final OutputTag<String> CUSTOMER_OUTPUT = new OutputTag<>("customer-analytics") {};
  private static final OutputTag<String> HEALTH_OUTPUT = new OutputTag<>("platform-health") {};

  public static void main(String[] args) throws Exception {
    Configuration configuration = new Configuration();
    StreamExecutionEnvironment env =
        StreamExecutionEnvironment.getExecutionEnvironment(configuration);

    String bootstrapServers = envOrDefault("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092");
    String sourceTopic = envOrDefault("FLINK_SOURCE_TOPIC", "evt.mail.lifecycle.raw");
    String internalTopic = envOrDefault("FLINK_INTERNAL_TOPIC", "evt.mail.internal.tracking");
    String customerTopic = envOrDefault("FLINK_CUSTOMER_TOPIC", "evt.mail.customer.analytics");
    String healthTopic = envOrDefault("FLINK_HEALTH_TOPIC", "evt.platform.health");
    String consumerGroupId = envOrDefault("FLINK_CONSUMER_GROUP", "flink-mail-lifecycle-router");
    String startingOffsets = envOrDefault("FLINK_STARTING_OFFSETS", "latest");
    OffsetsInitializer offsetsInitializer =
        "earliest".equalsIgnoreCase(startingOffsets)
            ? OffsetsInitializer.earliest()
            : OffsetsInitializer.latest();

    KafkaSource<String> source =
        KafkaSource.<String>builder()
            .setBootstrapServers(bootstrapServers)
            .setTopics(sourceTopic)
            .setGroupId(consumerGroupId)
            .setValueOnlyDeserializer(new SimpleStringSchema())
            .setStartingOffsets(offsetsInitializer)
            .build();

    DataStream<String> input =
        env.fromSource(source, WatermarkStrategy.noWatermarks(), "raw-lifecycle-events");

    SingleOutputStreamOperator<String> internalStream =
        input.process(
            new ProcessFunction<>() {
              @Override
              public void processElement(
                  String value, ProcessFunction<String, String>.Context ctx, Collector<String> out)
                  throws Exception {
                JsonNode root = OBJECT_MAPPER.readTree(value);
                String eventType = root.path("event_type").asText("unknown");
                String messageId = root.path("message_id").asText("");

                if (messageId.isBlank()) {
                  String healthEvent = buildHealthEvent("missing_message_id", value);
                  ctx.output(HEALTH_OUTPUT, healthEvent);
                  return;
                }

                out.collect(value);
                if (isCustomerFacingEvent(eventType)
                    && !root.path("tenant_id").asText("").isBlank()) {
                  ctx.output(CUSTOMER_OUTPUT, value);
                }
              }
            });

    DataStream<String> customerStream = internalStream.getSideOutput(CUSTOMER_OUTPUT);
    DataStream<String> healthStream = internalStream.getSideOutput(HEALTH_OUTPUT);

    KafkaSink<String> internalSink = stringSink(bootstrapServers, internalTopic);
    KafkaSink<String> customerSink = stringSink(bootstrapServers, customerTopic);
    KafkaSink<String> healthSink = stringSink(bootstrapServers, healthTopic);

    internalStream.sinkTo(internalSink).name("internal-topic-sink");
    customerStream.sinkTo(customerSink).name("customer-topic-sink");
    healthStream.sinkTo(healthSink).name("health-topic-sink");

    // Flink 2.0: ensure worker threads deserialize user operators with the correct classloader
    Thread.currentThread().setContextClassLoader(MailLifecycleRouterJob.class.getClassLoader());
    env.execute("mail-lifecycle-router-java");
  }

  private static KafkaSink<String> stringSink(String bootstrapServers, String topic) {
    return KafkaSink.<String>builder()
        .setBootstrapServers(bootstrapServers)
        .setRecordSerializer(
            KafkaRecordSerializationSchema.builder()
                .setTopic(topic)
                .setValueSerializationSchema(new SimpleStringSchema())
                .build())
        .build();
  }

  private static boolean isCustomerFacingEvent(String eventType) {
    Set<String> customerEvents =
        Set.of(
            "mail.requested", "mail.dispatched", "mail.delivered", "mail.opened", "mail.clicked");
    return customerEvents.contains(eventType);
  }

  private static String buildHealthEvent(String reason, String sourcePayload) {
    return "{"
        + "\"event_type\":\"pipeline.job_failed\","
        + "\"event_version\":\"1.0.0\","
        + "\"event_time\":\""
        + Instant.now()
        + "\","
        + "\"source_system\":\"flink.mail_lifecycle_router\","
        + "\"payload\":{"
        + "\"failure_reason\":\""
        + reason
        + "\","
        + "\"job_name\":\"mail-lifecycle-router-java\","
        + "\"job_type\":\"flink\","
        + "\"source_payload\":"
        + OBJECT_MAPPER.valueToTree(sourcePayload)
        + "}}";
  }

  private static String envOrDefault(String key, String fallback) {
    String value = System.getenv(key);
    return value == null || value.isBlank() ? fallback : value;
  }
}
