-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 14: Post-Generation Validation Script
-- File: 02-validate-data.sql
--
-- Verifies:
--   - Row counts meet minimum thresholds
--   - All enum/domain values are populated
--   - Academic year coverage spans 3 years
--   - Data integrity (FK, CHECK, business rules)
--   - Usage session alignment
--   - Advisory acknowledgement and impact history presence
-- ============================================================

USE University;
GO

SET NOCOUNT ON;
GO

PRINT '============================================================';
PRINT 'Step 14: Post-Generation Validation Report';
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
-- Check 2: Academic Year Coverage
-- ============================================================
PRINT '';
PRINT '--- Check 2: Academic Year Coverage ---';

SELECT
    'ACADEMIC YEAR COVERAGE' AS check_type,
    MIN(requested_start) AS earliest_booking,
    MAX(requested_start) AS latest_booking,
    COUNT(DISTINCT YEAR(requested_start)) AS distinct_years,
    CASE WHEN COUNT(DISTINCT YEAR(requested_start)) >= 3 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING;

-- Distribution by year
SELECT
    'YEAR DISTRIBUTION' AS check_type,
    YEAR(requested_start) AS booking_year,
    COUNT(*) AS booking_count
FROM dbo.BOOKING
GROUP BY YEAR(requested_start)
ORDER BY booking_year;
GO

-- ============================================================
-- Check 3: Enum Coverage — USER.role
-- ============================================================
PRINT '';
PRINT '--- Check 3: Enum Coverage ---';

SELECT 'USER.role' AS check_type, role AS enum_value, COUNT(*) AS count
FROM dbo.[USER] GROUP BY role ORDER BY role;

SELECT 'USER.account_status' AS check_type, account_status AS enum_value, COUNT(*) AS count
FROM dbo.[USER] GROUP BY account_status ORDER BY account_status;
GO

-- ============================================================
-- Check 4: Enum Coverage — SPACE
-- ============================================================
SELECT 'SPACE.space_type' AS check_type, space_type AS enum_value, COUNT(*) AS count
FROM dbo.SPACE GROUP BY space_type ORDER BY space_type;

SELECT 'SPACE.current_status' AS check_type, current_status AS enum_value, COUNT(*) AS count
FROM dbo.SPACE GROUP BY current_status ORDER BY current_status;
GO

-- ============================================================
-- Check 5: Enum Coverage — SPACE_FACILITY
-- ============================================================
SELECT 'SPACE_FACILITY.operation_status' AS check_type, operation_status AS enum_value, COUNT(*) AS count
FROM dbo.SPACE_FACILITY GROUP BY operation_status ORDER BY operation_status;
GO

-- ============================================================
-- Check 6: Enum Coverage — BOOKING
-- ============================================================
EXEC('SELECT ''BOOKING.booking_status'' AS check_type, booking_status AS enum_value, COUNT(*) AS count FROM dbo.BOOKING GROUP BY booking_status ORDER BY booking_status;');

EXEC('SELECT ''BOOKING.purpose'' AS check_type, purpose AS enum_value, COUNT(*) AS count FROM dbo.BOOKING GROUP BY purpose ORDER BY purpose;');

EXEC('SELECT ''BOOKING.approval_path'' AS check_type, approval_path AS enum_value, COUNT(*) AS count FROM dbo.BOOKING GROUP BY approval_path ORDER BY approval_path;');
GO

-- ============================================================
-- Check 7: Enum Coverage — MAINTENANCERECORD
-- ============================================================
EXEC('SELECT ''MAINTENANCERECORD.maintenance_status'' AS check_type, maintenance_status AS enum_value, COUNT(*) AS count FROM dbo.MAINTENANCERECORD GROUP BY maintenance_status ORDER BY maintenance_status;');

EXEC('SELECT ''MAINTENANCERECORD.problem_type'' AS check_type, problem_type AS enum_value, COUNT(*) AS count FROM dbo.MAINTENANCERECORD GROUP BY problem_type ORDER BY problem_type;');

