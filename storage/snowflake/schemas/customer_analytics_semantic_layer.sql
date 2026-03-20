create schema if not exists EVENT_TRACKING.ICEBERG_CUSTOMER_ANALYTICS;
create schema if not exists EVENT_TRACKING.ANALYTICS_SEMANTIC;

-- The following objects are placeholders that document the expected Snowflake-side
-- access pattern. Replace identifiers and integration names with environment-specific values.

-- Example: external or managed Iceberg table registration for the Spark-produced S3 lakehouse assets.
-- create iceberg table EVENT_TRACKING.ICEBERG_CUSTOMER_ANALYTICS.TABLEAU_REPORTING_EVENTS
--   external_volume = <external_volume_name>
--   catalog = 'SNOWFLAKE'
--   base_location = 'warehouse/customer_analytics/tableau_reporting_events';

-- create iceberg table EVENT_TRACKING.ICEBERG_CUSTOMER_ANALYTICS.DIM_CUSTOMER_TENANT
--   external_volume = <external_volume_name>
--   catalog = 'SNOWFLAKE'
--   base_location = 'warehouse/customer_analytics/dim_customer_tenant';

-- create iceberg table EVENT_TRACKING.ICEBERG_CUSTOMER_ANALYTICS.DIM_CUSTOMER_EVENT_TYPE
--   external_volume = <external_volume_name>
--   catalog = 'SNOWFLAKE'
--   base_location = 'warehouse/customer_analytics/dim_customer_event_type';

-- create iceberg table EVENT_TRACKING.ICEBERG_CUSTOMER_ANALYTICS.FCT_TABLEAU_DAILY_CUSTOMER_DELIVERY
--   external_volume = <external_volume_name>
--   catalog = 'SNOWFLAKE'
--   base_location = 'warehouse/customer_analytics/fct_tableau_daily_customer_delivery';

-- dbt should target EVENT_TRACKING.ANALYTICS_SEMANTIC for curated semantic models consumed by Tableau.
-- Expected semantic outputs include:
--   EVENT_TRACKING.ANALYTICS_SEMANTIC.MART_CUSTOMER_DELIVERY_SUMMARY
--   EVENT_TRACKING.ANALYTICS_SEMANTIC.MART_TABLEAU_CUSTOMER_TENANT
--   EVENT_TRACKING.ANALYTICS_SEMANTIC.MART_TABLEAU_EVENT_TYPE
--   EVENT_TRACKING.ANALYTICS_SEMANTIC.MART_TABLEAU_CAMPAIGN_PERFORMANCE
--   EVENT_TRACKING.ANALYTICS_SEMANTIC.MART_TABLEAU_TEMPLATE_PERFORMANCE
-- Campaign and template marts should expose descriptive attributes such as names,
-- channels, and providers in addition to IDs so Tableau dashboards do not need
-- separate ID-to-label lookups.