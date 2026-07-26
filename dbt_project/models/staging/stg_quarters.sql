{{ config(materialized='view') }}

with source_data as (
    select
        quarter_id,
        quarter_name,
        academic_year,
        start_date,
        end_date,
        is_current,
        extract(year from start_date) as start_year,
        extract(month from start_date) as start_month,
        case
            when extract(month from start_date) between 8 and 12 then 'Fall'
            when extract(month from start_date) between 1 and 5 then 'Spring'
            when extract(month from start_date) between 6 and 7 then 'Summer'
            else 'Special'
        end as quarter_type,
        end_date - start_date as quarter_duration_days,
        case
            when current_date between start_date and end_date then 'Active'
            when current_date < start_date then 'Upcoming'
            when current_date > end_date then 'Completed'
            else 'Unknown'
        end as quarter_status,
        created_at
    from {{ source('raw_edu', 'quarters') }}
)

select * from source_data