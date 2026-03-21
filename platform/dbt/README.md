# dbt Semantic Layer Guide

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

## Local Development (Docker Compose)

The dbt container runs inside the `dev-dbt` Compose profile and reads credentials from a root `.env` file (see `.env.example` for the required variables).

| Make target | What it does |
| --- | --- |
| `make dev-dbt-up` | Start the dbt Snowflake container |
| `make dev-dbt-deps` | Install dbt package dependencies (`dbt deps`) |
| `make dev-dbt-debug` | Validate Snowflake connectivity and profile (`dbt debug`) |
| `make dev-dbt-build` | Build staging and mart models (`dbt build --select staging.customer_analytics+ marts.customer_analytics`) |
| `make dev-dbt-seed-large` | Load 12 000-row synthetic data into Snowflake source tables and confirm row count |
| `make dev-dbt-down` | Stop the dbt container |

Typical first-time setup flow:

```bash
make dev-dbt-up
make dev-dbt-deps
make dev-dbt-debug
make dev-dbt-seed-large   # populate source tables with realistic synthetic data
make dev-dbt-build
```

### Synthetic source data

`make dev-dbt-seed-large` copies `storage/snowflake/schemas/sf_tuts_customer_analytics_generate_large_data.sql` into the container and executes it via the Snowflake connector. It generates:

- ~12 000 rows in `ICEBERG_CUSTOMER_ANALYTICS.TABLEAU_REPORTING_EVENTS`
- 80 unique tenants, 12 campaigns, 8 templates, 4 providers over a 45-day window
- Automatically rebuilds `DIM_CUSTOMER_TENANT`, `DIM_CUSTOMER_EVENT_TYPE`, and `FCT_TABLEAU_DAILY_CUSTOMER_DELIVERY` from the generated events

Re-run at any time to refresh the data set.

## Suggested Raw Commands

If you prefer to run dbt directly inside the container:

```bash
dbt deps
dbt debug
dbt build --select staging.customer_analytics+ marts.customer_analytics
```

The project uses `dbt_utils` for package-backed tests and utility macros.
