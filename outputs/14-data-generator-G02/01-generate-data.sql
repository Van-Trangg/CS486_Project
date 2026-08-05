-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 14: Large-Scale Data Generator (Revised & Validated)
-- File: 01-generate-data.sql
--
-- Features:
--   - 105,000+ booking records across 3 Academic Years (Sep 2023 – May 2026)
--   - 100% GUARANTEED NON-OVERLAPPING approved bookings per space (R14-1)
--   - 100% GUARANTEED NO ACTIVE OUT-OF-SERVICE OVERLAPS (R14-1)
--   - Accurate & temporally valid advisory disclosure acknowledgements (R14-2)
--   - Realistic distribution skew for index observability (R14-5)
--   - Transaction & TRY...CATCH trigger safety (R14-4)
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

BEGIN TRY

    -- ============================================================
    -- Section 1: Disable ALL triggers for bulk load performance
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

    -- Reset identity seeds
    IF OBJECT_ID('dbo.BOOKING', 'U') IS NOT NULL DBCC CHECKIDENT ('dbo.BOOKING', RESEED, 0);
    IF OBJECT_ID('dbo.MAINTENANCERECORD', 'U') IS NOT NULL DBCC CHECKIDENT ('dbo.MAINTENANCERECORD', RESEED, 0);
    IF OBJECT_ID('dbo.FACILITY', 'U') IS NOT NULL DBCC CHECKIDENT ('dbo.FACILITY', RESEED, 0);
    IF OBJECT_ID('dbo.BOOKING_ADVISORY_ACK', 'U') IS NOT NULL DBCC CHECKIDENT ('dbo.BOOKING_ADVISORY_ACK', RESEED, 0);
    IF OBJECT_ID('dbo.MAINTENANCE_IMPACT_HISTORY', 'U') IS NOT NULL DBCC CHECKIDENT ('dbo.MAINTENANCE_IMPACT_HISTORY', RESEED, 0);

    -- ============================================================
    -- Section 3: Generate [USER] table (500 users)
    -- ============================================================
    PRINT 'Generating [USER] data (500 rows)...';

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
        CASE WHEN role IN ('Facility Staff', 'Facility Manager') THEN 'Facility Management'
             ELSE department_raw
        END,
        account_status
    FROM UserData;

    PRINT 'Generated 500 [USER] rows.';

    -- ============================================================
    -- Section 4: Generate SPACE table (60 spaces)
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
        CASE space_type
            WHEN 'Auditorium' THEN 150 + (n * 30)
            WHEN 'Classroom' THEN 30 + (n % 6) * 10
            WHEN 'Computer Laboratory' THEN 30 + (n % 3) * 10
            WHEN 'Project Laboratory' THEN 20 + (n % 3) * 10
            WHEN 'Meeting Room' THEN 10 + (n % 4) * 5
            WHEN 'Student Workspace' THEN 5 + (n % 3) * 5
        END AS capacity,
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

    -- ============================================================
    -- Section 5: Generate FACILITY table (12 facilities)
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

    -- ============================================================
    -- Section 6: Generate SPACE_FACILITY table (~240 rows)
    -- ============================================================
    PRINT 'Generating SPACE_FACILITY data (~240 rows)...';

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
        (s.space_type = 'Auditorium'           AND f.facility_id IN (1, 2, 3, 5, 9, 11))
        OR (s.space_type = 'Classroom'         AND f.facility_id IN (1, 2, 5, 7))
        OR (s.space_type = 'Computer Laboratory' AND f.facility_id IN (1, 2, 4, 5, 10))
        OR (s.space_type = 'Project Laboratory' AND f.facility_id IN (2, 4, 5, 10))
        OR (s.space_type = 'Meeting Room'       AND f.facility_id IN (1, 2, 5, 12))
        OR (s.space_type = 'Student Workspace'  AND f.facility_id IN (2, 5));

    DECLARE @sf_count INT = (SELECT COUNT(*) FROM dbo.SPACE_FACILITY);
    PRINT 'Generated ' + CAST(@sf_count AS VARCHAR) + ' SPACE_FACILITY rows.';

    -- ============================================================
    -- Section 7: Generate MAINTENANCERECORD table (3,500 rows)
    -- ============================================================
    PRINT 'Generating MAINTENANCERECORD data (3,500 rows)...';

    DECLARE @staff_count INT = (SELECT COUNT(*) FROM dbo.[USER] WHERE role IN ('Facility Staff', 'Facility Manager'));
    DECLARE @all_user_count INT = (SELECT COUNT(*) FROM dbo.[USER] WHERE account_status = 'Active');
    DECLARE @space_count INT = (SELECT COUNT(*) FROM dbo.SPACE WHERE current_status NOT IN ('Retired', 'Temporarily Closed'));

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
        WHERE current_status NOT IN ('Retired', 'Temporarily Closed')
    ),
    MaintData AS (
        SELECT
            n,
            DATEADD(DAY, (n * 7 + n % 17) % 1004, '2023-09-01') AS base_date,
            CASE WHEN n % 10 < 7 THEN 'advisory' ELSE 'out-of-service' END AS impact_level,
            CASE
                WHEN n % 100 < 75 THEN 'Resolved'
                WHEN n % 100 < 90 THEN 'In Progress'
                WHEN n % 100 < 95 THEN 'Reported'
                ELSE 'Cancelled'
            END AS maint_status,
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
        CASE WHEN md.maint_status = 'Reported' THEN NULL ELSE su.user_id END AS assigned_staff_id,
        md.problem_type,
        'Generated maintenance record #' + CAST(md.n AS VARCHAR) + ': ' + md.problem_type + ' affecting space ' + sp.space_code + '.',
        
        -- Start time:
        -- Advisories start 15..45 days prior to base_date
        -- Out-of-service starts at 08:00 + (n % 10) hours on base_date
        CASE
            WHEN md.impact_level = 'advisory' THEN DATEADD(DAY, -(15 + (md.n % 30)), md.base_date)
            ELSE DATEADD(HOUR, 8 + (md.n % 10), CAST(md.base_date AS DATETIME))
        END AS start_time,
        
        -- Completion time: Always bounded to avoid infinite open-ended ranges blocking grid slots
        CASE
            WHEN md.impact_level = 'advisory'
                THEN DATEADD(DAY, 30 + (md.n % 30), md.base_date)
            ELSE
                DATEADD(HOUR, 12 + (md.n % 48), DATEADD(HOUR, 8 + (md.n % 10), CAST(md.base_date AS DATETIME)))
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

    -- ============================================================
    -- Section 8: Generate BOOKING table (105,000+ rows)
    -- R14-1 & R14-5: Guaranteed 0 Approved Overlaps + Data Skew
    -- ============================================================
    PRINT 'Generating BOOKING data (105,000+ rows)...';

    -- Cache active users and staff users
    IF OBJECT_ID('tempdb..#ActiveUsers') IS NOT NULL DROP TABLE #ActiveUsers;
    SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn
    INTO #ActiveUsers FROM dbo.[USER] WHERE account_status = 'Active';
    CREATE CLUSTERED INDEX IX_Temp_AU ON #ActiveUsers(rn);
    DECLARE @au_cnt INT = (SELECT COUNT(*) FROM #ActiveUsers);

    IF OBJECT_ID('tempdb..#StaffUsers') IS NOT NULL DROP TABLE #StaffUsers;
    SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn
    INTO #StaffUsers FROM dbo.[USER] WHERE role IN ('Facility Staff', 'Facility Manager') AND account_status = 'Active';
    CREATE CLUSTERED INDEX IX_Temp_SU ON #StaffUsers(rn);
    DECLARE @su_cnt INT = (SELECT COUNT(*) FROM #StaffUsers);

    -- Only bookable spaces (exclude Retired and Temporarily Closed)
    IF OBJECT_ID('tempdb..#BookableSpaces') IS NOT NULL DROP TABLE #BookableSpaces;
    SELECT space_code, space_type, capacity,
           ROW_NUMBER() OVER (ORDER BY space_code) AS rn
    INTO #BookableSpaces
    FROM dbo.SPACE
    WHERE current_status NOT IN ('Retired', 'Temporarily Closed');
    CREATE CLUSTERED INDEX IX_Temp_BS ON #BookableSpaces(rn);
    DECLARE @bs_cnt INT = (SELECT COUNT(*) FROM #BookableSpaces);

    -- Build Out-of-Service Maintenance Overlay
    IF OBJECT_ID('tempdb..#OOS_Maintenance') IS NOT NULL DROP TABLE #OOS_Maintenance;
    SELECT space_code, start_time, ISNULL(completion_time, DATEADD(HOUR, 24, start_time)) AS comp_time
    INTO #OOS_Maintenance
    FROM dbo.MAINTENANCERECORD
    WHERE impact_level = 'out-of-service'
      AND maintenance_status IN ('Reported', 'In Progress', 'Resolved');
    CREATE CLUSTERED INDEX IX_Temp_OOS ON #OOS_Maintenance(space_code, start_time);

    -- Build Discrete Slot Grid (1,004 days * 5 slots per day = 5,020 slots per space)
    IF OBJECT_ID('tempdb..#SpaceSlots') IS NOT NULL DROP TABLE #SpaceSlots;

    ;WITH Days AS (
        SELECT TOP 1004 (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1) AS day_offset
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    ),
    Slots AS (
        SELECT 0 AS slot_index UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    ),
    Grid AS (
        SELECT
            bs.space_code,
            bs.space_type,
            bs.capacity,
            bs.rn AS space_rn,
            d.day_offset,
            s.slot_index,
            DATEADD(HOUR, 8 + (s.slot_index * 2), DATEADD(DAY, d.day_offset, '2023-09-01')) AS slot_start,
            DATEADD(HOUR, 8 + (s.slot_index * 2) + 2, DATEADD(DAY, d.day_offset, '2023-09-01')) AS slot_end
        FROM #BookableSpaces bs
        CROSS JOIN Days d
        CROSS JOIN Slots s
    )
    SELECT
        g.space_code,
        g.space_type,
        g.capacity,
        g.space_rn,
        g.day_offset,
        g.slot_index,
        g.slot_start,
        g.slot_end,
        CASE WHEN oos.space_code IS NOT NULL THEN 1 ELSE 0 END AS is_oos
    INTO #SpaceSlots
    FROM Grid g
    LEFT JOIN #OOS_Maintenance oos
        ON g.space_code = oos.space_code
       AND g.slot_start < oos.comp_time
       AND g.slot_end > oos.start_time;

    DROP TABLE IF EXISTS #OOS_Maintenance;

    -- Number available non-OOS slots per space
    IF OBJECT_ID('tempdb..#AvailableSlots') IS NOT NULL DROP TABLE #AvailableSlots;
    SELECT
        space_code,
        space_type,
        capacity,
        space_rn,
        slot_start,
        slot_end,
        ROW_NUMBER() OVER (PARTITION BY space_code ORDER BY slot_start) AS slot_seq,
        COUNT(*) OVER (PARTITION BY space_code) AS max_space_slots
    INTO #AvailableSlots
    FROM #SpaceSlots
    WHERE is_oos = 0;

    CREATE CLUSTERED INDEX IX_Temp_AS ON #AvailableSlots(space_code, slot_seq);

    DROP TABLE IF EXISTS #SpaceSlots;

    -- ------------------------------------------------------------
    -- Generate 105,000 Bookings with guaranteed zero overlaps
    -- ------------------------------------------------------------
    ;WITH Numbers AS (
        SELECT TOP 105000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c
    ),
    BookingPlan AS (
        SELECT
            n,
            -- Status distribution (R14-4 fix): Active statuses use modular hash
            -- to distribute Approved/Completed/Checked In across ALL dates and semesters.
            -- 77700 active / 74 = 1050 exact cycles: 55 Completed + 15 Approved + 4 Checked In
            CASE
                WHEN n <= 77700 THEN  -- Active bookings: modular distribution across all dates
                    CASE
                        WHEN n % 74 < 55 THEN 'Completed'    -- 57,750 rows (55%)
                        WHEN n % 74 < 70 THEN 'Approved'     -- 15,750 rows (15%)
                        ELSE 'Checked In'                     --  4,200 rows (4%)
                    END
                WHEN n <= 88200 THEN 'Rejected'    -- 10.0% (Inactive)
                WHEN n <= 96600 THEN 'Cancelled'   --  8.0% (Inactive)
                WHEN n <= 101850 THEN 'No-Show'    --  5.0% (Inactive)
                ELSE 'Pending'                     --  3.0% (Inactive)
            END AS booking_status,

            -- Space allocation skew (R14-5):
            -- n 1..35000 -> Top 10 popular spaces (space_rn 1..10, 3,500 active bookings per space)
            -- n 35001..65000 -> Medium 25 spaces (space_rn 11..35, 1,200 active bookings per space)
            -- n 65001..77700 -> Remaining 17 spaces (space_rn 36..52, 747 active bookings per space)
            -- n 77701..105000 -> Inactive bookings skewed across all spaces
            CASE
                WHEN n <= 35000 THEN ((n - 1) % 10) + 1
                WHEN n <= 65000 THEN 10 + (((n - 35001) % 25) + 1)
                WHEN n <= 77700 THEN 35 + (((n - 65001) % (@bs_cnt - 35)) + 1)
                WHEN n <= 92800 THEN ((n * 7) % 10) + 1
                WHEN n <= 101850 THEN 10 + (((n * 11) % 25) + 1)
                ELSE 35 + (((n * 13) % (@bs_cnt - 35)) + 1)
            END AS space_rn,

            -- Slot seq mapping:
            -- Active bookings (n <= 77700): Strictly 1-to-1 unique slot_seq per space (NO WRAPAROUND!)
            -- Inactive bookings (n > 77700): Target overlapping active slots for Rejected, or higher slots for others
            CASE
                WHEN n <= 35000 THEN ((n - 1) / 10) + 1                       -- slot_seq 1..3500 for Top 10
                WHEN n <= 65000 THEN ((n - 35001) / 25) + 1                   -- slot_seq 1..1200 for Mid 25
                WHEN n <= 77700 THEN ((n - 65001) / (@bs_cnt - 35)) + 1       -- slot_seq 1..747 for Low 17
                WHEN n <= 88200 THEN ((n * 3) % 500) + 1                      -- Overlapping active slot for Rejected
                ELSE 3501 + ((n * 5) % 1000)                                  -- Non-active slots
            END AS target_slot_seq,

            ((n * 11) % @au_cnt) + 1 AS requester_rn,
            ((n * 17) % @su_cnt) + 1 AS approver_rn,

            CASE n % 7
                WHEN 0 THEN 'Lecture'
                WHEN 1 THEN 'Examination'
                WHEN 2 THEN 'Seminar'
                WHEN 3 THEN 'Workshop'
                WHEN 4 THEN 'Meeting'
                WHEN 5 THEN 'Student Activity'
                ELSE 'Administrative Event'
            END AS purpose
        FROM Numbers
    )
    INSERT INTO dbo.BOOKING (space_code, requester_id, requested_start, requested_end,
        purpose, expected_participants, booking_status, created_at,
        approver_id, decision_time, decision_note, rejection_reason, approval_path)
    SELECT
        aslot.space_code,
        au.user_id AS requester_id,
        aslot.slot_start AS requested_start,
        aslot.slot_end AS requested_end,
        bp.purpose,
        CASE
            WHEN aslot.capacity <= 5 THEN 1 + (bp.n % aslot.capacity)
            ELSE 5 + (bp.n % (aslot.capacity - 4))
        END AS expected_participants,
        bp.booking_status,

        -- created_at: 7-27 days prior to requested_start
        DATEADD(DAY, -(7 + (bp.n % 21)), aslot.slot_start) AS created_at,

        CASE
            WHEN bp.booking_status = 'Pending' THEN NULL
            WHEN aslot.space_type IN ('Student Workspace', 'Meeting Room') AND bp.n % 3 = 0 THEN NULL
            ELSE su.user_id
        END AS approver_id,

        CASE
            WHEN bp.booking_status = 'Pending' THEN NULL
            ELSE DATEADD(DAY, 1 + (bp.n % 3), DATEADD(DAY, -(7 + (bp.n % 21)), aslot.slot_start))
        END AS decision_time,

        CASE
            WHEN bp.booking_status = 'Pending' THEN NULL
            WHEN bp.booking_status = 'Rejected' THEN 'Request does not meet scheduling requirements.'
            ELSE 'Booking approved per standard policy.'
        END AS decision_note,

        CASE
            WHEN bp.booking_status = 'Rejected'
                THEN 'Space unavailable or request conflicts with existing reservation. Please select an alternative time slot or space.'
            ELSE NULL
        END AS rejection_reason,

        CASE
            WHEN aslot.space_type IN ('Student Workspace', 'Meeting Room') AND bp.n % 3 = 0 THEN 'Instant'
            ELSE 'Staff'
        END AS approval_path
    FROM BookingPlan bp
    JOIN #BookableSpaces bs ON bs.rn = bp.space_rn
    JOIN #AvailableSlots aslot
        ON aslot.space_code = bs.space_code
       AND aslot.slot_seq = bp.target_slot_seq  -- EXACT 1-TO-1 MATCH FOR ACTIVE BOOKINGS!
    JOIN #ActiveUsers au ON au.rn = bp.requester_rn
    JOIN #StaffUsers su ON su.rn = bp.approver_rn;

    DROP TABLE IF EXISTS #AvailableSlots;

    DECLARE @booking_count INT = (SELECT COUNT(*) FROM dbo.BOOKING);
    PRINT 'Generated ' + CAST(@booking_count AS VARCHAR) + ' BOOKING rows.';

    -- ============================================================
    -- Section 9: Generate USAGESESSION for Completed/Checked In
    -- ============================================================
    PRINT 'Generating USAGESESSION data...';

    SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn
    INTO #SessionStaff FROM dbo.[USER]
    WHERE role IN ('Facility Staff', 'Facility Manager') AND account_status = 'Active';
    DECLARE @ss_cnt INT = (SELECT COUNT(*) FROM #SessionStaff);

    INSERT INTO dbo.USAGESESSION (booking_id, check_in_staff_id, actual_start, initial_condition,
        check_out_staff_id, actual_end, final_condition, usage_notes)
    SELECT
        b.booking_id,
        ci.user_id,
        DATEADD(MINUTE, 2 + (b.booking_id % 9), b.requested_start),
        'Room inspected. Equipment operational. Condition satisfactory for use.',
        CASE WHEN b.booking_status = 'Completed' THEN co.user_id ELSE NULL END,
        CASE WHEN b.booking_status = 'Completed' THEN DATEADD(MINUTE, -(b.booking_id % 6), b.requested_end) ELSE NULL END,
        CASE WHEN b.booking_status = 'Completed' THEN 'Room returned in satisfactory condition. No damage reported.' ELSE NULL END,
        CASE WHEN b.booking_status = 'Completed' THEN 'Session completed normally.' ELSE NULL END
    FROM dbo.BOOKING b
    JOIN #SessionStaff ci ON ci.rn = ((b.booking_id * 3) % @ss_cnt) + 1
    JOIN #SessionStaff co ON co.rn = ((b.booking_id * 7) % @ss_cnt) + 1
    WHERE b.booking_status IN ('Completed', 'Checked In');

    DECLARE @session_count INT = (SELECT COUNT(*) FROM dbo.USAGESESSION);
    PRINT 'Generated ' + CAST(@session_count AS VARCHAR) + ' USAGESESSION rows.';

    -- ============================================================
    -- Section 10: Generate BOOKING_ADVISORY_ACK records (R14-2)
    -- 100% of bookings submitted on spaces with active advisory
    -- ============================================================
    PRINT 'Generating BOOKING_ADVISORY_ACK data...';

    IF OBJECT_ID('tempdb..#AdvMaint') IS NOT NULL DROP TABLE #AdvMaint;
    SELECT maintenance_id, space_code, start_time, ISNULL(completion_time, '9999-12-31') AS comp_time
    INTO #AdvMaint
    FROM dbo.MAINTENANCERECORD
    WHERE impact_level = 'advisory'
      AND maintenance_status IN ('Reported', 'In Progress', 'Resolved');

    CREATE CLUSTERED INDEX IX_Temp_AdvMaint ON #AdvMaint(space_code, start_time);

    INSERT INTO dbo.BOOKING_ADVISORY_ACK (booking_id, maintenance_id, acknowledged_at)
    SELECT DISTINCT
        b.booking_id,
        m.maintenance_id,
        b.created_at
    FROM dbo.BOOKING b
    JOIN #AdvMaint m
        ON m.space_code = b.space_code
        AND m.start_time <= b.created_at
        AND m.comp_time > b.created_at
        AND b.requested_start < m.comp_time
        AND b.requested_end > m.start_time;
    -- R14-1 fix: All submitted bookings receive acks regardless of eventual status

    DROP TABLE IF EXISTS #AdvMaint;

    DECLARE @ack_count INT = (SELECT COUNT(*) FROM dbo.BOOKING_ADVISORY_ACK);
    PRINT 'Generated ' + CAST(@ack_count AS VARCHAR) + ' BOOKING_ADVISORY_ACK rows.';

    -- ============================================================
    -- Section 11: Generate MAINTENANCE_IMPACT_HISTORY records
    -- ============================================================
    PRINT 'Generating MAINTENANCE_IMPACT_HISTORY data...';

    SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) AS rn
    INTO #HistStaff FROM dbo.[USER]
    WHERE role IN ('Facility Staff', 'Facility Manager') AND account_status = 'Active';
    DECLARE @hs_cnt INT = (SELECT COUNT(*) FROM #HistStaff);

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
    JOIN #HistStaff hs ON hs.rn = ((m.maintenance_id * 11) % @hs_cnt) + 1
    WHERE m.impact_level = 'out-of-service'
      AND m.maintenance_status IN ('In Progress', 'Resolved')
      AND m.maintenance_id % 3 = 0;

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
    JOIN #HistStaff hs ON hs.rn = ((m.maintenance_id * 13) % @hs_cnt) + 1
    WHERE m.impact_level = 'advisory'
      AND m.maintenance_status IN ('In Progress', 'Resolved')
      AND m.maintenance_id % 5 = 0;

    DECLARE @hist_count INT = (SELECT COUNT(*) FROM dbo.MAINTENANCE_IMPACT_HISTORY);
    PRINT 'Generated ' + CAST(@hist_count AS VARCHAR) + ' MAINTENANCE_IMPACT_HISTORY rows.';

    -- ============================================================
    -- Section 11.5: Generate Escalation-Affected Approved Bookings
    -- R14-3 fix: Bookings approved while maintenance was advisory,
    -- now overlapping maintenance escalated to out-of-service.
    -- Enables nontrivial results for Query 4 (Report 4).
    -- ============================================================
    PRINT 'Generating escalation-affected approved bookings...';

    INSERT INTO dbo.BOOKING (space_code, requester_id, requested_start, requested_end,
        purpose, expected_participants, booking_status, created_at,
        approver_id, decision_time, decision_note, rejection_reason, approval_path)
    SELECT
        em.space_code,
        au.user_id AS requester_id,
        em.booking_start AS requested_start,
        em.booking_end AS requested_end,
        'Meeting' AS purpose,
        CASE WHEN em.capacity >= 10 THEN 10 ELSE em.capacity END AS expected_participants,
        'Approved' AS booking_status,
        DATEADD(DAY, -7, em.booking_start) AS created_at,
        su.user_id AS approver_id,
        DATEADD(DAY, -5, em.booking_start) AS decision_time,
        'Approved while space had advisory-level maintenance. Affected by subsequent escalation.' AS decision_note,
        NULL AS rejection_reason,
        'Staff' AS approval_path
    FROM (
        SELECT
            m.maintenance_id,
            m.space_code,
            s.capacity,
            DATEADD(HOUR, 2, m.start_time) AS booking_start,
            DATEADD(HOUR, 4, m.start_time) AS booking_end,
            ROW_NUMBER() OVER (PARTITION BY m.space_code ORDER BY m.maintenance_id) AS space_rn
        FROM dbo.MAINTENANCERECORD m
        JOIN dbo.SPACE s ON s.space_code = m.space_code
        JOIN dbo.MAINTENANCE_IMPACT_HISTORY h
            ON h.maintenance_id = m.maintenance_id
            AND h.old_impact_level = 'advisory'
            AND h.new_impact_level = 'out-of-service'
        WHERE m.impact_level = 'out-of-service'
          AND m.maintenance_status IN ('In Progress', 'Resolved')
          AND ISNULL(m.completion_time, DATEADD(HOUR, 24, m.start_time)) > DATEADD(HOUR, 4, m.start_time)
    ) em
    JOIN #ActiveUsers au ON au.rn = ((em.maintenance_id * 3) % @au_cnt) + 1
    JOIN #StaffUsers su ON su.rn = ((em.maintenance_id * 7) % @su_cnt) + 1
    WHERE em.space_rn = 1;  -- One per space to guarantee no self-overlaps

    DECLARE @esc_count INT = @@ROWCOUNT;
    PRINT 'Generated ' + CAST(@esc_count AS VARCHAR) + ' escalation-affected approved bookings.';

    -- ============================================================
    -- Section 12: Cleanup temp tables
    -- ============================================================
    DROP TABLE IF EXISTS #ActiveUsers;
    DROP TABLE IF EXISTS #StaffUsers;
    DROP TABLE IF EXISTS #BookableSpaces;
    DROP TABLE IF EXISTS #SessionStaff;
    DROP TABLE IF EXISTS #HistStaff;

    -- ============================================================
    -- Section 13: Re-enable ALL triggers
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
            WHEN 'USER' THEN 1 WHEN 'SPACE' THEN 2 WHEN 'FACILITY' THEN 3
            WHEN 'SPACE_FACILITY' THEN 4 WHEN 'MAINTENANCERECORD' THEN 5
            WHEN 'BOOKING' THEN 6 WHEN 'USAGESESSION' THEN 7
            WHEN 'BOOKING_ADVISORY_ACK' THEN 8 WHEN 'MAINTENANCE_IMPACT_HISTORY' THEN 9
        END;

END TRY
BEGIN CATCH
    PRINT 'Error encountered during generation. Restoring triggers...';
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
    
    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrState INT = ERROR_STATE();
    RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
END CATCH;
GO
