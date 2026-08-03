/* M1 Session B. Start while Session A holds the T13-SPACE-A lock. */
USE University;
GO
SET NOCOUNT ON;
DECLARE @MaintenanceId INT;
SELECT @MaintenanceId = maintenance_id FROM dbo.MAINTENANCERECORD WHERE space_code = 'T13-SPACE-A' AND problem_description = N'Escalation-race advisory.';
BEGIN TRY
    PRINT 'M1 B calls protected escalation at ' + CONVERT(VARCHAR(30), SYSDATETIME(), 126) + '. It should wait on A''s SPACE lock.';
    EXEC dbo.sp_EscalateMaintenanceImpact @MaintenanceId = @MaintenanceId, @ChangedByUserId = 'T13-STAFF';
    PRINT 'M1 B escalation succeeded. The returned affected-booking set is expected to be empty in this escalation-first ordering.';
END TRY
BEGIN CATCH
    PRINT 'M1 B unexpected escalation error: ' + ERROR_MESSAGE();
END CATCH;
GO
