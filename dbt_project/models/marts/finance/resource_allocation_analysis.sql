{{ config(materialized='table') }}

with departmental_data as (
    select
        d.department_id,
        d.department_name,
        d.department_code,
        d.budget as allocated_budget,
        d.budget_millions,
        d.department_size,
        count(distinct f.faculty_id) as staff_count,
        count(distinct s.student_id) as student_count,
        count(distinct c.course_id) as course_offerings,
        sum(f.salary) as total_teacher_salaries,
        avg(f.salary) as avg_teacher_salary,
        count(distinct e.enrollment_id) as total_enrollments,
        avg(e.grade_points) as dept_avg_gpa,
        count(case when s.student_status = 'graduated' then 1 end) as graduates_produced,
        round(avg(e.attendance_percentage), 2) as dept_avg_attendance,
        count(distinct ea.student_id) as students_with_activities,
        round(avg(ar.attendance_percentage), 2) as dept_avg_attendance_record
    from {{ ref('stg_departments') }} d
    left join {{ ref('stg_teachers') }} f on d.department_id = f.department_id
    left join {{ ref('stg_courses') }} c on d.department_id = c.department_id
    left join {{ ref('stg_students') }} s on d.department_id = s.major_id
    left join {{ ref('stg_enrollments') }} e on c.course_id = e.course_id and s.student_id = e.student_id
    left join {{ ref('stg_extracurricular_activities') }} ea on s.student_id = ea.student_id
    left join {{ ref('stg_attendance_records') }} ar on s.student_id = ar.student_id
    group by
        d.department_id, d.department_name, d.department_code, d.budget,
        d.budget_millions, d.department_size
),

efficiency_analysis as (
    select
        dd.*,
        round(allocated_budget / nullif(student_count, 0), 2) as cost_per_student,
        round(allocated_budget / nullif(staff_count, 0), 2) as cost_per_teacher,
        round(allocated_budget / nullif(graduates_produced, 0), 2) as cost_per_graduate,
        round(allocated_budget / nullif(total_enrollments, 0), 2) as cost_per_enrollment,
        round(total_teacher_salaries / nullif(allocated_budget, 0) * 100, 2) as teacher_cost_percentage,
        round(student_count / nullif(staff_count, 0), 2) as student_teacher_ratio,
        round(total_enrollments / nullif(course_offerings, 0), 2) as avg_class_size,
        round(students_with_activities * 100.0 / nullif(student_count, 0), 2) as activity_participation_rate,
        round(graduates_produced / nullif(allocated_budget, 0) * 100000, 2) as graduates_per_100k_budget,
        round(dept_avg_gpa * total_enrollments / nullif(allocated_budget, 0) * 10000, 2) as quality_weighted_output
    from departmental_data dd
),

performance_benchmarking as (
    select
        ea.*,
        percent_rank() over (order by cost_per_graduate) as cost_effectiveness_percentile,
        percent_rank() over (order by quality_weighted_output desc) as quality_output_percentile,
        percent_rank() over (order by graduates_per_100k_budget desc) as graduate_productivity_percentile,
        percent_rank() over (order by activity_participation_rate desc) as engagement_percentile,
        avg(cost_per_student) over () as institutional_avg_cost_per_student,
        avg(dept_avg_gpa) over () as institutional_avg_gpa,
        avg(student_teacher_ratio) over () as institutional_avg_ratio,
        case
            when cost_per_graduate <= 50000 then 'Highly Cost Effective'
            when cost_per_graduate <= 100000 then 'Cost Effective'
            when cost_per_graduate <= 200000 then 'Moderately Cost Effective'
            else 'Costly'
        end as cost_effectiveness_category,
        case
            when quality_weighted_output >= 50 then 'High Quality Output'
            when quality_weighted_output >= 30 then 'Good Quality Output'
            when quality_weighted_output >= 20 then 'Adequate Quality Output'
            else 'Low Quality Output'
        end as quality_output_category,
        case
            when activity_participation_rate >= 70 then 'High Engagement'
            when activity_participation_rate >= 50 then 'Moderate Engagement'
            when activity_participation_rate >= 30 then 'Low Engagement'
            else 'Disengaged'
        end as engagement_category
    from efficiency_analysis ea
),

optimization_scores as (
    select
        pb.*,
        round(
            (case when cost_effectiveness_percentile >= 0.8 then 25
                  when cost_effectiveness_percentile >= 0.6 then 20
                  when cost_effectiveness_percentile >= 0.4 then 15
                  else 10 end) +
            (case when quality_output_percentile >= 0.8 then 25
                  when quality_output_percentile >= 0.6 then 20
                  when quality_output_percentile >= 0.4 then 15
                  else 10 end) +
            (case when graduate_productivity_percentile >= 0.8 then 25
                  when graduate_productivity_percentile >= 0.6 then 20
                  when graduate_productivity_percentile >= 0.4 then 15
                  else 10 end) +
            (case when engagement_percentile >= 0.8 then 25
                  when engagement_percentile >= 0.6 then 20
                  when engagement_percentile >= 0.4 then 15
                  else 10 end), 0
        ) as resource_optimization_score,
        case
            when cost_per_graduate > 150000 and dept_avg_gpa < 3.0 then 'Improve academic support for better retention'
            when teacher_cost_percentage > 80 then 'Review faculty compensation structure'
            when student_count < 100 and allocated_budget > 1000000 then 'Consider program consolidation or growth'
            when activity_participation_rate < 30 then 'Expand extracurricular programs to improve engagement'
            when student_teacher_ratio < 12 then 'Consider course consolidation or increased teaching load'
            when quality_weighted_output > 50 then 'Model department — consider expansion'
            else 'Minor optimizations recommended'
        end as primary_optimization_recommendation,
        case
            when cost_effectiveness_category = 'Highly Cost Effective' and quality_output_category = 'High Quality Output' then 'Strategic Growth Investment'
            when cost_effectiveness_category = 'Costly' and quality_output_category = 'Low Quality Output' then 'Restructuring Priority'
            when quality_output_category = 'Low Quality Output' and student_count > 200 then 'Quality Improvement Priority'
            when student_count < 50 then 'Viability Assessment Required'
            else 'Efficiency Optimization'
        end as strategic_priority
    from performance_benchmarking pb
),

optimization_opportunities as (
    select
        *,
        case
            when resource_optimization_score >= 80 then round(allocated_budget * 1.1, 0)
            when resource_optimization_score >= 60 then allocated_budget
            when resource_optimization_score >= 40 then round(allocated_budget * 0.95, 0)
            else round(allocated_budget * 0.85, 0)
        end as suggested_budget_allocation
    from optimization_scores
)

select
    oo.*,
    oo.suggested_budget_allocation - oo.allocated_budget as budget_change_amount,
    round(
        (oo.suggested_budget_allocation - oo.allocated_budget) / nullif(oo.allocated_budget, 0) * 100, 2
    ) as budget_change_percentage
from optimization_opportunities oo
order by resource_optimization_score desc, strategic_priority
