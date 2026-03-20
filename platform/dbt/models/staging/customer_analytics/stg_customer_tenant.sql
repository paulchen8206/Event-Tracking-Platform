select
    tenant_id,
    first_seen_at,
    last_seen_at,
    total_events
from {{ source('iceberg_customer_analytics', 'dim_customer_tenant') }}
