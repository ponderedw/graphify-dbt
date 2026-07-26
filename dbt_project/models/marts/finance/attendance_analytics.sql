{{ config(materialized='table') }}

with attendance_data as (
    select
        ar.attendance_id,
        ar.student_id,
        ar.quarter_id,
        ar.attendance_percentage,
        ar.excused_absences,
        ar.unexcused_absences,
        ar.tardies,
        ar.attendance_status,
        ar.unexcused_category,
        ar.tardy_category,
        sem.quarter_name,
        sem.academic_year,
        sem.quarter_type,
        sem.start_date as quarter_start,
        sem.end_date as quarter_end,
        s.student_status,
        s.gpa,
        s.academic_standing,
        s.major_id,
        d.department_name,
        d.department_code
    from {{ ref('stg_attendance_records') }} ar
    left join {{ ref('stg_quarters') }} sem on ar.quarter_id = sem.quarter_id
    left join {{ ref('stg_students') }} s on ar.student_id = s.student_id
    left join {{ ref('stg_departments') }} d on s.major_id = d.department_id
),

attendance_metrics as (
    select
        quarter_id,
        quarter_name,
        academic_year,
        quarter_type,
        quarter_start,
        quarter_end,
        department_name,
        department_code,
        count(distinct student_id) as students_tracked,
        round(avg(attendance_percentage), 2) as avg_attendance_rate,
        round(min(attendance_percentage), 2) as min_attendance_rate,
        round(max(attendance_percentage), 2) as max_attendance_rate,
        sum(excused_absences) as total_excused_absences,
        sum(unexcused_absences) as total_unexcused_absences,
        sum(tardies) as total_tardies,
        count(case when attendance_status = 'Excellent' then 1 end) as excellent_attendance_count,
        count(case when attendance_status = 'Good' then 1 end) as good_attendance_count,
        count(case when attendance_status = 'Fair' then 1 end) as fair_attendance_count,
        count(case when attendance_status = 'Poor' then 1 end) as poor_attendance_count,
        count(case when attendance_status = 'Critical' then 1 end) as critical_attendance_count,
        count(case when unexcused_category = 'Chronic Unexcused' then 1 end) as chronic_unexcused_count,
        round(
            count(case when attendance_percentage < 80 then 1 end) * 100.0 /
            nullif(count(student_id), 0), 2
        ) as at_risk_attendance_rate
    from attendance_data
    group by
        quarter_id, quarter_name, academic_year, quarter_type, quarter_start,
        quarter_end, department_name, department_code
),

trend_analysis as (
    select
        *,
        lag(avg_attendance_rate) over (
            partition by department_name
            order by quarter_start
        ) as prev_quarter_attendance,
        round(
            avg_attendance_rate - lag(avg_attendance_rate) over (
                partition by department_name
                order by quarter_start
            ), 2
        ) as attendance_change,
        case
            when avg_attendance_rate >= 95 then 'High Attendance Department'
            when avg_attendance_rate >= 90 then 'Good Attendance Department'
            when avg_attendance_rate >= 85 then 'Average Attendance Department'
            else 'Low Attendance Department'
        end as department_attendance_category,
        case
            when at_risk_attendance_rate >= 20 then 'High Intervention Need'
            when at_risk_attendance_rate >= 10 then 'Moderate Intervention Need'
            when at_risk_attendance_rate >= 5 then 'Low Intervention Need'
            else 'Minimal Intervention Need'
        end as intervention_priority,
        round(students_tracked - excellent_attendance_count - good_attendance_count, 0) as students_needing_support
    from attendance_metrics
)

select * from trend_analysis
order by quarter_start desc, avg_attendance_rate asc
