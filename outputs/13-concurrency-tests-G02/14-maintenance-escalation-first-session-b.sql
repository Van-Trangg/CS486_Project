/* M2 Session B: queue the real escalation while Session A holds the test gate. */
USE University;
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @MaintenanceId INT;

SELECT @MaintenanceId = maintenance_id
FROM dbo.MAINTENANCERECORD
WHERE space_code = 'T13-SPACE-A'
  AND problem_description = N'Escalation-race advisory.';

IF @MaintenanceId IS NULL
    THROW 52035, 'Run fresh setup before M2.', 1;

WAITFOR DELAY '00:00:01';
PRINT 'M2 B calls real escalation at '
    + CONVERT(VARCHAR(30), SYSDATETIME(), 126)
    + '. It must wait on A''s test SPACE gate.';

EXEC dbo.sp_EscalateMaintenanceImpact
    @MaintenanceId = @MaintenanceId,
    @ChangedByUserId = 'T13-STAFF';

INSERT INTO dbo.STEP13_MAINTENANCE_RESULT
    (test_code, booking_id, requester_id, space_code, requested_start,
     requested_end, booking_status, maintenance_id)
SELECT 'M2-ESCALATION-FIRST', b.booking_id, b.requester_id, b.space_code,
       b.requested_start, b.requested_end, b.booking_status, @MaintenanceId
FROM dbo.BOOKING AS b
JOIN dbo.MAINTENANCERECORD AS m ON m.maintenance_id = @MaintenanceId
WHERE b.space_code = m.space_code
  AND b.booking_status IN ('Approved', 'Checked In')
  AND b.requested_start < ISNULL(m.completion_time, CONVERT(DATETIME, '9999-12-31', 120))
  AND b.requested_end > m.start_time;

IF EXISTS
   (SELECT 1 FROM dbo.STEP13_MAINTENANCE_RESULT
    WHERE test_code = 'M2-ESCALATION-FIRST')
    THROW 52036, 'M2 escalation unexpectedly found an approved affected booking.', 1;

PRINT 'M2 B escalation committed with no affected booking, as expected.';
GO
