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

-- 1.1 Require a sufficiently large Step 14 dataset
IF (SELECT COUNT_BIG(*) FROM dbo.BOOKING) < 100000
    THROW 51040,
          'Step 15 requires the Step 14 dataset with at least 100,000 bookings.',
          1;


/* ------------------------------------------------------------
   1.2 Require at least three academic years
        Academic year starts in September.
        Example:
          Sep 2023 - Aug 2024 -> academic_year_start = 2023
   ------------------------------------------------------------ */

IF
(
    SELECT COUNT(DISTINCT
        CASE
            WHEN MONTH(requested_start) >= 9
                THEN YEAR(requested_start)
            ELSE YEAR(requested_start) - 1
        END
    )
    FROM dbo.BOOKING
) < 3
    THROW 51041,
          'Step 15 requires bookings spanning at least three academic years.',
          1;


/* ------------------------------------------------------------
   1.3 Dataset summary for the real conflict workload
   ------------------------------------------------------------ */

SELECT
    COUNT_BIG(*) AS booking_count,

    SUM(
        CASE
            WHEN booking_status = 'Approved' THEN 1
            ELSE 0
        END
    ) AS approved_booking_count,

    SUM(
        CASE
            WHEN booking_status = 'Checked In' THEN 1
            ELSE 0
        END
    ) AS checked_in_booking_count,

    SUM(
        CASE
            WHEN booking_status IN ('Approved', 'Checked In') THEN 1
            ELSE 0
        END
    ) AS occupying_booking_count,

    MIN(requested_start) AS earliest_booking_start,
    MAX(requested_start) AS latest_booking_start,

    COUNT(DISTINCT space_code) AS spaces_with_bookings

FROM dbo.BOOKING;


/* ------------------------------------------------------------
   1.4 Require both occupying statuses to be represented
   ------------------------------------------------------------ */

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.BOOKING
    WHERE booking_status = 'Approved'
)
    THROW 51042,
          'Step 15 conflict tuning requires Approved bookings.',
          1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.BOOKING
    WHERE booking_status = 'Checked In'
)
    THROW 51043,
          'Step 15 conflict tuning requires Checked In bookings.',
          1;


/* ------------------------------------------------------------
   1.5 Show booking density by space
        This helps select a representative high-density space
        for the benchmark.
   ------------------------------------------------------------ */

SELECT TOP (10)
    space_code,
    COUNT_BIG(*) AS occupying_booking_count
FROM dbo.BOOKING
WHERE booking_status IN ('Approved', 'Checked In')
GROUP BY space_code
ORDER BY occupying_booking_count DESC;


/* ------------------------------------------------------------
   1.6 Verify the authoritative occupancy invariant

   Occupying statuses:
       Approved
       Checked In

   Half-open intervals:
       existing_start < other_end
       existing_end   > other_start

   Adjacent bookings are therefore allowed.
   ------------------------------------------------------------ */

DECLARE @ProhibitedOverlapPairs BIGINT;

SELECT @ProhibitedOverlapPairs = COUNT_BIG(*)
FROM dbo.BOOKING AS b1
JOIN dbo.BOOKING AS b2
    ON b1.space_code = b2.space_code
   AND b1.booking_id < b2.booking_id
WHERE b1.booking_status IN ('Approved', 'Checked In')
  AND b2.booking_status IN ('Approved', 'Checked In')
  AND b1.requested_start < b2.requested_end
  AND b1.requested_end > b2.requested_start
OPTION (MAXDOP 1);

SELECT
    @ProhibitedOverlapPairs AS prohibited_occupying_overlap_pairs;

IF @ProhibitedOverlapPairs <> 0
    THROW 51044,
          'Step 15 tuning dataset contains prohibited Approved/Checked-In booking overlaps.',
          1;

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

   Select one real Pending booking from a high-density space
   whose requested interval actually conflicts with an occupying
   Approved / Checked In booking.
   ============================================================ */

DROP TABLE IF EXISTS #BenchmarkParameters;

CREATE TABLE #BenchmarkParameters
(
    booking_id INT NOT NULL,
    space_code VARCHAR(50) NOT NULL,
    requested_start DATETIME NOT NULL,
    requested_end DATETIME NOT NULL,
    occupying_booking_count BIGINT NOT NULL
);

