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
    -- 2.2 Table: BOOKING (Change ID: C08-04, P2-BR-07, CC-01-03)
    -- Add approval_path column with DEFAULT 'Staff' and CHECK constraint.
    -- Baseline backfill: Pre-existing booking records receive 'Staff'.
    -- Add row_version ROWVERSION column for optimistic concurrency support.
    -- ------------------------------------------------------------
    IF COL_LENGTH('dbo.BOOKING', 'approval_path') IS NULL
    BEGIN
        PRINT 'Adding column [approval_path] to [BOOKING]...';
        ALTER TABLE dbo.BOOKING
            ADD approval_path VARCHAR(20) NOT NULL 
                CONSTRAINT DF_BOOKING_APPROVAL_PATH DEFAULT 'Staff';
    END;

    IF OBJECT_ID('dbo.CK_BOOKING_APPROVAL_PATH', 'C') IS NULL
    BEGIN
        PRINT 'Adding CHECK constraint [CK_BOOKING_APPROVAL_PATH] to [BOOKING]...';
        EXEC('ALTER TABLE dbo.BOOKING ADD CONSTRAINT CK_BOOKING_APPROVAL_PATH CHECK (approval_path IN (''Instant'', ''Staff''));');
    END;

    IF COL_LENGTH('dbo.BOOKING', 'row_version') IS NULL
    BEGIN
        PRINT 'Adding column [row_version] (ROWVERSION) to [BOOKING]...';
        ALTER TABLE dbo.BOOKING
            ADD row_version ROWVERSION NOT NULL;
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
-- Section 4: Post-Migration Validation & Verification Queries
-- ============================================================

PRINT '============================================================';
PRINT 'Running Post-Migration Verification Queries...';
PRINT '============================================================';
GO

-- 4.1 Verify Column Alterations and Baseline Backfill Values
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
  AND c.name IN ('approval_path', 'row_version');

-- 4.2 Verify Created Tables Existence and Row Counts
SELECT 
    'Table Existence Check' AS verification_check,
    t.name AS table_name,
    t.create_date
FROM sys.tables t
WHERE t.name IN ('BOOKING_ADVISORY_ACK', 'MAINTENANCE_IMPACT_HISTORY');

-- 4.3 Verify Constraints Active Status
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
    'CK_BOOKING_APPROVAL_PATH',
    'CK_HIST_OLD_IMPACT',
    'CK_HIST_NEW_IMPACT'
);

-- 4.4 Verify Data Backfill Distribution on Pre-Existing Baseline Rows
IF EXISTS (SELECT 1 FROM dbo.MAINTENANCERECORD)
BEGIN
    EXEC('SELECT ''MAINTENANCERECORD Backfill Check'' AS verification_check, impact_level, COUNT(*) AS record_count FROM dbo.MAINTENANCERECORD GROUP BY impact_level;');
END;

IF EXISTS (SELECT 1 FROM dbo.BOOKING)
BEGIN
    EXEC('SELECT ''BOOKING Backfill Check'' AS verification_check, approval_path, COUNT(*) AS record_count FROM dbo.BOOKING GROUP BY approval_path;');
END;

PRINT '============================================================';
PRINT 'Phase 2 Step 10 Schema Migration Completed Successfully.';
PRINT '============================================================';
GO
