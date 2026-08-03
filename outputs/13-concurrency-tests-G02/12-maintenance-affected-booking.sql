/* M2 approval-first follow-up. Run after fresh setup; this validates the returned affected-booking result. */
USE University;
GO
SET NOCOUNT ON;
DECLARE @BookingId INT, @MaintenanceId INT;
SELECT @BookingId = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-07-01T09:00:00';
SELECT @MaintenanceId = maintenance_id FROM dbo.MAINTENANCERECORD WHERE space_code = 'T13-SPACE-A' AND problem_description = N'Escalation-race advisory.';
EXEC dbo.sp_ApproveBooking @BookingId = @BookingId, @ApproverId = NULL, @DecisionNote = N'M2 approved before escalation.';
/* Result set must include @BookingId because its time range overlaps the escalation. */
EXEC dbo.sp_EscalateMaintenanceImpact @MaintenanceId = @MaintenanceId, @ChangedByUserId = 'T13-STAFF';
SELECT booking_id, booking_status FROM dbo.BOOKING WHERE booking_id = @BookingId;
SELECT maintenance_id, impact_level FROM dbo.MAINTENANCERECORD WHERE maintenance_id = @MaintenanceId;
GO
