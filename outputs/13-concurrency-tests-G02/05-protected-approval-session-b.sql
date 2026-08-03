/* P1 Session B. Start while Session A reports it holds the lock. */
USE University;
GO
SET NOCOUNT ON;
DECLARE @BookingId INT;
DECLARE @ApproverId VARCHAR(50);
SELECT @BookingId = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-06-01T10:00:00' AND requested_end = '2035-06-01T12:00:00';
SELECT @ApproverId = CASE WHEN approval_path = 'Staff' THEN 'T13-STAFF' END FROM dbo.BOOKING WHERE booking_id = @BookingId;
BEGIN TRY
    PRINT 'P1 B calls the protected procedure at ' + CONVERT(VARCHAR(30), SYSDATETIME(), 126) + '. It should wait on A''s SPACE lock.';
    EXEC dbo.sp_ApproveBooking @BookingId = @BookingId, @ApproverId = @ApproverId, @DecisionNote = N'P1 protected approval.';
    PRINT 'P1 B protected approval succeeded.';
END TRY
BEGIN CATCH
    PRINT 'P1 B expected competing result: ' + ERROR_MESSAGE();
END CATCH;
GO
