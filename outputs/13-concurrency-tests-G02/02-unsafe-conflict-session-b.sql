/* U1 Session B. Start while Session A waits. */
USE University;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM dbo.STEP13_UNSAFE_BOOKING WHERE test_code = 'T13-UNSAFE' AND space_code = 'T13-SPACE-A' AND booking_status = 'Approved' AND requested_start < '2035-05-01T12:00:00' AND requested_end > '2035-05-01T10:00:00') THROW 52002, 'Unsafe race did not start from an empty test table.', 1;
    PRINT 'U1 B checked availability at ' + CONVERT(VARCHAR(30), SYSDATETIME(), 126) + '. It cannot see A uncommitted row.';
    WAITFOR DELAY '00:00:03';
    INSERT INTO dbo.STEP13_UNSAFE_BOOKING (test_code, space_code, requested_start, requested_end, booking_status) VALUES ('T13-UNSAFE', 'T13-SPACE-A', '2035-05-01T10:00:00', '2035-05-01T12:00:00', 'Approved');
    COMMIT TRANSACTION;
    PRINT 'U1 B committed unsafe approval. Wait for Session A, then run invariant checks.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
