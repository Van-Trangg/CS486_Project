/* B1: valid and invalid single-session boundary cases. Run after setup. */
USE University;
GO
SET NOCOUNT ON;
DECLARE @NonOverlap INT, @DifferentSpace INT, @AdjacentOne INT, @AdjacentTwo INT, @Finalized INT, @OutOfService INT, @Advisory INT;
SELECT @NonOverlap = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-08-01T09:00:00';
SELECT @AdjacentOne = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-08-01T10:00:00';
SELECT @DifferentSpace = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-B' AND requested_start = '2035-08-01T09:00:00';
SELECT @Finalized = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-09-01T09:00:00';
SELECT @OutOfService = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-B' AND requested_start = '2035-10-01T09:00:00';
SELECT @Advisory = booking_id FROM dbo.BOOKING WHERE space_code = 'T13-SPACE-A' AND requested_start = '2035-11-01T09:00:00';

BEGIN TRY EXEC dbo.sp_ApproveBooking @NonOverlap, NULL, N'B1 non-overlap.'; PRINT 'B1 non-overlap succeeded.'; END TRY BEGIN CATCH PRINT 'B1 unexpected non-overlap error: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC dbo.sp_ApproveBooking @AdjacentOne, NULL, N'B1 adjacent.'; PRINT 'B1 adjacency succeeded.'; END TRY BEGIN CATCH PRINT 'B1 unexpected adjacency error: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC dbo.sp_ApproveBooking @DifferentSpace, NULL, N'B1 different space.'; PRINT 'B1 different-space overlap succeeded.'; END TRY BEGIN CATCH PRINT 'B1 unexpected different-space error: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC dbo.sp_ApproveBooking @OutOfService, NULL, N'B1 should fail.'; PRINT 'B1 unexpected OOS success.'; END TRY BEGIN CATCH PRINT 'B1 expected OOS error 51013: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC dbo.sp_ApproveBooking @Advisory, NULL, N'B1 advisory allowed.'; PRINT 'B1 advisory approval succeeded.'; END TRY BEGIN CATCH PRINT 'B1 unexpected advisory error: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC dbo.sp_ApproveBooking @Finalized, NULL, N'B1 should fail.'; PRINT 'B1 unexpected finalized reapproval success.'; END TRY BEGIN CATCH PRINT 'B1 expected finalized error 51006: ' + ERROR_MESSAGE(); END CATCH;
GO
