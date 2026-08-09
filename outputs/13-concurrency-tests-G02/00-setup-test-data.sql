/* Step 13 isolated setup. Run once in a fresh Step13G02_* disposable database. */
USE [$(DatabaseName)];
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_NAME() NOT LIKE 'Step13G02[_]%'
    THROW 52000, 'Step 13 setup requires a disposable database named Step13G02_*.', 1;

IF OBJECT_ID('dbo.sp_SubmitBooking', 'P') IS NULL
   OR OBJECT_ID('dbo.sp_ApproveBooking', 'P') IS NULL
   OR OBJECT_ID('dbo.sp_EscalateMaintenanceImpact', 'P') IS NULL
   OR OBJECT_ID('dbo.TR_BOOKING_ADVISORY_ACK_IMMUTABLE', 'TR') IS NULL
   OR OBJECT_ID('dbo.TR_MAINTENANCE_IMPACT_HISTORY_IMMUTABLE', 'TR') IS NULL
    THROW 52000, 'Apply the exact Step 05 -> Step 10 -> Step 12 baseline before setup.', 1;

IF COL_LENGTH('dbo.SPACE', 'space_code') IS NULL
   OR COL_LENGTH('dbo.BOOKING', 'booking_id') IS NULL
   OR COL_LENGTH('dbo.BOOKING', 'space_code') IS NULL
   OR COL_LENGTH('dbo.BOOKING', 'requested_start') IS NULL
   OR COL_LENGTH('dbo.BOOKING', 'requested_end') IS NULL
   OR COL_LENGTH('dbo.BOOKING', 'booking_status') IS NULL
   OR COL_LENGTH('dbo.BOOKING', 'resolution_path') IS NULL
   OR COL_LENGTH('dbo.MAINTENANCERECORD', 'maintenance_id') IS NULL
   OR COL_LENGTH('dbo.MAINTENANCERECORD', 'space_code') IS NULL
   OR COL_LENGTH('dbo.MAINTENANCERECORD', 'start_time') IS NULL
   OR COL_LENGTH('dbo.MAINTENANCERECORD', 'completion_time') IS NULL
   OR COL_LENGTH('dbo.MAINTENANCERECORD', 'maintenance_status') IS NULL
   OR COL_LENGTH('dbo.MAINTENANCERECORD', 'impact_level') IS NULL
    THROW 52000, 'The Step 13 database does not match the required migrated table contract.', 1;

