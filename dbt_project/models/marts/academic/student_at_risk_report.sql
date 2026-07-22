{{ config(materialized='table') }}

select
    student_id,
    full_name,
    email,
    gpa,
    academic_standing,
    department_name,
    years_enrolled,
    total_enrollments,
    failed_courses_count,
    withdrawn_courses_count,
    avg_attendance,
    total_risk_score,
    risk_level,
    primary_risk_category,
    recommended_intervention,
    low_attendance_flag,
    academic_probation_flag,
    multiple_failures_flag,
    excessive_withdrawals_flag,
    payment_issues_flag,
    slow_progress_flag,
    financial_stress_flag
from {{ ref('int_student_at_risk_indicators') }}
where risk_level != 'Low Risk'
order by total_risk_score desc, gpa asc
