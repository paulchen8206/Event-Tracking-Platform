with tenant_dim as (
    select
        tenant_id,
        first_seen_at,
        last_seen_at,
        total_events as tenant_total_events
    from {{ ref('stg_customer_tenant') }}
),

event_type_dim as (
    select
        event_type,
        first_seen_at as event_type_first_seen_at,
        last_seen_at as event_type_last_seen_at,
        total_events as event_type_total_events
    from {{ ref('stg_customer_event_type') }}
)

select
    tenant_dim.tenant_id,
    tenant_dim.first_seen_at,
    tenant_dim.last_seen_at,
    tenant_dim.tenant_total_events,
    event_type_dim.event_type,
    event_type_dim.event_type_first_seen_at,
    event_type_dim.event_type_last_seen_at,
    event_type_dim.event_type_total_events
from tenant_dim
cross join event_type_dim
