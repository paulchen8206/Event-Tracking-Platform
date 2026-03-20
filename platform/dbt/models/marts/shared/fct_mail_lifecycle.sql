{{ config(materialized='incremental', unique_key='event_id') }}

select
    cast(null as varchar) as event_id,
    cast(null as varchar) as event_type,
    cast(null as varchar) as tenant_id,
    cast(null as varchar) as message_id,
    cast(null as varchar) as correlation_id,
    cast(null as varchar) as provider_id,
    cast(null as timestamp_ntz) as event_time,
    cast(null as timestamp_ntz) as ingested_at,
    cast(null as varchar) as latest_status,
    cast(null as varchar) as failure_code
where 1 = 0