;WITH SpaceDensity AS
(
    SELECT
        space_code,
        COUNT_BIG(*) AS occupying_booking_count
    FROM dbo.BOOKING
    WHERE booking_status IN ('Approved', 'Checked In')
    GROUP BY space_code
)
INSERT INTO #BenchmarkParameters
(
    booking_id,
    space_code,
    requested_start,
    requested_end,
    occupying_booking_count
)
SELECT TOP (1)
    p.booking_id,
    p.space_code,
    p.requested_start,
    p.requested_end,
    d.occupying_booking_count
FROM dbo.BOOKING AS p
JOIN SpaceDensity AS d
    ON d.space_code = p.space_code
WHERE p.booking_status = 'Pending'
  AND EXISTS
  (
      SELECT 1
      FROM dbo.BOOKING AS b
      WHERE b.space_code = p.space_code
        AND b.booking_id <> p.booking_id
        AND b.booking_status IN ('Approved', 'Checked In')
        AND b.requested_start < p.requested_end
        AND b.requested_end > p.requested_start
  )
ORDER BY
    d.occupying_booking_count DESC,
    p.booking_id;

IF NOT EXISTS (SELECT 1 FROM #BenchmarkParameters)
    THROW 51045,
          'No representative Pending booking with a real occupying conflict was found.',
          1;

SELECT
    booking_id,
    space_code,
    requested_start,
    requested_end,
    occupying_booking_count
FROM #BenchmarkParameters;
GO
/* ============================================================
   4. Baseline conflict-check execution

   Only this script's own candidate index is removed. No global cache or
   procedure-cache clearing is performed.
   ============================================================ */
DROP TABLE IF EXISTS #BenchmarkResults;

CREATE TABLE #BenchmarkResults
(
    phase VARCHAR(10) PRIMARY KEY,
    conflict_result BIT NOT NULL
);
GO

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.BOOKING')
      AND name = 'IX_BOOKING_ConflictLookup'
)
BEGIN
    DROP INDEX IX_BOOKING_ConflictLookup
    ON dbo.BOOKING;
END;
GO

-- Explicitly prove that BEFORE really has no candidate index.
IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.BOOKING')
      AND name = 'IX_BOOKING_ConflictLookup'
)
BEGIN
    THROW 51046,
          'Candidate index still exists before baseline benchmark.',
          1;
END;
GO
/* ============================================================
   Existing BOOKING index inventory
   ============================================================ */

SELECT
    i.name AS index_name,
    i.type_desc,
    i.is_unique,
    c.name AS column_name,
    ic.key_ordinal,
    ic.is_included_column
FROM sys.indexes AS i
JOIN sys.index_columns AS ic
    ON i.object_id = ic.object_id
   AND i.index_id = ic.index_id
JOIN sys.columns AS c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID('dbo.BOOKING')
  AND i.name IS NOT NULL
ORDER BY
    i.index_id,
    ic.key_ordinal,
    ic.index_column_id;
GO

DECLARE @LockedSpaceCode VARCHAR(50);
DECLARE @BookingId INT;
DECLARE @RequestedStart DATETIME;
DECLARE @RequestedEnd DATETIME;
DECLARE @BaselineConflictResult BIT;

SELECT
    @LockedSpaceCode = space_code,
    @BookingId = booking_id,
    @RequestedStart = requested_start,
    @RequestedEnd = requested_end
FROM #BenchmarkParameters;

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS PROFILE ON;

SELECT @BaselineConflictResult =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status IN ('Approved', 'Checked In')
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    )
    THEN CONVERT(BIT, 1)
    ELSE CONVERT(BIT, 0)
    END;

SET STATISTICS PROFILE OFF;

-- Warm run 1
SELECT @BaselineConflictResult =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status IN ('Approved', 'Checked In')
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    )
    THEN CONVERT(BIT, 1)
    ELSE CONVERT(BIT, 0)
    END;

-- Warm run 2
SELECT @BaselineConflictResult =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status IN ('Approved', 'Checked In')
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    )
    THEN CONVERT(BIT, 1)
    ELSE CONVERT(BIT, 0)
    END;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

INSERT INTO #BenchmarkResults
(
    phase,
    conflict_result
)
VALUES
(
    'BEFORE',
    @BaselineConflictResult
);

SELECT
    'BEFORE' AS measurement_phase,
    @BaselineConflictResult AS conflict_exists;
GO
/* ============================================================
   5. Candidate index

   Supports the authoritative conflict predicate:
     - equality on space_code
     - occupying-status filter on booking_status
     - range predicate on requested_start
     - requested_end available for residual overlap evaluation

   The index is not filtered because the real procedure must
   consider both Approved and Checked In rows.
   ============================================================ */
