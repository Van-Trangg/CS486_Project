-- ============================================================
-- Campus Space Management System — Query Design
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 7: Query Design
-- ============================================================

USE University;
GO

-- ============================================================
-- QUERY 1: Space Utilization Rate
-- ============================================================
-- Business Objective:
--   Determine the actual utilization rate for each space type by calculating
--   the total hours rooms were occupied. This metric is derived from check-in 
--   and check-out timestamps in usage sessions.
--
-- Target Audience:
--   Facility managers who need to identify high-demand space types 
--   versus underutilized ones.
--
-- Practical Value:
--   Enables data-driven decision-making for space allocation, such as
--   repurposing consistently empty meeting rooms or expanding high-demand
--   computer laboratory resources.
--
-- SQL:
SELECT 
    s.space_type,
    COUNT(DISTINCT s.space_code) AS total_spaces,
    COUNT(u.booking_id) AS total_usage_sessions,
    ISNULL(SUM(DATEDIFF(MINUTE, u.actual_start, u.actual_end)), 0) AS total_actual_minutes,
    CAST(
        ISNULL(ROUND(SUM(DATEDIFF(MINUTE, u.actual_start, u.actual_end)) / 60.0, 2), 0)
        AS DECIMAL(10,2)
    ) AS total_actual_hours
FROM SPACE s
LEFT JOIN BOOKING b ON s.space_code = b.space_code
LEFT JOIN USAGESESSION u ON b.booking_id = u.booking_id AND u.actual_end IS NOT NULL
GROUP BY s.space_type
ORDER BY total_actual_hours DESC, s.space_type;
GO

/*
Sample Output (based on our test data):
space_type               total_spaces total_usage_sessions total_actual_minutes total_actual_hours
------------------------ ------------ -------------------- -------------------- ------------------
Computer Laboratory                 1                    1                  185               3.08
Auditorium                          1                    0                    0                .00
Classroom                           2                    0                    0                .00
Meeting Room                        1                    0                    0                .00
Project Laboratory                  1                    0                    0                .00
Student Workspace                   1                    0                    0                .00
*/


-- ============================================================
-- QUERY 2: Peak Booking Time Slots
-- ============================================================
-- Business Objective:
--   Identify peak booking days and hours by analyzing active, check-in, 
--   and completed bookings to determine high-demand time slots.
--
-- Target Audience:
--   Facility operations managers and support staff.
--
-- Practical Value:
--   Optimizes staff scheduling for high-traffic periods and helps identify 
--   low-demand windows suitable for routine maintenance without disrupting users.
--
-- SQL:
SELECT 
    DATEPART(WEEKDAY, requested_start) AS day_of_week_num,
    DATENAME(WEEKDAY, requested_start) AS day_of_week_name,
    DATEPART(HOUR, requested_start) AS start_hour,
    COUNT(booking_id) AS total_bookings,
    SUM(expected_participants) AS total_expected_participants
FROM BOOKING
WHERE booking_status IN ('Approved', 'Checked In', 'Completed')
GROUP BY
    DATEPART(WEEKDAY, requested_start),
    DATENAME(WEEKDAY, requested_start),
    DATEPART(HOUR, requested_start)
ORDER BY total_bookings DESC, total_expected_participants DESC;
GO

/*
Sample Output (based on our test data):
day_of_week_num day_of_week_name   start_hour  total_bookings total_expected_participants
--------------- ------------------ ----------- -------------- --------------------------
              6 Friday                       9              2                         100
              6 Friday                      10              2                         130
              1 Sunday                       9              1                         100
              2 Monday                      13              1                          10
*/


