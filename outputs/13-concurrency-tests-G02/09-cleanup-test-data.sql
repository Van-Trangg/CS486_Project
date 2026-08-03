/* Deletes only Step 13 test rows and drops only its unsafe-test table. */
USE University;
GO
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.MAINTENANCE_IMPACT_HISTORY WHERE changed_by_user_id IN ('T13-STAFF', 'T13-REQUESTER') OR maintenance_id IN (SELECT maintenance_id FROM dbo.MAINTENANCERECORD WHERE space_code LIKE 'T13-%');
    DELETE FROM dbo.BOOKING_ADVISORY_ACK WHERE booking_id IN (SELECT booking_id FROM dbo.BOOKING WHERE space_code LIKE 'T13-%') OR maintenance_id IN (SELECT maintenance_id FROM dbo.MAINTENANCERECORD WHERE space_code LIKE 'T13-%');
    DELETE FROM dbo.BOOKING WHERE space_code LIKE 'T13-%';
    DELETE FROM dbo.MAINTENANCERECORD WHERE space_code LIKE 'T13-%';
    DELETE FROM dbo.SPACE WHERE space_code LIKE 'T13-%';
    DELETE FROM dbo.[USER] WHERE user_id IN ('T13-STAFF', 'T13-REQUESTER');
    COMMIT TRANSACTION;
    DROP TABLE IF EXISTS dbo.STEP13_UNSAFE_BOOKING;
    PRINT 'Step 13 test data removed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
