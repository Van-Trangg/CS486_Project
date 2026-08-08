/* B1: valid and invalid single-session boundary cases. Run after fresh setup. */
USE University;
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;

DECLARE @Base INT, @EqualInterval INT, @Adjacent INT, @NonOverlap INT, @DifferentSpace INT;
DECLARE @Finalized INT, @OutOfService INT, @Advisory INT;

SELECT @Base = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-08-01T09:00:00' AND purpose = 'Meeting';
SELECT @EqualInterval = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-08-01T09:00:00' AND purpose = 'Seminar';
SELECT @Adjacent = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-08-01T10:00:00';
SELECT @NonOverlap = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-08-01T12:00:00';
SELECT @DifferentSpace = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-B' AND requested_start = '2035-08-01T09:00:00';
SELECT @Finalized = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-09-01T09:00:00';
SELECT @OutOfService = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-B' AND requested_start = '2035-10-01T09:00:00';
SELECT @Advisory = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-11-01T09:00:00';

BEGIN TRY
    EXEC dbo.sp_ApproveBooking @Base, 'T13-STAFF', N'B1 base interval.';
END TRY BEGIN CATCH THROW; END CATCH;

BEGIN TRY
    EXEC dbo.sp_ApproveBooking @EqualInterval, 'T13-STAFF', N'B1 should fail.';
    THROW 52040, 'B1 equal interval unexpectedly approved.', 1;
END TRY BEGIN CATCH
    IF ERROR_NUMBER() <> 51012 THROW;
    PRINT 'B1 equal interval returned expected 51012.';
END CATCH;

BEGIN TRY EXEC dbo.sp_ApproveBooking @Adjacent, 'T13-STAFF', N'B1 adjacent interval.'; END TRY BEGIN CATCH THROW; END CATCH;
BEGIN TRY EXEC dbo.sp_ApproveBooking @NonOverlap, 'T13-STAFF', N'B1 non-overlap.'; END TRY BEGIN CATCH THROW; END CATCH;
BEGIN TRY EXEC dbo.sp_ApproveBooking @DifferentSpace, 'T13-STAFF', N'B1 different space.'; END TRY BEGIN CATCH THROW; END CATCH;

BEGIN TRY
    EXEC dbo.sp_ApproveBooking @OutOfService, 'T13-STAFF', N'B1 should fail.';
    THROW 52041, 'B1 Out-of-Service overlap unexpectedly approved.', 1;
END TRY BEGIN CATCH
    IF ERROR_NUMBER() <> 51013 THROW;
    PRINT 'B1 Out-of-Service overlap returned expected 51013.';
END CATCH;

BEGIN TRY EXEC dbo.sp_ApproveBooking @Advisory, 'T13-STAFF', N'B1 advisory allowed.'; END TRY BEGIN CATCH THROW; END CATCH;
BEGIN TRY EXEC dbo.sp_ApproveBooking @Finalized, 'T13-STAFF', N'B1 first finalization.'; END TRY BEGIN CATCH THROW; END CATCH;

BEGIN TRY
    EXEC dbo.sp_ApproveBooking @Finalized, 'T13-STAFF', N'B1 should fail.';
    THROW 52042, 'B1 finalized booking unexpectedly re-approved.', 1;
END TRY BEGIN CATCH
    IF ERROR_NUMBER() <> 51006 THROW;
    PRINT 'B1 re-approval returned expected 51006.';
END CATCH;

SELECT 'B1 boundary state' AS invariant_name,
       CASE
           WHEN (SELECT booking_status FROM dbo.BOOKING WHERE booking_id = @Base) = 'Approved'
            AND (SELECT booking_status FROM dbo.BOOKING WHERE booking_id = @EqualInterval) = 'Pending'
            AND (SELECT booking_status FROM dbo.BOOKING WHERE booking_id = @Adjacent) = 'Approved'
            AND (SELECT booking_status FROM dbo.BOOKING WHERE booking_id = @NonOverlap) = 'Approved'
            AND (SELECT booking_status FROM dbo.BOOKING WHERE booking_id = @DifferentSpace) = 'Approved'
            AND (SELECT booking_status FROM dbo.BOOKING WHERE booking_id = @OutOfService) = 'Pending'
            AND (SELECT booking_status FROM dbo.BOOKING WHERE booking_id = @Advisory) = 'Approved'
            AND (SELECT booking_status FROM dbo.BOOKING WHERE booking_id = @Finalized) = 'Approved'
               THEN 'BOUNDARY_CASES_HOLD'
           ELSE 'BOUNDARY_CASES_INVALID'
       END AS result;

SELECT booking_id, space_code, requested_start, requested_end, booking_status, resolution_path
FROM dbo.BOOKING
WHERE booking_id IN (@Base, @EqualInterval, @Adjacent, @NonOverlap, @DifferentSpace, @Finalized, @OutOfService, @Advisory)
ORDER BY requested_start, space_code;
GO
