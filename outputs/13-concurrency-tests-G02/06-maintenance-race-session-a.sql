/* M1 Session A: hold a real approved booking transaction uncommitted. */
USE University;
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @BookingId INT;
SELECT @BookingId = booking_id
FROM dbo.BOOKING
WHERE space_code = 'T13-SPACE-A'
  AND requested_start = '2035-07-01T09:00:00';

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC dbo.sp_ApproveBooking
        @BookingId = @BookingId,
        @ApproverId = 'T13-STAFF',
        @DecisionNote = N'M1 approval held before escalation.';

    PRINT 'M1 A approved through the real procedure but has not committed. Start M1 Session B now.';
    WAITFOR DELAY '00:00:10';
    COMMIT TRANSACTION;
    PRINT 'M1 A committed. Escalation should now identify this booking.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
