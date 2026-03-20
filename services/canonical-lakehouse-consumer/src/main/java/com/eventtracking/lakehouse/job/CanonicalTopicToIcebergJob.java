package com.eventtracking.lakehouse.job;

import static org.apache.spark.sql.functions.col;
import static org.apache.spark.sql.functions.from_json;
import static org.apache.spark.sql.functions.to_date;
import static org.apache.spark.sql.functions.to_timestamp;

import com.eventtracking.lakehouse.config.LakehouseConsumerProperties;
import org.apache.spark.api.java.function.VoidFunction2;
import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.SparkSession;
import org.apache.spark.sql.streaming.DataStreamWriter;
import org.apache.spark.sql.streaming.StreamingQuery;
import org.apache.spark.sql.types.DataTypes;
import org.apache.spark.sql.types.StructType;
import org.apache.spark.storage.StorageLevel;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
public class CanonicalTopicToIcebergJob implements ApplicationRunner {
  private static final Logger LOGGER = LoggerFactory.getLogger(CanonicalTopicToIcebergJob.class);

  private final LakehouseConsumerProperties properties;

  public CanonicalTopicToIcebergJob(LakehouseConsumerProperties properties) {
    this.properties = properties;
  }

  @Override
  public void run(ApplicationArguments args) throws Exception {
    SparkSession spark = buildSparkSession();

    String landingTableName =
        properties.getIceberg().getCatalogName()
            + "."
            + properties.getIceberg().getNamespace()
            + "."
            + properties.getIceberg().getTable();
    String tenantDimensionTable =
        qualifiedTableName(properties.getTableau().getTenantDimensionTable());
    String eventTypeDimensionTable =
        qualifiedTableName(properties.getTableau().getEventTypeDimensionTable());
    String dailyFactTable = qualifiedTableName(properties.getTableau().getDailyFactTable());

    ensureIcebergTables(
        spark, landingTableName, tenantDimensionTable, eventTypeDimensionTable, dailyFactTable);

    Dataset<Row> kafkaEvents =
        spark
            .readStream()
            .format("kafka")
            .option("kafka.bootstrap.servers", properties.getKafka().getBootstrapServers())
            .option("subscribe", properties.getKafka().getTopic())
            .option("startingOffsets", properties.getKafka().getStartingOffsets())
            // In local dev, topics may be recreated between runs; tolerate offset gaps.
            .option("failOnDataLoss", "false")
            .load();

    StructType canonicalSchema =
        new StructType()
            .add("event_id", DataTypes.StringType)
            .add("event_type", DataTypes.StringType)
            .add("event_version", DataTypes.StringType)
            .add("event_time", DataTypes.StringType)
            .add("ingested_at", DataTypes.StringType)
            .add("source_system", DataTypes.StringType)
            .add("tenant_id", DataTypes.StringType)
            .add("message_id", DataTypes.StringType)
            .add("correlation_id", DataTypes.StringType)
            .add("trace_id", DataTypes.StringType)
            .add("actor_type", DataTypes.StringType)
            .add("payload", DataTypes.StringType);

    Dataset<Row> canonicalEvents =
        kafkaEvents
            .selectExpr("CAST(value AS STRING) AS json_value")
            .select(from_json(col("json_value"), canonicalSchema).alias("event"))
            .select("event.*")
            .withColumn("event_ts", to_timestamp(col("event_time")))
            .withColumn("ingested_ts", to_timestamp(col("ingested_at")))
            .withColumn("event_date", to_date(col("event_ts")));

    DataStreamWriter<Row> writer =
        canonicalEvents
            .writeStream()
            .option("checkpointLocation", properties.getCheckpoint().getLocation())
            .foreachBatch(
                (VoidFunction2<Dataset<Row>, Long>)
                    (batch, batchId) ->
                        processBatch(
                            spark,
                            batch,
                            batchId,
                            landingTableName,
                            tenantDimensionTable,
                            eventTypeDimensionTable,
                            dailyFactTable));

    StreamingQuery query = writer.start();

    LOGGER.info(
        "Started customer analytics consumer from {} into landing table {} with Tableau assets {},"
            + " {}, {}",
        properties.getKafka().getTopic(),
        landingTableName,
        tenantDimensionTable,
        eventTypeDimensionTable,
        dailyFactTable);
    query.awaitTermination();
  }

  private void processBatch(
      SparkSession spark,
      Dataset<Row> batch,
      long batchId,
      String landingTableName,
      String tenantDimensionTable,
      String eventTypeDimensionTable,
      String dailyFactTable)
      throws Exception {
    if (batch.takeAsList(1).isEmpty()) {
      LOGGER.info("Skipping empty micro-batch {}", batchId);
      return;
    }

    batch.persist(StorageLevel.MEMORY_AND_DISK());
    batch.writeTo(landingTableName).append();

    refreshTableauAssets(
        spark, landingTableName, tenantDimensionTable, eventTypeDimensionTable, dailyFactTable);
    batch.unpersist();

    LOGGER.info(
        "Processed micro-batch {} into landing and Tableau-serving Iceberg tables", batchId);
  }

