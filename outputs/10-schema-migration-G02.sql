-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 10: Schema Migration DDL
-- Target Schema: Step 09 Logical Design (outputs/09-updated-erd-and-logical-design-G02.md)
-- Baseline Schema: Step 05 DDL Baseline (outputs/05-db-definition-G02.sql)
-- ============================================================

USE University;
GO

SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;
GO

PRINT '============================================================';
PRINT 'Starting Phase 2 Step 10 Schema Migration (Group G02)';
PRINT '============================================================';
GO

-- ============================================================
-- Section 1: Pre-Migration Context & Dependency Verification
-- ============================================================

IF DB_ID('University') IS NULL
BEGIN
    RAISERROR('Database [University] does not exist. Please run 05-db-definition-G02.sql first.', 16, 1);
    RETURN;
END;
GO

-- Verify required baseline tables exist before attempting migration
IF OBJECT_ID('dbo.MAINTENANCERECORD', 'U') IS NULL OR OBJECT_ID('dbo.BOOKING', 'U') IS NULL OR OBJECT_ID('dbo.USER', 'U') IS NULL
BEGIN
    RAISERROR('Required Phase 1 baseline tables (MAINTENANCERECORD, BOOKING, USER) are missing.', 16, 1);
    RETURN;
END;
GO

-- ============================================================
-- Section 2: Transactional Schema Alterations (Modified Tables)
-- ============================================================

BEGIN TRANSACTION;
BEGIN TRY

    -- ------------------------------------------------------------
    -- 2.1 Table: MAINTENANCERECORD (Change ID: C08-01, P2-BR-01/02)
    -- Add impact_level column with DEFAULT 'out-of-service' and CHECK constraint.
    -- Baseline backfill: Pre-existing maintenance records receive 'out-of-service'.
    -- ------------------------------------------------------------
    IF COL_LENGTH('dbo.MAINTENANCERECORD', 'impact_level') IS NULL
    BEGIN
        PRINT 'Adding column [impact_level] to [MAINTENANCERECORD]...';
        ALTER TABLE dbo.MAINTENANCERECORD
            ADD impact_level VARCHAR(20) NOT NULL 
                CONSTRAINT DF_MAINTENANCERECORD_IMPACT_LEVEL DEFAULT 'out-of-service';
    END;

    IF OBJECT_ID('dbo.CK_MAINTENANCERECORD_IMPACT_LEVEL', 'C') IS NULL
    BEGIN
        PRINT 'Adding CHECK constraint [CK_MAINTENANCERECORD_IMPACT_LEVEL] to [MAINTENANCERECORD]...';
        EXEC('ALTER TABLE dbo.MAINTENANCERECORD ADD CONSTRAINT CK_MAINTENANCERECORD_IMPACT_LEVEL CHECK (impact_level IN (''advisory'', ''out-of-service''));');
    END;

    -- ------------------------------------------------------------
    -- 2.2 Table: BOOKING (Change ID: C08-04, C08-06, P2-BR-07, P2-BR-10, P2-BR-11, CC-01-03)
    -- Add resolution_path column with DEFAULT 'Staff' and CHECK constraint.
    -- Baseline backfill: Pre-existing booking records receive 'Staff'.
    -- ------------------------------------------------------------
    IF COL_LENGTH('dbo.BOOKING', 'resolution_path') IS NULL
    BEGIN
        PRINT 'Adding column [resolution_path] to [BOOKING]...';
        ALTER TABLE dbo.BOOKING
            ADD resolution_path VARCHAR(20) NOT NULL 
                CONSTRAINT DF_BOOKING_RESOLUTION_PATH DEFAULT 'Staff';
    END;

    IF OBJECT_ID('dbo.CK_BOOKING_RESOLUTION_PATH', 'C') IS NULL
    BEGIN
        PRINT 'Adding CHECK constraint [CK_BOOKING_RESOLUTION_PATH] to [BOOKING]...';
        EXEC('ALTER TABLE dbo.BOOKING ADD CONSTRAINT CK_BOOKING_RESOLUTION_PATH CHECK (resolution_path IN (''Instant'', ''Staff''));');
    END;

    COMMIT TRANSACTION;
    PRINT 'Section 2 (Modified Tables Alteration) completed successfully.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrState INT = ERROR_STATE();
    RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
END CATCH;
GO

-- ============================================================
-- Section 3: Transactional Schema Creations (New Tables)
-- ============================================================

