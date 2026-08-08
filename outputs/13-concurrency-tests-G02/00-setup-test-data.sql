/* Step 13 isolated setup. Run after Steps 05, 10, and 12 in University. */
USE University;
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM dbo.MAINTENANCE_IMPACT_HISTORY
    WHERE changed_by_user_id LIKE 'T13-%'
       OR maintenance_id IN
          (SELECT maintenance_id FROM dbo.MAINTENANCERECORD WHERE space_code LIKE 'T13-%');

    DELETE FROM dbo.BOOKING_ADVISORY_ACK
    WHERE booking_id IN (SELECT booking_id FROM dbo.BOOKING WHERE space_code LIKE 'T13-%')
       OR maintenance_id IN
          (SELECT maintenance_id FROM dbo.MAINTENANCERECORD WHERE space_code LIKE 'T13-%');

    DELETE FROM dbo.BOOKING WHERE space_code LIKE 'T13-%';
    DELETE FROM dbo.MAINTENANCERECORD WHERE space_code LIKE 'T13-%';
    DELETE FROM dbo.SPACE WHERE space_code LIKE 'T13-%';
    DELETE FROM dbo.[USER] WHERE user_id LIKE 'T13-%';

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

    /* Recreate test-only helpers so setup also upgrades an older package run. */
    DROP TABLE IF EXISTS dbo.STEP13_MAINTENANCE_RESULT;
    DROP TABLE IF EXISTS dbo.STEP13_TEST_CONFIG;
    DROP TABLE IF EXISTS dbo.STEP13_UNSAFE_BOOKING;

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
    DECLARE @BookingA INT;
    DECLARE @BookingB INT;
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

    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-06-01T09:00:00', '2035-06-01T11:00:00', 'Meeting', 10, @EmptyAcks, @BookingA OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-06-01T10:00:00', '2035-06-01T12:00:00', 'Meeting', 10, @EmptyAcks, @BookingB OUTPUT;

    INSERT INTO dbo.STEP13_TEST_CONFIG
        (config_id, pairing, booking_a_id, booking_b_id, session_a_finished, session_b_finished)
    VALUES
        (1, 'StaffStaff', @BookingA, @BookingB, 0, 0);

    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-07-01T09:00:00', '2035-07-01T11:00:00', 'Meeting', 10, @JulyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-08-01T09:00:00', '2035-08-01T10:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-08-01T09:00:00', '2035-08-01T10:00:00', 'Seminar', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-08-01T10:00:00', '2035-08-01T11:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-08-01T12:00:00', '2035-08-01T13:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-B', '2035-08-01T09:00:00', '2035-08-01T11:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-09-01T09:00:00', '2035-09-01T10:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-B', '2035-10-01T09:00:00', '2035-10-01T11:00:00', 'Meeting', 10, @EmptyAcks, @IgnoredBookingId OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-11-01T09:00:00', '2035-11-01T11:00:00', 'Meeting', 10, @NovemberAcks, @IgnoredBookingId OUTPUT;

    PRINT 'Step 13 test data is ready. Default protected pairing: StaffStaff.';
END TRY
BEGIN CATCH
    THROW;
END CATCH;
GO
