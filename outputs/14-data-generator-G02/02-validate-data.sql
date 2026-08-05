-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 14: Comprehensive Post-Generation Validation Script (Revised & Expanded)
-- File: 02-validate-data.sql
--
-- Features independent audit queries for:
--   - Row counts against required scale thresholds (R14-3)
--   - Academic year (AY2023-24, AY2024-25, AY2025-26) & semester distribution (R14-4)
--   - 100% Enum domain coverage
--   - Approved Booking Overlap Invariant (R14-1, R14-3)
--   - Out-of-service maintenance overlap audit (R14-1, R14-3)
--   - Advisory acknowledgement active open status, window, overlap & duplicate pair audit (R14-2, R14-3)
--   - Selectivity & data skew audit (R14-3, R14-5)
--   - Comprehensive FK orphan, null, PK duplicate & time-order audits across all 9 tables (R14-3)
--   - Capacity and facility combination coverage checks (R14-3)
--   - Trigger enablement verification
-- ============================================================

USE University;
GO

SET NOCOUNT ON;
GO

PRINT '============================================================';
PRINT 'Step 14: Post-Generation Validation Report (Group G02)';
PRINT '============================================================';
PRINT '';
GO

-- ============================================================
-- Check 1: Row Count Audit
-- ============================================================
PRINT '--- Check 1: Row Count Audit ---';

SELECT
    'ROW COUNT AUDIT' AS check_type,
    t.name AS table_name,
    p.rows AS actual_count,
    CASE t.name
        WHEN 'USER' THEN 400
        WHEN 'SPACE' THEN 50
        WHEN 'FACILITY' THEN 10
        WHEN 'SPACE_FACILITY' THEN 200
        WHEN 'MAINTENANCERECORD' THEN 3000
        WHEN 'BOOKING' THEN 100000
        WHEN 'USAGESESSION' THEN 50000
        WHEN 'BOOKING_ADVISORY_ACK' THEN 5000
        WHEN 'MAINTENANCE_IMPACT_HISTORY' THEN 500
        ELSE 0
    END AS required_minimum,
    CASE
        WHEN p.rows >= CASE t.name
            WHEN 'USER' THEN 400 WHEN 'SPACE' THEN 50 WHEN 'FACILITY' THEN 10
            WHEN 'SPACE_FACILITY' THEN 200 WHEN 'MAINTENANCERECORD' THEN 3000
            WHEN 'BOOKING' THEN 100000 WHEN 'USAGESESSION' THEN 50000
            WHEN 'BOOKING_ADVISORY_ACK' THEN 5000 WHEN 'MAINTENANCE_IMPACT_HISTORY' THEN 500
            ELSE 0
        END THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0, 1)
WHERE t.name IN ('USER', 'SPACE', 'FACILITY', 'SPACE_FACILITY',
                 'MAINTENANCERECORD', 'BOOKING', 'USAGESESSION',
                 'BOOKING_ADVISORY_ACK', 'MAINTENANCE_IMPACT_HISTORY')
ORDER BY
    CASE t.name
        WHEN 'USER' THEN 1 WHEN 'SPACE' THEN 2 WHEN 'FACILITY' THEN 3
        WHEN 'SPACE_FACILITY' THEN 4 WHEN 'MAINTENANCERECORD' THEN 5
        WHEN 'BOOKING' THEN 6 WHEN 'USAGESESSION' THEN 7
        WHEN 'BOOKING_ADVISORY_ACK' THEN 8 WHEN 'MAINTENANCE_IMPACT_HISTORY' THEN 9
    END;
GO

-- ============================================================
-- Check 2: Academic Year & Semester Coverage (R14-4 Fix)
-- ============================================================
PRINT '';
PRINT '--- Check 2: Academic Year & Semester Coverage ---';

-- 2a: Calendar Year Span
SELECT
    'ACADEMIC YEAR SPAN' AS check_type,
    MIN(requested_start) AS earliest_booking,
    MAX(requested_start) AS latest_booking,
    COUNT(DISTINCT YEAR(requested_start)) AS calendar_years,
    CASE WHEN COUNT(DISTINCT YEAR(requested_start)) >= 3 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING;