EXEC('SELECT ''MAINTENANCERECORD.impact_level'' AS check_type, impact_level AS enum_value, COUNT(*) AS count FROM dbo.MAINTENANCERECORD GROUP BY impact_level ORDER BY impact_level;');
GO

-- ============================================================
-- Check 8: Enum Coverage — MAINTENANCE_IMPACT_HISTORY
-- ============================================================
SELECT 'IMPACT_HISTORY.old_impact_level' AS check_type, old_impact_level AS enum_value, COUNT(*) AS count
FROM dbo.MAINTENANCE_IMPACT_HISTORY GROUP BY old_impact_level ORDER BY old_impact_level;

SELECT 'IMPACT_HISTORY.new_impact_level' AS check_type, new_impact_level AS enum_value, COUNT(*) AS count
FROM dbo.MAINTENANCE_IMPACT_HISTORY GROUP BY new_impact_level ORDER BY new_impact_level;
GO

-- ============================================================
-- Check 9: Usage Session Alignment
-- ============================================================
PRINT '';
PRINT '--- Check 9: Usage Session Alignment ---';

-- Every Completed/Checked In booking should have a USAGESESSION
SELECT
    'USAGESESSION ALIGNMENT' AS check_type,
    'Bookings needing session' AS metric,
    COUNT(*) AS count,
    (SELECT COUNT(*) FROM dbo.USAGESESSION) AS sessions_found,
    CASE
        WHEN COUNT(*) = (SELECT COUNT(*) FROM dbo.USAGESESSION) THEN 'PASS'
        ELSE 'FAIL (mismatch: ' + CAST(COUNT(*) - (SELECT COUNT(*) FROM dbo.USAGESESSION) AS VARCHAR) + ')'
    END AS result
FROM dbo.BOOKING
WHERE booking_status IN ('Completed', 'Checked In');

-- No orphan sessions (sessions for non-Completed/non-CheckedIn bookings)
SELECT
    'ORPHAN SESSION CHECK' AS check_type,
    COUNT(*) AS orphan_sessions,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.USAGESESSION us
JOIN dbo.BOOKING b ON us.booking_id = b.booking_id
WHERE b.booking_status NOT IN ('Completed', 'Checked In');
GO

-- ============================================================
-- Check 10: Rejection Reason Integrity
-- ============================================================
PRINT '';
PRINT '--- Check 10: Data Integrity Checks ---';

SELECT
    'REJECTION REASON' AS check_type,
    COUNT(*) AS rejected_without_reason,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING
WHERE booking_status = 'Rejected' AND rejection_reason IS NULL;
GO

-- ============================================================
-- Check 11: Time Ordering
-- ============================================================
SELECT
    'BOOKING TIME ORDER' AS check_type,
    COUNT(*) AS invalid_time_order,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING
WHERE requested_end <= requested_start;
GO

-- ============================================================
-- Check 12: Capacity Constraint
-- ============================================================
EXEC('SELECT ''CAPACITY CONSTRAINT'' AS check_type, COUNT(*) AS over_capacity, CASE WHEN COUNT(*) = 0 THEN ''PASS'' ELSE ''FAIL'' END AS result FROM dbo.BOOKING b JOIN dbo.SPACE s ON b.space_code = s.space_code WHERE b.expected_participants > s.capacity;');
GO

-- ============================================================
-- Check 13: Staff Role Validation (Approvers)
-- ============================================================
EXEC('SELECT ''APPROVER ROLE'' AS check_type, COUNT(*) AS invalid_approvers, CASE WHEN COUNT(*) = 0 THEN ''PASS'' ELSE ''FAIL'' END AS result FROM dbo.BOOKING b JOIN dbo.[USER] u ON b.approver_id = u.user_id WHERE u.role NOT IN (''Facility Staff'', ''Facility Manager'');');
GO

