{{ config(materialized='table') }}

with activity_impact as (
    select
        s.student_id,
        s.full_name,
        s.gpa,
        s.academic_standing,
        s.student_status,
        s.years_enrolled,
        d.department_name,
        d.department_code,
        ea.activity_name,
        ea.activity_category,
        ea.hours_per_week,
        ea.commitment_level,
        ea.academic_year,
        eh.total_enrollments,
        eh.total_credits_earned,
        eh.avg_grade_points,
        eh.failed_courses_count,
        eh.withdrawn_courses_count,
        case when ea.student_id is not null then 1 else 0 end as participates_in_activities
    from {{ ref('stg_extracurricular_activities') }} ea
    right join {{ ref('stg_students') }} s on ea.student_id = s.student_id
    left join {{ ref('stg_departments') }} d on s.major_id = d.department_id
    left join (
        select
            student_id,
            max(total_enrollments) as total_enrollments,
            max(total_credits_earned) as total_credits_earned,
            max(avg_grade_points) as avg_grade_points,
            max(failed_courses_count) as failed_courses_count,
            max(withdrawn_courses_count) as withdrawn_courses_count
        from {{ ref('int_student_enrollment_history') }}
        group by student_id
    ) eh on s.student_id = eh.student_id
),

activity_summary as (
    select
        student_id,
        full_name,
        gpa,
        academic_standing,
        student_status,
        years_enrolled,
        department_name,
        department_code,
        total_enrollments,
        total_credits_earned,
        avg_grade_points,
        failed_courses_count,
        withdrawn_courses_count,
        count(case when participates_in_activities = 1 then 1 end) as total_activities,
        sum(case when participates_in_activities = 1 then hours_per_week else 0 end) as total_activity_hours,
        max(case when activity_category = 'Athletics' then hours_per_week else 0 end) as athletics_hours,
        max(case when activity_category = 'Arts' then hours_per_week else 0 end) as arts_hours,
        max(case when activity_category = 'Academic' then hours_per_week else 0 end) as academic_club_hours,
        max(case when activity_category = 'Community Service' then hours_per_week else 0 end) as service_hours,
        max(participates_in_activities) as is_active_participant
    from activity_impact
    group by
        student_id, full_name, gpa, academic_standing, student_status,
        years_enrolled, department_name, department_code, total_enrollments,
        total_credits_earned, avg_grade_points, failed_courses_count, withdrawn_courses_count
),

impact_analysis as (
    select
        *,
        case
            when is_active_participant = 1 then 'Activity Participant'
            else 'Non-Participant'
        end as participation_status,
        case
            when total_activities >= 3 then 'Highly Involved'
            when total_activities = 2 then 'Moderately Involved'
            when total_activities = 1 then 'Minimally Involved'
            else 'Not Involved'
        end as involvement_level,
        case
            when athletics_hours > arts_hours and athletics_hours > academic_club_hours then 'Athletics Primary'
            when arts_hours > academic_club_hours then 'Arts Primary'
            when academic_club_hours > 0 then 'Academic Clubs Primary'
            else 'No Primary Activity'
        end as primary_activity_type,
        round(total_activity_hours / nullif(years_enrolled, 0), 2) as avg_hours_per_year,
        case
            when gpa >= 3.5 and is_active_participant = 1 then 'High Performing Participant'
            when gpa >= 3.0 and is_active_participant = 1 then 'Good Performing Participant'
            when gpa < 3.0 and is_active_participant = 1 then 'At-Risk Participant'
            when gpa >= 3.5 and is_active_participant = 0 then 'High Performing Non-Participant'
            when gpa >= 3.0 and is_active_participant = 0 then 'Good Performing Non-Participant'
            else 'At-Risk Non-Participant'
        end as performance_activity_category
    from activity_summary
),

departmental_stats as (
    select
        department_name,
        count(*) as total_students_in_dept,
        count(case when is_active_participant = 1 then 1 end) as participants_in_dept,
        avg(case when is_active_participant = 1 then gpa end) as avg_gpa_participants,
        avg(case when is_active_participant = 0 then gpa end) as avg_gpa_non_participants,
        avg(case when is_active_participant = 1 then total_activity_hours end) as avg_activity_hours,
        round(
            count(case when is_active_participant = 1 then 1 end) * 100.0 /
            nullif(count(*), 0), 2
        ) as participation_rate
    from impact_analysis
    group by department_name
)

select
    ia.*,
    ds.participants_in_dept,
    ds.avg_gpa_participants as dept_avg_gpa_participants,
    ds.avg_gpa_non_participants as dept_avg_gpa_non_participants,
    ds.avg_activity_hours as dept_avg_activity_hours,
    ds.participation_rate as dept_participation_rate,
    case
        when ds.avg_gpa_participants > ds.avg_gpa_non_participants then 'Participants Outperform'
        when ds.avg_gpa_participants < ds.avg_gpa_non_participants then 'Non-Participants Outperform'
        else 'Similar Performance'
    end as dept_participation_performance_comparison
from impact_analysis ia
left join departmental_stats ds on ia.department_name = ds.department_name