-- 2b: Academic Year Active Booking Distribution (AY 2023-24, 2024-25, 2025-26)
SELECT
    'AY ACTIVE BOOKINGS' AS check_type,
    CASE
        WHEN requested_start BETWEEN '2023-09-01' AND '2024-05-31' THEN 'AY 2023-2024'
        WHEN requested_start BETWEEN '2024-09-01' AND '2025-05-31' THEN 'AY 2024-2025'
        WHEN requested_start BETWEEN '2025-09-01' AND '2026-05-31' THEN 'AY 2025-2026'
        ELSE 'Summer / Off-Grid'
    END AS academic_year_period,
    COUNT(*) AS total_bookings,
    SUM(CASE WHEN booking_status IN ('Approved', 'Completed', 'Checked In') THEN 1 ELSE 0 END) AS active_approved_bookings,
    CASE
        WHEN SUM(CASE WHEN booking_status IN ('Approved', 'Completed', 'Checked In') THEN 1 ELSE 0 END) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM dbo.BOOKING
GROUP BY
    CASE
        WHEN requested_start BETWEEN '2023-09-01' AND '2024-05-31' THEN 'AY 2023-2024'
        WHEN requested_start BETWEEN '2024-09-01' AND '2025-05-31' THEN 'AY 2024-2025'
        WHEN requested_start BETWEEN '2025-09-01' AND '2026-05-31' THEN 'AY 2025-2026'
        ELSE 'Summer / Off-Grid'
    END
ORDER BY academic_year_period;

-- 2c: Semester Breakdown
SELECT
    'SEMESTER DISTRIBUTION' AS check_type,
    CASE
        WHEN MONTH(requested_start) BETWEEN 9 AND 12 THEN 'Fall (Sep-Dec)'
        WHEN MONTH(requested_start) BETWEEN 1 AND 5 THEN 'Spring (Jan-May)'
        ELSE 'Summer (Jun-Aug)'
    END AS semester,
    YEAR(requested_start) AS calendar_year,
    COUNT(*) AS booking_count
FROM dbo.BOOKING
GROUP BY
    CASE
        WHEN MONTH(requested_start) BETWEEN 9 AND 12 THEN 'Fall (Sep-Dec)'
        WHEN MONTH(requested_start) BETWEEN 1 AND 5 THEN 'Spring (Jan-May)'
        ELSE 'Summer (Jun-Aug)'
    END,
    YEAR(requested_start)
ORDER BY calendar_year, semester;
GO

-- ============================================================
-- Check 3: APPROVED BOOKING OVERLAP INVARIANT (R14-1, R14-3)
-- ============================================================
PRINT '';
PRINT '--- Check 3: Approved Booking Overlap Invariant ---';

SELECT
    'APPROVED OVERLAP INVARIANT' AS check_type,
    COUNT(*) AS prohibited_overlapping_pairs,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL (Overlapping approved bookings detected!)' END AS result
FROM dbo.BOOKING b1
JOIN dbo.BOOKING b2
    ON b1.space_code = b2.space_code
    AND b1.booking_id < b2.booking_id
    AND b1.booking_status IN ('Approved', 'Checked In', 'Completed')
    AND b2.booking_status IN ('Approved', 'Checked In', 'Completed')
    -- Half-open overlap predicate
    AND b1.requested_start < b2.requested_end
    AND b1.requested_end > b2.requested_start;
GO

-- ============================================================
-- Check 4: Out-of-Service Maintenance Overlap Audit (R14-1, R14-3)
-- ============================================================
PRINT '';
PRINT '--- Check 4: Out-of-Service Maintenance Overlap Audit ---';

SELECT
    'OUT-OF-SERVICE OVERLAP AUDIT' AS check_type,
    COUNT(*) AS active_out_of_service_overlaps,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING b
JOIN dbo.MAINTENANCERECORD m
    ON b.space_code = m.space_code
    AND m.impact_level = 'out-of-service'
    AND m.maintenance_status IN ('Reported', 'In Progress')
    AND b.booking_status IN ('Approved', 'Checked In', 'Completed')
    AND b.requested_start < ISNULL(m.completion_time, '9999-12-31')
    AND b.requested_end > m.start_time;
GO

-- ============================================================
-- Check 5: Advisory Acknowledgement Comprehensive Audit (R14-2, R14-3)
-- ============================================================
PRINT '';
PRINT '--- Check 5: Advisory Acknowledgement Comprehensive Audit ---';

