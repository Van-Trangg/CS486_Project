/* P1/P2/P3 Session B. Start after Session A prints its coordination message. */
USE [$(DatabaseName)];
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

DECLARE @Pairing VARCHAR(20);
DECLARE @BookingId INT;
DECLARE @EmptyAcks dbo.BookingAdvisoryAckListType;

SELECT @Pairing = pairing, @BookingId = booking_b_id
FROM dbo.STEP13_TEST_CONFIG
WHERE config_id = 1;

IF @Pairing IS NULL
    THROW 52021, 'Run setup and pairing configuration before the protected test.', 1;

WAITFOR DELAY '00:00:01';

IF @Pairing = 'InstantInstant'
BEGIN
    PRINT 'P2 B calls the real sp_SubmitBooking at '
        + CONVERT(VARCHAR(30), SYSDATETIME(), 126)
        + '. It must wait on A''s test SPACE gate.';

    EXEC dbo.sp_SubmitBooking
        @RequesterId = 'T13-LECTURER',
        @SpaceCode = 'T13-SPACE-A',
        @RequestedStart = '2035-06-01T10:00:00',
        @RequestedEnd = '2035-06-01T12:00:00',
        @Purpose = 'Meeting',
        @ExpectedParticipants = 10,
        @Acknowledgements = @EmptyAcks,
        @BookingId = @BookingId OUTPUT;

    UPDATE dbo.STEP13_TEST_CONFIG
    SET booking_b_id = @BookingId,
        session_b_finished = 1
    WHERE config_id = 1;

    SELECT 'P2 B real submission completed' AS result,
           booking_id, booking_status, resolution_path, SYSDATETIME() AS observed_at
    FROM dbo.BOOKING
    WHERE booking_id = @BookingId;
END
ELSE IF @Pairing = 'InstantStaff'
BEGIN
    IF @BookingId IS NULL
        THROW 52021, 'InstantStaff requires Session B booking data.', 1;

    PRINT 'P3 B calls the real Staff approval at '
        + CONVERT(VARCHAR(30), SYSDATETIME(), 126)
        + '. It must wait on A''s test SPACE gate.';

    EXEC dbo.sp_ApproveBooking
        @BookingId = @BookingId,
        @ApproverId = 'T13-STAFF',
        @DecisionNote = N'Step 13 InstantStaff Session B.';

    UPDATE dbo.STEP13_TEST_CONFIG
    SET session_b_finished = 1
    WHERE config_id = 1;

    SELECT 'P3 B Staff approval completed' AS result,
           booking_id, booking_status, resolution_path, SYSDATETIME() AS observed_at
    FROM dbo.BOOKING
    WHERE booking_id = @BookingId;
END
ELSE
BEGIN
    IF @BookingId IS NULL
        THROW 52021, 'StaffStaff requires Session B booking data.', 1;

    BEGIN TRY
        PRINT 'P1 B calls the real Staff approval at '
            + CONVERT(VARCHAR(30), SYSDATETIME(), 126)
            + '. It must wait for A''s uncommitted approval.';

        EXEC dbo.sp_ApproveBooking
            @BookingId = @BookingId,
            @ApproverId = 'T13-STAFF',
            @DecisionNote = N'Step 13 StaffStaff Session B.';

        THROW 52023, 'P1 B unexpectedly approved an overlapping booking.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 51012 THROW;
        SELECT 'P1 B expected fresh-recheck rejection' AS result,
               ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message,
               SYSDATETIME() AS observed_at;
    END CATCH;

    UPDATE dbo.STEP13_TEST_CONFIG
    SET session_b_finished = 1
    WHERE config_id = 1;
END;
SELECT @@SPID AS worker_session_id, @@TRANCOUNT AS worker_open_transaction_count;
GO
