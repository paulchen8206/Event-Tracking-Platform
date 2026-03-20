{{ config(materialized='table') }}

select
    metrics.tenant_id,
    metrics.campaign_id,
    dim.campaign_name,
    dim.provider,
    metrics.event_date,
    metrics.requested_count,
    metrics.dispatched_count,
    metrics.delivered_count,
    metrics.opened_count,
    metrics.clicked_count,
    metrics.open_rate,
    metrics.click_through_rate,
    dim.total_events as campaign_total_events,
    dim.first_seen_at as campaign_first_seen_at,
    dim.last_seen_at as campaign_last_seen_at
from {{ ref('int_customer_campaign_daily_metrics') }} as metrics
left join {{ ref('int_customer_campaign_dimension') }} as dim
    on metrics.tenant_id = dim.tenant_id
   and metrics.campaign_id = dim.campaign_id