BEGIN TRANSACTION;
BEGIN TRY

    -- ------------------------------------------------------------
    -- 3.1 Table: BOOKING_ADVISORY_ACK (Change ID: C08-02, P2-BR-03)
    -- Junction table linking bookings to active advisories disclosed at submission.
    -- ------------------------------------------------------------
    IF OBJECT_ID('dbo.BOOKING_ADVISORY_ACK', 'U') IS NULL
    BEGIN
        PRINT 'Creating table [BOOKING_ADVISORY_ACK]...';
        CREATE TABLE dbo.BOOKING_ADVISORY_ACK (
            ack_id INT NOT NULL IDENTITY(1,1),
            booking_id INT NOT NULL,
            maintenance_id INT NOT NULL,
            acknowledged_at DATETIME NOT NULL CONSTRAINT DF_BOOKING_ADVISORY_ACK_ACKNOWLEDGED_AT DEFAULT GETDATE(),

            CONSTRAINT PK_BOOKING_ADVISORY_ACK
                PRIMARY KEY (ack_id),
            CONSTRAINT UQ_BOOKING_MAINTENANCE_ACK
                UNIQUE (booking_id, maintenance_id),
            CONSTRAINT FK_ACK_BOOKING
                FOREIGN KEY (booking_id) REFERENCES dbo.BOOKING(booking_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT FK_ACK_MAINTENANCE
                FOREIGN KEY (maintenance_id) REFERENCES dbo.MAINTENANCERECORD(maintenance_id) ON DELETE NO ACTION ON UPDATE NO ACTION
        );
    END;

    -- ------------------------------------------------------------
    -- 3.2 Table: MAINTENANCE_IMPACT_HISTORY (Change ID: C08-03, P2-BR-05/06)
    -- Audit table recording escalation/downgrade history of maintenance records.
    -- ------------------------------------------------------------
    IF OBJECT_ID('dbo.MAINTENANCE_IMPACT_HISTORY', 'U') IS NULL
    BEGIN
        PRINT 'Creating table [MAINTENANCE_IMPACT_HISTORY]...';
        CREATE TABLE dbo.MAINTENANCE_IMPACT_HISTORY (
            history_id INT NOT NULL IDENTITY(1,1),
            maintenance_id INT NOT NULL,
            old_impact_level VARCHAR(20) NOT NULL,
            new_impact_level VARCHAR(20) NOT NULL,
            changed_at DATETIME NOT NULL CONSTRAINT DF_MAINTENANCE_IMPACT_HISTORY_CHANGED_AT DEFAULT GETDATE(),
            changed_by_user_id VARCHAR(50) NOT NULL,

            CONSTRAINT PK_MAINTENANCE_IMPACT_HISTORY
                PRIMARY KEY (history_id),
            CONSTRAINT CK_HIST_OLD_IMPACT
                CHECK (old_impact_level IN ('advisory', 'out-of-service')),
            CONSTRAINT CK_HIST_NEW_IMPACT
                CHECK (new_impact_level IN ('advisory', 'out-of-service')),
            CONSTRAINT CK_HIST_TRANSITION
                CHECK (old_impact_level <> new_impact_level),
            CONSTRAINT FK_HIST_MAINTENANCE
                FOREIGN KEY (maintenance_id) REFERENCES dbo.MAINTENANCERECORD(maintenance_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT FK_HIST_USER
                FOREIGN KEY (changed_by_user_id) REFERENCES dbo.[USER](user_id) ON DELETE NO ACTION ON UPDATE NO ACTION
        );
    END;

    COMMIT TRANSACTION;
    PRINT 'Section 3 (New Tables Creation) completed successfully.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    DECLARE @ErrMsg2 NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrSeverity2 INT = ERROR_SEVERITY();
    DECLARE @ErrState2 INT = ERROR_STATE();
    RAISERROR(@ErrMsg2, @ErrSeverity2, @ErrState2);
END CATCH;
GO

-- ============================================================
-- Section 4: Triggers (Write-Once Constraints)
-- ============================================================

PRINT '============================================================';
PRINT 'Creating Triggers...';
PRINT '============================================================';
GO

IF OBJECT_ID('dbo.TR_BOOKING_RESOLUTION_PATH_IMMUTABLE', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TR_BOOKING_RESOLUTION_PATH_IMMUTABLE;
GO

CREATE TRIGGER dbo.TR_BOOKING_RESOLUTION_PATH_IMMUTABLE
ON dbo.BOOKING
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(resolution_path)
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM inserted i
            JOIN deleted d ON i.booking_id = d.booking_id
            WHERE i.resolution_path <> d.resolution_path
        )
        BEGIN
            RAISERROR ('The resolution_path attribute is write-once and cannot be modified after assignment.', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO

PRINT 'Trigger TR_BOOKING_RESOLUTION_PATH_IMMUTABLE created successfully.';
GO

-- 4.2 Drop obsolete Phase 1 trigger TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP (C08-01, P2-BR-06)
-- In Phase 2, maintenance creation/escalation must not be blocked by pre-existing approved bookings.
-- Overlapping approved bookings are identified via Report Query 4 for staff follow-up.
IF OBJECT_ID('dbo.TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP', 'TR') IS NOT NULL
BEGIN
    DROP TRIGGER dbo.TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP;
    PRINT 'Obsolete Phase 1 trigger [TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP] dropped successfully.';
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE
ON dbo.BOOKING
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.SPACE AS s ON s.space_code = i.space_code
        WHERE i.booking_status IN ('Approved', 'Checked In')
          AND
          (
              s.current_status IN ('Retired', 'Temporarily Closed')
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.BOOKING AS b
                  WHERE b.space_code = i.space_code
                    AND b.booking_id <> i.booking_id
                    AND b.booking_status IN ('Approved', 'Checked In')
                    AND b.requested_start < i.requested_end
                    AND b.requested_end > i.requested_start
              )
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.MAINTENANCERECORD AS m
                  WHERE m.space_code = i.space_code
                    AND m.maintenance_status IN ('Reported', 'In Progress')
                    AND m.impact_level = 'out-of-service'
                    AND m.start_time < i.requested_end
                    AND ISNULL(m.completion_time, CONVERT(DATETIME, '9999-12-31', 120)) > i.requested_start
              )
          )
    )
    BEGIN
        THROW 51001, 'Approved bookings cannot overlap another approved booking, active out-of-service maintenance, or an unavailable space.', 1;
    END;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_BOOKING_LOCK_SUBMISSION_FACTS