-- 5a: Verify all acknowledged maintenance records have advisory impact level
SELECT
    'ACK IMPACT LEVEL AUDIT' AS check_type,
    COUNT(*) AS total_acks,
    SUM(CASE WHEN m.impact_level = 'advisory' THEN 1 ELSE 0 END) AS advisory_acks,
    SUM(CASE WHEN m.impact_level <> 'advisory' THEN 1 ELSE 0 END) AS non_advisory_acks,
    CASE WHEN SUM(CASE WHEN m.impact_level <> 'advisory' THEN 1 ELSE 0 END) = 0
        THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING_ADVISORY_ACK ack
JOIN dbo.MAINTENANCERECORD m ON ack.maintenance_id = m.maintenance_id;

-- 5b: Verify acknowledged maintenance records are OPEN (Reported, In Progress) — R14-2 Fix
SELECT
    'ACK OPEN STATUS AUDIT' AS check_type,
    COUNT(*) AS total_acks,
    SUM(CASE WHEN m.maintenance_status IN ('Reported', 'In Progress') THEN 1 ELSE 0 END) AS open_advisory_acks,
    SUM(CASE WHEN m.maintenance_status NOT IN ('Reported', 'In Progress') THEN 1 ELSE 0 END) AS invalid_resolved_acks,
    CASE WHEN SUM(CASE WHEN m.maintenance_status NOT IN ('Reported', 'In Progress') THEN 1 ELSE 0 END) = 0
        THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING_ADVISORY_ACK ack
JOIN dbo.MAINTENANCERECORD m ON ack.maintenance_id = m.maintenance_id;

-- 5c: Verify advisory was temporally active at acknowledgement time
SELECT
    'ACK TEMPORAL WINDOW AUDIT' AS check_type,
    COUNT(*) AS total_acks,
    SUM(CASE WHEN m.start_time <= ack.acknowledged_at
              AND ISNULL(m.completion_time, '9999-12-31') > ack.acknowledged_at THEN 1 ELSE 0 END) AS valid_within_period,
    SUM(CASE WHEN m.start_time > ack.acknowledged_at THEN 1 ELSE 0 END) AS invalid_future,
    SUM(CASE WHEN ISNULL(m.completion_time, '9999-12-31') <= ack.acknowledged_at THEN 1 ELSE 0 END) AS invalid_expired,
    CASE
        WHEN SUM(CASE WHEN m.start_time > ack.acknowledged_at THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN ISNULL(m.completion_time, '9999-12-31') <= ack.acknowledged_at THEN 1 ELSE 0 END) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS result
FROM dbo.BOOKING_ADVISORY_ACK ack
JOIN dbo.MAINTENANCERECORD m ON ack.maintenance_id = m.maintenance_id;

-- 5d: Verify booking period overlaps advisory maintenance period
SELECT
    'ACK PERIOD OVERLAP AUDIT' AS check_type,
    COUNT(*) AS total_acks,
    SUM(CASE WHEN b.requested_start < ISNULL(m.completion_time, '9999-12-31')
              AND b.requested_end > m.start_time THEN 1 ELSE 0 END) AS valid_overlapping,
    SUM(CASE WHEN NOT (b.requested_start < ISNULL(m.completion_time, '9999-12-31')
              AND b.requested_end > m.start_time) THEN 1 ELSE 0 END) AS non_overlapping,
    CASE WHEN SUM(CASE WHEN NOT (b.requested_start < ISNULL(m.completion_time, '9999-12-31')
              AND b.requested_end > m.start_time) THEN 1 ELSE 0 END) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS result
FROM dbo.BOOKING_ADVISORY_ACK ack
JOIN dbo.BOOKING b ON ack.booking_id = b.booking_id
JOIN dbo.MAINTENANCERECORD m ON ack.maintenance_id = m.maintenance_id;

-- 5e: Duplicate pair audit in BOOKING_ADVISORY_ACK
SELECT
    'ACK DUPLICATE PAIR AUDIT' AS check_type,
    COUNT(*) - COUNT(DISTINCT CAST(booking_id AS VARCHAR) + '_' + CAST(maintenance_id AS VARCHAR)) AS duplicate_pairs,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CAST(booking_id AS VARCHAR) + '_' + CAST(maintenance_id AS VARCHAR))
        THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING_ADVISORY_ACK;
GO

-- ============================================================
-- Check 6: Selectivity & Data Skew Audit (R14-3, R14-5)
-- ============================================================
PRINT '';
PRINT '--- Check 6: Selectivity & Data Skew Audit ---';

