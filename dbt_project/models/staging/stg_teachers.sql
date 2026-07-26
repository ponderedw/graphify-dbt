{{ config(materialized='view') }}

with source_data as (
    select
        faculty_id,
        first_name,
        last_name,
        first_name || ' ' || last_name as full_name,
        email,
        department_id,
        position,
        salary,
        hire_date,
        office_number,
        research_interests as teaching_specialties,
        extract(year from age(current_date, hire_date)) as years_of_service,
        case
            when position = 'Department Head' then 4
            when position = 'Senior Teacher' then 3
            when position = 'Teacher' then 2
            when position = 'Substitute' then 1
            else 0
        end as rank_level,
        case
            when salary >= 80000 then 'Senior'
            when salary >= 65000 then 'Mid-level'
            when salary >= 50000 then 'Junior'
            else 'Entry'
        end as salary_band,
        created_at
    from {{ source('raw_edu', 'faculty') }}
)

select * from source_data