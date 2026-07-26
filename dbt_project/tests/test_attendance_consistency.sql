-- Test to ensure attendance records have valid percentage values
select *
from {{ ref('stg_attendance_records') }}
where attendance_percentage > 100  -- Attendance cannot exceed 100%
   or attendance_percentage < 0    -- Attendance cannot be negative
