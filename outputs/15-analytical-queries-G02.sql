-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 16: Analytical Queries
-- File: 16-analytical-queries-G02.sql
-- ============================================================

USE University;
GO

SET NOCOUNT ON;
GO

PRINT '============================================================';
PRINT 'Step 16: Executing Analytical Queries (Group G02)';
PRINT '============================================================';
PRINT '';
GO

-- ============================================================
-- Query 1: Total Approved Booking Hours of Each Space for a Given Semester
-- ============================================================
/*
1. Business Question:
   What is the total accumulated duration (in hours) of approved bookings for each space on campus during a specified academic semester?

2. Target User:
   Facility Manager, Department Administrators, and Academic Space Planners.

3. Business Value:
   Provides essential space utilization metrics across campus buildings and room types.
   Enables administrators to identify heavily congested rooms vs underutilized spaces,
   informing future space allocation, energy management, maintenance scheduling, and capital planning.

4. Parameters:
   @SemesterName NVARCHAR(50) — Human-readable semester label (e.g., 'Fall 2024')
   @SemesterStart DATETIME    — Inclusive start timestamp of the semester (e.g., '2024-09-01 00:00:00')
   @SemesterEnd DATETIME      — Inclusive end timestamp of the semester (e.g., '2024-12-31 23:59:59')

5. SQL Statement:
   Provided below.

6. Correctness Notes:
   - Active Booking Filter: Considers only bookings in active approved states ('Approved', 'Checked In', 'Completed'). Excludes 'Pending', 'Rejected', 'Cancelled', and 'No-Show'.
   - Space Coverage: Performs a LEFT JOIN from dbo.SPACE to dbo.BOOKING so that every space in the system is reported, including spaces with zero bookings during the target semester.
   - Duration Calculation: Calculates total minutes using DATEDIFF(MINUTE, requested_start, requested_end), sums them per space, handles NULLs using ISNULL(..., 0), and divides by 60.0 to return an accurate decimal hour value without integer truncation.
   - Semester Boundary Filter: Filters bookings whose requested_start falls within [@SemesterStart, @SemesterEnd].

7. Expected Output Meaning:
   - space_code, space_name, space_type, building, capacity: Descriptive space attributes.
   - total_approved_bookings: Total count of active approved reservations during the semester.
   - total_approved_hours: Accumulated reservation hours. A value of 0.00 indicates no approved bookings occurred in that space during the semester.
*/

PRINT '--- Query 1: Total Approved Booking Hours per Space for a Given Semester ---';

-- Declare Semester Parameters (Default: Fall 2024)
DECLARE @SemesterName NVARCHAR(50) = 'Fall 2024';
DECLARE @SemesterStart DATETIME   = '2024-09-01 00:00:00';
DECLARE @SemesterEnd DATETIME     = '2024-12-31 23:59:59';

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status,
    @SemesterName AS semester,
    COUNT(b.booking_id) AS total_approved_bookings,
    CAST(ISNULL(SUM(DATEDIFF(MINUTE, b.requested_start, b.requested_end)), 0) / 60.0 AS DECIMAL(10, 2)) AS total_approved_hours
FROM dbo.SPACE s
LEFT JOIN dbo.BOOKING b
    ON s.space_code = b.space_code
   AND b.booking_status IN ('Approved', 'Checked In', 'Completed')
   AND b.requested_start >= @SemesterStart
   AND b.requested_start <= @SemesterEnd
GROUP BY
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status
ORDER BY
    total_approved_hours DESC,
    s.space_code ASC;
GO

PRINT '============================================================';
PRINT 'Query 1 Execution Complete';
PRINT '============================================================';
PRINT '';
GO

