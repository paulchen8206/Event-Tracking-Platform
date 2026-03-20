with source_events as (
    select
        event_id,
        tenant_id,
        message_id,
        correlation_id,
        event_type,
        source_system,
        actor_type,
        event_ts,
        ingested_ts,
        event_date,
        payload,
        try_parse_json(payload) as payload_variant
    from {{ source('iceberg_customer_analytics', 'tableau_reporting_events') }}
)

select
    event_id,
    tenant_id,
    message_id,
    correlation_id,
    event_type,
    source_system,
    actor_type,
    event_ts,
    ingested_ts,
    event_date,
    payload,
    coalesce(payload_variant:campaign_id::string, payload_variant:campaign.id::string) as campaign_id,
    coalesce(payload_variant:campaign_name::string, payload_variant:campaign.name::string) as campaign_name,
    coalesce(payload_variant:template_id::string, payload_variant:template.id::string) as template_id,
    coalesce(payload_variant:template_name::string, payload_variant:template.name::string) as template_name,
    coalesce(payload_variant:template_channel::string, payload_variant:template.channel::string) as template_channel,
    coalesce(payload_variant:provider::string, payload_variant:delivery.provider::string) as provider,
    coalesce(payload_variant:status::string, payload_variant:delivery.status::string) as delivery_status
from source_events
