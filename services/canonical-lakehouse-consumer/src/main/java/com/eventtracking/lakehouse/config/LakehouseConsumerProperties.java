package com.eventtracking.lakehouse.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public class LakehouseConsumerProperties {
  private String sparkMaster = "local[*]";
  private boolean sparkUiEnabled = true;
  private final Kafka kafka = new Kafka();
  private final Iceberg iceberg = new Iceberg();
  private final S3 s3 = new S3();
  private final Checkpoint checkpoint = new Checkpoint();
  private final Tableau tableau = new Tableau();

  public Kafka getKafka() {
    return kafka;
  }

  public Iceberg getIceberg() {
    return iceberg;
  }

  public S3 getS3() {
    return s3;
  }

  public Checkpoint getCheckpoint() {
    return checkpoint;
  }

  public Tableau getTableau() {
    return tableau;
  }

  public String getSparkMaster() {
    return sparkMaster;
  }

  public void setSparkMaster(String sparkMaster) {
    this.sparkMaster = sparkMaster;
  }

  public boolean isSparkUiEnabled() {
    return sparkUiEnabled;
  }

  public void setSparkUiEnabled(boolean sparkUiEnabled) {
    this.sparkUiEnabled = sparkUiEnabled;
  }

  public static class Kafka {
    private String bootstrapServers = "localhost:9092";
    private String topic = "evt.mail.customer.analytics";
    private String startingOffsets = "latest";

    public String getBootstrapServers() {
      return bootstrapServers;
    }

    public void setBootstrapServers(String bootstrapServers) {
      this.bootstrapServers = bootstrapServers;
    }

    public String getTopic() {
      return topic;
    }

    public void setTopic(String topic) {
      this.topic = topic;
    }

    public String getStartingOffsets() {
      return startingOffsets;
    }

    public void setStartingOffsets(String startingOffsets) {
      this.startingOffsets = startingOffsets;
    }
  }

  public static class Iceberg {
    private String catalogName = "lakehouse";
    private String namespace = "customer_analytics";
    private String table = "tableau_reporting_events";
    private String warehouse = "s3a://event-tracking-lakehouse/warehouse";

    public String getCatalogName() {
      return catalogName;
    }

    public void setCatalogName(String catalogName) {
      this.catalogName = catalogName;
    }

    public String getNamespace() {
      return namespace;
    }

    public void setNamespace(String namespace) {
      this.namespace = namespace;
    }

    public String getTable() {
      return table;
    }

    public void setTable(String table) {
      this.table = table;
    }

    public String getWarehouse() {
      return warehouse;
    }

    public void setWarehouse(String warehouse) {
      this.warehouse = warehouse;
    }
  }

  public static class S3 {
    private String endpoint = "";
    private String accessKey = "";
    private String secretKey = "";
    private String pathStyleAccess = "true";

    public String getEndpoint() {
      return endpoint;
    }

    public void setEndpoint(String endpoint) {
      this.endpoint = endpoint;
    }

    public String getAccessKey() {
      return accessKey;
    }

    public void setAccessKey(String accessKey) {
      this.accessKey = accessKey;
    }

    public String getSecretKey() {
      return secretKey;
    }

    public void setSecretKey(String secretKey) {
      this.secretKey = secretKey;
    }

    public String getPathStyleAccess() {
      return pathStyleAccess;
    }

    public void setPathStyleAccess(String pathStyleAccess) {
      this.pathStyleAccess = pathStyleAccess;
    }
  }

  public static class Checkpoint {
    private String location =
        "s3a://event-tracking-lakehouse/checkpoints/customer-analytics/tableau-reporting-events";

    public String getLocation() {
      return location;
    }

    public void setLocation(String location) {
      this.location = location;
    }
  }

  public static class Tableau {
    private String tenantDimensionTable = "dim_customer_tenant";
    private String eventTypeDimensionTable = "dim_customer_event_type";
    private String dailyFactTable = "fct_tableau_daily_customer_delivery";

    public String getTenantDimensionTable() {
      return tenantDimensionTable;
    }

    public void setTenantDimensionTable(String tenantDimensionTable) {
      this.tenantDimensionTable = tenantDimensionTable;
    }

    public String getEventTypeDimensionTable() {
      return eventTypeDimensionTable;
    }

    public void setEventTypeDimensionTable(String eventTypeDimensionTable) {
      this.eventTypeDimensionTable = eventTypeDimensionTable;
    }

    public String getDailyFactTable() {
      return dailyFactTable;
    }

    public void setDailyFactTable(String dailyFactTable) {
      this.dailyFactTable = dailyFactTable;
    }
  }
}
