-- Starter Flink SQL skeleton for normalizing lifecycle events and routing them
-- into customer-safe analytics streams and richer internal tracking streams.

create table raw_mail_events (
    event_id string,
    event_type string,
    event_version string,
    event_time timestamp(3),
    ingested_at timestamp(3),
    source_system string,
    tenant_id string,
    message_id string,
    correlation_id string,
    trace_id string,
    actor_type string,
    payload string
) with (
    'connector' = 'kafka',
    'topic' = 'evt.mail.lifecycle.raw',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.group.id' = 'mail-lifecycle-router',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json'
);

create table normalized_mail_events (
    event_id string,
    event_type string,
    event_version string,
    event_time timestamp(3),
    ingested_at timestamp(3),
    source_system string,
    tenant_id string,
    message_id string,
    correlation_id string,
    trace_id string,
    actor_type string,
    payload string
) with (
    'connector' = 'kafka',
    'topic' = 'evt.mail.lifecycle.normalized',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'format' = 'json'
);

create table customer_analytics_events (
    tenant_id string,
    message_id string,
    event_type string,
    event_time timestamp(3),
    payload string
) with (
    'connector' = 'kafka',
    'topic' = 'evt.mail.customer.analytics',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'format' = 'json'
);

create table internal_tracking_events (
    tenant_id string,
    message_id string,
    correlation_id string,
    event_type string,
    event_time timestamp(3),
    payload string
) with (
    'connector' = 'kafka',
    'topic' = 'evt.mail.internal.tracking',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'format' = 'json'
);

insert into normalized_mail_events
select
    event_id,
    lower(event_type) as event_type,
    event_version,
    event_time,
    ingested_at,
    source_system,
    tenant_id,
    message_id,
    correlation_id,
    trace_id,
    actor_type,
    payload
from raw_mail_events
where event_id is not null
  and message_id is not null
  and correlation_id is not null;

insert into customer_analytics_events
select
    tenant_id,
    message_id,
    event_type,
    event_time,
    payload
from normalized_mail_events
where tenant_id is not null
  and event_type in (
      'mail.requested',
      'mail.dispatched',
      'mail.delivered',
      'mail.opened',
      'mail.clicked'
  );

insert into internal_tracking_events
select
    tenant_id,
    message_id,
    correlation_id,
    event_type,
    event_time,
    payload
from normalized_mail_events;