package com.eventtracking.producers;

import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.ListTopicsResult;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Properties;

/**
 * CLI entry point for the synthetic event producer suite.
 *
 * <p>Reads all configuration from environment variables so the producers can be
 * run inside the local Docker Compose development stack or directly from the shell.
 *
 * <p>Environment variables:
 * <table>
 *   <tr><th>Variable</th><th>Default</th><th>Description</th></tr>
 *   <tr><td>KAFKA_BOOTSTRAP_SERVERS</td><td>localhost:9092</td><td>Kafka broker address</td></tr>
 *   <tr><td>PRODUCER_MODE</td><td>both</td><td>{@code cdc}, {@code mail-tracking}, or {@code both}</td></tr>
 *   <tr><td>EVENT_COUNT</td><td>100</td><td>Number of events per producer</td></tr>
 *   <tr><td>EVENTS_PER_SECOND</td><td>10</td><td>Target throughput per producer (0 = no limit)</td></tr>
 *   <tr><td>TENANT_COUNT</td><td>5</td><td>Size of the simulated tenant pool</td></tr>
 *   <tr><td>CDC_TARGET_TOPIC</td><td>dbz.postgres.mail.public.mail_events</td><td>CDC output topic</td></tr>
 *   <tr><td>MAIL_TRACKING_TARGET_TOPIC</td><td>evt.mail.operational.raw</td><td>Mail-tracking output topic</td></tr>
 *   <tr><td>RUN_CONTINUOUSLY</td><td>false</td><td>Repeat batches forever for dev traffic generation</td></tr>
 *   <tr><td>BATCH_INTERVAL_MS</td><td>2000</td><td>Pause between batches when running continuously</td></tr>
 *   <tr><td>TOPIC_WAIT_TIMEOUT_MS</td><td>120000</td><td>Maximum wait time for required Kafka topics to exist</td></tr>
 *   <tr><td>TOPIC_WAIT_POLL_INTERVAL_MS</td><td>2000</td><td>Polling interval while waiting for topics</td></tr>
 *   <tr><td>STATUS_FILE_PATH</td><td>/tmp/event-producer-status</td><td>Health/status marker file for container checks</td></tr>
 * </table>
 *
 * <p>Example — emit 500 events across both pipelines at 50 events/sec each:
 * <pre>
 *   EVENT_COUNT=500 EVENTS_PER_SECOND=50 java -jar event-producers.jar
 * </pre>
 */
public class EventProducerApp {

    private static final Logger LOG = LoggerFactory.getLogger(EventProducerApp.class);

    public static void main(String[] args) throws Exception {
        String bootstrapServers = env("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092");
        String mode = env("PRODUCER_MODE", "both").toLowerCase();
        int eventCount = intEnv("EVENT_COUNT", 100);
        int eventsPerSecond = intEnv("EVENTS_PER_SECOND", 10);
        int tenantCount = intEnv("TENANT_COUNT", 5);
        boolean runContinuously = boolEnv("RUN_CONTINUOUSLY", false);
        int batchIntervalMs = intEnv("BATCH_INTERVAL_MS", 2000);
        int topicWaitTimeoutMs = intEnv("TOPIC_WAIT_TIMEOUT_MS", 120000);
        int topicWaitPollIntervalMs = intEnv("TOPIC_WAIT_POLL_INTERVAL_MS", 2000);
        String cdcTopic = env("CDC_TARGET_TOPIC", "dbz.postgres.mail.public.mail_events");
        String mailTrackingTopic = env("MAIL_TRACKING_TARGET_TOPIC", "evt.mail.operational.raw");
        Path statusFile = Path.of(env("STATUS_FILE_PATH", "/tmp/event-producer-status"));

        LOG.info("Event producer suite — mode={} count={} rps={} tenants={} continuous={} batchIntervalMs={} topicWaitTimeoutMs={}",
            mode, eventCount, eventsPerSecond, tenantCount, runContinuously, batchIntervalMs, topicWaitTimeoutMs);

        markStatus(statusFile, "starting");

        markStatus(statusFile, "waiting-for-topics");
        waitForRequiredTopics(
            bootstrapServers,
            requiredTopics(mode, cdcTopic, mailTrackingTopic),
            topicWaitTimeoutMs,
            topicWaitPollIntervalMs
        );
        markStatus(statusFile, "ready");

        do {
            markStatus(statusFile, "running");
            runBatch(mode, bootstrapServers, cdcTopic, mailTrackingTopic, eventCount, eventsPerSecond, tenantCount);
            if (runContinuously) {
                LOG.info("Batch complete. Sleeping {} ms before next batch.", batchIntervalMs);
                Thread.sleep(batchIntervalMs);
            }
        } while (runContinuously);

        markStatus(statusFile, "completed");
        LOG.info("All producers completed.");
    }

