{{ config(materialized='table') }}

select
    tenant_id,
    event_date,
    requested_count,
    dispatched_count,
    delivered_count,
    opened_count,
    clicked_count,
    open_rate,
    click_through_rate,
    delivery_success_rate,
    tenant_lifetime_events
from {{ ref('int_customer_delivery_daily_metrics') }}
