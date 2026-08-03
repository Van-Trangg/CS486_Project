/* M1 Session A. This creates a visible pre-procedure lock window. */
USE University;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @BookingId INT;
SELECT @BookingId = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-07-01T09:00:00';
BEGIN TRY
    BEGIN TRANSACTION;
    SELECT space_code FROM dbo.SPACE WITH (UPDLOCK, HOLDLOCK) WHERE space_code = 'T13-SPACE-A';
    PRINT 'M1 A holds T13-SPACE-A. Start M1 Session B now so escalation queues first.';
    WAITFOR DELAY '00:00:10';
    COMMIT TRANSACTION;
    /* Let the already-queued escalation acquire the released SPACE lock. */
    WAITFOR DELAY '00:00:01';
    PRINT 'M1 A calls protected approval after the queued escalation.';
    EXEC dbo.sp_ApproveBooking @BookingId = @BookingId, @ApproverId = NULL, @DecisionNote = N'M1 approval after escalation.';
    PRINT 'M1 A unexpected success: investigate invariant checks.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    PRINT 'M1 A expected error 51013: ' + ERROR_MESSAGE();
END CATCH;
GO