  private SparkSession buildSparkSession() {
    SparkSession.Builder builder =
        SparkSession.builder()
            .appName("canonical-lakehouse-consumer")
            .master(properties.getSparkMaster())
            .config("spark.ui.enabled", String.valueOf(properties.isSparkUiEnabled()))
            .config(
                "spark.sql.catalog." + properties.getIceberg().getCatalogName(),
                "org.apache.iceberg.spark.SparkCatalog")
            .config(
                "spark.sql.catalog." + properties.getIceberg().getCatalogName() + ".type", "hadoop")
            .config(
                "spark.sql.catalog." + properties.getIceberg().getCatalogName() + ".warehouse",
                properties.getIceberg().getWarehouse())
            .config(
                "spark.sql.extensions",
                "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
            .config(
                "spark.hadoop.fs.s3a.path.style.access", properties.getS3().getPathStyleAccess());

    if (!properties.getS3().getEndpoint().isBlank()) {
      builder = builder.config("spark.hadoop.fs.s3a.endpoint", properties.getS3().getEndpoint());
    }
    if (!properties.getS3().getAccessKey().isBlank()) {
      builder = builder.config("spark.hadoop.fs.s3a.access.key", properties.getS3().getAccessKey());
    }
    if (!properties.getS3().getSecretKey().isBlank()) {
      builder = builder.config("spark.hadoop.fs.s3a.secret.key", properties.getS3().getSecretKey());
    }

    return builder.getOrCreate();
  }

  private void ensureIcebergTables(
      SparkSession spark,
      String landingTableName,
      String tenantDimensionTable,
      String eventTypeDimensionTable,
      String dailyFactTable) {
    String namespaceName =
        properties.getIceberg().getCatalogName() + "." + properties.getIceberg().getNamespace();
    spark.sql("CREATE NAMESPACE IF NOT EXISTS " + namespaceName);

    String landingDdl =
        "CREATE TABLE IF NOT EXISTS "
            + landingTableName
            + " ("
            + "event_id STRING,"
            + "event_type STRING,"
            + "event_version STRING,"
            + "event_time STRING,"
            + "ingested_at STRING,"
            + "source_system STRING,"
            + "tenant_id STRING,"
            + "message_id STRING,"
            + "correlation_id STRING,"
            + "trace_id STRING,"
            + "actor_type STRING,"
            + "payload STRING,"
            + "event_ts TIMESTAMP,"
            + "ingested_ts TIMESTAMP,"
            + "event_date DATE"
            + ") USING iceberg "
            + "PARTITIONED BY (days(event_ts), tenant_id)";
    spark.sql(landingDdl);

    String tenantDimensionDdl =
        "CREATE TABLE IF NOT EXISTS "
            + tenantDimensionTable
            + " ("
            + "tenant_id STRING,"
            + "first_seen_at TIMESTAMP,"
            + "last_seen_at TIMESTAMP,"
            + "total_events BIGINT"
            + ") USING iceberg";
    spark.sql(tenantDimensionDdl);

    String eventTypeDimensionDdl =
        "CREATE TABLE IF NOT EXISTS "
            + eventTypeDimensionTable
            + " ("
            + "event_type STRING,"
            + "first_seen_at TIMESTAMP,"
            + "last_seen_at TIMESTAMP,"
            + "total_events BIGINT"
            + ") USING iceberg";
    spark.sql(eventTypeDimensionDdl);

    String dailyFactDdl =
        "CREATE TABLE IF NOT EXISTS "
            + dailyFactTable
            + " ("
            + "tenant_id STRING,"
            + "event_date DATE,"
            + "requested_count BIGINT,"
            + "dispatched_count BIGINT,"
            + "delivered_count BIGINT,"
            + "opened_count BIGINT,"
            + "clicked_count BIGINT"
            + ") USING iceberg PARTITIONED BY (event_date, tenant_id)";
    spark.sql(dailyFactDdl);
  }

  private void refreshTableauAssets(
      SparkSession spark,
      String landingTableName,
      String tenantDimensionTable,
      String eventTypeDimensionTable,
      String dailyFactTable) {
    spark.sql(
        "INSERT OVERWRITE "
            + tenantDimensionTable
            + " SELECT tenant_id, MIN(event_ts) AS first_seen_at, MAX(event_ts) AS last_seen_at,"
            + " COUNT(*) AS total_events FROM "
            + landingTableName
            + " "
            + "WHERE tenant_id IS NOT NULL "
            + "GROUP BY tenant_id");

    spark.sql(
        "INSERT OVERWRITE "
            + eventTypeDimensionTable
            + " SELECT event_type, MIN(event_ts) AS first_seen_at, MAX(event_ts) AS last_seen_at,"
            + " COUNT(*) AS total_events FROM "
            + landingTableName
            + " "
            + "WHERE event_type IS NOT NULL "
            + "GROUP BY event_type");

    spark.sql(
        "INSERT OVERWRITE "
            + dailyFactTable
            + " SELECT tenant_id, event_date, SUM(CASE WHEN event_type = 'mail.requested' THEN 1"
            + " ELSE 0 END) AS requested_count, SUM(CASE WHEN event_type = 'mail.dispatched' THEN 1"
            + " ELSE 0 END) AS dispatched_count, SUM(CASE WHEN event_type = 'mail.delivered' THEN 1"
            + " ELSE 0 END) AS delivered_count, SUM(CASE WHEN event_type = 'mail.opened' THEN 1"
            + " ELSE 0 END) AS opened_count, SUM(CASE WHEN event_type = 'mail.clicked' THEN 1 ELSE"
            + " 0 END) AS clicked_count FROM "
            + landingTableName
            + " "
            + "WHERE tenant_id IS NOT NULL AND event_date IS NOT NULL "
            + "GROUP BY tenant_id, event_date");
  }

  private String qualifiedTableName(String tableName) {
    return properties.getIceberg().getCatalogName()
        + "."
        + properties.getIceberg().getNamespace()
        + "."
        + tableName;
  }
}