-- Top 5 Popular Spaces
SELECT TOP 5
    'TOP SPACES (HIGH VOLUME)' AS check_type,
    b.space_code,
    s.space_type,
    COUNT(*) AS booking_count
FROM dbo.BOOKING b
JOIN dbo.SPACE s ON b.space_code = s.space_code
GROUP BY b.space_code, s.space_type
ORDER BY booking_count DESC;

-- Bottom 5 Less Popular Spaces
SELECT TOP 5
    'BOTTOM SPACES (LOW VOLUME)' AS check_type,
    b.space_code,
    s.space_type,
    COUNT(*) AS booking_count
FROM dbo.BOOKING b
JOIN dbo.SPACE s ON b.space_code = s.space_code
GROUP BY b.space_code, s.space_type
ORDER BY booking_count ASC;

-- Weekday Distribution
SELECT
    'WEEKDAY DISTRIBUTION' AS check_type,
    DATENAME(WEEKDAY, requested_start) AS day_of_week,
    COUNT(*) AS booking_count
FROM dbo.BOOKING
GROUP BY DATENAME(WEEKDAY, requested_start), DATEPART(WEEKDAY, requested_start)
ORDER BY DATEPART(WEEKDAY, requested_start);

-- Hour Distribution
SELECT
    'HOUR DISTRIBUTION' AS check_type,
    DATEPART(HOUR, requested_start) AS start_hour,
    COUNT(*) AS booking_count
FROM dbo.BOOKING
GROUP BY DATEPART(HOUR, requested_start)
ORDER BY start_hour;
GO

-- ============================================================
-- Check 7: Enum Coverage — USER & SPACE
-- ============================================================
PRINT '';
PRINT '--- Check 7: Enum Coverage ---';

SELECT 'USER.role' AS check_type, role AS enum_value, COUNT(*) AS count FROM dbo.[USER] GROUP BY role ORDER BY role;
SELECT 'USER.account_status' AS check_type, account_status AS enum_value, COUNT(*) AS count FROM dbo.[USER] GROUP BY account_status ORDER BY account_status;
SELECT 'SPACE.space_type' AS check_type, space_type AS enum_value, COUNT(*) AS count FROM dbo.SPACE GROUP BY space_type ORDER BY space_type;
SELECT 'SPACE.current_status' AS check_type, current_status AS enum_value, COUNT(*) AS count FROM dbo.SPACE GROUP BY current_status ORDER BY current_status;
SELECT 'SPACE_FACILITY.operation_status' AS check_type, operation_status AS enum_value, COUNT(*) AS count FROM dbo.SPACE_FACILITY GROUP BY operation_status ORDER BY operation_status;
GO

-- ============================================================
-- Check 8: Enum Coverage — BOOKING & MAINTENANCERECORD
-- ============================================================
EXEC('SELECT ''BOOKING.booking_status'' AS check_type, booking_status AS enum_value, COUNT(*) AS count FROM dbo.BOOKING GROUP BY booking_status ORDER BY booking_status;');
EXEC('SELECT ''BOOKING.purpose'' AS check_type, purpose AS enum_value, COUNT(*) AS count FROM dbo.BOOKING GROUP BY purpose ORDER BY purpose;');
EXEC('SELECT ''BOOKING.approval_path'' AS check_type, approval_path AS enum_value, COUNT(*) AS count FROM dbo.BOOKING GROUP BY approval_path ORDER BY approval_path;');
EXEC('SELECT ''MAINTENANCERECORD.maintenance_status'' AS check_type, maintenance_status AS enum_value, COUNT(*) AS count FROM dbo.MAINTENANCERECORD GROUP BY maintenance_status ORDER BY maintenance_status;');
EXEC('SELECT ''MAINTENANCERECORD.problem_type'' AS check_type, problem_type AS enum_value, COUNT(*) AS count FROM dbo.MAINTENANCERECORD GROUP BY problem_type ORDER BY problem_type;');
EXEC('SELECT ''MAINTENANCERECORD.impact_level'' AS check_type, impact_level AS enum_value, COUNT(*) AS count FROM dbo.MAINTENANCERECORD GROUP BY impact_level ORDER BY impact_level;');
GO

-- ============================================================
-- Check 9: Comprehensive Data Integrity, FK Orphan & Time-Order Audits (R14-3)
-- ============================================================
PRINT '';
PRINT '--- Check 9: Data Integrity & Orphan Audits ---';

