{{ config(materialized='view') }}

with source_data as (
    select
        attendance_id,
        student_id,
        quarter_id,
        attendance_percentage,
        excused_absences,
        unexcused_absences,
        tardies,
        excused_absences + unexcused_absences as total_absences,
        case
            when attendance_percentage >= 95 then 'Excellent'
            when attendance_percentage >= 90 then 'Good'
            when attendance_percentage >= 80 then 'Fair'
            when attendance_percentage >= 70 then 'Poor'
            else 'Critical'
        end as attendance_status,
        case
            when unexcused_absences = 0 then 'No Unexcused Absences'
            when unexcused_absences <= 2 then 'Minimal Unexcused'
            when unexcused_absences <= 5 then 'Moderate Unexcused'
            else 'Chronic Unexcused'
        end as unexcused_category,
        case
            when tardies = 0 then 'No Tardies'
            when tardies <= 3 then 'Minimal Tardies'
            when tardies <= 8 then 'Moderate Tardies'
            else 'Chronic Tardies'
        end as tardy_category,
        created_at
    from {{ source('raw_edu', 'attendance_records') }}
)

select * from source_data