-- ============================================================
-- Query 2: Number of Approved Bookings by Weekday and Hour for a Given Semester
-- ============================================================
/*
1. Business Question:
   How many approved bookings occur on each weekday and in each hour of the day during a specified academic semester?

2. Target User:
   Facility Manager, Facility Staff, and Academic Space Planners who plan staffing, maintenance windows, and peak-hour demand.

3. Business Value:
   Reveals high- and low-demand weekday/hour buckets so the facility team can schedule staff during peak times, place maintenance in low-demand windows, and inform usage-policy decisions. Complements Query 1 (hours per space) by showing the temporal distribution of demand.

4. Parameters:
   @SemesterName NVARCHAR(50) — Human-readable semester label (e.g., 'Fall 2024')
   @SemesterStart DATETIME    — Inclusive start timestamp of the semester (e.g., '2024-09-01 00:00:00')
   @SemesterEnd DATETIME      — Inclusive end timestamp of the semester (e.g., '2024-12-31 23:59:59')

5. SQL Statement:
   Provided below.

6. Correctness Notes:
   - Active Booking Filter: Considers only bookings in active approved states ('Approved', 'Checked In', 'Completed'), matching Query 1. Excludes 'Pending', 'Rejected', 'Cancelled', and 'No-Show'.
   - Bucketing: Each booking is counted once, in the weekday and hour bucket of its requested_start. The weekday-and-hour report buckets by the requested start time, consistent with the semester boundary filter.
   - Semester Boundary Filter: Filters bookings whose requested_start falls within [@SemesterStart, @SemesterEnd].

7. Expected Output Meaning:
   - weekday_num: Numeric weekday (1 = Sunday under default DATEFIRST).
   - weekday_name: Weekday name (e.g., 'Monday').
   - start_hour: Hour bucket (0-23) of requested_start.
   - approved_booking_count: Number of active approved bookings starting in that weekday and hour.
*/

-- ============================================================
-- Performance Index
-- ============================================================
-- Supports the semester range seek on requested_start and the approved-lifecycle
-- status filter. After creating this index, Query 2's logical reads dropped from
-- 1,988 to 26 and median elapsed time from 26 ms to 6 ms (Step 15 report).

CREATE INDEX IX_BOOKING_WeekdayHour
ON BOOKING(requested_start)
WHERE booking_status IN ('Approved', 'Checked In', 'Completed');

PRINT '--- Query 2: Number of Approved Bookings by Weekday and Hour for a Given Semester ---';

-- Declare Semester Parameters (Default: Fall 2024)
DECLARE @SemesterName NVARCHAR(50) = 'Fall 2024';
DECLARE @SemesterStart DATETIME   = '2024-09-01 00:00:00';
DECLARE @SemesterEnd DATETIME     = '2024-12-31 23:59:59';

SELECT
    DATEPART(WEEKDAY, requested_start) AS weekday_num,
    DATENAME(WEEKDAY, requested_start) AS weekday_name,
    DATEPART(HOUR, requested_start) AS start_hour,
    COUNT(*) AS approved_booking_count
FROM dbo.BOOKING
WHERE booking_status IN ('Approved', 'Checked In', 'Completed')
  AND requested_start >= @SemesterStart
  AND requested_start <= @SemesterEnd
GROUP BY
    DATEPART(WEEKDAY, requested_start),
    DATENAME(WEEKDAY, requested_start),
    DATEPART(HOUR, requested_start)
ORDER BY weekday_num, start_hour;
GO

PRINT '============================================================';
PRINT 'Query 2 Execution Complete';
PRINT '============================================================';
PRINT '';
GO

-- ============================================================
-- Query 3: Available Spaces by Capacity, Facilities, and Time Period
-- ============================================================
/*
1. Business Question:
   Which campus spaces have at least the required capacity, possess all requested operational facilities, and are not occupied by approved bookings or out‑of‑service maintenance during a specified time period?

2. Target User:
   Facility Managers or Event Planners who need to find suitable rooms for meetings, classes, or events with specific equipment and capacity constraints.

3. Business Value:
   Provides a real‑time list of available spaces that meet complex criteria, reducing manual room hunting.
   Enables efficient resource allocation and improves user satisfaction by quickly presenting viable options.

4. Parameters:
   @RequiredCapacity INT          – Minimum seating/occupancy capacity required.
   @StartTime        DATETIME     – Beginning of the desired booking window.
   @EndTime          DATETIME     – End of the desired booking window.
   @RequiredFacilities TABLE      – A table variable containing facility_id(s) that the space must have (all must be operational). Populated before the query.

5. Correctness Notes:
   - Capacity: Only spaces with capacity >= @RequiredCapacity are considered.
   - Availability Status: Spaces with current_status = 'Retired' or 'Temporarily Closed' are excluded.
   - Facility Requirement: The space must have every facility listed in @RequiredFacilities and each must be marked 'Operational' in SPACE_FACILITY. 
   - Booking Conflicts: Approved bookings that overlap the requested interval disqualify the space.
   - Maintenance Conflicts: Only maintenance records with impact_level = 'out-of-service' and status in ('Reported', 'In Progress') that overlap the period are considered. 
     Advisory maintenance does not block availability. An open‑ended maintenance (completion_time IS NULL) is treated as continuing indefinitely (9999-12-31).

6. Expected Output Meaning:
   - space_code      : Unique identifier of the space.
   - space_name      : Descriptive name.
   - space_type      : e.g., Classroom, Lab, Auditorium.
   - building        : Building name.
   - floor           : Floor number.
   - room_number     : Room number.
   - capacity        : Maximum occupancy.
   - current_status  : Current operational status of the space.
   The result set is ordered by capacity ascending, then space_code.
*/

