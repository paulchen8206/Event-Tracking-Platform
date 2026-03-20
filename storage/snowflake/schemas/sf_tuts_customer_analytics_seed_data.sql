-- Seed sample customer analytics data into Snowflake source tables.
-- Target: SF_TUTS.ICEBERG_CUSTOMER_ANALYTICS

use role ACCOUNTADMIN;
use warehouse COMPUTE_WH;
use database SF_TUTS;
use schema ICEBERG_CUSTOMER_ANALYTICS;

begin;

-- Reset sample tables so the script is idempotent for local development.
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
select
  column1,
  column2,
  '1.0.0',
  to_varchar(column3, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  to_varchar(column3 + interval '1 minute', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  'mail.pipeline',
  column4,
  column5,
  'corr-' || column5,
  'trace-' || column5,
  'service',
  parse_json(column6)::string,
  column3,
  column3 + interval '1 minute',
  to_date(column3)
from values
  ('evt-1001', 'mail.requested',  to_timestamp_ntz('2026-03-20 09:00:00'), 'tenant-1', 'msg-1001', '{"campaign_id":"cmp-spring","campaign_name":"Spring Promo","template_id":"tpl-a","template_name":"Welcome A","template_channel":"email","provider":"sendgrid","status":"requested"}'),
  ('evt-1002', 'mail.delivered',  to_timestamp_ntz('2026-03-20 09:05:00'), 'tenant-1', 'msg-1001', '{"campaign_id":"cmp-spring","campaign_name":"Spring Promo","template_id":"tpl-a","template_name":"Welcome A","template_channel":"email","provider":"sendgrid","status":"delivered"}'),
  ('evt-1003', 'mail.opened',     to_timestamp_ntz('2026-03-20 09:10:00'), 'tenant-1', 'msg-1001', '{"campaign_id":"cmp-spring","campaign_name":"Spring Promo","template_id":"tpl-a","template_name":"Welcome A","template_channel":"email","provider":"sendgrid","status":"opened"}'),
  ('evt-2001', 'mail.requested',  to_timestamp_ntz('2026-03-20 10:00:00'), 'tenant-2', 'msg-2001', '{"campaign_id":"cmp-retain","campaign_name":"Retention Flow","template_id":"tpl-b","template_name":"Retention B","template_channel":"email","provider":"ses","status":"requested"}'),
  ('evt-2002', 'mail.delivered',  to_timestamp_ntz('2026-03-20 10:07:00'), 'tenant-2', 'msg-2001', '{"campaign_id":"cmp-retain","campaign_name":"Retention Flow","template_id":"tpl-b","template_name":"Retention B","template_channel":"email","provider":"ses","status":"delivered"}'),
  ('evt-2003', 'mail.clicked',    to_timestamp_ntz('2026-03-20 10:12:00'), 'tenant-2', 'msg-2001', '{"campaign_id":"cmp-retain","campaign_name":"Retention Flow","template_id":"tpl-b","template_name":"Retention B","template_channel":"email","provider":"ses","status":"clicked"}');

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
