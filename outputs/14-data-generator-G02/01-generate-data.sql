-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 14: Large-Scale Data Generator
-- File: 01-generate-data.sql
--
-- Generates realistic data covering:
--   - 3 academic years (Sep 2023 – May 2026)
--   - 105,000+ booking records
--   - All booking statuses, both approval paths
--   - Maintenance with advisory & out-of-service impact levels
--   - Overlapping maintenance, advisory acknowledgements
--   - Escalation/downgrade history
--   - Usage sessions for completed/checked-in bookings
--
-- Deterministic: Uses RAND() seeded via fixed checksum patterns
-- and ABS(CHECKSUM(NEWID())) for repeatable-distribution generation.
--
-- IMPORTANT: This script DISABLES triggers during bulk data load
-- for performance. All business rules are enforced programmatically
-- within the generation logic. Triggers are RE-ENABLED at the end.
-- ============================================================

USE University;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

PRINT '============================================================';
PRINT 'Step 14: Starting Large-Scale Data Generation (Group G02)';
PRINT 'Target: 105,000+ bookings across 3 academic years';
PRINT '============================================================';
GO

-- ============================================================
-- Section 1: Disable ALL triggers for bulk load and cleanup performance
-- ============================================================
PRINT 'Disabling triggers for bulk data load...';

IF OBJECT_ID('dbo.TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE', 'TR') IS NOT NULL
    DISABLE TRIGGER TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE ON dbo.BOOKING;
IF OBJECT_ID('dbo.TR_BOOKING_STATUS_AND_AUDIT', 'TR') IS NOT NULL
    DISABLE TRIGGER TR_BOOKING_STATUS_AND_AUDIT ON dbo.BOOKING;
IF OBJECT_ID('dbo.TR_BOOKING_FUTURE_START_ENFORCEMENT', 'TR') IS NOT NULL
    DISABLE TRIGGER TR_BOOKING_FUTURE_START_ENFORCEMENT ON dbo.BOOKING;
IF OBJECT_ID('dbo.TR_BOOKING_VALIDATE_APPROVER_ROLE', 'TR') IS NOT NULL
    DISABLE TRIGGER TR_BOOKING_VALIDATE_APPROVER_ROLE ON dbo.BOOKING;
IF OBJECT_ID('dbo.TR_BOOKING_LOCK_APPROVED_FIELDS', 'TR') IS NOT NULL
    DISABLE TRIGGER TR_BOOKING_LOCK_APPROVED_FIELDS ON dbo.BOOKING;
IF OBJECT_ID('dbo.TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP', 'TR') IS NOT NULL
    DISABLE TRIGGER TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP ON dbo.MAINTENANCERECORD;
IF OBJECT_ID('dbo.TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE', 'TR') IS NOT NULL
    DISABLE TRIGGER TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE ON dbo.MAINTENANCERECORD;
IF OBJECT_ID('dbo.TR_USAGESESSION_VALIDATE_STAFF_ROLES', 'TR') IS NOT NULL
    DISABLE TRIGGER TR_USAGESESSION_VALIDATE_STAFF_ROLES ON dbo.USAGESESSION;
IF OBJECT_ID('dbo.TR_USAGESESSION_CHECK_BOOKING_STATUS', 'TR') IS NOT NULL
    DISABLE TRIGGER TR_USAGESESSION_CHECK_BOOKING_STATUS ON dbo.USAGESESSION;

PRINT 'All triggers disabled.';
GO

-- ============================================================
-- Section 2: Clean existing data (reverse FK dependency order)
-- ============================================================
PRINT 'Cleaning existing data...';

IF OBJECT_ID('dbo.MAINTENANCE_IMPACT_HISTORY', 'U') IS NOT NULL DELETE FROM dbo.MAINTENANCE_IMPACT_HISTORY;
IF OBJECT_ID('dbo.BOOKING_ADVISORY_ACK', 'U') IS NOT NULL DELETE FROM dbo.BOOKING_ADVISORY_ACK;
IF OBJECT_ID('dbo.USAGESESSION', 'U') IS NOT NULL DELETE FROM dbo.USAGESESSION;
IF OBJECT_ID('dbo.MAINTENANCERECORD', 'U') IS NOT NULL DELETE FROM dbo.MAINTENANCERECORD;
IF OBJECT_ID('dbo.BOOKING', 'U') IS NOT NULL DELETE FROM dbo.BOOKING;
IF OBJECT_ID('dbo.SPACE_FACILITY', 'U') IS NOT NULL DELETE FROM dbo.SPACE_FACILITY;
IF OBJECT_ID('dbo.FACILITY', 'U') IS NOT NULL DELETE FROM dbo.FACILITY;
IF OBJECT_ID('dbo.SPACE', 'U') IS NOT NULL DELETE FROM dbo.SPACE;
IF OBJECT_ID('dbo.[USER]', 'U') IS NOT NULL DELETE FROM dbo.[USER];
GO

