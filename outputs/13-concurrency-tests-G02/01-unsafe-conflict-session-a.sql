/* U1 Session A. Run first in its own query window. */
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRY
    BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM dbo.STEP13_UNSAFE_BOOKING WHERE test_code = 'T13-UNSAFE' AND space_code = 'T13-SPACE-A' AND booking_status = 'Approved' AND requested_start < '2035-05-01T11:00:00' AND requested_end > '2035-05-01T09:00:00') THROW 52001, 'Unsafe setup is not empty.', 1;
    PRINT 'U1 A checked availability at ' + CONVERT(VARCHAR(30), SYSDATETIME(), 126) + '. Start U1 Session B now.';
    WAITFOR DELAY '00:00:10';
    INSERT INTO dbo.STEP13_UNSAFE_BOOKING (test_code, space_code, requested_start, requested_end, booking_status) VALUES ('T13-UNSAFE', 'T13-SPACE-A', '2035-05-01T09:00:00', '2035-05-01T11:00:00', 'Approved');
    COMMIT TRANSACTION;
    PRINT 'U1 A committed unsafe approval.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
SELECT @@SPID AS worker_session_id, @@TRANCOUNT AS worker_open_transaction_count;
GO