-- ============================================================
-- Performance Indexes
-- ============================================================
-- Designed to improve the performance of overlapping checks against BOOKING and MAINTENANCERECORD
-- After creating these indexes, testing revealed that query 3's execution time has reduced from approximately 3 seconds to near-instantaneous

CREATE INDEX IX_BOOKINGAPPROVED_OVERLAP
ON BOOKING(space_code, requested_start)
INCLUDE (requested_end)
WHERE booking_status IN ('Approved', 'Checked In')

CREATE INDEX IX_MAINTOOS_OVERLAP
ON MAINTENANCERECORD(space_code, start_time, completion_time)
INCLUDE (maintenance_status)
WHERE impact_level='out-of-service'

PRINT '--- Query 3: Available Spaces by Capacity, Facilities, and Time Period ---';
PRINT '--- Executing availability search ---';

-- Declare and set parameters (change according to request)
DECLARE @RequiredCapacity INT       = 10;
DECLARE @StartTime        DATETIME  = '2026-03-01 09:00:00';
DECLARE @EndTime          DATETIME  = '2026-03-01 12:00:00';

-- Required facility list: populate with the facility_id values the caller needs
DECLARE @RequiredFacilities TABLE (facility_id INT PRIMARY KEY);
--INSERT INTO @RequiredFacilities (facility_id) VALUES (1), (2); -- Projector, Whiteboard

DECLARE @RequiredFacilityCount INT = (SELECT COUNT(*) FROM @RequiredFacilities);

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
WHERE
    -- Capacity requirement
    s.capacity >= @RequiredCapacity

    -- Space must be available for booking (Retired / Temporarily Closed / In Use)
    AND s.current_status NOT IN ('Retired', 'Temporarily Closed', 'In Use')

    -- Space must have ALL required facilities, each operational
    AND @RequiredFacilityCount = (
        SELECT COUNT(DISTINCT sf.facility_id)
        FROM SPACE_FACILITY sf
        JOIN @RequiredFacilities rf ON rf.facility_id = sf.facility_id
        WHERE sf.space_code = s.space_code
          AND sf.operation_status = 'Operational'
    )

    -- No approved booking overlapping the requested period
    AND NOT EXISTS (
        SELECT 1
        FROM BOOKING b
        WHERE b.space_code = s.space_code
          AND b.booking_status IN ('Approved', 'Checked In')
          AND b.requested_start < @EndTime
          AND b.requested_end >  @StartTime
    )

    -- No OUT-OF-SERVICE maintenance overlapping the requested period (advisory maintenance does not block availability)
    AND NOT EXISTS (
        SELECT 1
        FROM MAINTENANCERECORD m
        WHERE m.space_code = s.space_code
          AND m.maintenance_status IN ('Reported', 'In Progress')
          AND m.impact_level = 'out-of-service'
          AND m.start_time < @EndTime
          AND ISNULL(m.completion_time, '9999-12-31') > @StartTime
    )

ORDER BY s.capacity ASC, s.space_code;
GO

PRINT '============================================================';
PRINT 'Query 3 Execution Complete';
PRINT '============================================================';
GO