    private static void runBatch(String mode, String bootstrapServers, String cdcTopic,
                                 String mailTrackingTopic, int eventCount, int eventsPerSecond,
                                 int tenantCount) throws Exception {
        switch (mode) {
            case "cdc" -> runCdc(bootstrapServers, cdcTopic, eventCount, eventsPerSecond, tenantCount);
            case "mail-tracking" -> runMailTracking(bootstrapServers, mailTrackingTopic, eventCount, eventsPerSecond, tenantCount);
            case "both" -> {
                runCdc(bootstrapServers, cdcTopic, eventCount, eventsPerSecond, tenantCount);
                runMailTracking(bootstrapServers, mailTrackingTopic, eventCount, eventsPerSecond, tenantCount);
            }
            default -> {
                LOG.error("Unknown PRODUCER_MODE '{}'. Valid values: cdc, mail-tracking, both", mode);
                System.exit(1);
            }
        }
    }

    private static void runCdc(String bootstrapServers, String topic, int count,
                                int rps, int tenantCount) throws Exception {
        new CdcEventProducer().run(bootstrapServers, topic, count, rps, tenantCount);
    }

    private static void runMailTracking(String bootstrapServers, String topic, int count,
                                        int rps, int tenantCount) throws Exception {
        new MailTrackingEventProducer().run(bootstrapServers, topic, count, rps, tenantCount);
    }

    private static List<String> requiredTopics(String mode, String cdcTopic, String mailTrackingTopic) {
        return switch (mode) {
            case "cdc" -> List.of(cdcTopic);
            case "mail-tracking" -> List.of(mailTrackingTopic);
            case "both" -> List.of(cdcTopic, mailTrackingTopic);
            default -> throw new IllegalArgumentException("Unknown PRODUCER_MODE '" + mode + "'");
        };
    }

    private static void waitForRequiredTopics(String bootstrapServers, List<String> requiredTopics,
                                              int timeoutMs, int pollIntervalMs) throws Exception {
        Properties props = new Properties();
        props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);

        Instant deadline = Instant.now().plus(Duration.ofMillis(timeoutMs));
        try (AdminClient adminClient = AdminClient.create(props)) {
            while (Instant.now().isBefore(deadline)) {
                try {
                    ListTopicsResult topicsResult = adminClient.listTopics();
                    var existingTopics = topicsResult.names().get();
                    if (existingTopics.containsAll(requiredTopics)) {
                        LOG.info("Required topics are ready: {}", requiredTopics);
                        return;
                    }
                    LOG.info("Waiting for topics {}. Currently available: {}", requiredTopics, existingTopics);
                } catch (Exception e) {
                    LOG.warn("Failed to query topic metadata yet. Retrying.", e);
                }
                Thread.sleep(pollIntervalMs);
            }
        }

        throw new IllegalStateException("Timed out waiting for required Kafka topics: " + requiredTopics);
    }

    private static void markStatus(Path statusFile, String status) {
        try {
            if (statusFile.getParent() != null) {
                Files.createDirectories(statusFile.getParent());
            }
            Files.writeString(
                statusFile,
                status + System.lineSeparator(),
                StandardOpenOption.CREATE,
                StandardOpenOption.TRUNCATE_EXISTING,
                StandardOpenOption.WRITE
            );
            LOG.info("Status updated: {} -> {}", statusFile, status);
        } catch (Exception e) {
            LOG.warn("Failed to write status file {}", statusFile, e);
        }
    }

    private static String env(String key, String fallback) {
        String value = System.getenv(key);
        return (value == null || value.isBlank()) ? fallback : value;
    }

    private static int intEnv(String key, int fallback) {
        String value = System.getenv(key);
        if (value == null || value.isBlank()) {
            return fallback;
        }
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            LOG.warn("Invalid integer value '{}' for env var '{}', using default {}", value, key, fallback);
            return fallback;
        }
    }

    private static boolean boolEnv(String key, boolean fallback) {
        String value = System.getenv(key);
        if (value == null || value.isBlank()) {
            return fallback;
        }
        return Boolean.parseBoolean(value.trim());
    }
}
