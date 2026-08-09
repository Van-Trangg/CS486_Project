/* M3 optional sequential control: escalation commits before approval starts. */
USE [$(DatabaseName)];
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;

DECLARE @BookingId INT;
DECLARE @MaintenanceId INT;

SELECT @BookingId = booking_id
FROM dbo.BOOKING
WHERE space_code = 'T13-SPACE-A'
  AND requested_start = '2035-07-01T09:00:00';

SELECT @MaintenanceId = maintenance_id
FROM dbo.MAINTENANCERECORD
WHERE space_code = 'T13-SPACE-A'
  AND problem_description = N'Escalation-race advisory.';

EXEC dbo.sp_EscalateMaintenanceImpact
    @MaintenanceId = @MaintenanceId,
    @ChangedByUserId = 'T13-STAFF';

BEGIN TRY
    EXEC dbo.sp_ApproveBooking
        @BookingId = @BookingId,
        @ApproverId = 'T13-STAFF',
        @DecisionNote = N'M3 should fail after escalation.';
    THROW 52032, 'M3 unexpectedly approved after escalation.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 51013 THROW;
    PRINT 'M3 expected error 51013: ' + ERROR_MESSAGE();
END CATCH;

SELECT booking_id, booking_status FROM dbo.BOOKING WHERE booking_id = @BookingId;
SELECT maintenance_id, impact_level FROM dbo.MAINTENANCERECORD WHERE maintenance_id = @MaintenanceId;
GO
