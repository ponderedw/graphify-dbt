{{ config(materialized='table') }}

with institutional_metrics as (
    select
        sem.quarter_id,
        sem.quarter_name,
        sem.academic_year,
        sem.quarter_type,
        -- Enrollment metrics
        count(distinct e.student_id) as unique_students_enrolled,
        count(distinct e.enrollment_id) as total_course_enrollments,
        count(distinct e.course_id) as unique_courses_offered,
        count(distinct c.department_id) as departments_active,
        count(distinct f.faculty_id) as faculty_teaching,
        
        -- Academic performance metrics
        avg(e.grade_points) as institutional_avg_gpa,
        avg(e.attendance_percentage) as institutional_avg_attendance,
        count(case when e.grade_category = 'Excellent' then 1 end) as excellent_grades,
        count(case when e.grade_category in ('Excellent', 'Good', 'Satisfactory') then 1 end) as passing_grades,
        round(
            count(case when e.grade_category in ('Excellent', 'Good', 'Satisfactory') then 1 end) * 100.0 / 
            nullif(count(case when e.grade_category != 'Unknown' then 1 end), 0), 2
        ) as institutional_pass_rate,
        
        -- Student success indicators
        count(case when s.academic_standing = 'Dean''s List' then 1 end) as deans_list_students,
        count(case when s.academic_standing = 'Academic Probation' then 1 end) as students_on_probation,
        count(case when s.student_status = 'graduated' then 1 end) as graduates_this_period,
        
        -- Attendance and engagement metrics
        round(avg(ar.attendance_percentage), 2) as avg_student_attendance_rate,
        count(distinct ea.student_id) as students_in_activities,
        sum(f.salary) as total_faculty_compensation,

        -- Operational efficiency
        round(count(distinct e.enrollment_id)::numeric / nullif(count(distinct f.faculty_id), 0), 2) as enrollments_per_faculty,
        round(count(distinct e.student_id)::numeric / nullif(count(distinct f.faculty_id), 0), 2) as students_per_faculty,
        round(
            count(distinct ea.student_id) * 100.0 / nullif(count(distinct e.student_id), 0), 2
        ) as activity_participation_rate
    from {{ ref('stg_quarters') }} sem
    left join {{ ref('stg_enrollments') }} e on sem.quarter_id = e.quarter_id
    left join {{ ref('stg_courses') }} c on e.course_id = c.course_id
    left join {{ ref('stg_students') }} s on e.student_id = s.student_id
    left join {{ ref('stg_class_sessions') }} cs on c.course_id = cs.course_id and sem.quarter_id = cs.quarter_id
    left join {{ ref('stg_faculty') }} f on cs.faculty_id = f.faculty_id
    left join {{ ref('stg_attendance_records') }} ar on s.student_id = ar.student_id and sem.quarter_id = ar.quarter_id
    left join {{ ref('stg_extracurricular_activities') }} ea on s.student_id = ea.student_id
    group by sem.quarter_id, sem.quarter_name, sem.academic_year, sem.quarter_type
),

performance_trends as (
    select
        im.*,
        lag(institutional_avg_gpa) over (order by quarter_id) as prev_quarter_gpa,
        lag(institutional_pass_rate) over (order by quarter_id) as prev_quarter_pass_rate,
        lag(unique_students_enrolled) over (order by quarter_id) as prev_quarter_enrollment,
        lag(avg_student_attendance_rate) over (order by quarter_id) as prev_quarter_attendance,

        -- Calculate trends
        institutional_avg_gpa - lag(institutional_avg_gpa) over (order by quarter_id) as gpa_trend,
        institutional_pass_rate - lag(institutional_pass_rate) over (order by quarter_id) as pass_rate_trend,
        unique_students_enrolled - lag(unique_students_enrolled) over (order by quarter_id) as enrollment_trend,
        avg_student_attendance_rate - lag(avg_student_attendance_rate) over (order by quarter_id) as attendance_trend,

        -- Calculate percentile rankings
        percent_rank() over (order by institutional_avg_gpa) as gpa_percentile,
        percent_rank() over (order by institutional_pass_rate) as pass_rate_percentile,
        percent_rank() over (order by unique_students_enrolled) as enrollment_percentile,
        percent_rank() over (order by avg_student_attendance_rate) as attendance_efficiency_percentile
    from institutional_metrics im
),

