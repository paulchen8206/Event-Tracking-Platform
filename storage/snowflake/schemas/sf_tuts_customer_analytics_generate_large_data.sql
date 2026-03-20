-- Generate high-volume synthetic customer analytics data for Tableau demos.
-- Target: SF_TUTS.ICEBERG_CUSTOMER_ANALYTICS
-- Default volume: 12,000 event rows

use role ACCOUNTADMIN;
use warehouse COMPUTE_WH;
use database SF_TUTS;
use schema ICEBERG_CUSTOMER_ANALYTICS;

begin;

-- Idempotent refresh for local demo runs.
delete from TABLEAU_REPORTING_EVENTS;
delete from DIM_CUSTOMER_TENANT;
delete from DIM_CUSTOMER_EVENT_TYPE;
delete from FCT_TABLEAU_DAILY_CUSTOMER_DELIVERY;

insert into TABLEAU_REPORTING_EVENTS (
  EVENT_ID,
  EVENT_TYPE,
  EVENT_VERSION,
  EVENT_TIME,
  INGESTED_AT,
  SOURCE_SYSTEM,
  TENANT_ID,
  MESSAGE_ID,
  CORRELATION_ID,
  TRACE_ID,
  ACTOR_TYPE,
  PAYLOAD,
  EVENT_TS,
  INGESTED_TS,
  EVENT_DATE
)
with base as (
  select
    seq4() as n,
    dateadd(
      second,
      uniform(0, 45 * 24 * 60 * 60, random()),
      dateadd(day, -45, current_timestamp())
    ) as event_ts
  from table(generator(rowcount => 12000))
),
shaped as (
  select
    n,
    event_ts,
    'tenant-' || lpad(to_varchar(1 + mod(n, 80)), 3, '0') as tenant_id,
    'msg-' || lpad(to_varchar(1 + mod(n, 3000)), 6, '0') as message_id,
    case mod(n, 5)
      when 0 then 'mail.requested'
      when 1 then 'mail.dispatched'
      when 2 then 'mail.delivered'
      when 3 then 'mail.opened'
      else 'mail.clicked'
    end as event_type,
    case mod(n, 12)
      when 0 then 'cmp-spring-promo'
      when 1 then 'cmp-retention-wave'
      when 2 then 'cmp-reactivation'
      when 3 then 'cmp-newsletter'
      when 4 then 'cmp-onboarding'
      when 5 then 'cmp-transactional'
      when 6 then 'cmp-upgrade-offer'
      when 7 then 'cmp-loyalty-points'
      when 8 then 'cmp-digest-weekly'
      when 9 then 'cmp-feature-launch'
      when 10 then 'cmp-cart-recovery'
      else 'cmp-survey-followup'
    end as campaign_id,
    case mod(n, 8)
      when 0 then 'tpl-welcome-a'
      when 1 then 'tpl-welcome-b'
      when 2 then 'tpl-reengage-a'
      when 3 then 'tpl-reengage-b'
      when 4 then 'tpl-digest-a'
      when 5 then 'tpl-digest-b'
      when 6 then 'tpl-upgrade-a'
      else 'tpl-upgrade-b'
    end as template_id,
    case mod(n, 4)
      when 0 then 'sendgrid'
      when 1 then 'ses'
      when 2 then 'mailgun'
      else 'postmark'
    end as provider
  from base
)
select
  'evt-' || lpad(to_varchar(n + 1), 8, '0') as event_id,
  event_type,
  '1.0.0' as event_version,
  to_varchar(event_ts, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as event_time,
  to_varchar(dateadd(second, 20, event_ts), 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as ingested_at,
  'mail.pipeline.synthetic' as source_system,
  tenant_id,
  message_id,
  'corr-' || message_id as correlation_id,
  'trace-' || lpad(to_varchar(n + 1), 8, '0') as trace_id,
  'service' as actor_type,
  object_construct(
    'campaign_id', campaign_id,
    'campaign_name', initcap(replace(campaign_id, '-', ' ')),
    'template_id', template_id,
    'template_name', initcap(replace(template_id, '-', ' ')),
    'template_channel', 'email',
    'provider', provider,
    'status', split_part(event_type, '.', 2)
  )::string as payload,
  event_ts,
  dateadd(second, 20, event_ts) as ingested_ts,
  to_date(event_ts) as event_date
from shaped;

insert into DIM_CUSTOMER_TENANT (
  TENANT_ID,
  FIRST_SEEN_AT,
  LAST_SEEN_AT,
  TOTAL_EVENTS
)
select
  TENANT_ID,
  min(EVENT_TS),
  max(EVENT_TS),
  count(*)
from TABLEAU_REPORTING_EVENTS
group by TENANT_ID;

insert into DIM_CUSTOMER_EVENT_TYPE (
  EVENT_TYPE,
  FIRST_SEEN_AT,
  LAST_SEEN_AT,
  TOTAL_EVENTS
)
select
  EVENT_TYPE,
  min(EVENT_TS),
  max(EVENT_TS),
  count(*)
from TABLEAU_REPORTING_EVENTS
group by EVENT_TYPE;

insert into FCT_TABLEAU_DAILY_CUSTOMER_DELIVERY (
  TENANT_ID,
  EVENT_DATE,
  REQUESTED_COUNT,
  DISPATCHED_COUNT,
  DELIVERED_COUNT,
  OPENED_COUNT,
  CLICKED_COUNT
)
select
  TENANT_ID,
  EVENT_DATE,
  sum(case when EVENT_TYPE = 'mail.requested' then 1 else 0 end),
  sum(case when EVENT_TYPE = 'mail.dispatched' then 1 else 0 end),
  sum(case when EVENT_TYPE = 'mail.delivered' then 1 else 0 end),
  sum(case when EVENT_TYPE = 'mail.opened' then 1 else 0 end),
  sum(case when EVENT_TYPE = 'mail.clicked' then 1 else 0 end)
from TABLEAU_REPORTING_EVENTS
group by TENANT_ID, EVENT_DATE;

commit;

-- Quick sanity checks (optional):
-- select count(*) as events from TABLEAU_REPORTING_EVENTS;
-- select count(*) as tenants from DIM_CUSTOMER_TENANT;
-- select count(*) as event_types from DIM_CUSTOMER_EVENT_TYPE;
-- select count(*) as fact_rows from FCT_TABLEAU_DAILY_CUSTOMER_DELIVERY;
