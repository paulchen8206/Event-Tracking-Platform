with campaign_events as (
    select
        tenant_id,
        campaign_id,
        campaign_name,
        provider,
        min(event_ts) as first_seen_at,
        max(event_ts) as last_seen_at,
        count(*) as total_events
    from {{ ref('stg_customer_analytics_events') }}
    where campaign_id is not null
    group by 1, 2, 3, 4
)

select
    tenant_id,
    campaign_id,
    coalesce(campaign_name, campaign_id) as campaign_name,
    provider,
    first_seen_at,
    last_seen_at,
    total_events
from campaign_events
