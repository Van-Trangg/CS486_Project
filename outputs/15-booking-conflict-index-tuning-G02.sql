/* ============================================================
   Step 15: Booking Conflict Check Index Tuning
   Database: University | Group: G02

   Tunes only the approved-booking overlap check in
   dbo.sp_ApproveBooking. The dbo.SPACE (UPDLOCK, HOLDLOCK) serialization
   point, transaction, and fresh check remain the correctness mechanism.
   ============================================================ */

USE University;
GO

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

/* ============================================================
   1. Environment and dataset validation
   ============================================================ */
IF (SELECT COUNT(*) FROM dbo.BOOKING) < 100000
    THROW 51040, 'Step 15 requires the Step 14 dataset with at least 100,000 bookings.', 1;

IF (SELECT COUNT(DISTINCT YEAR(requested_start)) FROM dbo.BOOKING) < 3
    THROW 51041, 'Step 15 requires bookings spanning at least three calendar years.', 1;

SELECT
    COUNT(*) AS booking_count,
    SUM(CASE WHEN booking_status = 'Approved' THEN 1 ELSE 0 END) AS approved_booking_count,
    MIN(requested_start) AS earliest_booking_start,
    MAX(requested_start) AS latest_booking_start,
    COUNT(DISTINCT space_code) AS spaces_with_bookings
FROM dbo.BOOKING;

SELECT
    COUNT(*) AS prohibited_approved_overlap_pairs
FROM dbo.BOOKING AS b1
JOIN dbo.BOOKING AS b2
    ON b1.space_code = b2.space_code
   AND b1.booking_id < b2.booking_id
   AND b1.booking_status = 'Approved'
   AND b2.booking_status = 'Approved'
   AND b1.requested_start < b2.requested_end
   AND b1.requested_end > b2.requested_start;
GO

/* ============================================================
   2. Existing BOOKING index inventory
   ============================================================ */
SELECT
    i.name AS index_name,
    i.type_desc,
    i.is_unique,
    i.has_filter,
    i.filter_definition,
    key_columns.key_columns,
    included_columns.included_columns
FROM sys.indexes AS i
OUTER APPLY
(
    SELECT STRING_AGG
    (
        c.name + CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END,
        ', '
    ) WITHIN GROUP (ORDER BY ic.key_ordinal) AS key_columns
    FROM sys.index_columns AS ic
    JOIN sys.columns AS c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    WHERE ic.object_id = i.object_id
      AND ic.index_id = i.index_id
      AND ic.is_included_column = 0
) AS key_columns
OUTER APPLY
(
    SELECT STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.index_column_id) AS included_columns
    FROM sys.index_columns AS ic
    JOIN sys.columns AS c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    WHERE ic.object_id = i.object_id
      AND ic.index_id = i.index_id
      AND ic.is_included_column = 1
) AS included_columns
WHERE i.object_id = OBJECT_ID('dbo.BOOKING')
  AND i.index_id > 0
ORDER BY i.index_id;
GO

/* ============================================================
   3. Representative parameter selection

   This is an approved booking on a densely populated generated space.
   @BookingId = -1 represents a new pending booking; the exact Step 12
   current-booking exclusion remains in the predicate.
   ============================================================ */
DECLARE @LockedSpaceCode VARCHAR(50) = 'CLS-BD-F1-011';
DECLARE @BookingId INT = -1;
DECLARE @RequestedStart DATETIME = '2023-09-01T08:00:00';
DECLARE @RequestedEnd DATETIME = '2023-09-01T10:00:00';
DECLARE @BaselineConflictResult BIT;
DECLARE @AfterConflictResult BIT;

/* ============================================================
   4. Baseline conflict-check execution

   Only this script's own candidate index is removed. No global cache or
   procedure-cache clearing is performed.
   ============================================================ */
IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.BOOKING')
      AND name = 'IX_BOOKING_Approved_Space_Start'
)
    DROP INDEX IX_BOOKING_Approved_Space_Start ON dbo.BOOKING;

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS PROFILE ON; -- Captures actual operator, actual rows, and estimates.

SELECT @BaselineConflictResult =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status = 'Approved'
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    ) THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END;

SET STATISTICS PROFILE OFF;

-- Two additional warm-cache executions use the identical predicate and parameters.
SELECT @BaselineConflictResult =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status = 'Approved'
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    ) THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END;

SELECT @BaselineConflictResult =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status = 'Approved'
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    ) THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 'Baseline' AS measurement_phase,
       @BaselineConflictResult AS conflict_exists;
GO

/* ============================================================
   5. Proposed index creation

   The filtered index contains only the 15% Approved subset. The clustered
   key booking_id is implicitly available in this nonclustered index; it is
   not redundantly listed as an INCLUDE column. requested_end is included for
   the residual half-open predicate.
   ============================================================ */
CREATE NONCLUSTERED INDEX IX_BOOKING_Approved_Space_Start
ON dbo.BOOKING (space_code, requested_start)
INCLUDE (requested_end)
WHERE booking_status = 'Approved';
GO

/* ============================================================
   6. After-index conflict-check execution

   Uses the identical predicate and parameter values from section 4.
   ============================================================ */
DECLARE @LockedSpaceCode VARCHAR(50) = 'CLS-BD-F1-011';
DECLARE @BookingId INT = -1;
DECLARE @RequestedStart DATETIME = '2023-09-01T08:00:00';
DECLARE @RequestedEnd DATETIME = '2023-09-01T10:00:00';
DECLARE @AfterConflictResult BIT;

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS PROFILE ON;

SELECT @AfterConflictResult =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status = 'Approved'
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    ) THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END;

SET STATISTICS PROFILE OFF;

-- Two additional warm-cache executions use the identical predicate and parameters.
SELECT @AfterConflictResult =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status = 'Approved'
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    ) THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END;

SELECT @AfterConflictResult =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status = 'Approved'
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    ) THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 'After index' AS measurement_phase,
       @AfterConflictResult AS conflict_exists;
GO

/* ============================================================
   7. Correctness and invariant checks
   ============================================================ */
DECLARE @LockedSpaceCode VARCHAR(50) = 'CLS-BD-F1-011';
DECLARE @BookingId INT = -1;
DECLARE @RequestedStart DATETIME = '2023-09-01T08:00:00';
DECLARE @RequestedEnd DATETIME = '2023-09-01T10:00:00';

SELECT
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status = 'Approved'
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    ) THEN 1 ELSE 0 END AS conflict_exists_after_index;

SELECT
    COUNT(*) AS prohibited_approved_overlap_pairs_after_index
FROM dbo.BOOKING AS b1
JOIN dbo.BOOKING AS b2
    ON b1.space_code = b2.space_code
   AND b1.booking_id < b2.booking_id
   AND b1.booking_status = 'Approved'
   AND b2.booking_status = 'Approved'
   AND b1.requested_start < b2.requested_end
   AND b1.requested_end > b2.requested_start;

SELECT
    OBJECT_DEFINITION(OBJECT_ID('dbo.sp_ApproveBooking')) AS approval_procedure_definition;
GO

/* ============================================================
   8. Optional rollback

   Run only when the benchmark index should be removed. This is the only
   index this script may drop.

   DROP INDEX IX_BOOKING_Approved_Space_Start ON dbo.BOOKING;
   ============================================================ */
