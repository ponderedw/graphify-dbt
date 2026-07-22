{{ config(materialized='table') }}

select
    course_id,
    course_code,
    course_name,
    credits,
    difficulty_level,
    difficulty_description,
    department_name,
    department_code,
    total_enrollments,
    unique_students,
    semesters_offered,
    round(avg_grade_points::numeric, 2)  as avg_grade_points,
    round(avg_attendance::numeric, 1)    as avg_attendance_pct,
    excellent_grades,
    good_grades,
    satisfactory_grades,
    poor_grades,
    failing_grades,
    withdrawals,
    pass_rate,
    withdrawal_rate,
    case
        when pass_rate >= 90 then 'High Performing'
        when pass_rate >= 75 then 'Good Performing'
        when pass_rate >= 60 then 'Average Performing'
        else 'Needs Improvement'
    end as course_performance_category
from {{ ref('int_course_performance_metrics') }}
order by total_enrollments desc
