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

-- ============================================================
-- QUERY 6: Spaces with a Specific Maintenance Issue
-- ============================================================
-- Business Objective:
--   Identify all spaces that have experienced a particular maintenance issue
--   (e.g., Projector Failure, Network Issue, Air-Conditioning Issue).
-- Target Audience:
--   Facility Staff
--   Facility Manager
-- Practical Value:
--   Helps maintenance teams quickly locate affected rooms and identify
--   recurring problem areas. Supports maintenance planning and resource
--   allocation for common equipment failures.
----------------------------------------------
use University;
go
-- SQL:
SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    m.problem_type,
    m.maintenance_status,
    m.start_time,
    m.completion_time
FROM SPACE s
JOIN MAINTENANCERECORD m
ON s.space_code = m.space_code
WHERE m.problem_type = 'Projector Failure'
ORDER BY m.start_time DESC;
GO

/*
Sample Output (based on our test data):
space_code      space_name               space_type            problem_type        maintenance_status      start_time                 completion_time
CS-C3-F1-R001   Rutherford Project Lab   Project Laboratory    Projector Failure   In Progress             2027-01-15 08:00:00.000    NULL
*/

-- ============================================================
-- QUERY 7: Unassigned Facility Catalog Items
-- ============================================================
-- Business Objective:
--   Identify facility types that have not yet been assigned to any space.
-- Target Audience:
--   Facility Staff
--   Facility Manager
-- Practical Value:
--   Supports inventory auditing by identifying equipment recorded in the
--   facility catalog but not currently deployed in any room. Helps detect
--   procurement, inventory, or configuration issues.
-- SQL:
SELECT
    f.facility_id,
    f.facility_name
FROM FACILITY f
LEFT JOIN SPACE_FACILITY sf
ON f.facility_id = sf.facility_id
WHERE sf.facility_id IS NULL
ORDER BY f.facility_name;
GO

/*
Sample Output (based on our test data):
facility_id     facility_name
(Empty result set)
*/

-- ============================================================
-- QUERY 8: Approved Bookings for a Specific Space
-- ============================================================
-- Business Objective:
--   Display all approved bookings scheduled for a specific physical space.
-- Target Audience:
--   Facility Staff
--   Department Administrator
-- Practical Value:
--   Provides a complete schedule of approved reservations for a room,
--   supporting operational planning, conflict investigation, and room
--   utilization monitoring.
-- SQL:

SELECT
    b.booking_id,
    b.requested_start,
    b.requested_end,
    b.expected_participants,
    b.booking_status,
    u.full_name AS requester_name
FROM BOOKING b
JOIN [USER] u
ON b.requester_id = u.user_id
WHERE b.space_code = 'CS-B2-F1-R201'
AND b.booking_status = 'Approved'
ORDER BY b.requested_start;
GO

/*
Sample Output (based on our test data):
booking_id    requested_start           requested_end            expected_participants  booking_status requester_name
2	          2027-01-20 09:00:00.000	2027-01-20 11:00:00.000	 40	                    Approved	   Dr. Sarah Thompson
6	          2027-02-15 14:00:00.000	2027-02-15 17:00:00.000	 30	                    Approved	   Alice Chen
*/

-- ============================================================
-- QUERY 9: Available Spaces of a Specific Type During a Time Window
-- ============================================================
-- Business Objective:
--   Identify spaces of a specific type that have no approved bookings
--   during a specified time period on a particular day.
-- Target Audience:
--   Student
--   Lecturer
--   Department Administrator
-- Practical Value:
--   Helps users quickly locate available rooms that satisfy their
--   requirements without manually checking individual schedules.
--   Supports efficient space allocation and booking planning.
-- SQL:
SELECT
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.capacity
FROM SPACE s
WHERE s.space_type = 'Meeting Room'
  AND s.current_status IN ('Available', 'In Use')
  AND NOT EXISTS (
      SELECT 1
      FROM BOOKING b
      WHERE b.space_code = s.space_code
        AND b.booking_status = 'Approved'
        AND b.requested_start < '2026-07-15 12:00:00'
        AND b.requested_end > '2026-07-15 10:00:00'
  )
