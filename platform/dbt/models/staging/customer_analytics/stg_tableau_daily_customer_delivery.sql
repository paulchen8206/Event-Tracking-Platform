select
    tenant_id,
    event_date,
    requested_count,
    dispatched_count,
    delivered_count,
    opened_count,
    clicked_count
from {{ source('iceberg_customer_analytics', 'fct_tableau_daily_customer_delivery') }}
