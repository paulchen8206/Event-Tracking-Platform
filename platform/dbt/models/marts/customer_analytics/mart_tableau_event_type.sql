{{ config(materialized='table') }}

select
    event_type,
    first_seen_at,
    last_seen_at,
    total_events
from {{ ref('stg_customer_event_type') }}
