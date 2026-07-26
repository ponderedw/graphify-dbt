{{ config(materialized='view') }}

with department_data as (
    select
        d.department_id,
        d.department_name,
        d.department_code,
        d.budget,
        d.budget_millions,
        d.department_size,
        d.building_location,
        count(distinct f.faculty_id) as staff_count,
        count(distinct c.course_id) as course_count,
        count(distinct s.student_id) as student_count,
        count(distinct e.enrollment_id) as total_enrollments,
        avg(f.salary) as avg_teacher_salary,
        sum(f.salary) as total_teacher_salary_cost,
        avg(s.gpa) as avg_student_gpa,
        sum(c.credits) as total_credit_hours_offered,
        count(case when f.position = 'Department Head' then 1 end) as dept_head_count,
        count(case when f.position = 'Senior Teacher' then 1 end) as senior_teacher_count,
        count(case when f.position = 'Teacher' then 1 end) as teacher_count,
        avg(c.difficulty_level) as avg_course_difficulty
    from {{ ref('stg_departments') }} d
    left join {{ ref('stg_teachers') }} f on d.department_id = f.department_id
    left join {{ ref('stg_courses') }} c on d.department_id = c.department_id
    left join {{ ref('stg_students') }} s on d.department_id = s.major_id
    left join {{ ref('stg_enrollments') }} e on c.course_id = e.course_id
    group by 
        d.department_id, d.department_name, d.department_code, d.budget, 
        d.budget_millions, d.department_size, d.building_location
),

department_metrics as (
    select
        *,
        round(budget / nullif(staff_count, 0), 2) as budget_per_teacher,
        round(budget / nullif(student_count, 0), 2) as budget_per_student,
        round(total_teacher_salary_cost / nullif(budget, 0) * 100, 2) as salary_cost_percentage,
        round(student_count::numeric / nullif(staff_count, 0), 2) as student_teacher_ratio,
        round(course_count::numeric / nullif(staff_count, 0), 2) as courses_per_teacher,
        round(total_enrollments::numeric / nullif(course_count, 0), 2) as avg_enrollment_per_course,
        case
            when student_count > 500 then 'Large Department'
            when student_count > 200 then 'Medium Department'
            when student_count > 50 then 'Small Department'
            else 'Very Small Department'
        end as department_scale,
        case
            when student_count::numeric / nullif(staff_count, 0) > 30 then 'High Student-Teacher Ratio'
            when student_count::numeric / nullif(staff_count, 0) > 20 then 'Moderate Student-Teacher Ratio'
            when student_count::numeric / nullif(staff_count, 0) > 10 then 'Low Student-Teacher Ratio'
            else 'Very Low Student-Teacher Ratio'
        end as ratio_category
    from department_data
)

select * from department_metrics