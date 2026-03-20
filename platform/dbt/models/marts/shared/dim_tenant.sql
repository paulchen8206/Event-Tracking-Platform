{{ config(materialized='view') }}

select
    cast(null as varchar) as tenant_id,
    cast(null as varchar) as tenant_name,
    cast(null as varchar) as tenant_tier,
    cast(null as timestamp_ntz) as tenant_created_at
where 1 = 0