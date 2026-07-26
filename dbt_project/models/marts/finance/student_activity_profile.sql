{{ config(materialized='table') }}

with student_activities as (
    select
        s.student_id,
        s.full_name,
        s.email,
        s.student_status,
        s.gpa,
        s.academic_standing,
        s.years_enrolled,
        d.department_name as major_department,
        ea.activity_id,
        ea.activity_name,
        ea.activity_type,
        ea.activity_category,
        ea.hours_per_week,
        ea.commitment_level,
        ea.academic_year as activity_academic_year,
        ar.quarter_id,
        ar.attendance_percentage,
        ar.excused_absences,
        ar.unexcused_absences,
        ar.tardies,
        ar.attendance_status,
        sem.quarter_name,
        sem.academic_year as attendance_academic_year
    from {{ ref('stg_students') }} s
    left join {{ ref('stg_departments') }} d on s.major_id = d.department_id
    left join {{ ref('stg_extracurricular_activities') }} ea on s.student_id = ea.student_id
    left join {{ ref('stg_attendance_records') }} ar on s.student_id = ar.student_id
    left join {{ ref('stg_quarters') }} sem on ar.quarter_id = sem.quarter_id
),

activity_summary as (
    select
        student_id,
        full_name,
        email,
        student_status,
        gpa,
        academic_standing,
        years_enrolled,
        major_department,
        count(distinct activity_id) as total_activities,
        sum(hours_per_week) as total_weekly_activity_hours,
        avg(hours_per_week) as avg_hours_per_activity,
        count(distinct activity_academic_year) as active_years,
        count(distinct quarter_id) as quarters_with_attendance,
        round(avg(attendance_percentage), 2) as avg_attendance_rate,
        sum(excused_absences) as total_excused_absences,
        sum(unexcused_absences) as total_unexcused_absences,
        sum(tardies) as total_tardies,
        max(case when activity_category = 'Athletics' then hours_per_week else 0 end) as athletics_hours,
        max(case when activity_category = 'Arts' then hours_per_week else 0 end) as arts_hours,
        max(case when activity_category = 'Academic' then hours_per_week else 0 end) as academic_club_hours,
        max(case when activity_category = 'Community Service' then hours_per_week else 0 end) as service_hours
    from student_activities
    where student_id is not null
    group by
        student_id, full_name, email, student_status, gpa,
        academic_standing, years_enrolled, major_department
),

profile_analysis as (
    select
        *,
        case
            when total_activities >= 4 then 'Highly Engaged'
            when total_activities >= 2 then 'Moderately Engaged'
            when total_activities = 1 then 'Minimally Engaged'
            else 'Not Engaged'
        end as engagement_level,
        case
            when avg_attendance_rate >= 95 then 'Excellent Attendance'
            when avg_attendance_rate >= 90 then 'Good Attendance'
            when avg_attendance_rate >= 80 then 'Fair Attendance'
            else 'Poor Attendance'
        end as attendance_rating,
        case
            when athletics_hours > arts_hours and athletics_hours > academic_club_hours then 'Athletics Focus'
            when arts_hours > academic_club_hours then 'Arts Focus'
            when academic_club_hours > 0 then 'Academic Clubs Focus'
            else 'No Primary Activity'
        end as primary_activity_focus,
        round(total_weekly_activity_hours / nullif(years_enrolled, 0), 2) as avg_hours_per_year
    from activity_summary
)

select * from profile_analysis