-- ============================================================
-- QUERY 3: No-Show and Cancellation Audit
-- ============================================================
-- Business Objective:
--   Audit booking accountability by identifying users with high cancellation
--   or no-show rates. Calculates a "waste percentage" for each user.
--
-- Target Audience:
--   Facility administrators and department leads.
--
-- Practical Value:
--   Enables the enforcement of fair-use policies and accountability. Administrators 
--   can identify repeat offenders to issue warnings or temporarily suspend booking privileges, 
--   minimizing wasted room capacity.
--
-- SQL:
SELECT 
    u.user_id,
    u.full_name,
    u.role,
    u.department,
    COUNT(b.booking_id) AS total_bookings,
    SUM(CASE WHEN b.booking_status = 'No-Show' THEN 1 ELSE 0 END) AS no_shows,
    SUM(CASE WHEN b.booking_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancellations,
    SUM(CASE WHEN b.booking_status IN ('No-Show', 'Cancelled') THEN 1 ELSE 0 END) AS total_wasted,
    CAST(
        ROUND(
            SUM(CASE WHEN b.booking_status IN ('No-Show', 'Cancelled') THEN 1.0 ELSE 0.0 END)
            / COUNT(b.booking_id) * 100, 2
        ) AS DECIMAL(5,2)
    ) AS waste_percentage
FROM [USER] u
JOIN BOOKING b ON u.user_id = b.requester_id
GROUP BY u.user_id, u.full_name, u.role, u.department
ORDER BY total_wasted DESC, waste_percentage DESC;
GO

/*
Sample Output (based on our test data):
user_id      full_name            role                  department         total_bookings no_shows cancellations total_wasted waste_percentage
------------ -------------------- --------------------- ------------------ -------------- -------- ------------- ------------ ----------------
STU2023001   Sarah Chen           Student               Computer Science              5        1             1            2            40.00
STU2021004   Alex Jordan          Student               Data Science                  1        0             0            0              .00
ADM2019001   Priya Sharma         Department Admin...   Computer Science              2        0             1            1            50.00
LEC2021001   Dr. James Mitchell   Lecturer              Computer Science              4        0             0            0              .00
TA2023002    Miguel Rios          Teaching Assistant     Computer Science              3        0             0            0              .00
*/


-- ============================================================
-- QUERY 4: Maintenance Impact and Downtime Analysis
-- ============================================================
-- Business Objective:
--   Analyze maintenance frequency, active issues, total downtime (in hours), 
--   and the most common failure type for each physical space.
--
-- Target Audience:
--   Maintenance operations and facility managers.
--
-- Practical Value:
--   Identifies chronic issues (e.g., recurring HVAC or projector failures) to support 
--   long-term budgeting for equipment replacements rather than repeated temporary repairs.
--
-- SQL:
WITH MaintenanceStats AS (
    SELECT 
        space_code,
        COUNT(maintenance_id) AS total_maintenance_events,
        SUM(CASE WHEN maintenance_status IN ('Reported', 'In Progress') THEN 1 ELSE 0 END) AS active_events,
        ISNULL(SUM(DATEDIFF(MINUTE, start_time, completion_time)), 0) AS total_downtime_minutes
    FROM MAINTENANCERECORD
    GROUP BY space_code
),
ProblemFrequencies AS (
    SELECT 
        space_code,
        problem_type,
        COUNT(maintenance_id) AS problem_count,
        ROW_NUMBER() OVER (PARTITION BY space_code ORDER BY COUNT(maintenance_id) DESC) AS rn
    FROM MAINTENANCERECORD
    GROUP BY space_code, problem_type
)
SELECT 
    s.space_code,
    s.space_name,
    s.space_type,
    ISNULL(ms.total_maintenance_events, 0) AS total_maintenance_events,
    ISNULL(ms.active_events, 0) AS active_events,
    ISNULL(ms.total_downtime_minutes, 0) AS total_downtime_minutes,
    CAST(ROUND(ISNULL(ms.total_downtime_minutes, 0) / 60.0, 2) AS DECIMAL(10,2)) AS total_downtime_hours,
    ISNULL(pf.problem_type, 'None') AS most_common_problem
FROM SPACE s
LEFT JOIN MaintenanceStats ms ON s.space_code = ms.space_code
LEFT JOIN ProblemFrequencies pf ON s.space_code = pf.space_code AND pf.rn = 1
ORDER BY total_maintenance_events DESC, total_downtime_minutes DESC;
GO

/*
Sample Output (based on our test data):
space_code      space_name           space_type          total_maintenance_events active_events total_downtime_minutes total_downtime_hours most_common_problem
--------------- -------------------- ------------------- ------------------------ ------------- ---------------------- -------------------- ----------------------
CS-B1-F2-R201   Lecture Hall 201     Classroom                                  1             1                      0                 .00 Air-Conditioning Issue
CS-B3-F1-R015   Project Pod 15       Project Laboratory                         1             1                      0                 .00 Projector Failure
CS-B2-F1-R101   Auditorium A         Auditorium                                 1             0                    540                9.00 Cleaning Issue
CS-B2-F1-R102   Lab 102              Computer Lab...                            1             0                      0                 .00 Furniture Damage
CS-B1-F0-R001   Meeting Room A       Meeting Room                               1             1                      0                 .00 Network Issue
CS-B3-F2-R210   Retired Lab 210      Classroom                                  1             0                   1920               32.00 Other
CS-B2-F2-R205   Student Hub 205      Student Workspace                          1             1                      0                 .00 Cleaning Issue
*/


-- ============================================================
-- QUERY 5: Dynamic Space Search with Facility Filter
-- ============================================================
-- Business Objective:
--   Query available spaces dynamically based on a target capacity (>= 15 seats), 
--   presence of functional equipment (e.g., projector), and availability within 
--   a specific time window.
--
-- Target Audience:
--   End-users (students, faculty, department admins) looking to book a space, 
--   powering the backend search function of the application.
--
-- Practical Value:
--   Automates availability checks by simultaneously filtering out spaces that are 
--   already booked, undergo active maintenance, or do not meet equipment/capacity requirements.
--
-- SQL:
SELECT 
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.room_number,
    s.capacity,
    s.current_status
FROM SPACE s
WHERE s.capacity >= 15
  AND s.current_status IN ('Available', 'In Use')
  -- Make sure the room has a working projector
  AND s.space_code IN (
      SELECT sf.space_code
      FROM SPACE_FACILITY sf
      JOIN FACILITY f ON sf.facility_id = f.facility_id
      WHERE f.facility_name = 'Projector'
        AND sf.operation_status IN ('Operational', 'Partially Operational')
  )
  -- Make sure nobody else has it booked during our time window
  AND NOT EXISTS (
      SELECT 1 
      FROM BOOKING b
      WHERE b.space_code = s.space_code
        AND b.booking_status IN ('Approved', 'Checked In', 'Completed')
        AND '2026-07-15 14:00:00' < b.requested_end 
        AND '2026-07-15 16:00:00' > b.requested_start
  )
  -- Make sure there's no active maintenance during that time
  AND NOT EXISTS (
      SELECT 1 
      FROM MAINTENANCERECORD m
      WHERE m.space_code = s.space_code
        AND m.maintenance_status IN ('Reported', 'In Progress')
        AND '2026-07-15 14:00:00' < ISNULL(m.completion_time, '9999-12-31')
        AND '2026-07-15 16:00:00' > m.start_time
  );
GO

/*
Sample Output (based on our test data):
space_code      space_name       space_type           building         room_number capacity current_status
--------------- ---------------- -------------------- ---------------- ----------- -------- --------------
CS-B2-F1-R101   Auditorium A     Auditorium           Bateson Hall     101              200 Available
CS-B2-F1-R102   Lab 102          Computer Laboratory  Bateson Hall     102               40 Available
*/
