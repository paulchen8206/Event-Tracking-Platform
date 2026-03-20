{{ config(materialized='table') }}

select
    tenant_id,
    first_seen_at,
    last_seen_at,
    total_events as tenant_total_events
from {{ ref('stg_customer_tenant') }}