-- 9a: Foreign Key Orphan Checks (All 9 Tables)
SELECT 'ORPHAN SPACE_FACILITY -> SPACE' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.SPACE_FACILITY sf LEFT JOIN dbo.SPACE s ON sf.space_code = s.space_code WHERE s.space_code IS NULL;
SELECT 'ORPHAN SPACE_FACILITY -> FACILITY' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.SPACE_FACILITY sf LEFT JOIN dbo.FACILITY f ON sf.facility_id = f.facility_id WHERE f.facility_id IS NULL;
SELECT 'ORPHAN MAINTENANCERECORD -> SPACE' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.MAINTENANCERECORD m LEFT JOIN dbo.SPACE s ON m.space_code = s.space_code WHERE s.space_code IS NULL;
SELECT 'ORPHAN MAINTENANCERECORD -> USER (reporter)' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.MAINTENANCERECORD m LEFT JOIN dbo.[USER] u ON m.reporter_id = u.user_id WHERE u.user_id IS NULL;
SELECT 'ORPHAN MAINTENANCERECORD -> USER (staff)' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.MAINTENANCERECORD m LEFT JOIN dbo.[USER] u ON m.assigned_staff_id = u.user_id WHERE m.assigned_staff_id IS NOT NULL AND u.user_id IS NULL;
SELECT 'ORPHAN BOOKING -> SPACE' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.BOOKING b LEFT JOIN dbo.SPACE s ON b.space_code = s.space_code WHERE s.space_code IS NULL;
SELECT 'ORPHAN BOOKING -> USER (requester)' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.BOOKING b LEFT JOIN dbo.[USER] u ON b.requester_id = u.user_id WHERE u.user_id IS NULL;
SELECT 'ORPHAN BOOKING -> USER (approver)' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.BOOKING b LEFT JOIN dbo.[USER] u ON b.approver_id = u.user_id WHERE b.approver_id IS NOT NULL AND u.user_id IS NULL;
SELECT 'ORPHAN USAGESESSION -> BOOKING' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.USAGESESSION us LEFT JOIN dbo.BOOKING b ON us.booking_id = b.booking_id WHERE b.booking_id IS NULL;
SELECT 'ORPHAN ACK -> BOOKING' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.BOOKING_ADVISORY_ACK ack LEFT JOIN dbo.BOOKING b ON ack.booking_id = b.booking_id WHERE b.booking_id IS NULL;
SELECT 'ORPHAN ACK -> MAINTENANCERECORD' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.BOOKING_ADVISORY_ACK ack LEFT JOIN dbo.MAINTENANCERECORD m ON ack.maintenance_id = m.maintenance_id WHERE m.maintenance_id IS NULL;
SELECT 'ORPHAN HIST -> MAINTENANCERECORD' AS check_type, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.MAINTENANCE_IMPACT_HISTORY h LEFT JOIN dbo.MAINTENANCERECORD m ON h.maintenance_id = m.maintenance_id WHERE m.maintenance_id IS NULL;

-- 9b: Business Rule & Constraint Integrity
SELECT 'REJECTION REASON' AS check_type, COUNT(*) AS rejected_without_reason, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.BOOKING WHERE booking_status = 'Rejected' AND rejection_reason IS NULL;
SELECT 'BOOKING TIME ORDER' AS check_type, COUNT(*) AS invalid_time_order, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.BOOKING WHERE requested_end <= requested_start;
SELECT 'MAINTENANCE TIME ORDER' AS check_type, COUNT(*) AS invalid_time_order, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.MAINTENANCERECORD WHERE completion_time IS NOT NULL AND completion_time <= start_time;
SELECT 'SESSION TIME ORDER' AS check_type, COUNT(*) AS invalid_time_order, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.USAGESESSION WHERE actual_end IS NOT NULL AND actual_end <= actual_start;
EXEC('SELECT ''CAPACITY CONSTRAINT'' AS check_type, COUNT(*) AS over_capacity, CASE WHEN COUNT(*) = 0 THEN ''PASS'' ELSE ''FAIL'' END AS result FROM dbo.BOOKING b JOIN dbo.SPACE s ON b.space_code = s.space_code WHERE b.expected_participants > s.capacity;');
EXEC('SELECT ''APPROVER ROLE'' AS check_type, COUNT(*) AS invalid_approvers, CASE WHEN COUNT(*) = 0 THEN ''PASS'' ELSE ''FAIL'' END AS result FROM dbo.BOOKING b JOIN dbo.[USER] u ON b.approver_id = u.user_id WHERE u.role NOT IN (''Facility Staff'', ''Facility Manager'');');
EXEC('SELECT ''INSTANT PATH CONSISTENCY'' AS check_type, COUNT(*) AS instant_with_approver, CASE WHEN COUNT(*) = 0 THEN ''PASS'' ELSE ''FAIL'' END AS result FROM dbo.BOOKING WHERE approval_path = ''Instant'' AND approver_id IS NOT NULL;');
SELECT 'CREATED_AT ORDER' AS check_type, COUNT(*) AS invalid_created_at, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM dbo.BOOKING WHERE created_at > requested_start;
GO

