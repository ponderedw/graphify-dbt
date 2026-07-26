{{ config(materialized='view') }}

with source_data as (
    select
        activity_id,
        student_id,
        activity_name,
        activity_type,
        hours_per_week,
        academic_year,
        start_date,
        case
            when activity_type ilike '%sport%' then 'Athletics'
            when activity_type ilike '%art%' or activity_type ilike '%music%' or activity_type ilike '%theater%' then 'Arts'
            when activity_type ilike '%academic%' or activity_type ilike '%debate%' or activity_type ilike '%math%' then 'Academic'
            when activity_type ilike '%volunteer%' or activity_type ilike '%service%' then 'Community Service'
            else 'General Club'
        end as activity_category,
        case
            when hours_per_week >= 10 then 'High Commitment'
            when hours_per_week >= 5 then 'Moderate Commitment'
            when hours_per_week >= 2 then 'Low Commitment'
            else 'Minimal Commitment'
        end as commitment_level,
        extract(year from start_date) as start_year,
        created_at
    from {{ source('raw_edu', 'extracurricular_activities') }}
)

select * from source_data
