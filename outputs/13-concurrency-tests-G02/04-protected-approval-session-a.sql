/* P1 Session A. Start first; run Session B during the ten-second lock hold. */
USE University;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @BookingId INT;
DECLARE @ApproverId VARCHAR(50);
SELECT @BookingId = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-06-01T09:00:00' AND requested_end = '2035-06-01T11:00:00';
SELECT @ApproverId = CASE WHEN approval_path = 'Staff' THEN 'T13-STAFF' END FROM dbo.BOOKING WHERE booking_id = @BookingId;
BEGIN TRY
    BEGIN TRANSACTION;
    SELECT space_code FROM dbo.SPACE WITH (UPDLOCK, HOLDLOCK) WHERE space_code = 'T13-SPACE-A';
    PRINT 'P1 A holds the T13-SPACE-A lock at ' + CONVERT(VARCHAR(30), SYSDATETIME(), 126) + '. Start P1 Session B now.';
    WAITFOR DELAY '00:00:10';
    COMMIT TRANSACTION;
    PRINT 'P1 A released the test lock and calls the protected procedure.';
    EXEC dbo.sp_ApproveBooking @BookingId = @BookingId, @ApproverId = @ApproverId, @DecisionNote = N'P1 protected approval.';
    PRINT 'P1 A protected approval succeeded.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    PRINT 'P1 A expected competing result: ' + ERROR_MESSAGE();
END CATCH;
GO