effectiveness_scoring as (
    select
        pt.*,
        -- Academic effectiveness score (0-100)
        round(
            (case when institutional_avg_gpa >= 3.0 then 25
                  when institutional_avg_gpa >= 2.5 then 20
                  when institutional_avg_gpa >= 2.0 then 15
                  else 10 end) +
            (case when institutional_pass_rate >= 85 then 25
                  when institutional_pass_rate >= 75 then 20
                  when institutional_pass_rate >= 65 then 15
                  else 10 end) +
            (case when institutional_avg_attendance >= 90 then 25
                  when institutional_avg_attendance >= 80 then 20
                  when institutional_avg_attendance >= 70 then 15
                  else 10 end) +
            (case when (deans_list_students::numeric / nullif(unique_students_enrolled, 0)) >= 0.15 then 25
                  when (deans_list_students::numeric / nullif(unique_students_enrolled, 0)) >= 0.10 then 20
                  when (deans_list_students::numeric / nullif(unique_students_enrolled, 0)) >= 0.05 then 15
                  else 10 end), 0
        ) as academic_effectiveness_score,
        
        -- Operational efficiency score (0-100)
        round(
            (case when students_per_faculty between 15 and 25 then 30
                  when students_per_faculty between 10 and 30 then 25
                  when students_per_faculty between 8 and 35 then 20
                  else 15 end) +
            (case when activity_participation_rate >= 60 then 25
                  when activity_participation_rate >= 40 then 20
                  when activity_participation_rate >= 20 then 15
                  else 10 end) +
            (case when avg_student_attendance_rate >= 95 then 25
                  when avg_student_attendance_rate >= 90 then 20
                  when avg_student_attendance_rate >= 80 then 15
                  else 10 end) +
            (case when (students_on_probation::numeric / nullif(unique_students_enrolled, 0)) <= 0.05 then 20
                  when (students_on_probation::numeric / nullif(unique_students_enrolled, 0)) <= 0.10 then 15
                  when (students_on_probation::numeric / nullif(unique_students_enrolled, 0)) <= 0.15 then 10
                  else 5 end), 0
        ) as operational_efficiency_score,

        -- Engagement health score (0-100)
        round(
            (case when avg_student_attendance_rate >= 95 then 40
                  when avg_student_attendance_rate >= 90 then 30
                  when avg_student_attendance_rate >= 80 then 20
                  else 10 end) +
            (case when attendance_trend > 0 then 30
                  when attendance_trend = 0 then 20
                  else 10 end) +
            (case when activity_participation_rate >= 60 then 30
                  when activity_participation_rate >= 40 then 20
                  else 10 end), 0
        ) as engagement_health_score
    from performance_trends pt
),

comparative_analysis as (
    select
        es.*,
        -- Overall institutional effectiveness (weighted average)
        round(
            (academic_effectiveness_score * 0.4) + 
            (operational_efficiency_score * 0.3) + 
            (engagement_health_score * 0.3), 1
        ) as overall_effectiveness_score,
        
        -- Trend categories
        case
            when gpa_trend > 0.1 then 'Improving Academic Performance'
            when gpa_trend < -0.1 then 'Declining Academic Performance'
            else 'Stable Academic Performance'
        end as academic_trend_category,
        
        case
            when enrollment_trend > 50 then 'Growing Enrollment'
            when enrollment_trend < -50 then 'Declining Enrollment'
            else 'Stable Enrollment'
        end as enrollment_trend_category,
        
        case
            when attendance_trend > 2 then 'Improving Attendance'
            when attendance_trend < -2 then 'Declining Attendance'
            else 'Stable Attendance'
        end as financial_trend_category,
        
        -- Performance categories
        case
            when academic_effectiveness_score >= 80 then 'High Academic Performance'
            when academic_effectiveness_score >= 65 then 'Good Academic Performance'
            when academic_effectiveness_score >= 50 then 'Fair Academic Performance'
            else 'Poor Academic Performance'
        end as academic_performance_category,
        
        case
            when operational_efficiency_score >= 80 then 'Highly Efficient'
            when operational_efficiency_score >= 65 then 'Efficient'
            when operational_efficiency_score >= 50 then 'Moderately Efficient'
            else 'Inefficient'
        end as operational_efficiency_category,
        
        case
            when engagement_health_score >= 80 then 'Excellent Engagement Health'
            when engagement_health_score >= 65 then 'Good Engagement Health'
            when engagement_health_score >= 50 then 'Fair Engagement Health'
            else 'Poor Engagement Health'
        end as engagement_health_category
    from effectiveness_scoring es
),

strategic_recommendations as (
    select
        ca.*,
        case
            when overall_effectiveness_score >= 80 then 'Maintain excellence and consider expansion opportunities'
            when academic_effectiveness_score < 50 then 'Focus on academic support and faculty development'
            when operational_efficiency_score < 50 then 'Review operational processes and resource allocation'
            when engagement_health_score < 50 then 'Address student engagement and attendance improvement strategies'
            when enrollment_trend_category = 'Declining Enrollment' then 'Implement enrollment growth strategies'
            else 'Continue current strategies with minor improvements'
        end as primary_strategic_recommendation,
        
        case
            when academic_trend_category = 'Declining Academic Performance' and
                 operational_efficiency_category = 'Inefficient' then 'High Priority Action Required'
            when engagement_health_category = 'Poor Engagement Health' and
                 enrollment_trend_category = 'Declining Enrollment' then 'Critical Intervention Needed'
            when overall_effectiveness_score < 60 then 'Moderate Intervention Required'
            else 'Standard Monitoring'
        end as intervention_priority,
        
        -- Key performance indicators status
        case
            when institutional_pass_rate >= 80 and
                 students_per_faculty between 15 and 25 and
                 avg_student_attendance_rate >= 90 then 'All KPIs Met'
            when institutional_pass_rate < 70 or students_per_faculty > 30 or avg_student_attendance_rate < 80 then 'Critical KPIs Not Met'
            else 'Some KPIs Need Attention'
        end as kpi_status
    from comparative_analysis ca
)

select * from strategic_recommendations
order by quarter_id desc