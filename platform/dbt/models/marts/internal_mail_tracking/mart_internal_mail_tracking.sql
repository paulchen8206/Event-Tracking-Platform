{{ config(materialized='view') }}

with ranked_events as (
    select
        message_id,
        tenant_id,
        correlation_id,
        event_type,
        event_time,
        ingested_at,
        latest_status,
        failure_code,
        row_number() over (
            partition by message_id
            order by event_time desc, ingested_at desc
        ) as row_num
    from {{ ref('fct_mail_lifecycle') }}
)

select
    message_id,
    tenant_id,
    correlation_id,
    event_type as latest_event_type,
    event_time as latest_event_time,
    latest_status,
    failure_code
from ranked_events
where row_num = 1