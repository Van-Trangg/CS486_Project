/* M1 Session B. Start while Session A holds its protected approval uncommitted. */
USE University;
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;
DECLARE @MaintenanceId INT;
SELECT @MaintenanceId = maintenance_id FROM dbo.MAINTENANCERECORD WHERE space_code = 'T13-SPACE-A' AND problem_description = N'Escalation-race advisory.';
BEGIN TRY
    WAITFOR DELAY '00:00:01';
    PRINT 'M1 B calls protected escalation at ' + CONVERT(VARCHAR(30), SYSDATETIME(), 126) + '. It must wait on A''s production SPACE lock.';
    EXEC dbo.sp_EscalateMaintenanceImpact
        @MaintenanceId = @MaintenanceId,
        @ChangedByUserId = 'T13-STAFF';

    /* The procedure result above is the observed affected list. Persist the
       same post-commit predicate separately because INSERT...EXEC would create
       a caller transaction that Step 12 intentionally rejects. */
    INSERT INTO dbo.STEP13_MAINTENANCE_RESULT
        (test_code, booking_id, requester_id, space_code, requested_start,
         requested_end, booking_status, maintenance_id)
    SELECT 'M1-APPROVAL-FIRST', b.booking_id, b.requester_id, b.space_code,
           b.requested_start, b.requested_end, b.booking_status, @MaintenanceId
    FROM dbo.BOOKING AS b
    JOIN dbo.MAINTENANCERECORD AS m ON m.maintenance_id = @MaintenanceId
    WHERE b.space_code = m.space_code
      AND b.booking_status IN ('Approved', 'Checked In')
      AND b.requested_start < ISNULL(m.completion_time, CONVERT(DATETIME, '9999-12-31', 120))
      AND b.requested_end > m.start_time;

    IF NOT EXISTS
       (SELECT 1 FROM dbo.STEP13_MAINTENANCE_RESULT
        WHERE test_code = 'M1-APPROVAL-FIRST')
        THROW 52031, 'M1 escalation did not return the committed affected booking.', 1;

    SELECT 'M1 affected booking captured' AS result, *
    FROM dbo.STEP13_MAINTENANCE_RESULT
    WHERE test_code = 'M1-APPROVAL-FIRST';
END TRY
BEGIN CATCH
    PRINT 'M1 B unexpected escalation error: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO
