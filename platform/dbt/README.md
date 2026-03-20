# dbt Semantic Layer

This dbt project builds Snowflake semantic models on top of Iceberg-backed customer analytics tables produced by the Spark lakehouse consumer.

## Expected Flow

1. Spark writes customer analytics assets to Iceberg tables on S3.
2. Snowflake exposes those Iceberg tables in the `ICEBERG_CUSTOMER_ANALYTICS` schema.
3. dbt reads those sources, applies semantic modeling, and materializes Tableau-facing marts into a Snowflake target schema.

## Profiles

Use [profiles.example.yml](profiles.example.yml) as the template for your local or CI dbt profile.

Required environment variables include:

- `DBT_SNOWFLAKE_ACCOUNT`
- `DBT_SNOWFLAKE_USER`
- `DBT_SNOWFLAKE_PASSWORD`
- `DBT_SNOWFLAKE_ROLE`
- `DBT_SNOWFLAKE_WAREHOUSE`
- `DBT_SNOWFLAKE_DATABASE`
- `DBT_SNOWFLAKE_TARGET_SCHEMA`
- `DBT_SNOWFLAKE_ICEBERG_SCHEMA`

## Tableau Semantic Models

- `mart_customer_delivery_summary`
- `mart_tableau_customer_tenant`
- `mart_tableau_event_type`
- `mart_tableau_campaign_performance`
- `mart_tableau_template_performance`

## Suggested Commands

```bash
dbt deps
dbt debug
dbt build --select staging.customer_analytics+ marts.customer_analytics
```

The project uses `dbt_utils` for package-backed tests and utility macros.