-- ============================================================
-- Check 14: Approval Path Consistency
-- ============================================================
EXEC('SELECT ''INSTANT PATH CONSISTENCY'' AS check_type, COUNT(*) AS instant_with_approver, CASE WHEN COUNT(*) = 0 THEN ''PASS'' ELSE ''FAIL'' END AS result FROM dbo.BOOKING WHERE approval_path = ''Instant'' AND approver_id IS NOT NULL;');
GO

-- ============================================================
-- Check 15: Advisory Acknowledgement Audit
-- ============================================================
SELECT
    'ADVISORY ACK AUDIT' AS check_type,
    COUNT(*) AS total_acks,
    COUNT(DISTINCT booking_id) AS distinct_bookings,
    COUNT(DISTINCT maintenance_id) AS distinct_maintenance,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING_ADVISORY_ACK;
GO

-- ============================================================
-- Check 16: Impact History Audit
-- ============================================================
SELECT
    'IMPACT HISTORY AUDIT' AS check_type,
    SUM(CASE WHEN old_impact_level = 'advisory' AND new_impact_level = 'out-of-service' THEN 1 ELSE 0 END) AS escalation_count,
    SUM(CASE WHEN old_impact_level = 'out-of-service' AND new_impact_level = 'advisory' THEN 1 ELSE 0 END) AS downgrade_count,
    CASE
        WHEN SUM(CASE WHEN old_impact_level = 'advisory' AND new_impact_level = 'out-of-service' THEN 1 ELSE 0 END) > 0
         AND SUM(CASE WHEN old_impact_level = 'out-of-service' AND new_impact_level = 'advisory' THEN 1 ELSE 0 END) > 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM dbo.MAINTENANCE_IMPACT_HISTORY;
GO

-- ============================================================
-- Check 17: Overlapping Maintenance Periods
-- ============================================================
SELECT TOP 5
    'OVERLAPPING MAINTENANCE' AS check_type,
    m1.maintenance_id AS maint_1,
    m2.maintenance_id AS maint_2,
    m1.space_code,
    m1.impact_level AS impact_1,
    m2.impact_level AS impact_2
FROM dbo.MAINTENANCERECORD m1
JOIN dbo.MAINTENANCERECORD m2
    ON m1.space_code = m2.space_code
    AND m1.maintenance_id < m2.maintenance_id
    AND m1.start_time < ISNULL(m2.completion_time, '9999-12-31')
    AND ISNULL(m1.completion_time, '9999-12-31') > m2.start_time;
GO

-- ============================================================
-- Check 18: Trigger Status Verification
-- ============================================================
PRINT '';
PRINT '--- Check 18: Trigger Status ---';

SELECT
    'TRIGGER STATUS' AS check_type,
    t.name AS trigger_name,
    OBJECT_NAME(t.parent_id) AS parent_table,
    CASE WHEN t.is_disabled = 0 THEN 'ENABLED' ELSE 'DISABLED' END AS status,
    CASE WHEN t.is_disabled = 0 THEN 'PASS' ELSE 'FAIL (still disabled!)' END AS result
FROM sys.triggers t
WHERE t.parent_id IN (
    OBJECT_ID('dbo.BOOKING'),
    OBJECT_ID('dbo.MAINTENANCERECORD'),
    OBJECT_ID('dbo.USAGESESSION')
)
ORDER BY OBJECT_NAME(t.parent_id), t.name;
GO

-- ============================================================
-- Check 19: created_at <= requested_start
-- ============================================================
SELECT
    'CREATED_AT ORDER' AS check_type,
    COUNT(*) AS invalid_created_at,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.BOOKING
WHERE created_at > requested_start;
GO

-- ============================================================
-- Final Summary
-- ============================================================
PRINT '';
PRINT '============================================================';
PRINT 'Step 14: Validation Complete';
PRINT '============================================================';
GO
