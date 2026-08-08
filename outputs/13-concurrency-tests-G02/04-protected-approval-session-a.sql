/* P1/P2/P3 Session A. Run first in its own query window. */
USE University;
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Pairing VARCHAR(20);
DECLARE @BookingId INT;
DECLARE @EmptyAcks dbo.BookingAdvisoryAckListType;
DECLARE @LockedSpaceCode VARCHAR(50);

SELECT @Pairing = pairing, @BookingId = booking_a_id
FROM dbo.STEP13_TEST_CONFIG
WHERE config_id = 1;

IF @Pairing IS NULL
    THROW 52020, 'Run setup and pairing configuration before the protected test.', 1;

IF @Pairing = 'StaffStaff'
BEGIN
    IF @BookingId IS NULL
        THROW 52020, 'StaffStaff requires Session A booking data.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC dbo.sp_ApproveBooking
            @BookingId = @BookingId,
            @ApproverId = 'T13-STAFF',
            @DecisionNote = N'Step 13 StaffStaff Session A.';

        PRINT 'P1 A completed the real Staff approval but has not committed at '
            + CONVERT(VARCHAR(30), SYSDATETIME(), 126)
            + '. Start Session B now.';

        WAITFOR DELAY '00:00:10';
        COMMIT TRANSACTION;
        PRINT 'P1 A committed at ' + CONVERT(VARCHAR(30), SYSDATETIME(), 126) + '.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
ELSE
BEGIN
    /* This test-only gate queues Session B before Session A submits. After the
       gate commits, both real production operations compete for the SPACE lock. */
    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @LockedSpaceCode = s.space_code
        FROM dbo.SPACE AS s WITH (UPDLOCK, HOLDLOCK)
        WHERE s.space_code = 'T13-SPACE-A';

        IF @LockedSpaceCode IS NULL
            THROW 52022, 'T13-SPACE-A is missing.', 1;

        PRINT 'P2/P3 A holds the test SPACE gate at '
            + CONVERT(VARCHAR(30), SYSDATETIME(), 126)
            + '. Start Session B now; it must queue on this row.';

        WAITFOR DELAY '00:00:10';
        COMMIT TRANSACTION;
        PRINT 'P2/P3 A released the test gate and calls the real sp_SubmitBooking at '
            + CONVERT(VARCHAR(30), SYSDATETIME(), 126) + '.';

        EXEC dbo.sp_SubmitBooking
            @RequesterId = 'T13-LECTURER',
            @SpaceCode = 'T13-SPACE-A',
            @RequestedStart = '2035-06-01T09:00:00',
            @RequestedEnd = '2035-06-01T11:00:00',
            @Purpose = 'Meeting',
            @ExpectedParticipants = 10,
            @Acknowledgements = @EmptyAcks,
            @BookingId = @BookingId OUTPUT;

        UPDATE dbo.STEP13_TEST_CONFIG
        SET booking_a_id = @BookingId,
            session_a_finished = 1
        WHERE config_id = 1;

        SELECT 'P2/P3 A real submission completed' AS result,
               booking_id, booking_status, resolution_path, SYSDATETIME() AS observed_at
        FROM dbo.BOOKING
        WHERE booking_id = @BookingId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

IF @Pairing = 'StaffStaff'
BEGIN
    UPDATE dbo.STEP13_TEST_CONFIG
    SET session_a_finished = 1
    WHERE config_id = 1;
END;
GO
