select
    tenant_id,
    template_id,
    event_date,
    sum(case when event_type = 'mail.requested' then 1 else 0 end) as requested_count,
    sum(case when event_type = 'mail.dispatched' then 1 else 0 end) as dispatched_count,
    sum(case when event_type = 'mail.delivered' then 1 else 0 end) as delivered_count,
    sum(case when event_type = 'mail.opened' then 1 else 0 end) as opened_count,
    sum(case when event_type = 'mail.clicked' then 1 else 0 end) as clicked_count,
    case
        when sum(case when event_type = 'mail.delivered' then 1 else 0 end) = 0 then 0
        else sum(case when event_type = 'mail.opened' then 1 else 0 end)::float
            / sum(case when event_type = 'mail.delivered' then 1 else 0 end)
    end as open_rate,
    case
        when sum(case when event_type = 'mail.delivered' then 1 else 0 end) = 0 then 0
        else sum(case when event_type = 'mail.clicked' then 1 else 0 end)::float
            / sum(case when event_type = 'mail.delivered' then 1 else 0 end)
    end as click_through_rate
from {{ ref('stg_customer_analytics_events') }}
where template_id is not null
group by 1, 2, 3