ORDER BY s.space_code;
GO
/*
Sample Output (based on our test data):
space_code      space_name             building       floor   capacity
CS-A2-F2-R202	Hopper Meeting Room	   Building A2	  2	      16
*/

-- ============================================================
-- QUERY 10: Long-Running Maintenance Activities
-- ============================================================
-- Business Objective:
--   Identify rooms that have remained under maintenance for more
--   than five days.
-- Target Audience:
--   Facility Manager
--   Facility Staff
-- Practical Value:
--   Highlights potentially delayed maintenance tasks requiring
--   escalation, additional resources, or management attention.
--   Supports maintenance performance monitoring.
-- SQL:
SELECT
    s.space_code,
    s.space_name,
    m.problem_type,
    m.maintenance_status,
    m.start_time,
    m.completion_time,
DATEDIFF(DAY,nm.start_time,ISNULL(m.completion_time, GETDATE())) AS maintenance_days
FROM MAINTENANCERECORD m
JOIN SPACE s ON m.space_code = s.space_code
WHERE m.maintenance_status IN ('Reported', 'In Progress')
  AND DATEDIFF(DAY, m.start_time, ISNULL(m.completion_time, GETDATE())) > 5
ORDER BY maintenance_days DESC;
GO

/*
Sample Output (based on our test data):
space_code      space_name          problem_type        maintenance_status      start_time                 completion_time          maintenance_days
*/

-- ============================================================
-- QUERY 11
-- ============================================================
-- Business question: Which approved bookings are scheduled for tomorrow, and who is responsible for them?

-- Target user(s): Facility Staff, Facility Manager

-- Why this is useful: 
--  Facility staff currently rely on manually checking spreadsheets to know which rooms will be in use and who is arriving. 
--  This query gives staff a same-day operational view before the start of each shift (who is coming, to which room, and for what purpose) so they can prepare the space, verify it isn't flagged for maintenance, and be ready to check the requester in when they arrive.

-- SQL:
SELECT
    b.booking_id,
    s.space_name,
    s.building,
    s.room_number,
    u.full_name        AS requester_name,
    u.department,
    b.purpose,
    b.requested_start,
    b.requested_end,
    b.expected_participants
FROM BOOKING b
JOIN SPACE s ON b.space_code = s.space_code
JOIN [USER] u ON b.requester_id = u.user_id
WHERE b.booking_status = 'Approved'
  AND b.requested_start >= DATEADD(DAY, 1, CAST(GETDATE() AS DATE))
  AND b.requested_start <  DATEADD(DAY, 2, CAST(GETDATE() AS DATE))
ORDER BY b.requested_start;
GO

/* Sample Output (based on our test data, assuming query executed 2027-02-14):
booking_id space_name       building    room_number requester_name department       purpose          requested_start     requested_end       expected_participants
---------- ---------------- ----------- ----------- -------------- ---------------- ---------------- ------------------- ------------------- ---------------------
         6 Turing Classroom Building B2 R201        Alice Chen     Computer Science Student Activity 2027-02-15 14:00:00 2027-02-15 17:00:00                    30
*/

-- ============================================================
-- QUERY 12
-- ============================================================
-- Business question: Which spaces are most frequently booked but never actually used, and what is the no-show rate as a % of total approved bookings for that room?

-- Target user(s): Facility Manager, Department Administrator

-- Why this is useful: 
--  No-shows waste shared resource that could be allocated to someone else who needed it, especially for those that is in high demand. Managers also need to ensure fair distribution of the spaces.
--  This query identifies where no-show behavior is concentrated within the last 6 months, which allows Facility Managers to  tighten booking policies for these specific rooms or investigate whether a particular department is the source of repeated no-shows. 

