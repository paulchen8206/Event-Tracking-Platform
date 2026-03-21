# Snowflake Storage and Schema Assets

Schema DDL and data seeding scripts for the Snowflake source tables consumed by the dbt semantic layer.

## Purpose

These scripts bootstrap the Snowflake side of the local and dev environment. In production the source tables are backed by Iceberg on S3, exposed through Snowflake's external Iceberg table feature. In local dev, the same table contracts are created as native Snowflake tables so the full dbt build can run without an S3/Iceberg dependency.

## Layout

```text
schemas/
  sf_tuts_customer_analytics_sources.sql          — DDL bootstrap (schema + 4 source tables)
  sf_tuts_customer_analytics_seed_data.sql        — Small 6-row sample dataset
  sf_tuts_customer_analytics_generate_large_data.sql — 12 000-row synthetic data generator
```

## Scripts

### `sf_tuts_customer_analytics_sources.sql`

Idempotent DDL (`CREATE SCHEMA IF NOT EXISTS`, `CREATE TABLE IF NOT EXISTS`) that creates the `ICEBERG_CUSTOMER_ANALYTICS` schema and the four source tables inside the configured database:

| Table | Description |
| --- | --- |
| `TABLEAU_REPORTING_EVENTS` | Raw customer analytics events — one row per event |
| `DIM_CUSTOMER_TENANT` | Tenant dimension with first/last seen timestamps and total event counts |
| `DIM_CUSTOMER_EVENT_TYPE` | Event type dimension (delivered, bounced, opened, clicked, unsubscribed) |
| `FCT_TABLEAU_DAILY_CUSTOMER_DELIVERY` | Daily delivery fact aggregated by tenant, event type, campaign, and template |

Run once after provisioning a new Snowflake database for local dev.

### `sf_tuts_customer_analytics_seed_data.sql`

Loads 6 representative rows (2 tenants × 3 event types) into all four source tables. Idempotent — uses `DELETE` then `INSERT` inside a transaction. Use this for a lightweight smoke test of the dbt semantic layer.

### `sf_tuts_customer_analytics_generate_large_data.sql`

Generates a realistic dataset for Tableau dashboard demos using Snowflake's `table(generator(rowcount => 12000))`:

- ~12 000 events across 80 unique tenants
- 12 campaigns, 8 templates, 4 mail providers
- 45-day rolling time window
- All 5 event types in equal distribution
- Rebuilds `DIM_CUSTOMER_TENANT`, `DIM_CUSTOMER_EVENT_TYPE`, and `FCT_TABLEAU_DAILY_CUSTOMER_DELIVERY` from the generated events

Run via the Make target `make dev-dbt-seed-large`, or manually by executing the script via the Snowflake connector inside the dbt container.

## Usage

### Make target (recommended)

```bash
make dev-dbt-seed-large
```

This copies the large generator script into the running dbt container, executes it via the Snowflake connector, and prints the final row count of `TABLEAU_REPORTING_EVENTS`.

### Manual bootstrap (first-time setup)

```bash
# Copy DDL script into the dbt container and execute it
docker cp storage/snowflake/schemas/sf_tuts_customer_analytics_sources.sql etp-dbt-snowflake:/tmp/sources.sql
docker compose -f infra/docker/docker-compose.kafka.yml exec dbt-snowflake \
  python3 -c "
import snowflake.connector, os
conn = snowflake.connector.connect(
    account=os.environ['DBT_SNOWFLAKE_ACCOUNT'],
    user=os.environ['DBT_SNOWFLAKE_USER'],
    password=os.environ['DBT_SNOWFLAKE_PASSWORD'],
    role=os.environ['DBT_SNOWFLAKE_ROLE'],
    warehouse=os.environ['DBT_SNOWFLAKE_WAREHOUSE'],
    database=os.environ['DBT_SNOWFLAKE_DATABASE'],
)
cur = conn.cursor()
for stmt in [s.strip() for s in open('/tmp/sources.sql').read().split(';') if s.strip()]:
    cur.execute(stmt)
conn.close()
print('Done')
"
```

## Related

- [platform/dbt/README.md](../../platform/dbt/README.md) — dbt project and Make target reference
- [docs/runbooks/local-dev-docker-compose.md](../../docs/runbooks/local-dev-docker-compose.md) — Full local dev workflow including dbt
- [.env.example](../../.env.example) — Snowflake credential template