ON dbo.BOOKING
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d
            ON d.booking_id = i.booking_id
        WHERE
               i.requester_id <> d.requester_id
            OR i.space_code <> d.space_code
            OR i.requested_start <> d.requested_start
            OR i.requested_end <> d.requested_end
    )
    BEGIN
        THROW 51070,
            'Requester, space, and requested period cannot be changed after booking submission.',
            1;
    END;
END;
GO
/* =========================================================
   BOOKING_ADVISORY_ACK — SCHEMA INTEGRITY BACKSTOP
   ========================================================= */

-- 1. Reject acknowledgements that were not applicable
CREATE OR ALTER TRIGGER dbo.TR_BOOKING_ADVISORY_ACK_VALIDATE_INSERT
ON dbo.BOOKING_ADVISORY_ACK
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN dbo.BOOKING b
            ON b.booking_id = i.booking_id
        JOIN dbo.MAINTENANCERECORD m
            ON m.maintenance_id = i.maintenance_id
        WHERE
            -- Advisory must belong to the same space
            m.space_code <> b.space_code

            -- Must be active at acknowledgement insertion
            OR m.maintenance_status NOT IN ('Reported', 'In Progress')

            -- Only advisory maintenance may be acknowledged
            OR m.impact_level <> 'advisory'

            -- Booking interval must overlap maintenance interval
            OR NOT
            (
                m.start_time < b.requested_end
                AND (
                    m.completion_time IS NULL
                    OR m.completion_time > b.requested_start
                )
            )
    )
    BEGIN
        THROW 51020,
            'Invalid advisory acknowledgement: maintenance must be an active overlapping advisory for the booking space.',
            1;
    END;
END;
GO


-- 2. ACK rows are audit records: never update or delete them
CREATE OR ALTER TRIGGER dbo.TR_BOOKING_ADVISORY_ACK_IMMUTABLE
ON dbo.BOOKING_ADVISORY_ACK
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    THROW 51021,
        'Booking advisory acknowledgement records are immutable and cannot be updated or deleted.',
        1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_MAINTENANCE_IMPACT_HISTORY_IMMUTABLE
ON dbo.MAINTENANCE_IMPACT_HISTORY
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        THROW 51023,
            'Maintenance impact history is immutable and cannot be updated or deleted.',
            1;
    END;
