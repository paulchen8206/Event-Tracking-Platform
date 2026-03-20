with template_events as (
    select
        tenant_id,
        template_id,
        template_name,
        template_channel,
        provider,
        min(event_ts) as first_seen_at,
        max(event_ts) as last_seen_at,
        count(*) as total_events
    from {{ ref('stg_customer_analytics_events') }}
    where template_id is not null
    group by 1, 2, 3, 4, 5
)

select
    tenant_id,
    template_id,
    coalesce(template_name, template_id) as template_name,
    template_channel,
    provider,
    first_seen_at,
    last_seen_at,
    total_events
from template_events