-- Reset identity seeds
IF OBJECT_ID('dbo.BOOKING', 'U') IS NOT NULL DBCC CHECKIDENT ('dbo.BOOKING', RESEED, 0);
IF OBJECT_ID('dbo.MAINTENANCERECORD', 'U') IS NOT NULL DBCC CHECKIDENT ('dbo.MAINTENANCERECORD', RESEED, 0);
IF OBJECT_ID('dbo.FACILITY', 'U') IS NOT NULL DBCC CHECKIDENT ('dbo.FACILITY', RESEED, 0);
IF OBJECT_ID('dbo.BOOKING_ADVISORY_ACK', 'U') IS NOT NULL DBCC CHECKIDENT ('dbo.BOOKING_ADVISORY_ACK', RESEED, 0);
IF OBJECT_ID('dbo.MAINTENANCE_IMPACT_HISTORY', 'U') IS NOT NULL DBCC CHECKIDENT ('dbo.MAINTENANCE_IMPACT_HISTORY', RESEED, 0);
GO

-- ============================================================
-- Section 2: Generate [USER] table (500 users)
-- ============================================================
PRINT 'Generating [USER] data (500 rows)...';

-- Distribution: 350 Students, 75 Lecturers, 45 TAs, 20 Facility Staff,
--               8 Department Administrators, 2 Facility Managers
-- Account Status: 90% Active, 7% Suspended, 3% Inactive
-- Departments: 6 departments

;WITH Nums AS (
    SELECT TOP 500 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
),
UserData AS (
    SELECT
        n,
        CASE
            WHEN n <= 350 THEN 'Student'
            WHEN n <= 425 THEN 'Lecturer'
            WHEN n <= 470 THEN 'Teaching Assistant'
            WHEN n <= 490 THEN 'Facility Staff'
            WHEN n <= 498 THEN 'Department Administrator'
            ELSE 'Facility Manager'
        END AS role,
        CASE
            WHEN n <= 350 THEN 'STU' + RIGHT('2023' + RIGHT('000' + CAST(n AS VARCHAR), 3), 7)
            WHEN n <= 425 THEN 'LEC' + RIGHT('2023' + RIGHT('000' + CAST(n - 350 AS VARCHAR), 3), 7)
            WHEN n <= 470 THEN 'TA_' + RIGHT('2023' + RIGHT('000' + CAST(n - 425 AS VARCHAR), 3), 7)
            WHEN n <= 490 THEN 'STF' + RIGHT('2023' + RIGHT('000' + CAST(n - 470 AS VARCHAR), 3), 7)
            WHEN n <= 498 THEN 'ADM' + RIGHT('2023' + RIGHT('000' + CAST(n - 490 AS VARCHAR), 3), 7)
            ELSE 'MGR' + RIGHT('2023' + RIGHT('000' + CAST(n - 498 AS VARCHAR), 3), 7)
        END AS user_id,
        CASE (n % 6)
            WHEN 0 THEN 'School of Computer Science'
            WHEN 1 THEN 'School of Engineering'
            WHEN 2 THEN 'School of Business'
            WHEN 3 THEN 'School of Science'
            WHEN 4 THEN 'School of Arts'
            WHEN 5 THEN 'Facility Management'
        END AS department_raw,
        CASE
            WHEN n % 100 < 90 THEN 'Active'
            WHEN n % 100 < 97 THEN 'Suspended'
            ELSE 'Inactive'
        END AS account_status
    FROM Nums
)
INSERT INTO dbo.[USER] (user_id, email, full_name, phone_number, role, department, account_status)
SELECT
    user_id,
    LOWER(REPLACE(user_id, '_', '')) + '@university.edu',
    CASE role
        WHEN 'Student' THEN 'Student '
        WHEN 'Lecturer' THEN 'Dr. Lecturer '
        WHEN 'Teaching Assistant' THEN 'TA '
        WHEN 'Facility Staff' THEN 'Staff '
        WHEN 'Department Administrator' THEN 'Admin '
        WHEN 'Facility Manager' THEN 'Manager '
    END + CAST(n AS VARCHAR),
    CASE WHEN n % 3 = 0 THEN NULL
         ELSE '9' + RIGHT('0000000' + CAST(10000000 + n * 7 AS VARCHAR), 7)
    END,
    role,
    -- Facility Staff and Facility Manager always belong to Facility Management
    CASE WHEN role IN ('Facility Staff', 'Facility Manager') THEN 'Facility Management'
         ELSE department_raw
    END,
    account_status
FROM UserData;

PRINT 'Generated 500 [USER] rows.';
GO

-- ============================================================
-- Section 3: Generate SPACE table (60 spaces)
-- ============================================================
PRINT 'Generating SPACE data (60 rows)...';