IF (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.sp_ApproveBooking')) <> 3
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.sp_ApproveBooking') AND name = '@BookingId' AND TYPE_NAME(user_type_id) = 'int')
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.sp_ApproveBooking') AND name = '@ApproverId' AND TYPE_NAME(user_type_id) = 'varchar' AND max_length = 50)
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.sp_ApproveBooking') AND name = '@DecisionNote' AND TYPE_NAME(user_type_id) = 'nvarchar' AND max_length = -1)
   OR (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.sp_EscalateMaintenanceImpact')) <> 2
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.sp_EscalateMaintenanceImpact') AND name = '@MaintenanceId' AND TYPE_NAME(user_type_id) = 'int')
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.sp_EscalateMaintenanceImpact') AND name = '@ChangedByUserId' AND TYPE_NAME(user_type_id) = 'varchar' AND max_length = 50)
   OR (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.sp_SubmitBooking')) <> 8
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.sp_SubmitBooking') AND name = '@Acknowledgements' AND TYPE_NAME(user_type_id) = 'BookingAdvisoryAckListType')
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.sp_SubmitBooking') AND name = '@BookingId' AND TYPE_NAME(user_type_id) = 'int' AND is_output = 1)
    THROW 52000, 'Protected procedure signatures do not match the accepted Step 12 contract.', 1;

IF EXISTS
   (SELECT 1 FROM sys.triggers
    WHERE object_id IN (OBJECT_ID('dbo.TR_BOOKING_ADVISORY_ACK_IMMUTABLE'), OBJECT_ID('dbo.TR_MAINTENANCE_IMPACT_HISTORY_IMMUTABLE'))
      AND is_disabled = 1)
   OR OBJECT_DEFINITION(OBJECT_ID('dbo.sp_SubmitBooking')) NOT LIKE '%UPDLOCK%HOLDLOCK%'
   OR OBJECT_DEFINITION(OBJECT_ID('dbo.sp_ApproveBooking')) NOT LIKE '%UPDLOCK%HOLDLOCK%'
   OR OBJECT_DEFINITION(OBJECT_ID('dbo.sp_EscalateMaintenanceImpact')) NOT LIKE '%UPDLOCK%HOLDLOCK%'
   OR OBJECT_DEFINITION(OBJECT_ID('dbo.sp_SubmitBooking')) LIKE '%WAITFOR%'
   OR OBJECT_DEFINITION(OBJECT_ID('dbo.sp_ApproveBooking')) LIKE '%WAITFOR%'
   OR OBJECT_DEFINITION(OBJECT_ID('dbo.sp_EscalateMaintenanceImpact')) LIKE '%WAITFOR%'
    THROW 52000, 'Protected definitions or immutable trigger state do not match the Step 12 testing contract.', 1;

SELECT DB_NAME() AS verified_database,
       d.compatibility_level,
       d.is_read_committed_snapshot_on,
       d.snapshot_isolation_state_desc
FROM sys.databases AS d
WHERE d.database_id = DB_ID();

SELECT p.name AS verified_procedure, p.modify_date
FROM sys.procedures AS p
WHERE p.object_id IN
      (OBJECT_ID('dbo.sp_SubmitBooking'), OBJECT_ID('dbo.sp_ApproveBooking'),
       OBJECT_ID('dbo.sp_EscalateMaintenanceImpact'))
ORDER BY p.name;

PRINT 'Verified migrated columns, protected signatures/locks, enabled immutable triggers, and no production WAITFOR.';

IF EXISTS (SELECT 1 FROM dbo.[USER] WHERE user_id LIKE 'T13-%')
   OR EXISTS (SELECT 1 FROM dbo.SPACE WHERE space_code LIKE 'T13-%')
   OR OBJECT_ID('dbo.STEP13_UNSAFE_BOOKING', 'U') IS NOT NULL
   OR OBJECT_ID('dbo.STEP13_TEST_CONFIG', 'U') IS NOT NULL
   OR OBJECT_ID('dbo.STEP13_MAINTENANCE_RESULT', 'U') IS NOT NULL
    THROW 52000, 'This disposable database already contains Step 13 state. Drop it and create a fresh database.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.[USER]
        (user_id, email, full_name, phone_number, role, department, account_status)
    VALUES
        ('T13-STAFF', 't13.staff@example.test', 'Step 13 Staff', '0000000001', 'Facility Staff', 'CS486 Test', 'Active'),
        ('T13-STUDENT', 't13.student@example.test', 'Step 13 Student', '0000000002', 'Student', 'CS486 Test', 'Active'),
        ('T13-LECTURER', 't13.lecturer@example.test', 'Step 13 Lecturer', '0000000003', 'Lecturer', 'CS486 Test', 'Active');

    INSERT INTO dbo.SPACE
        (space_code, space_name, space_type, building, floor, room_number,
         capacity, current_status, usage_policy)
    VALUES
        ('T13-SPACE-A', 'Step 13 Classroom A', 'Classroom', 'T13', '1', 'A01', 100, 'Available', N'Test-only note.'),
        ('T13-SPACE-B', 'Step 13 Classroom B', 'Classroom', 'T13', '1', 'B01', 100, 'Available', N'Test-only note.');

    INSERT INTO dbo.MAINTENANCERECORD
        (space_code, reporter_id, assigned_staff_id, problem_type,
         problem_description, start_time, completion_time,
         maintenance_status, result_note, impact_level)
    VALUES
        ('T13-SPACE-A', 'T13-STUDENT', 'T13-STAFF', 'Projector Failure',
         N'Escalation-race advisory.', '2035-07-01T09:30:00', '2035-07-01T10:30:00',
         'In Progress', NULL, 'advisory'),
        ('T13-SPACE-B', 'T13-STUDENT', 'T13-STAFF', 'Network Issue',
         N'Out-of-service blocking test.', '2035-10-01T09:30:00', '2035-10-01T10:30:00',
         'In Progress', NULL, 'out-of-service'),
        ('T13-SPACE-A', 'T13-STUDENT', 'T13-STAFF', 'Projector Failure',
         N'Advisory non-blocking test.', '2035-11-01T09:30:00', '2035-11-01T10:30:00',
         'In Progress', NULL, 'advisory');

    CREATE TABLE dbo.STEP13_UNSAFE_BOOKING
    (
        unsafe_booking_id INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
        test_code VARCHAR(30) NOT NULL,
        space_code VARCHAR(50) NOT NULL,
        requested_start DATETIME NOT NULL,
        requested_end DATETIME NOT NULL,
        booking_status VARCHAR(30) NOT NULL
    );

    CREATE TABLE dbo.STEP13_TEST_CONFIG
    (
        config_id INT NOT NULL PRIMARY KEY,
        pairing VARCHAR(20) NOT NULL,
        booking_a_id INT NULL,
        booking_b_id INT NULL,
        session_a_finished BIT NOT NULL CONSTRAINT DF_STEP13_CONFIG_A_FINISHED DEFAULT 0,
        session_b_finished BIT NOT NULL CONSTRAINT DF_STEP13_CONFIG_B_FINISHED DEFAULT 0,
        CONSTRAINT CK_STEP13_TEST_CONFIG_ONE_ROW CHECK (config_id = 1),
        CONSTRAINT CK_STEP13_TEST_CONFIG_PAIRING
            CHECK (pairing IN ('InstantInstant', 'StaffStaff', 'InstantStaff'))
    );

    CREATE TABLE dbo.STEP13_MAINTENANCE_RESULT
    (
        test_code VARCHAR(30) NOT NULL,
        booking_id INT NOT NULL,
        requester_id VARCHAR(50) NOT NULL,
        space_code VARCHAR(50) NOT NULL,
        requested_start DATETIME NOT NULL,
        requested_end DATETIME NOT NULL,
        booking_status VARCHAR(30) NOT NULL,
        maintenance_id INT NOT NULL
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/* Procedures own their transactions, so booking creation follows the setup transaction. */
BEGIN TRY
    DECLARE @EmptyAcks dbo.BookingAdvisoryAckListType;
    DECLARE @JulyAcks dbo.BookingAdvisoryAckListType;
    DECLARE @NovemberAcks dbo.BookingAdvisoryAckListType;
    DECLARE @IgnoredBookingId INT;

    INSERT INTO @JulyAcks (maintenance_id)
    SELECT maintenance_id
    FROM dbo.MAINTENANCERECORD
    WHERE space_code = 'T13-SPACE-A'
      AND problem_description = N'Escalation-race advisory.';

    INSERT INTO @NovemberAcks (maintenance_id)
    SELECT maintenance_id
    FROM dbo.MAINTENANCERECORD
    WHERE space_code = 'T13-SPACE-A'
      AND problem_description = N'Advisory non-blocking test.';

    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-07-01T09:00:00', '2035-07-01T11:00:00', 'Meeting', 10, @JulyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-08-01T09:00:00', '2035-08-01T10:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-08-01T09:00:00', '2035-08-01T10:00:00', 'Seminar', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-08-01T10:00:00', '2035-08-01T11:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-08-01T12:00:00', '2035-08-01T13:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-B', '2035-08-01T09:00:00', '2035-08-01T11:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-09-01T09:00:00', '2035-09-01T10:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-B', '2035-10-01T09:00:00', '2035-10-01T11:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-11-01T09:00:00', '2035-11-01T11:00:00', 'Meeting', 10, @NovemberAcks, @IgnoredBookingId OUTPUT;

    PRINT 'Step 13 common test data is ready. Configure one protected pairing once if required.';
END TRY
BEGIN CATCH
    THROW;
END CATCH;
GO
