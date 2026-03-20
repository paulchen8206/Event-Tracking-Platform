{{ config(materialized='view') }}

select
    cast(null as varchar) as provider_id,
    cast(null as varchar) as provider_name,
    cast(null as varchar) as provider_type,
    cast(null as varchar) as provider_region
where 1 = 0