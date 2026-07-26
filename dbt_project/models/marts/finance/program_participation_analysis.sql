{{ config(materialized='table') }}

with participation_data as (
    select
        sem.quarter_id,
        sem.quarter_name,
        sem.academic_year,
        sem.quarter_type,
        d.department_id,
        d.department_name,
        d.budget as department_budget,
        count(distinct e.student_id) as enrolled_students,
        count(distinct e.enrollment_id) as total_enrollments,
        count(distinct ea.student_id) as students_in_activities,
        sum(ea.hours_per_week) as total_activity_hours,
        round(avg(ar.attendance_percentage), 2) as avg_attendance_rate,
        count(distinct f.faculty_id) as staff_count,
        count(distinct c.course_id) as course_count
    from {{ ref('stg_quarters') }} sem
    left join {{ ref('stg_enrollments') }} e on sem.quarter_id = e.quarter_id
    left join {{ ref('stg_courses') }} c on e.course_id = c.course_id
    left join {{ ref('stg_departments') }} d on c.department_id = d.department_id
    left join {{ ref('stg_extracurricular_activities') }} ea on e.student_id = ea.student_id
    left join {{ ref('stg_attendance_records') }} ar on e.student_id = ar.student_id and sem.quarter_id = ar.quarter_id
    left join {{ ref('stg_class_sessions') }} cs on c.course_id = cs.course_id and sem.quarter_id = cs.quarter_id
    left join {{ ref('stg_teachers') }} f on cs.faculty_id = f.faculty_id
    group by
        sem.quarter_id, sem.quarter_name, sem.academic_year, sem.quarter_type,
        d.department_id, d.department_name, d.budget
),

engagement_metrics as (
    select
        pd.*,
        round(
            students_in_activities * 100.0 / nullif(enrolled_students, 0), 2
        ) as activity_participation_rate,
        round(total_activity_hours / nullif(students_in_activities, 0), 2) as avg_hours_per_active_student,
        round(total_enrollments::numeric / nullif(staff_count, 0), 2) as student_teacher_ratio,
        round(total_enrollments::numeric / nullif(course_count, 0), 2) as avg_class_size,
        case
            when avg_attendance_rate >= 95 then 'Excellent Attendance'
            when avg_attendance_rate >= 90 then 'Good Attendance'
            when avg_attendance_rate >= 85 then 'Average Attendance'
            else 'Below Average Attendance'
        end as attendance_tier,
        case
            when round(total_enrollments::numeric / nullif(staff_count, 0), 2) > 25 then 'High Student Load'
            when round(total_enrollments::numeric / nullif(staff_count, 0), 2) < 10 then 'Low Student Load'
            else 'Optimal Load'
        end as staffing_assessment
    from participation_data pd
),

strategic_insights as (
    select
        em.*,
        case
            when activity_participation_rate >= 70 then 'High Engagement Program'
            when activity_participation_rate >= 50 then 'Moderate Engagement Program'
            when activity_participation_rate >= 30 then 'Low Engagement Program'
            else 'Disengaged Program'
        end as engagement_category,
        case
            when avg_attendance_rate >= 95 and activity_participation_rate >= 60 then 'Thriving'
            when avg_attendance_rate >= 90 and activity_participation_rate >= 40 then 'Performing Well'
            when avg_attendance_rate >= 85 or activity_participation_rate >= 30 then 'Needs Attention'
            else 'Intervention Required'
        end as program_health_status,
        case
            when avg_attendance_rate < 85 and activity_participation_rate < 30 then
                'Focus on student engagement and attendance improvement'
            when staffing_assessment = 'High Student Load' then
                'Consider adding instructional staff or reducing class sizes'
            when activity_participation_rate < 30 then
                'Expand extracurricular offerings to boost engagement'
            when avg_attendance_rate < 90 then
                'Implement attendance intervention strategies'
            else 'Maintain current program with minor optimizations'
        end as primary_recommendation
    from engagement_metrics em
)

select * from strategic_insights
order by program_health_status, department_name
