/* M2 Session A: gate the space, then attempt approval after escalation queues. */
USE University;
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @BookingId INT;
DECLARE @LockedSpaceCode VARCHAR(50);

SELECT @BookingId = booking_id
FROM dbo.BOOKING
WHERE space_code = 'T13-SPACE-A'
  AND requested_start = '2035-07-01T09:00:00';

IF @BookingId IS NULL
    THROW 52033, 'Run fresh setup before M2.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @LockedSpaceCode = s.space_code
    FROM dbo.SPACE AS s WITH (UPDLOCK, HOLDLOCK)
    WHERE s.space_code = 'T13-SPACE-A';

    PRINT 'M2 A holds the test SPACE gate at '
        + CONVERT(VARCHAR(30), SYSDATETIME(), 126)
        + '. Start M2 Session B now; escalation must queue first.';

    WAITFOR DELAY '00:00:10';
    COMMIT TRANSACTION;

    PRINT 'M2 A released the gate and calls real approval at '
        + CONVERT(VARCHAR(30), SYSDATETIME(), 126) + '.';

    BEGIN TRY
        EXEC dbo.sp_ApproveBooking
            @BookingId = @BookingId,
            @ApproverId = 'T13-STAFF',
            @DecisionNote = N'M2 approval must fail after queued escalation.';

        THROW 52034, 'M2 unexpectedly approved after escalation.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 51013 THROW;
        SELECT 'M2 expected fresh maintenance rejection' AS result,
               ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message,
               SYSDATETIME() AS observed_at;
    END CATCH;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