CREATE NONCLUSTERED INDEX IX_BOOKING_ConflictLookup
ON dbo.BOOKING
(
    space_code,
    booking_status,
    requested_start
)
INCLUDE
(
    requested_end
);
GO

/* ============================================================
   6. After-index conflict-check execution

   Uses the identical predicate and parameter values from section 4.
   ============================================================ */
DECLARE @LockedSpaceCode VARCHAR(50);
DECLARE @BookingId INT;
DECLARE @RequestedStart DATETIME;
DECLARE @RequestedEnd DATETIME;
DECLARE @AfterConflictResult BIT;

SELECT
    @LockedSpaceCode = space_code,
    @BookingId = booking_id,
    @RequestedStart = requested_start,
    @RequestedEnd = requested_end
FROM #BenchmarkParameters;

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
          AND b.booking_status IN ('Approved', 'Checked In')
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    )
    THEN CONVERT(BIT, 1)
    ELSE CONVERT(BIT, 0)
    END;

SET STATISTICS PROFILE OFF;

-- Two additional warm-cache executions use the identical predicate and parameters.
SELECT @AfterConflictResult =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_id <> @BookingId
          AND b.booking_status IN ('Approved', 'Checked In')
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
          AND b.booking_status IN ('Approved', 'Checked In')
          AND b.requested_start < @RequestedEnd
          AND b.requested_end > @RequestedStart
    ) THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;


INSERT INTO #BenchmarkResults (phase, conflict_result)
VALUES ('AFTER', @AfterConflictResult);

SELECT 'After index' AS measurement_phase,
       @AfterConflictResult AS conflict_exists;
GO
/* ============================================================
   Candidate index storage footprint
   ============================================================ */

SELECT
    i.name AS index_name,
    SUM(ps.row_count) AS index_row_count,
    SUM(ps.used_page_count) AS used_pages,
    CAST(
        SUM(ps.used_page_count) * 8.0 / 1024
        AS DECIMAL(12,2)
    ) AS used_size_mb
FROM sys.indexes AS i
JOIN sys.dm_db_partition_stats AS ps
    ON ps.object_id = i.object_id
   AND ps.index_id = i.index_id
WHERE i.object_id = OBJECT_ID('dbo.BOOKING')
  AND i.name = 'IX_BOOKING_ConflictLookup'
GROUP BY i.name;
GO
/* ============================================================
   7. Correctness and invariant checks
   ============================================================ */

DECLARE @BeforeResult BIT;
DECLARE @AfterResult BIT;

SELECT @BeforeResult = conflict_result
FROM #BenchmarkResults
WHERE phase = 'BEFORE';

SELECT @AfterResult = conflict_result
FROM #BenchmarkResults
WHERE phase = 'AFTER';

IF @BeforeResult IS NULL OR @AfterResult IS NULL
BEGIN
    THROW 51049,
          'Before or after benchmark result is missing.',
          1;
END;

IF @BeforeResult <> @AfterResult
BEGIN
    THROW 51050,
          'Before/after booking conflict results differ.',
          1;
END;

SELECT
    @BeforeResult AS before_conflict_result,
    @AfterResult AS after_conflict_result,
    'PASS' AS result_equality_check;
GO

SELECT
    COUNT(*) AS prohibited_occupying_overlap_pairs_after_index
FROM dbo.BOOKING AS b1
JOIN dbo.BOOKING AS b2
    ON b1.space_code = b2.space_code
   AND b1.booking_id < b2.booking_id
WHERE b1.booking_status IN ('Approved', 'Checked In')
  AND b2.booking_status IN ('Approved', 'Checked In')
  AND b1.requested_start < b2.requested_end
  AND b1.requested_end > b2.requested_start
OPTION (MAXDOP 1);

SELECT
    OBJECT_DEFINITION(OBJECT_ID('dbo.sp_ApproveBooking'))
        AS approval_procedure_definition;
GO

/* ============================================================
   8. Optional rollback

   Run only when the benchmark index should be removed. This is the only
   index this script may drop.

   DROP INDEX IX_BOOKING_ConflictLookup ON dbo.BOOKING;
   ============================================================ */
DROP TABLE IF EXISTS #BenchmarkResults;
DROP TABLE IF EXISTS #BenchmarkParameters;
GO