-- SQL:
SELECT
    s.space_code,
    s.space_name,
    s.building,
    COUNT(*) AS total_approved_bookings,
    SUM(CASE WHEN b.booking_status = 'No-Show' THEN 1 ELSE 0 END) AS no_show_count,
    CAST(
        100.0 * SUM(CASE WHEN b.booking_status = 'No-Show' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS no_show_rate_pct
FROM BOOKING b
JOIN SPACE s ON b.space_code = s.space_code
WHERE b.booking_status IN ('No-Show', 'Completed')
  AND b.requested_start >= DATEADD(MONTH, -6, GETDATE())
GROUP BY s.space_code, s.space_name, s.building
HAVING COUNT(*) >= 5
ORDER BY no_show_rate_pct DESC;
GO

/* Sample Output (based on our test data)
space_code space_name building total_approved_bookings no_show_count no_show_rate_pct
---------- ---------- -------- ----------------------- ------------- ----------------
(0 rows due to count >= 5 constraint)
*/

-- ============================================================
-- QUERY 13
-- ============================================================
-- Business question:  How accurately do requesters estimate their booking duration

-- Target user(s): Facility Manager, Department Administrator

-- Why this is useful: 
--   Booking durations are self-reported at request time, but the system also records actual check-in and check-out times once a session finishes. Comparing the two reveals whether certain booking purposes (e.g., Examinations vs. Meetings) systematically run longer than requested.
--   This insight lets the Facility Manager consider default buffer time for purpose types with a history of overrun to ensure smooth future operations and reduce back-to-back bookings collision.

-- SQL:
SELECT
    b.purpose,
    COUNT(*) AS sessions_with_checkout,
    AVG(DATEDIFF(MINUTE, b.requested_start, b.requested_end)) AS avg_requested_minutes,
    AVG(DATEDIFF(MINUTE, us.actual_start, us.actual_end))     AS avg_actual_minutes,
    AVG(
        DATEDIFF(MINUTE, us.actual_start, us.actual_end)
        - DATEDIFF(MINUTE, b.requested_start, b.requested_end)
    ) AS avg_overrun_minutes
FROM BOOKING b
JOIN USAGESESSION us ON b.booking_id = us.booking_id
WHERE us.actual_end IS NOT NULL
GROUP BY b.purpose
HAVING AVG(
    DATEDIFF(MINUTE, us.actual_start, us.actual_end)
    - DATEDIFF(MINUTE, b.requested_start, b.requested_end)
) > 0
ORDER BY avg_overrun_minutes DESC;
GO

/* Sample Output (based on our test data):
purpose sessions_with_checkout avg_requested_minutes avg_actual_minutes avg_overrun_minutes
------- ---------------------- ---------------------- ------------------- --------------------
Lecture                      1                    120                 123                    3
*/

-- ============================================================
-- QUERY 14
-- ============================================================
-- Business question:  Which spaces face the most booking competition in general, and specifically on which day of the week?

-- Target user(s): Facility Manager, Department Administrator

-- Why this is useful: 
--   Managers may need to identify high-demand combinations of a room corresponding with specific time slots where demand is too high.
--   To avoid overlapping bookings while allowing everyone to have a fair chance of using the space, managers can use the results of this query to consider additional capacity, extended booking window, or a stricter priority policy for these room or certain time slots.

-- SQL:
SELECT
    s.space_name,
    s.building,
    DATENAME(WEEKDAY, b.requested_start) AS day_of_week,
    COUNT(*) AS total_requests,
    SUM(CASE WHEN b.booking_status = 'Approved' THEN 1 ELSE 0 END)  AS approved_count,
    SUM(CASE WHEN b.booking_status = 'Rejected' THEN 1 ELSE 0 END)  AS rejected_count
FROM BOOKING b
JOIN SPACE s ON b.space_code = s.space_code
WHERE b.requested_start >= DATEADD(MONTH, -3, GETDATE())
GROUP BY s.space_name, s.building, DATENAME(WEEKDAY, b.requested_start)
HAVING COUNT(*) >= 3
ORDER BY total_requests DESC;
GO

/* Sample Output (based on our test data)
space_name building day_of_week total_requests approved_count rejected_count
---------- -------- ----------- -------------- -------------- --------------
(0 rows due to to count >= 3 constraint)
*/

-- ============================================================
-- QUERY 15 
-- ============================================================
-- Business question:  Which facilities are currently unusable, and what spaces are affected?

-- Target user(s): Facility Staff, Lecturer/Teaching Assistant

-- Why this is useful: 
--   A space can be Available in overall status while a specific piece of equipment inside it (a projector, a microphone) is broken.
--   Allows staff to check whether a room is suitable for a requester and inform them promptly before they make their booking.

-- SQL:
SELECT
    s.space_name,
    s.building,
    s.room_number,
    f.facility_name,
    sf.quantity,
    sf.operation_status,
    sf.description AS fault_notes
FROM SPACE_FACILITY sf
JOIN SPACE s ON sf.space_code = s.space_code
JOIN FACILITY f ON sf.facility_id = f.facility_id
WHERE sf.operation_status IN ('Broken', 'Partially Operational')
ORDER BY s.space_name, f.facility_name;
GO

/* Sample Output (based on our test data):
space_name             building    room_number facility_name        quantity operation_status      fault_notes
---------------------- ----------- ----------- -------------------- -------- --------------------- --------------------------------------------------------------------------
Lovelace Lab           Building B2 R205        Computer Workstation       25 Partially Operational 25 workstations operational. 5 workstations in Row C awaiting maintenance.
Rutherford Project Lab Building C3 R001        Air Conditioner             2 Broken                Both air conditioning units non-functional. Parts on order.
*/

-- ============================================================
-- QUERY 16: Urgent Pending Bookings (Starting Within 24 Hours)
-- ============================================================
-- Business Objective:
--   Identify pending booking requests that are scheduled to start
--   within the next 24 hours, enabling staff to prioritise approvals.
--
-- Target Audience:
--   Facility Staff, Facility Manager.
--
-- Practical Value:
--   Prevents last‑minute schedule gaps and ensures requesters are not
--   left waiting without a decision on the day of their event.
--
-- SQL:
SELECT
    b.booking_id,
    u.full_name AS requester,
    u.role,
    u.email,
    s.space_name,
    s.space_type,
    b.requested_start,
    b.requested_end,
    b.purpose,
    b.expected_participants,
    b.created_at,
    ROUND(DATEDIFF(MINUTE, GETDATE(), b.requested_start) / 60.0, 1) AS hours_until_start,
    CASE
        WHEN b.requested_start <= DATEADD(HOUR,  2, GETDATE()) THEN 'Critical (< 2h)'
        WHEN b.requested_start <= DATEADD(HOUR,  8, GETDATE()) THEN 'High     (2-8h)'
        ELSE                                                         'Normal  (8-24h)'
    END AS urgency_tier
FROM BOOKING b
JOIN [USER] u ON b.requester_id = u.user_id
JOIN SPACE  s ON b.space_code   = s.space_code
WHERE b.booking_status = 'Pending'
  AND b.requested_start BETWEEN GETDATE() AND DATEADD(DAY, 1, GETDATE())
ORDER BY b.requested_start;
GO

/*
Sample Output:
booking_id  requester        role                  email                              space_name              space_type        requested_start          requested_end            purpose           expected_participants  created_at               hours_until_start  urgency_tier
----------  ---------------  --------------------  ---------------------------------  ----------------------  ----------------  -----------------------  -----------------------  ----------------  --------------------  -----------------------  -----------------  ---------------
*/


-- ============================================================
-- QUERY 17: Average Booking Lead Time by Purpose
-- ============================================================
-- Business Objective:
--   Calculate how many days in advance each purpose type is typically
--   booked, comparing the request creation date to the scheduled start.
--
-- Target Audience:
--   Facility Manager, Department Administrator.
--
-- Practical Value:
--   Helps set minimum notice policies for different event types and
--   identify which purposes are planned vs. last‑minute requests.
--
-- SQL:
SELECT
    purpose,
    COUNT(*) AS total_bookings,
    AVG(DATEDIFF(DAY, created_at, requested_start)) AS avg_lead_days,
    MIN(DATEDIFF(DAY, created_at, requested_start)) AS min_lead_days,
    MAX(DATEDIFF(DAY, created_at, requested_start)) AS max_lead_days
FROM BOOKING
WHERE requested_start >= created_at   -- safety check
GROUP BY purpose
ORDER BY avg_lead_days DESC;
GO

/*
Sample Output (based on test data):
purpose               total_bookings  avg_lead_days  min_lead_days  max_lead_days
--------------------  --------------  -------------  -------------  -------------
Examination                        2             21             21             21
Administrative Event               2             17             17             18
Workshop                           2             17             14             21
Seminar                            1             15             15             15
Student Activity                   2             13             12             14
Lecture                            2             12              7             17
Meeting                            2             11              7             15
*/


-- ============================================================
-- QUERY 18: Spaces That Have Never Been Booked
-- ============================================================
-- Business Objective:
--   Identify rooms that have never appeared in any booking request.
--
-- Target Audience:
--   Facility Manager, Department Administrator.
--
-- Practical Value:
--   Helps identify completely unused spaces that could be reallocated,
--   upgraded, or designated for non‑bookable activities without
--   impacting current users.
--
-- SQL:
SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status
FROM SPACE s
LEFT JOIN BOOKING b ON s.space_code = b.space_code
WHERE b.booking_id IS NULL
ORDER BY s.current_status, s.space_type, s.space_code;
GO

/*
Sample Output:
space_code      space_name              space_type         building       floor  room_number capacity current_status
--------------- ----------------------- ------------------ -------------- ----- ----------- -------- ----------------------
CS-A1-F3-R301   Berners-Lee Lecture Hall Auditorium         Building A1    3      R301        150      Retired
CS-B1-F1-R102   Einstein Workspace       Student Workspace  Building B1    1      R102        50       Temporarily Closed
*/


-- ============================================================
-- QUERY 19: Users Who Have Never Made a Booking
-- ============================================================
-- Business Objective:
--   List all users who have never submitted a booking request.
--
-- Target Audience:
--   Department Administrator, Facility Manager.
--
-- Practical Value:
--   Useful for account housekeeping, identifying inactive accounts
--   that could be suspended, or understanding which user groups
--   are not yet utilising the system.
--
-- SQL:
SELECT
    u.user_id,
    u.full_name,
    u.role,
    u.department,
    u.account_status
FROM [USER] u
LEFT JOIN BOOKING b ON u.user_id = b.requester_id
WHERE b.booking_id IS NULL
ORDER BY u.role, u.full_name;
GO

/*
Sample Output (based on test data):
user_id      full_name           role               department         account_status
-----------  ------------------- ------------------ ------------------ --------------
MGR2017001   Priya Sharma        Facility Manager   Computer Science   Active
STF2020002   Emily Nakamura      Facility Staff     Computer Science   Active
STF2019001   Michael Okonkwo     Facility Staff     Computer Science   Active
LEC2019003   Prof. Robert Kim    Lecturer           Computer Science   Inactive
STU2021004   Lisa Johansson      Student            Computer Science   Suspended
*/


-- ============================================================
-- QUERY 20: Users with Highest Rejection Rate
-- ============================================================
-- Business Objective:
--   Identify users who have the highest proportion of their booking
--   requests rejected, to uncover repeated policy violations or
--   misunderstandings of booking rules.
--
-- Target Audience:
--   Facility Manager, Department Administrator.
--
-- Practical Value:
--   Enables targeted training or policy clarification for users who
--   frequently submit invalid requests, reducing future rejections
--   and improving efficient use of spaces.
--
-- SQL:
SELECT
    u.user_id,
    u.full_name,
    u.role,
    u.department,
    COUNT(b.booking_id) AS total_submitted,
    SUM(CASE WHEN b.booking_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_count,
    CAST(
        100.0 * SUM(CASE WHEN b.booking_status = 'Rejected' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(b.booking_id), 0) AS DECIMAL(5,2)
    ) AS rejection_rate_pct
FROM [USER] u
JOIN BOOKING b ON u.user_id = b.requester_id
GROUP BY u.user_id, u.full_name, u.role, u.department
HAVING SUM(CASE WHEN b.booking_status = 'Rejected' THEN 1 ELSE 0 END) > 0
ORDER BY rejection_rate_pct DESC, rejected_count DESC;
GO

/*
Sample Output (based on our test data):
user_id      full_name       role                department         total_submitted rejected_count rejection_rate_pct
-----------  --------------  ------------------- ------------------ --------------- -------------- ------------------
TA2024001    James Wilson    Teaching Assistant  Computer Science               2              1              50.00
ADM2018001   David Park      Department Admin.   Computer Science               3              1              33.33
*/