/* Step 13 setup. Run after Steps 05, 10, and 12 in University. */
USE University;
GO
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM dbo.MAINTENANCE_IMPACT_HISTORY
    WHERE changed_by_user_id IN ('T13-STAFF', 'T13-REQUESTER')
       OR maintenance_id IN (SELECT maintenance_id FROM dbo.MAINTENANCERECORD WHERE space_code LIKE 'T13-%');
    DELETE FROM dbo.BOOKING_ADVISORY_ACK
    WHERE booking_id IN (SELECT booking_id FROM dbo.BOOKING WHERE space_code LIKE 'T13-%')
       OR maintenance_id IN (SELECT maintenance_id FROM dbo.MAINTENANCERECORD WHERE space_code LIKE 'T13-%');
    DELETE FROM dbo.BOOKING WHERE space_code LIKE 'T13-%';
    DELETE FROM dbo.MAINTENANCERECORD WHERE space_code LIKE 'T13-%';
    DELETE FROM dbo.SPACE WHERE space_code LIKE 'T13-%';
    DELETE FROM dbo.[USER] WHERE user_id IN ('T13-STAFF', 'T13-REQUESTER');

    INSERT INTO dbo.[USER] (user_id, email, full_name, phone_number, role, department, account_status)
    VALUES
        ('T13-STAFF', 't13.staff@example.test', 'Step 13 Staff', '0000000001', 'Facility Staff', 'CS486 Test', 'Active'),
        ('T13-REQUESTER', 't13.requester@example.test', 'Step 13 Requester', '0000000002', 'Student', 'CS486 Test', 'Active');

    INSERT INTO dbo.SPACE (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
    VALUES
        ('T13-SPACE-A', 'Step 13 Space A', 'Meeting Room', 'T13', '1', 'A01', 100, 'Available', N'Test-only space.'),
        ('T13-SPACE-B', 'Step 13 Space B', 'Meeting Room', 'T13', '1', 'B01', 100, 'Available', N'Test-only space.');

    INSERT INTO dbo.BOOKING
        (space_code, requester_id, requested_start, requested_end, purpose, expected_participants, booking_status, created_at, approver_id, decision_time, decision_note, rejection_reason, approval_path)
    VALUES
        ('T13-SPACE-A', 'T13-REQUESTER', '2035-06-01T09:00:00', '2035-06-01T11:00:00', 'Meeting', 10, 'Pending', '2035-01-01T00:00:00', NULL, NULL, NULL, NULL, 'Instant'),
        ('T13-SPACE-A', 'T13-REQUESTER', '2035-06-01T10:00:00', '2035-06-01T12:00:00', 'Meeting', 10, 'Pending', '2035-01-01T00:00:00', NULL, NULL, NULL, NULL, 'Instant'),
        ('T13-SPACE-A', 'T13-REQUESTER', '2035-07-01T09:00:00', '2035-07-01T11:00:00', 'Meeting', 10, 'Pending', '2035-01-01T00:00:00', NULL, NULL, NULL, NULL, 'Instant'),
        ('T13-SPACE-A', 'T13-REQUESTER', '2035-08-01T09:00:00', '2035-08-01T10:00:00', 'Meeting', 10, 'Pending', '2035-01-01T00:00:00', NULL, NULL, NULL, NULL, 'Instant'),
        ('T13-SPACE-A', 'T13-REQUESTER', '2035-08-01T10:00:00', '2035-08-01T11:00:00', 'Meeting', 10, 'Pending', '2035-01-01T00:00:00', NULL, NULL, NULL, NULL, 'Instant'),
        ('T13-SPACE-B', 'T13-REQUESTER', '2035-08-01T09:00:00', '2035-08-01T11:00:00', 'Meeting', 10, 'Pending', '2035-01-01T00:00:00', NULL, NULL, NULL, NULL, 'Instant'),
        ('T13-SPACE-A', 'T13-REQUESTER', '2035-09-01T09:00:00', '2035-09-01T10:00:00', 'Meeting', 10, 'Approved', '2035-01-01T00:00:00', NULL, '2035-01-02T00:00:00', N'Finalized test row.', NULL, 'Instant'),
        ('T13-SPACE-B', 'T13-REQUESTER', '2035-10-01T09:00:00', '2035-10-01T11:00:00', 'Meeting', 10, 'Pending', '2035-01-01T00:00:00', NULL, NULL, NULL, NULL, 'Instant'),
        ('T13-SPACE-A', 'T13-REQUESTER', '2035-11-01T09:00:00', '2035-11-01T11:00:00', 'Meeting', 10, 'Pending', '2035-01-01T00:00:00', NULL, NULL, NULL, NULL, 'Instant');

    INSERT INTO dbo.MAINTENANCERECORD
        (space_code, reporter_id, assigned_staff_id, problem_type, problem_description, start_time, completion_time, maintenance_status, result_note, impact_level)
    VALUES
        ('T13-SPACE-A', 'T13-REQUESTER', 'T13-STAFF', 'Projector Failure', N'Escalation-race advisory.', '2035-07-01T09:30:00', '2035-07-01T10:30:00', 'In Progress', NULL, 'advisory'),
        ('T13-SPACE-B', 'T13-REQUESTER', 'T13-STAFF', 'Network Issue', N'Out-of-service blocking test.', '2035-10-01T09:30:00', '2035-10-01T10:30:00', 'In Progress', NULL, 'out-of-service'),
        ('T13-SPACE-A', 'T13-REQUESTER', 'T13-STAFF', 'Projector Failure', N'Advisory non-blocking test.', '2035-11-01T09:30:00', '2035-11-01T10:30:00', 'In Progress', NULL, 'advisory');

    /* The advisory boundary booking records its required disclosure acknowledgement. */
    INSERT INTO dbo.BOOKING_ADVISORY_ACK (booking_id, maintenance_id, acknowledged_at)
    SELECT b.booking_id, m.maintenance_id, '2035-01-01T00:00:00'
    FROM dbo.BOOKING AS b
    JOIN dbo.MAINTENANCERECORD AS m ON m.space_code = b.space_code
    WHERE b.space_code = 'T13-SPACE-A'
      AND b.requested_start = '2035-11-01T09:00:00'
      AND m.problem_description = N'Advisory non-blocking test.';

    IF OBJECT_ID('dbo.STEP13_UNSAFE_BOOKING', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.STEP13_UNSAFE_BOOKING
        (
            unsafe_booking_id INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
            test_code VARCHAR(30) NOT NULL,
            space_code VARCHAR(50) NOT NULL,
            requested_start DATETIME NOT NULL,
            requested_end DATETIME NOT NULL,
            booking_status VARCHAR(30) NOT NULL
        );
    END;
    DELETE FROM dbo.STEP13_UNSAFE_BOOKING WHERE test_code = 'T13-UNSAFE';

    COMMIT TRANSACTION;
    PRINT 'Step 13 test data is ready.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