-- ============================================================
-- QUERY 4: APPROVED BOOKINGS AFFECTED BY MAINTENANCE ESCALATION
-- ============================================================
/*
1. Business Question:
   Which approved bookings overlap the period of a selected maintenance
   record that has been escalated from advisory to out-of-service?

2. Target User(s): Facility Staff; Facility Manager.

3. Business Value:
   Identifies requesters for staff follow-up after an escalation. The result
   supports contact, relocation, cancellation, or other follow-up; it does
   not perform any of those actions.

4. Parameters:
   @maintenance_id INT: selected dbo.MAINTENANCERECORD.maintenance_id.

5. Correctness Notes:
   - dbo.MAINTENANCE_IMPACT_HISTORY records escalation events. Requires at least
     one advisory-to-out-of-service history row and returns the latest such event.
   - The selected record must currently have impact_level = 'out-of-service'.
   - NULL completion_time means open-ended maintenance and is treated as ending at 9999-12-31.
   - Half-open interval: b.requested_start < ISNULL(tm.completion_time, '9999-12-31')
     AND b.requested_end > tm.start_time.

6. Expected Output Meaning:
   Returns one row per currently approved booking on the escalated maintenance record's space
   whose requested period overlaps maintenance.
*/

PRINT '--- Query 4: Approved Bookings Affected by Maintenance Escalation ---';

DECLARE @maintenance_id INT = 18;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.MAINTENANCERECORD AS m
    WHERE m.maintenance_id = @maintenance_id
      AND m.impact_level = 'out-of-service'
      AND EXISTS
      (
          SELECT 1
          FROM dbo.MAINTENANCE_IMPACT_HISTORY AS h
          WHERE h.maintenance_id = m.maintenance_id
            AND h.old_impact_level = 'advisory'
            AND h.new_impact_level = 'out-of-service'
      )
)
    THROW 51030,
          'MaintenanceId must identify a currently out-of-service record with a recorded advisory-to-out-of-service escalation.',
          1;

;WITH TargetMaintenance AS
(
    SELECT
        m.maintenance_id,
        m.space_code,
        m.start_time,
        m.completion_time,
        m.maintenance_status,
        m.impact_level,
        escalation.history_id AS escalation_history_id,
        escalation.changed_at AS escalated_at,
        escalation.changed_by_user_id
    FROM dbo.MAINTENANCERECORD AS m
    CROSS APPLY
    (
        SELECT TOP (1)
            h.history_id,
            h.changed_at,
            h.changed_by_user_id
        FROM dbo.MAINTENANCE_IMPACT_HISTORY AS h
        WHERE h.maintenance_id = m.maintenance_id
          AND h.old_impact_level = 'advisory'
          AND h.new_impact_level = 'out-of-service'
        ORDER BY h.changed_at DESC, h.history_id DESC
    ) AS escalation
    WHERE m.maintenance_id = @maintenance_id
      AND m.impact_level = 'out-of-service'
)
SELECT
    tm.maintenance_id,
    tm.escalation_history_id,
    tm.escalated_at,
    tm.changed_by_user_id AS escalated_by_user_id,
    tm.impact_level AS maintenance_impact_level,
    tm.maintenance_status,
    tm.start_time AS maintenance_start_time,
    tm.completion_time AS maintenance_completion_time,
    s.space_code,
    s.space_name,
    b.booking_id,
    b.requested_start,
    b.requested_end,
    b.booking_status,
    b.approval_path,
    b.purpose,
    b.expected_participants,
    u.user_id AS requester_id,
    u.full_name AS requester_name,
    u.email AS requester_email,
    u.phone_number AS requester_phone_number
FROM TargetMaintenance AS tm
JOIN dbo.SPACE AS s
    ON s.space_code = tm.space_code
JOIN dbo.BOOKING AS b
    ON b.space_code = tm.space_code
   AND b.booking_status = 'Approved'
   AND b.requested_start < ISNULL(tm.completion_time, CONVERT(DATETIME, '9999-12-31', 120))
   AND b.requested_end > tm.start_time
JOIN dbo.[USER] AS u
    ON u.user_id = b.requester_id
ORDER BY b.requested_start, b.booking_id;
GO

PRINT '============================================================';
PRINT 'Query 4 Execution Complete';
PRINT '============================================================';
GO