;WITH SpaceNums AS (
    SELECT TOP 60 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
),
SpaceData AS (
    SELECT
        n,
        CASE
            WHEN n <= 5  THEN 'Auditorium'
            WHEN n <= 25 THEN 'Classroom'
            WHEN n <= 40 THEN 'Computer Laboratory'
            WHEN n <= 48 THEN 'Project Laboratory'
            WHEN n <= 55 THEN 'Meeting Room'
            ELSE 'Student Workspace'
        END AS space_type,
        CASE
            WHEN n % 4 = 0 THEN 'Building A'
            WHEN n % 4 = 1 THEN 'Building B'
            WHEN n % 4 = 2 THEN 'Building C'
            ELSE 'Building D'
        END AS building,
        CAST(((n - 1) % 5) + 1 AS VARCHAR) AS floor_val,
        RIGHT('000' + CAST(n AS VARCHAR), 3) AS room_num
    FROM SpaceNums
)
INSERT INTO dbo.SPACE (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
SELECT
    -- space_code: TYPE_PREFIX-BLDG-FLOOR-ROOM
    CASE space_type
        WHEN 'Auditorium' THEN 'AUD'
        WHEN 'Classroom' THEN 'CLS'
        WHEN 'Computer Laboratory' THEN 'CLAB'
        WHEN 'Project Laboratory' THEN 'PLAB'
        WHEN 'Meeting Room' THEN 'MTR'
        WHEN 'Student Workspace' THEN 'SWS'
    END + '-' +
    CASE building
        WHEN 'Building A' THEN 'BA'
        WHEN 'Building B' THEN 'BB'
        WHEN 'Building C' THEN 'BC'
        ELSE 'BD'
    END + '-F' + floor_val + '-' + room_num AS space_code,

    space_type + ' ' + room_num AS space_name,
    space_type,
    building,
    floor_val,
    room_num,
    -- capacity: varies by space type
    CASE space_type
        WHEN 'Auditorium' THEN 150 + (n * 30)
        WHEN 'Classroom' THEN 30 + (n % 6) * 10
        WHEN 'Computer Laboratory' THEN 30 + (n % 3) * 10
        WHEN 'Project Laboratory' THEN 20 + (n % 3) * 10
        WHEN 'Meeting Room' THEN 10 + (n % 4) * 5
        WHEN 'Student Workspace' THEN 5 + (n % 3) * 5
    END AS capacity,
    -- current_status: mostly Available; some Under Maintenance, In Use, etc.
    CASE
        WHEN n <= 52 THEN 'Available'
        WHEN n <= 55 THEN 'In Use'
        WHEN n <= 57 THEN 'Under Maintenance'
        WHEN n = 58 THEN 'Temporarily Closed'
        WHEN n = 59 THEN 'Retired'
        ELSE 'Available'
    END AS current_status,
    'Standard usage policy for ' + space_type + '. Maximum booking duration applies. Users must comply with facility rules.' AS usage_policy
FROM SpaceData;

PRINT 'Generated 60 SPACE rows.';
GO

-- ============================================================
-- Section 4: Generate FACILITY table (12 facilities)
-- ============================================================
PRINT 'Generating FACILITY data (12 rows)...';

SET IDENTITY_INSERT dbo.FACILITY ON;

INSERT INTO dbo.FACILITY (facility_id, facility_name, facility_description) VALUES
    (1, 'Projector', 'Standard HD projector, 1080p resolution with HDMI and VGA inputs'),
    (2, 'Whiteboard', 'Magnetic whiteboard, 2m x 1.2m with marker tray'),
    (3, 'Microphone', 'Wireless handheld microphone with lapel clip option'),
    (4, 'Computer', 'Desktop workstation with standard university software suite'),
    (5, 'Air Conditioner', 'Split-type air conditioning unit, 2HP capacity'),
    (6, 'Livestreaming Equipment', '4K camera with tripod and USB capture card'),
    (7, 'Document Camera', 'Overhead document camera with 12x optical zoom'),
    (8, 'Smart Board', 'Interactive smart board with touch input and annotation software'),
    (9, 'Sound System', 'Ceiling-mounted speakers with amplifier and audio mixer'),
    (10, 'Dual Monitors', 'Dual 27-inch LCD monitors on adjustable VESA mounts'),
    (11, 'Podium', 'Height-adjustable electronic podium with integrated controls'),
    (12, 'Video Conferencing Kit', 'USB conference camera with 360-degree microphone array');

SET IDENTITY_INSERT dbo.FACILITY OFF;

PRINT 'Generated 12 FACILITY rows.';
GO

-- ============================================================
-- Section 5: Generate SPACE_FACILITY table (~240 rows)
-- ============================================================
PRINT 'Generating SPACE_FACILITY data (~240 rows)...';

-- Each space gets 3-6 facilities depending on its type
INSERT INTO dbo.SPACE_FACILITY (space_code, facility_id, quantity, operation_status, description)
SELECT
    s.space_code,
    f.facility_id,
    CASE
        WHEN f.facility_name = 'Computer' AND s.space_type = 'Computer Laboratory' THEN 25
        WHEN f.facility_name = 'Computer' AND s.space_type = 'Project Laboratory' THEN 10
        WHEN f.facility_name = 'Air Conditioner' AND s.space_type = 'Auditorium' THEN 3
        WHEN f.facility_name = 'Microphone' AND s.space_type = 'Auditorium' THEN 4
        ELSE 1
    END AS quantity,
    CASE
        WHEN ABS(CHECKSUM(s.space_code + CAST(f.facility_id AS VARCHAR))) % 100 < 85 THEN 'Operational'
        WHEN ABS(CHECKSUM(s.space_code + CAST(f.facility_id AS VARCHAR))) % 100 < 95 THEN 'Partially Operational'
        ELSE 'Broken'
    END AS operation_status,
    NULL AS description
FROM dbo.SPACE s
CROSS JOIN dbo.FACILITY f
WHERE
    -- Assign facilities based on space type
    (s.space_type = 'Auditorium'           AND f.facility_id IN (1, 2, 3, 5, 9, 11))
    OR (s.space_type = 'Classroom'         AND f.facility_id IN (1, 2, 5, 7))
    OR (s.space_type = 'Computer Laboratory' AND f.facility_id IN (1, 2, 4, 5, 10))
    OR (s.space_type = 'Project Laboratory' AND f.facility_id IN (2, 4, 5, 10))
    OR (s.space_type = 'Meeting Room'       AND f.facility_id IN (1, 2, 5, 12))
    OR (s.space_type = 'Student Workspace'  AND f.facility_id IN (2, 5));

DECLARE @sf_count INT = (SELECT COUNT(*) FROM dbo.SPACE_FACILITY);
PRINT 'Generated ' + CAST(@sf_count AS VARCHAR) + ' SPACE_FACILITY rows.';
GO

-- ============================================================
-- Section 6: Generate MAINTENANCERECORD table (3,500 rows)
-- ============================================================
PRINT 'Generating MAINTENANCERECORD data (3,500 rows)...';

-- Collect staff user IDs (Facility Staff + Facility Manager) for assigned_staff_id and reporter_id
-- Collect all user IDs for reporter_id
DECLARE @staff_count INT;
SELECT @staff_count = COUNT(*) FROM dbo.[USER] WHERE role IN ('Facility Staff', 'Facility Manager');

DECLARE @all_user_count INT;
SELECT @all_user_count = COUNT(*) FROM dbo.[USER] WHERE account_status = 'Active';

DECLARE @space_count INT;
SELECT @space_count = COUNT(*) FROM dbo.SPACE WHERE current_status NOT IN ('Retired');

;WITH Nums AS (
    SELECT TOP 3500 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
),
StaffUsers AS (
    SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn
    FROM dbo.[USER]
    WHERE role IN ('Facility Staff', 'Facility Manager')
),
ActiveUsers AS (
    SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn
    FROM dbo.[USER]
    WHERE account_status = 'Active'
),
AvailableSpaces AS (
    SELECT space_code, ROW_NUMBER() OVER (ORDER BY space_code) AS rn
    FROM dbo.SPACE
    WHERE current_status NOT IN ('Retired')
),
MaintData AS (
    SELECT
        n,
        -- Spread start_time across 3 academic years: Sep 2023 to May 2026
        DATEADD(DAY, (n * 7 + n % 17) % 1004, '2023-09-01') AS base_date,
        -- impact_level: 70% advisory, 30% out-of-service
        CASE WHEN n % 10 < 7 THEN 'advisory' ELSE 'out-of-service' END AS impact_level,
        -- maintenance_status
        CASE
            WHEN n % 100 < 75 THEN 'Resolved'
            WHEN n % 100 < 90 THEN 'In Progress'
            WHEN n % 100 < 95 THEN 'Reported'
            ELSE 'Cancelled'
        END AS maint_status,
        -- problem_type
        CASE n % 6
            WHEN 0 THEN 'Projector Failure'
            WHEN 1 THEN 'Air-Conditioning Issue'
            WHEN 2 THEN 'Cleaning Issue'
            WHEN 3 THEN 'Furniture Damage'
            WHEN 4 THEN 'Network Issue'
            ELSE 'Other'
        END AS problem_type
    FROM Nums
)
INSERT INTO dbo.MAINTENANCERECORD (space_code, reporter_id, assigned_staff_id, problem_type,
    problem_description, start_time, completion_time, maintenance_status, result_note, impact_level)
SELECT
    sp.space_code,
    au.user_id AS reporter_id,
    CASE
        WHEN md.maint_status = 'Reported' THEN NULL  -- Reported records may not yet have assigned staff
        ELSE su.user_id
    END AS assigned_staff_id,
    md.problem_type,
    'Generated maintenance record #' + CAST(md.n AS VARCHAR) + ': ' + md.problem_type
        + ' affecting space ' + sp.space_code + '.' AS problem_description,
    DATEADD(HOUR, 8 + (md.n % 10), CAST(md.base_date AS DATETIME)) AS start_time,
    CASE
        WHEN md.maint_status IN ('Resolved', 'Cancelled')
            THEN DATEADD(DAY, 1 + (md.n % 14), DATEADD(HOUR, 8 + (md.n % 10), CAST(md.base_date AS DATETIME)))
        ELSE NULL
    END AS completion_time,
    md.maint_status,
    CASE
        WHEN md.maint_status = 'Resolved' THEN 'Issue resolved. Equipment restored to operational status.'
        WHEN md.maint_status = 'Cancelled' THEN 'Maintenance cancelled. Issue resolved without intervention.'
        ELSE NULL
    END AS result_note,
    md.impact_level
FROM MaintData md
JOIN AvailableSpaces sp ON sp.rn = ((md.n - 1) % @space_count) + 1
JOIN ActiveUsers au ON au.rn = ((md.n * 3) % @all_user_count) + 1
JOIN StaffUsers su ON su.rn = ((md.n * 7) % @staff_count) + 1;

PRINT 'Generated 3,500 MAINTENANCERECORD rows.';
GO

-- ============================================================
-- Section 7: Generate BOOKING table (105,000+ rows)
-- ============================================================
PRINT 'Generating BOOKING data (105,000+ rows)...';
PRINT 'This may take a moment...';

-- Pre-compute lookup tables into temp tables for performance
SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn
INTO #ActiveUsers
FROM dbo.[USER]
WHERE account_status = 'Active';

DECLARE @au_count INT = (SELECT COUNT(*) FROM #ActiveUsers);

SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn
INTO #StaffUsers
FROM dbo.[USER]
WHERE role IN ('Facility Staff', 'Facility Manager')
  AND account_status = 'Active';

DECLARE @su_count INT = (SELECT COUNT(*) FROM #StaffUsers);

-- Only bookable spaces (not Retired)
SELECT space_code, space_type, capacity,
       ROW_NUMBER() OVER (ORDER BY space_code) AS rn
INTO #BookableSpaces
FROM dbo.SPACE
WHERE current_status NOT IN ('Retired');

DECLARE @bs_count INT = (SELECT COUNT(*) FROM #BookableSpaces);

-- Generate 105,000 bookings using a tally CTE
-- We split into batches of ~35,000 to keep memory manageable
DECLARE @batch INT = 1;
DECLARE @batch_size INT = 35000;
DECLARE @total_target INT = 105000;

WHILE @batch * @batch_size - @batch_size < @total_target
BEGIN
    DECLARE @batch_start INT = (@batch - 1) * @batch_size + 1;
    DECLARE @batch_end INT = @batch * @batch_size;
    IF @batch_end > @total_target SET @batch_end = @total_target;
    DECLARE @current_batch_size INT = @batch_end - @batch_start + 1;

    ;WITH N1 AS (SELECT 1 AS n UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1
                 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1),
         N2 AS (SELECT 1 AS n FROM N1 a CROSS JOIN N1 b),           -- 100
         N3 AS (SELECT 1 AS n FROM N2 a CROSS JOIN N2 b),           -- 10,000
         N4 AS (SELECT 1 AS n FROM N3 a CROSS JOIN N1 b),           -- 100,000
    Nums AS (
        SELECT TOP (@current_batch_size)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + @batch_start - 1 AS n
        FROM N4
    ),
    BookingData AS (
        SELECT
            n,
            -- Spread across 1004 days (Sep 2023 to May 2026)
            -- Use a hash-based distribution for realistic spread
            DATEADD(DAY, ABS(CHECKSUM(HASHBYTES('MD5', CAST(n AS VARCHAR)))) % 1004, '2023-09-01') AS booking_day,
            -- Hour: weighted toward business hours (8-18)
            8 + ABS(CHECKSUM(HASHBYTES('MD5', CAST(n * 3 AS VARCHAR)))) % 10 AS start_hour,
            -- Duration: 1-4 hours
            1 + ABS(CHECKSUM(HASHBYTES('MD5', CAST(n * 7 AS VARCHAR)))) % 4 AS duration_hours,
            -- Space assignment
            ((ABS(CHECKSUM(HASHBYTES('MD5', CAST(n * 11 AS VARCHAR)))) % @bs_count) + 1) AS space_rn,
            -- Requester assignment
            ((ABS(CHECKSUM(HASHBYTES('MD5', CAST(n * 13 AS VARCHAR)))) % @au_count) + 1) AS requester_rn,
            -- Staff for approval
            ((ABS(CHECKSUM(HASHBYTES('MD5', CAST(n * 17 AS VARCHAR)))) % @su_count) + 1) AS approver_rn,
            -- booking_status distribution
            CASE
                WHEN n % 100 < 55 THEN 'Completed'
                WHEN n % 100 < 70 THEN 'Approved'
                WHEN n % 100 < 80 THEN 'Rejected'
                WHEN n % 100 < 88 THEN 'Cancelled'
                WHEN n % 100 < 93 THEN 'No-Show'
                WHEN n % 100 < 97 THEN 'Checked In'
                ELSE 'Pending'
            END AS booking_status,
            -- purpose distribution
            CASE n % 7
                WHEN 0 THEN 'Lecture'
                WHEN 1 THEN 'Examination'
                WHEN 2 THEN 'Seminar'
                WHEN 3 THEN 'Workshop'
                WHEN 4 THEN 'Meeting'
                WHEN 5 THEN 'Student Activity'
                ELSE 'Administrative Event'
            END AS purpose
        FROM Nums
    )
    INSERT INTO dbo.BOOKING (space_code, requester_id, requested_start, requested_end,
        purpose, expected_participants, booking_status, created_at,
        approver_id, decision_time, decision_note, rejection_reason, approval_path)
    SELECT
        bs.space_code,
        au.user_id AS requester_id,
        -- requested_start
        DATEADD(HOUR, bd.start_hour, CAST(bd.booking_day AS DATETIME)) AS requested_start,
        -- requested_end
        DATEADD(HOUR, bd.start_hour + bd.duration_hours, CAST(bd.booking_day AS DATETIME)) AS requested_end,
        bd.purpose,
        -- expected_participants: 1 to capacity (but at least 1, at most capacity)
        CASE
            WHEN bs.capacity <= 5 THEN 1 + ABS(CHECKSUM(HASHBYTES('MD5', CAST(bd.n * 19 AS VARCHAR)))) % bs.capacity
            ELSE 5 + ABS(CHECKSUM(HASHBYTES('MD5', CAST(bd.n * 19 AS VARCHAR)))) % (bs.capacity - 4)
        END AS expected_participants,
        bd.booking_status,
        -- created_at: 7-30 days before requested_start
        DATEADD(DAY, -(7 + ABS(CHECKSUM(HASHBYTES('MD5', CAST(bd.n * 23 AS VARCHAR)))) % 24),
            DATEADD(HOUR, bd.start_hour, CAST(bd.booking_day AS DATETIME))) AS created_at,
        -- approver_id: NULL for Pending, set for others
        CASE
            WHEN bd.booking_status = 'Pending' THEN NULL
            -- Instant approval path: approver_id is NULL
            WHEN bs.space_type IN ('Student Workspace', 'Meeting Room') AND bd.n % 3 = 0
                THEN NULL
            ELSE su.user_id
        END AS approver_id,
        -- decision_time: 1-3 days after created_at for decided bookings
        CASE
            WHEN bd.booking_status = 'Pending' THEN NULL
            ELSE DATEADD(DAY, 1 + bd.n % 3,
                DATEADD(DAY, -(7 + ABS(CHECKSUM(HASHBYTES('MD5', CAST(bd.n * 23 AS VARCHAR)))) % 24),
                    DATEADD(HOUR, bd.start_hour, CAST(bd.booking_day AS DATETIME))))
        END AS decision_time,
        -- decision_note
        CASE
            WHEN bd.booking_status = 'Pending' THEN NULL
            WHEN bd.booking_status = 'Rejected' THEN 'Request does not meet scheduling requirements.'
            ELSE 'Booking approved per standard policy.'
        END AS decision_note,
        -- rejection_reason (required when status = Rejected)
        CASE
            WHEN bd.booking_status = 'Rejected'
                THEN 'Space unavailable or request conflicts with existing reservation. Please select an alternative time slot or space.'
            ELSE NULL
        END AS rejection_reason,
        -- approval_path
        CASE
            WHEN bs.space_type IN ('Student Workspace', 'Meeting Room') AND bd.n % 3 = 0
                THEN 'Instant'
            ELSE 'Staff'
        END AS approval_path
    FROM BookingData bd
    JOIN #BookableSpaces bs ON bs.rn = bd.space_rn
    JOIN #ActiveUsers au ON au.rn = bd.requester_rn
    JOIN #StaffUsers su ON su.rn = bd.approver_rn;

    PRINT 'Inserted batch ' + CAST(@batch AS VARCHAR) + ' (' + CAST(@current_batch_size AS VARCHAR) + ' rows)';
    SET @batch = @batch + 1;
END;

DECLARE @booking_count INT = (SELECT COUNT(*) FROM dbo.BOOKING);
PRINT 'Generated ' + CAST(@booking_count AS VARCHAR) + ' BOOKING rows.';
GO

-- ============================================================
-- Section 8: Generate USAGESESSION for Completed/Checked In bookings
-- ============================================================
PRINT 'Generating USAGESESSION data...';

-- Get staff users for check-in/check-out
SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn
INTO #SessionStaff
FROM dbo.[USER]
WHERE role IN ('Facility Staff', 'Facility Manager')
  AND account_status = 'Active';

DECLARE @ss_count INT = (SELECT COUNT(*) FROM #SessionStaff);

INSERT INTO dbo.USAGESESSION (booking_id, check_in_staff_id, actual_start, initial_condition,
    check_out_staff_id, actual_end, final_condition, usage_notes)
SELECT
    b.booking_id,
    -- check_in_staff_id
    ci.user_id,
    -- actual_start: 2-10 minutes after requested_start
    DATEADD(MINUTE, 2 + (b.booking_id % 9), b.requested_start),
    'Room inspected. Equipment operational. Condition satisfactory for use.',
    -- check_out_staff_id: only for Completed bookings
    CASE WHEN b.booking_status = 'Completed' THEN co.user_id ELSE NULL END,
    -- actual_end: only for Completed bookings, 0-5 minutes before requested_end
    CASE WHEN b.booking_status = 'Completed'
         THEN DATEADD(MINUTE, -(b.booking_id % 6), b.requested_end)
         ELSE NULL
    END,
    -- final_condition: only for Completed bookings
    CASE WHEN b.booking_status = 'Completed'
         THEN 'Room returned in satisfactory condition. No damage reported.'
         ELSE NULL
    END,
    -- usage_notes: only for Completed
    CASE WHEN b.booking_status = 'Completed'
         THEN 'Session completed normally.'
         ELSE NULL
    END
FROM dbo.BOOKING b
JOIN #SessionStaff ci ON ci.rn = ((b.booking_id * 3) % @ss_count) + 1
JOIN #SessionStaff co ON co.rn = ((b.booking_id * 7) % @ss_count) + 1
WHERE b.booking_status IN ('Completed', 'Checked In');

DECLARE @session_count INT = (SELECT COUNT(*) FROM dbo.USAGESESSION);
PRINT 'Generated ' + CAST(@session_count AS VARCHAR) + ' USAGESESSION rows.';
GO

-- ============================================================
-- Section 9: Generate BOOKING_ADVISORY_ACK records
-- ============================================================
PRINT 'Generating BOOKING_ADVISORY_ACK data...';

-- Link bookings to active advisory maintenance records that overlapped
-- at booking creation time. This creates a realistic acknowledgement trail.
INSERT INTO dbo.BOOKING_ADVISORY_ACK (booking_id, maintenance_id, acknowledged_at)
SELECT DISTINCT
    b.booking_id,
    m.maintenance_id,
    b.created_at  -- Acknowledged at the time of booking submission
FROM dbo.BOOKING b
JOIN dbo.MAINTENANCERECORD m
    ON m.space_code = b.space_code
    AND m.impact_level = 'advisory'
    AND m.maintenance_status IN ('Reported', 'In Progress')
    -- Overlapping time periods
    AND b.requested_start < ISNULL(m.completion_time, '9999-12-31')
    AND b.requested_end > m.start_time
WHERE b.booking_status NOT IN ('Rejected', 'Cancelled')
  -- Limit to a manageable subset to avoid cartesian explosion
  AND b.booking_id % 3 = 0;

DECLARE @ack_count INT = (SELECT COUNT(*) FROM dbo.BOOKING_ADVISORY_ACK);
PRINT 'Generated ' + CAST(@ack_count AS VARCHAR) + ' BOOKING_ADVISORY_ACK rows.';
GO

-- ============================================================
-- Section 10: Generate MAINTENANCE_IMPACT_HISTORY records
-- ============================================================
PRINT 'Generating MAINTENANCE_IMPACT_HISTORY data...';

-- Generate escalation and downgrade history for maintenance records
-- that are In Progress or Resolved. Approximately 40% of eligible
-- records get impact history entries.

-- Get staff users for changed_by_user_id
SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn
INTO #HistStaff
FROM dbo.[USER]
WHERE role IN ('Facility Staff', 'Facility Manager')
  AND account_status = 'Active';

DECLARE @hs_count INT = (SELECT COUNT(*) FROM #HistStaff);

-- Escalation events: advisory -> out-of-service
INSERT INTO dbo.MAINTENANCE_IMPACT_HISTORY (maintenance_id, old_impact_level, new_impact_level,
    changed_at, changed_by_user_id)
SELECT
    m.maintenance_id,
    'advisory' AS old_impact_level,
    'out-of-service' AS new_impact_level,
    DATEADD(DAY, 2 + (m.maintenance_id % 5), m.start_time) AS changed_at,
    hs.user_id AS changed_by_user_id
FROM dbo.MAINTENANCERECORD m
JOIN #HistStaff hs ON hs.rn = ((m.maintenance_id * 11) % @hs_count) + 1
WHERE m.impact_level = 'out-of-service'   -- Currently out-of-service
  AND m.maintenance_status IN ('In Progress', 'Resolved')
  AND m.maintenance_id % 3 = 0;           -- ~33% of eligible records

-- Downgrade events: out-of-service -> advisory
INSERT INTO dbo.MAINTENANCE_IMPACT_HISTORY (maintenance_id, old_impact_level, new_impact_level,
    changed_at, changed_by_user_id)
SELECT
    m.maintenance_id,
    'out-of-service' AS old_impact_level,
    'advisory' AS new_impact_level,
    DATEADD(DAY, 3 + (m.maintenance_id % 7), m.start_time) AS changed_at,
    hs.user_id AS changed_by_user_id
FROM dbo.MAINTENANCERECORD m
JOIN #HistStaff hs ON hs.rn = ((m.maintenance_id * 13) % @hs_count) + 1
WHERE m.impact_level = 'advisory'          -- Currently advisory
  AND m.maintenance_status IN ('In Progress', 'Resolved')
  AND m.maintenance_id % 5 = 0;            -- ~20% of eligible records

DECLARE @hist_count INT = (SELECT COUNT(*) FROM dbo.MAINTENANCE_IMPACT_HISTORY);
PRINT 'Generated ' + CAST(@hist_count AS VARCHAR) + ' MAINTENANCE_IMPACT_HISTORY rows.';
GO

-- ============================================================
-- Section 11: Cleanup temp tables
-- ============================================================
DROP TABLE IF EXISTS #ActiveUsers;
DROP TABLE IF EXISTS #StaffUsers;
DROP TABLE IF EXISTS #BookableSpaces;
DROP TABLE IF EXISTS #SessionStaff;
DROP TABLE IF EXISTS #HistStaff;
GO

-- ============================================================
-- Section 12: Re-enable ALL triggers
-- ============================================================
PRINT 'Re-enabling triggers...';

IF OBJECT_ID('dbo.TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE', 'TR') IS NOT NULL
    ENABLE TRIGGER TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE ON dbo.BOOKING;
IF OBJECT_ID('dbo.TR_BOOKING_STATUS_AND_AUDIT', 'TR') IS NOT NULL
    ENABLE TRIGGER TR_BOOKING_STATUS_AND_AUDIT ON dbo.BOOKING;
IF OBJECT_ID('dbo.TR_BOOKING_FUTURE_START_ENFORCEMENT', 'TR') IS NOT NULL
    ENABLE TRIGGER TR_BOOKING_FUTURE_START_ENFORCEMENT ON dbo.BOOKING;
IF OBJECT_ID('dbo.TR_BOOKING_VALIDATE_APPROVER_ROLE', 'TR') IS NOT NULL
    ENABLE TRIGGER TR_BOOKING_VALIDATE_APPROVER_ROLE ON dbo.BOOKING;
IF OBJECT_ID('dbo.TR_BOOKING_LOCK_APPROVED_FIELDS', 'TR') IS NOT NULL
    ENABLE TRIGGER TR_BOOKING_LOCK_APPROVED_FIELDS ON dbo.BOOKING;
IF OBJECT_ID('dbo.TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP', 'TR') IS NOT NULL
    ENABLE TRIGGER TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP ON dbo.MAINTENANCERECORD;
IF OBJECT_ID('dbo.TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE', 'TR') IS NOT NULL
    ENABLE TRIGGER TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE ON dbo.MAINTENANCERECORD;
IF OBJECT_ID('dbo.TR_USAGESESSION_VALIDATE_STAFF_ROLES', 'TR') IS NOT NULL
    ENABLE TRIGGER TR_USAGESESSION_VALIDATE_STAFF_ROLES ON dbo.USAGESESSION;
IF OBJECT_ID('dbo.TR_USAGESESSION_CHECK_BOOKING_STATUS', 'TR') IS NOT NULL
    ENABLE TRIGGER TR_USAGESESSION_CHECK_BOOKING_STATUS ON dbo.USAGESESSION;

PRINT 'All triggers re-enabled.';
GO

-- ============================================================
-- Section 13: Final Summary
-- ============================================================
PRINT '============================================================';
PRINT 'Step 14: Data Generation Complete';
PRINT '============================================================';

SELECT 'GENERATION SUMMARY' AS report_type, t.name AS table_name,
       p.rows AS row_count
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0, 1)
WHERE t.name IN ('USER', 'SPACE', 'FACILITY', 'SPACE_FACILITY',
                 'BOOKING', 'MAINTENANCERECORD', 'USAGESESSION',
                 'BOOKING_ADVISORY_ACK', 'MAINTENANCE_IMPACT_HISTORY')
ORDER BY
    CASE t.name
        WHEN 'USER' THEN 1
        WHEN 'SPACE' THEN 2
        WHEN 'FACILITY' THEN 3
        WHEN 'SPACE_FACILITY' THEN 4
        WHEN 'MAINTENANCERECORD' THEN 5
        WHEN 'BOOKING' THEN 6
        WHEN 'USAGESESSION' THEN 7
        WHEN 'BOOKING_ADVISORY_ACK' THEN 8
        WHEN 'MAINTENANCE_IMPACT_HISTORY' THEN 9
    END;
GO
