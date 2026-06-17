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
-- What we're trying to find out:
--   How much are our different space types actually being used?
--   We want the total hours each type of room has been occupied
--   based on real check-in/check-out data from usage sessions.
--
-- Who would use this:
--   Facility managers — so they can figure out which room types
--   are in high demand and which ones are sitting empty most of
--   the time.
--
-- Why this matters:
--   If we see that computer labs are getting way more usage than
--   meeting rooms, the school can decide to convert underused
--   spaces or adjust schedules. It's the main metric
--   for deciding if our rooms are being used efficiently.
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
-- What we're trying to find out:
--   Which days and hours get the most booking traffic? We're
--   looking at approved, checked-in, and completed bookings to
--   see when demand is highest.
--
-- Who would use this:
--   Facility managers and staff — they need to know when to
--   schedule extra help at the front desk and when it's safe
--   to do maintenance without disrupting anyone.
--
-- Why this matters:
--   If most bookings happen on Wednesdays between 9-11 AM,
--   that's when we need the most staff on duty. We can also
--   schedule cleaning and repairs during the quieter slots.
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
-- What we're trying to find out:
--   Which users are wasting room slots by not showing up or
--   cancelling their bookings? We calculate a "waste ratio"
--   for each person.
--
-- Who would use this:
--   Facility managers and department admins — they can use
--   this to spot repeat offenders and decide whether to send
--   warnings or even suspend booking privileges.
--
-- Why this matters:
--   Every no-show or late cancellation means a room sat empty
--   when someone else could have used it. Tracking this lets
--   the school enforce accountability and keep things fair
--   for everyone.
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
-- What we're trying to find out:
--   For each room, how many maintenance events have happened,
--   how many are still open, and how many total hours the room
--   has been down? We also pull the most frequent problem type
--   for each space.
--
-- Who would use this:
--   Facility managers — if a room keeps breaking down because
--   of the same issue (like the AC keeps dying), they can
--   justify budget for a proper fix instead of patching it
--   every time.
--
-- Why this matters:
--   Chronic maintenance issues hurt everyone. Students lose
--   access to rooms, staff waste time on repeat repairs, and
--   the school loses money. This query gives hard numbers to
--   back up repair/replacement decisions.
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
-- What we're trying to find out:
--   Which available rooms have at least 15 seats, come with a
--   working projector, and are free during a specific time slot?
--   This is basically the search logic behind a booking form.
--
-- Who would use this:
--   Students, lecturers, TAs, department admins — anyone who
--   needs to find and book a room that fits their requirements.
--
-- Why this matters:
--   This is the most practical query in the whole system. Instead
--   of manually checking each room's capacity, equipment list,
--   and booking calendar, this query does it all in one shot.
--   It filters out rooms that are under maintenance, already
--   booked, or don't have the right equipment.
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