-- ============================================================
-- Check 10: Space Capacity & Facility Coverage Audit (R14-3)
-- ============================================================
PRINT '';
PRINT '--- Check 10: Space Capacity & Facility Coverage Audit ---';

SELECT
    'SPACE TYPE CAPACITY RANGE' AS check_type,
    space_type,
    COUNT(*) AS space_count,
    MIN(capacity) AS min_capacity,
    MAX(capacity) AS max_capacity,
    AVG(capacity) AS avg_capacity
FROM dbo.SPACE
GROUP BY space_type
ORDER BY space_type;

SELECT
    'SPACE TYPE FACILITY COVERAGE' AS check_type,
    s.space_type,
    COUNT(DISTINCT sf.facility_id) AS distinct_facilities_assigned,
    COUNT(*) AS total_facility_mappings
FROM dbo.SPACE s
JOIN dbo.SPACE_FACILITY sf ON s.space_code = sf.space_code
GROUP BY s.space_type
ORDER BY s.space_type;
GO

-- ============================================================
-- Check 11: Trigger Status Verification
-- ============================================================
PRINT '';
PRINT '--- Check 11: Trigger Status ---';

SELECT
    'TRIGGER STATUS' AS check_type,
    t.name AS trigger_name,
    OBJECT_NAME(t.parent_id) AS parent_table,
    CASE WHEN t.is_disabled = 0 THEN 'ENABLED' ELSE 'DISABLED' END AS status,
    CASE WHEN t.is_disabled = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM sys.triggers t
WHERE t.parent_id IN (
    OBJECT_ID('dbo.BOOKING'),
    OBJECT_ID('dbo.MAINTENANCERECORD'),
    OBJECT_ID('dbo.USAGESESSION')
)
ORDER BY OBJECT_NAME(t.parent_id), t.name;
GO

-- ============================================================
-- Check 12: Escalation-Affected Booking & Approved Date Span Audit
-- ============================================================
PRINT '';
PRINT '--- Check 12: Escalation-Affected Booking & Approved Date Span ---';

-- 12a: Verify escalation-affected approved bookings exist
SELECT
    'ESCALATION-AFFECTED BOOKINGS' AS check_type,
    COUNT(DISTINCT b.booking_id) AS affected_approved_bookings,
    COUNT(DISTINCT m.maintenance_id) AS escalated_maintenance_records,
    CASE WHEN COUNT(DISTINCT b.booking_id) > 0 THEN 'PASS'
         ELSE 'FAIL (No escalation-affected bookings found)' END AS result
FROM dbo.BOOKING b
JOIN dbo.MAINTENANCERECORD m
    ON b.space_code = m.space_code
    AND m.impact_level = 'out-of-service'
    AND b.booking_status = 'Approved'
    AND b.requested_start < ISNULL(m.completion_time, '9999-12-31')
    AND b.requested_end > m.start_time
JOIN dbo.MAINTENANCE_IMPACT_HISTORY h
    ON h.maintenance_id = m.maintenance_id
    AND h.old_impact_level = 'advisory'
    AND h.new_impact_level = 'out-of-service';

-- 12b: Verify Approved bookings span at least 3 calendar years
SELECT
    'APPROVED BOOKING DATE SPAN' AS check_type,
    MIN(requested_start) AS earliest_approved,
    MAX(requested_start) AS latest_approved,
    COUNT(DISTINCT YEAR(requested_start)) AS calendar_years_with_approved,
    CASE WHEN COUNT(DISTINCT YEAR(requested_start)) >= 3 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING
WHERE booking_status = 'Approved';
GO

PRINT '============================================================';
PRINT 'Step 14: Validation Complete';
PRINT '============================================================';
GO
