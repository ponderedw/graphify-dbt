{{ config(materialized='table') }}

select
    department_id,
    department_name,
    department_code,
    building_location,
    budget_millions,
    department_size,
    faculty_count,
    course_count,
    student_count,
    total_enrollments,
    avg_faculty_salary,
    avg_student_gpa,
    budget_per_faculty,
    budget_per_student,
    salary_cost_percentage,
    student_faculty_ratio,
    courses_per_faculty,
    avg_enrollment_per_course,
    department_scale,
    ratio_category
from {{ ref('int_department_analytics') }}
