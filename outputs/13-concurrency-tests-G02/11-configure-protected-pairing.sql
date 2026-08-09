/* Run with sqlcmd -v Pairing=StaffStaff, InstantInstant, or InstantStaff. */
USE [$(DatabaseName)];
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Pairing VARCHAR(20) = '$(Pairing)';
IF @Pairing NOT IN ('InstantInstant', 'StaffStaff', 'InstantStaff')
    THROW 52010, 'Unsupported protected approval pairing.', 1;

IF EXISTS (SELECT 1 FROM dbo.STEP13_TEST_CONFIG WHERE config_id = 1)
   OR EXISTS
      (SELECT 1 FROM dbo.BOOKING
       WHERE space_code = 'T13-SPACE-A'
         AND requested_start IN ('2035-06-01T09:00:00', '2035-06-01T10:00:00'))
    THROW 52011, 'A protected pairing is already configured. Use a fresh Step13G02_* database.', 1;

DECLARE @EmptyAcks dbo.BookingAdvisoryAckListType;
DECLARE @BookingA INT = NULL;
DECLARE @BookingB INT = NULL;

IF @Pairing = 'StaffStaff'
BEGIN
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-06-01T09:00:00', '2035-06-01T11:00:00', 'Meeting', 10, @EmptyAcks, @BookingA OUTPUT;
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-06-01T10:00:00', '2035-06-01T12:00:00', 'Meeting', 10, @EmptyAcks, @BookingB OUTPUT;
END
ELSE IF @Pairing = 'InstantStaff'
BEGIN
    /* Session A will create its Instant candidate through sp_SubmitBooking. */
    EXEC dbo.sp_SubmitBooking 'T13-STUDENT', 'T13-SPACE-A', '2035-06-01T10:00:00', '2035-06-01T12:00:00', 'Meeting', 10, @EmptyAcks, @BookingB OUTPUT;
END;

INSERT INTO dbo.STEP13_TEST_CONFIG
    (config_id, pairing, booking_a_id, booking_b_id, session_a_finished, session_b_finished)
VALUES
    (1, @Pairing, @BookingA, @BookingB, 0, 0);

PRINT 'Configured protected pairing: ' + @Pairing + '.';
GO