END;
GO
/* ============================================================
-- 4.3 Stored Procedure Stub: dbo.sp_SubmitBooking (C08-04, C08-06, P2-BR-07, P2-BR-10)
   Booking submission and resolution-path assignment

   NOTE:
   This is intentionally NOT concurrency-safe.
   Step 12 will upgrade this procedure with:
   - explicit transaction
   - per-space UPDLOCK, HOLDLOCK
   - fresh booking-conflict check
   - Out-of-Service maintenance check
   - advisory acknowledgement validation
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_SubmitBooking
    @BookingId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @BookingId IS NULL
    BEGIN
        RAISERROR('BookingId is required.', 16, 1);
        RETURN;
    END;

    /* Booking must exist and still be pending */
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING
        WHERE booking_id = @BookingId
          AND booking_status = 'Pending'
    )
    BEGIN
        RAISERROR('Booking does not exist or is not Pending.', 16, 1);
        RETURN;
    END;

    /*
       Phase 2 resolution policy:

       Lecturer / Teaching Assistant + Classroom
       -> Instant

       All other requests
       -> Staff
    */
    IF EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        JOIN dbo.[USER] AS u
            ON u.user_id = b.requester_id
        JOIN dbo.SPACE AS s
            ON s.space_code = b.space_code
        WHERE b.booking_id = @BookingId
          AND u.role IN ('Lecturer', 'Teaching Assistant')
          AND s.space_type = 'Classroom'
    )
    BEGIN
        UPDATE dbo.BOOKING
        SET
            resolution_path = 'Instant',
            booking_status = 'Approved',
            approver_id = NULL,
            decision_time = GETDATE(),
            decision_note = 'Automatically resolved at submission.'
        WHERE booking_id = @BookingId
          AND booking_status = 'Pending';
    END
    ELSE
    BEGIN
        UPDATE dbo.BOOKING
        SET
            resolution_path = 'Staff'
        WHERE booking_id = @BookingId
          AND booking_status = 'Pending';
    END;
END;
GO

PRINT 'Placeholder procedure dbo.sp_SubmitBooking registered successfully.';
GO

-- ============================================================
-- Section 5: Post-Migration Validation & Verification Queries
-- ============================================================

PRINT '============================================================';
PRINT 'Running Post-Migration Verification Queries...';
PRINT '============================================================';
GO

-- 5.1 Verify Column Alterations and Baseline Backfill Values
SELECT 
    'MAINTENANCERECORD Columns' AS verification_check,
    c.name AS column_name,
    t.name AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.MAINTENANCERECORD')
  AND c.name = 'impact_level';

SELECT 
    'BOOKING Columns' AS verification_check,
    c.name AS column_name,
    t.name AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.BOOKING')
  AND c.name = 'resolution_path';

-- 5.2 Verify Created Tables Existence and Row Counts
SELECT 
    'Table Existence Check' AS verification_check,
    t.name AS table_name,
    t.create_date
FROM sys.tables t
WHERE t.name IN ('BOOKING_ADVISORY_ACK', 'MAINTENANCE_IMPACT_HISTORY');

-- 5.3 Verify Constraints Active Status
SELECT 
    'Active Constraints Check' AS verification_check,
    parent.name AS table_name,
    chk.name AS constraint_name,
    chk.type_desc,
    chk.is_disabled
FROM sys.check_constraints chk
JOIN sys.tables parent ON chk.parent_object_id = parent.object_id
WHERE chk.name IN (
    'CK_MAINTENANCERECORD_IMPACT_LEVEL',
    'CK_BOOKING_RESOLUTION_PATH',
    'CK_HIST_OLD_IMPACT',
    'CK_HIST_NEW_IMPACT',
    'CK_HIST_TRANSITION'
);

-- 5.4 Verify Data Backfill Distribution on Pre-Existing Baseline Rows
IF EXISTS (SELECT 1 FROM dbo.MAINTENANCERECORD)
BEGIN
    EXEC('SELECT ''MAINTENANCERECORD Backfill Check'' AS verification_check, impact_level, COUNT(*) AS record_count FROM dbo.MAINTENANCERECORD GROUP BY impact_level;');
END;

IF EXISTS (SELECT 1 FROM dbo.BOOKING)
BEGIN
    EXEC('SELECT ''BOOKING Backfill Check'' AS verification_check, resolution_path, COUNT(*) AS record_count FROM dbo.BOOKING GROUP BY resolution_path;');
END;

PRINT '============================================================';
PRINT 'Phase 2 Step 10 Schema Migration Completed Successfully.';
PRINT '============================================================';
GO
