with base as (
    select *
    from {{ ref('stg_tableau_daily_customer_delivery') }}
),

tenant_enriched as (
    select
        base.tenant_id,
        base.event_date,
        base.requested_count,
        base.dispatched_count,
        base.delivered_count,
        base.opened_count,
        base.clicked_count,
        coalesce(tenant.total_events, 0) as tenant_lifetime_events
    from base
    left join {{ ref('stg_customer_tenant') }} as tenant
        on base.tenant_id = tenant.tenant_id
)

select
    tenant_id,
    event_date,
    requested_count,
    dispatched_count,
    delivered_count,
    opened_count,
    clicked_count,
    tenant_lifetime_events,
    case
        when delivered_count = 0 then 0
        else opened_count::float / delivered_count
    end as open_rate,
    case
        when delivered_count = 0 then 0
        else clicked_count::float / delivered_count
    end as click_through_rate,
    case
        when requested_count = 0 then 0
        else delivered_count::float / requested_count
    end as delivery_success_rate
from tenant_enriched
