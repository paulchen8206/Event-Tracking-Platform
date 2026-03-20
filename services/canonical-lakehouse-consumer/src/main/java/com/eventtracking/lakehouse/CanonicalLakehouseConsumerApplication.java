package com.eventtracking.lakehouse;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class CanonicalLakehouseConsumerApplication {
  public static void main(String[] args) {
    SpringApplication.run(CanonicalLakehouseConsumerApplication.class, args);
  }
}
