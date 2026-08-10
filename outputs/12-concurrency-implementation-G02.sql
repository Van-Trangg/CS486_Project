/* =========================================================
   STEP 12 -- CONCURRENCY IMPLEMENTATION
   Campus Space Management System, Group G02

   Implements the Step 11 strict two-phase locking design using
   dbo.SPACE as the per-space serialization resource.
   Schema baseline: outputs/05-db-definition-G02.sql, migrated by
   outputs/10-schema-migration-G02.sql to the Step 9 design.

   The Phase 1 maintenance triggers are replaced below because they
   blocked advisory bookings and prevented an escalation from exposing
   already-approved affected bookings. Test-only delays and separate-
   session demonstrations are intentionally deferred to Step 13.
   ========================================================= */

/* Step 12 update:
   - Converts sp_SubmitBooking into the sole protected booking-creation path.
   - Derives resolution_path once at INSERT and immediately invokes the
     protected approval path for eligible Instant submissions.
   - Records the exact applicable advisory acknowledgement set atomically.
   - Closes direct BOOKING INSERT and protected-column write bypasses.
   - Restores Approved + Checked In occupancy semantics while preserving the
     approved per-space lock protocol for submission, approval, and escalation. */

USE University;
GO
/* =========================================================
   Approval access-path enforcement
   ========================================================= */

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = 'AppServiceRole'
      AND type = 'R'
)
BEGIN
    CREATE ROLE AppServiceRole;
END;
GO


/* =========================================================
   1. Implementation assumptions and object mapping

   BOOKING: booking_id, space_code, requested_start, requested_end,
            booking_status, resolution_path, approver_id, decision_time,
            decision_note
   MAINTENANCERECORD: maintenance_id, space_code, start_time,
            completion_time, maintenance_status, impact_level

   dbo.sp_SubmitBooking is the sole normal BOOKING insert path, and every
   transition of BOOKING.booking_status to Approved must call
   dbo.sp_ApproveBooking. Direct writes are prohibited by section 5.
   ========================================================= */

IF OBJECT_ID('dbo.SPACE', 'U') IS NULL
   OR OBJECT_ID('dbo.BOOKING', 'U') IS NULL
   OR OBJECT_ID('dbo.MAINTENANCERECORD', 'U') IS NULL
   OR OBJECT_ID('dbo.MAINTENANCE_IMPACT_HISTORY', 'U') IS NULL
BEGIN
    ;THROW 51000, 'Step 12 requires the Phase 1 schema and Step 10 migration.', 1;
END;
GO

/* Phase 1 treated every open maintenance record as unavailable. Phase 2
   blocks only active out-of-service maintenance; advisory maintenance is
   disclosed and acknowledged at booking submission instead. */


/* An escalation must be allowed to identify already-approved bookings for
   staff follow-up. The protected escalation procedure serializes this
   change with approval; the Phase 1 bidirectional-overlap trigger would
   reject the required escalation and is therefore removed. */
DROP TRIGGER IF EXISTS dbo.TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP;
DROP TRIGGER IF EXISTS dbo.TR_BOOKING_LOCK_APPROVED_FIELDS;
GO


/* =========================================================
   2. Protected booking submission procedure

   The application supplies booking facts and the complete set of advisories
   it presented. This procedure locks SPACE before inserting BOOKING, derives
   resolution_path from authoritative data, records acknowledgements, and
   immediately invokes the protected approval path for Instant submissions.
   ========================================================= */
IF TYPE_ID(N'dbo.BookingAdvisoryAckListType') IS NULL
BEGIN
    EXEC(N'CREATE TYPE dbo.BookingAdvisoryAckListType AS TABLE
    (
        maintenance_id INT NOT NULL PRIMARY KEY
    );');
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SubmitBooking
    @RequesterId VARCHAR(50),
    @SpaceCode VARCHAR(50),
    @RequestedStart DATETIME,
    @RequestedEnd DATETIME,
    @Purpose VARCHAR(100),
    @ExpectedParticipants INT,
    @Acknowledgements dbo.BookingAdvisoryAckListType READONLY,
    @BookingId INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LockedSpaceCode VARCHAR(50);
    DECLARE @CurrentSpaceStatus VARCHAR(30);
    DECLARE @SpaceType VARCHAR(50);
    DECLARE @UsagePolicy NVARCHAR(MAX);
    DECLARE @Capacity INT;
    DECLARE @RequesterRole VARCHAR(50);
    DECLARE @RequesterStatus VARCHAR(20);
    DECLARE @ResolutionPath VARCHAR(20);
    DECLARE @CreatedAt DATETIME;
    DECLARE @HasApprovedOverlap BIT = 0;
    DECLARE @HasOutOfServiceOverlap BIT = 0;

    IF @RequesterId IS NULL OR @SpaceCode IS NULL
       OR @RequestedStart IS NULL OR @RequestedEnd IS NULL
       OR @Purpose IS NULL OR @ExpectedParticipants IS NULL
        THROW 51041, 'Requester, space, time range, purpose, and participant count are required.', 1;

    IF @@TRANCOUNT <> 0
        THROW 51042, 'sp_SubmitBooking cannot run inside a caller transaction.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @LockedSpaceCode = s.space_code,
            @CurrentSpaceStatus = s.current_status,
            @SpaceType = s.space_type,
            @UsagePolicy = s.usage_policy,
            @Capacity = s.capacity
        FROM dbo.SPACE AS s WITH (UPDLOCK, HOLDLOCK)
        WHERE s.space_code = @SpaceCode;

        IF @LockedSpaceCode IS NULL
            THROW 51044, 'Space not found.', 1;

        SELECT
            @RequesterRole = u.role,
            @RequesterStatus = u.account_status
        FROM dbo.[USER] AS u
        WHERE u.user_id = @RequesterId;

        IF @RequesterRole IS NULL
            THROW 51043, 'Requester not found.', 1;

        IF @RequesterStatus <> 'Active'
            THROW 51047, 'Only an active requester may submit a booking.', 1;

        IF @RequestedStart >= @RequestedEnd OR @ExpectedParticipants <= 0
            THROW 51048, 'Booking time range or participant count is invalid.', 1;

        SET @CreatedAt = GETDATE();

        IF @RequestedStart < @CreatedAt
            THROW 51049, 'The requested start must not be earlier than booking creation.', 1;

        IF @ExpectedParticipants > @Capacity
            THROW 51050, 'Expected participants exceed the space capacity.', 1;

        /* The caller-provided set must exactly equal the authoritative active
           overlapping advisory set after the SPACE lock is held. */
        IF EXISTS
        (
            SELECT 1
            FROM dbo.MAINTENANCERECORD AS m
            WHERE m.space_code = @LockedSpaceCode
              AND m.maintenance_status IN ('Reported', 'In Progress')
              AND m.impact_level = 'advisory'
              AND m.start_time < @RequestedEnd
              AND ISNULL(m.completion_time, CONVERT(DATETIME, '9999-12-31', 120)) > @RequestedStart
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM @Acknowledgements AS a
                  WHERE a.maintenance_id = m.maintenance_id
              )
        )
            THROW 51051, 'Every active overlapping advisory must be acknowledged at submission.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM @Acknowledgements AS a
            LEFT JOIN dbo.MAINTENANCERECORD AS m
              ON m.maintenance_id = a.maintenance_id
             AND m.space_code = @LockedSpaceCode
             AND m.maintenance_status IN ('Reported', 'In Progress')
             AND m.impact_level = 'advisory'
             AND m.start_time < @RequestedEnd
             AND ISNULL(m.completion_time, CONVERT(DATETIME, '9999-12-31', 120)) > @RequestedStart
            WHERE m.maintenance_id IS NULL
        )
            THROW 51052, 'Booking contains an acknowledgement for a non-applicable advisory.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.MAINTENANCERECORD AS m
            WHERE m.space_code = @LockedSpaceCode
              AND m.maintenance_status IN ('Reported', 'In Progress')
              AND m.impact_level = 'out-of-service'
              AND m.start_time < @RequestedEnd
              AND ISNULL(m.completion_time, CONVERT(DATETIME, '9999-12-31', 120)) > @RequestedStart
        )
            SET @HasOutOfServiceOverlap = 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.BOOKING AS b
            WHERE b.space_code = @LockedSpaceCode
              AND b.booking_status IN ('Approved', 'Checked In')
              AND b.requested_start < @RequestedEnd
              AND b.requested_end > @RequestedStart
        )
            SET @HasApprovedOverlap = 1;

        /* usage_policy remains unstructured Phase 1 text. No executable text
           grammar is approved, so only approved machine-evaluable rules are
           applied here. A request that cannot be approved now follows Staff. */
        IF @SpaceType = 'Classroom'
           AND @RequesterRole IN ('Lecturer', 'Teaching Assistant')
           AND @CurrentSpaceStatus NOT IN ('Retired', 'Temporarily Closed')
           AND @HasApprovedOverlap = 0
           AND @HasOutOfServiceOverlap = 0
            SET @ResolutionPath = 'Instant';
        ELSE
            SET @ResolutionPath = 'Staff';

        INSERT INTO dbo.BOOKING
            (space_code, requester_id, requested_start, requested_end, purpose,
             expected_participants, booking_status, created_at, approver_id,
             decision_time, decision_note, rejection_reason, resolution_path)
        VALUES
            (@LockedSpaceCode, @RequesterId, @RequestedStart, @RequestedEnd,
             @Purpose, @ExpectedParticipants, 'Pending', @CreatedAt, NULL,
             NULL, NULL, NULL, @ResolutionPath);

        SET @BookingId = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.BOOKING_ADVISORY_ACK
            (booking_id, maintenance_id, acknowledged_at)
        SELECT
            @BookingId,
            a.maintenance_id,
            @CreatedAt
        FROM @Acknowledgements AS a;

        IF @ResolutionPath = 'Instant'
        BEGIN
            EXEC dbo.sp_ApproveBooking
                @BookingId = @BookingId,
                @ApproverId = NULL,
                @DecisionNote = NULL;
        END;

        COMMIT TRANSACTION;

        SELECT
            @BookingId AS booking_id,
            @ResolutionPath AS resolution_path,
            CASE WHEN @ResolutionPath = 'Instant' THEN 'Approved' ELSE 'Pending' END AS booking_status;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        SET @BookingId = NULL;
        THROW;
    END CATCH;
END;
GO

/* =========================================================
   3. Protected booking approval procedure
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_ApproveBooking
    @BookingId INT,
    @ApproverId VARCHAR(50) = NULL,
    @DecisionNote NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SpaceCode VARCHAR(50);
    DECLARE @LockedSpaceCode VARCHAR(50);
    DECLARE @CurrentSpaceStatus VARCHAR(30);
    DECLARE @RequestedStart DATETIME;
    DECLARE @RequestedEnd DATETIME;
    DECLARE @CreatedAt DATETIME;
    DECLARE @BookingStatus VARCHAR(30);
    DECLARE @ResolutionPath VARCHAR(20);
    DECLARE @StartedTransaction BIT = 0;

    IF @BookingId IS NULL
        THROW 51002, 'BookingId is required.', 1;

    /*
        This non-locking lookup identifies the per-space lock target.
        The booking is reread after the space lock has been acquired.
    */
    SELECT @SpaceCode = b.space_code
    FROM dbo.BOOKING AS b
    WHERE b.booking_id = @BookingId;

    IF @SpaceCode IS NULL
        THROW 51003, 'Booking not found.', 1;

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @StartedTransaction = 1;
        END
        ELSE
        BEGIN
            SAVE TRANSACTION sp_ApproveBookingSave;
        END;

        /*
            Strict 2PL serialization point.

            The procedure also reads current_status while holding the
            per-space lock so that space availability cannot change
            unnoticed during approval.
        */
        SELECT
            @LockedSpaceCode = s.space_code,
            @CurrentSpaceStatus = s.current_status
        FROM dbo.SPACE AS s WITH (UPDLOCK, HOLDLOCK)
        WHERE s.space_code = @SpaceCode;

        IF @LockedSpaceCode IS NULL
            THROW 51004, 'Space not found.', 1;

        /*
            Primary space-status validation.

            The trigger remains as a secondary backstop, but the procedure
            now rejects retired and temporarily closed spaces explicitly.
        */
        IF @CurrentSpaceStatus IN ('Retired', 'Temporarily Closed')
            THROW 51014,
                  'The space is retired or temporarily closed and cannot be booked.',
                  1;

        SET @BookingStatus = NULL;

        SELECT
            @SpaceCode = b.space_code,
            @RequestedStart = b.requested_start,
            @RequestedEnd = b.requested_end,
            @CreatedAt = b.created_at,
            @BookingStatus = b.booking_status,
            @ResolutionPath = b.resolution_path
        FROM dbo.BOOKING AS b
        WHERE b.booking_id = @BookingId;

        IF @BookingStatus IS NULL
            THROW 51003, 'Booking not found.', 1;

        IF @SpaceCode <> @LockedSpaceCode
            THROW 51005,
                  'Booking space changed before approval; retry the approval.',
                  1;

        IF @BookingStatus <> 'Pending'
            THROW 51006, 'Booking is not eligible for approval.', 1;

        IF @RequestedStart >= @RequestedEnd
            THROW 51007, 'Booking time range is invalid.', 1;

        IF @ResolutionPath = 'Staff'
        BEGIN
            IF @ApproverId IS NULL
                THROW 51008,
                      'A staff approval requires an approver.',
                      1;

            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.[USER] AS u
                WHERE u.user_id = @ApproverId
                  AND u.account_status = 'Active'
                  AND u.role IN
                      ('Facility Staff', 'Facility Manager')
            )
                THROW 51009,
                      'Approver must be an active Facility Staff or Facility Manager user.',
                      1;
        END
        ELSE IF @ResolutionPath = 'Instant'
        BEGIN
            IF @ApproverId IS NOT NULL
                THROW 51010,
                      'Instant approval must not specify an approver.',
                      1;

            IF @DecisionNote IS NOT NULL
                THROW 51023,
                      'Instant approval must not specify a staff decision note.',
                      1;
        END
        ELSE
        BEGIN
            ;THROW 51011,
                  'Booking has an invalid resolution path.',
                  1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.BOOKING AS b
            WHERE b.space_code = @LockedSpaceCode
              AND b.booking_id <> @BookingId
              AND b.booking_status IN ('Approved', 'Checked In')
              AND b.requested_start < @RequestedEnd
              AND b.requested_end > @RequestedStart
        )
            THROW 51012,
                  'An overlapping approved or checked-in booking exists for this space.',
                  1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.MAINTENANCERECORD AS m
            WHERE m.space_code = @LockedSpaceCode
              AND m.maintenance_status IN
                  ('Reported', 'In Progress')
              AND m.impact_level = 'out-of-service'
              AND m.start_time < @RequestedEnd
              AND ISNULL
                  (
                      m.completion_time,
                      CONVERT(DATETIME, '9999-12-31', 120)
                  ) > @RequestedStart
        )
            THROW 51013,
                  'Overlapping active out-of-service maintenance exists for this space.',
                  1;

        /* Acknowledgements are captured at submission time. Their historical
           status/impact must not be reinterpreted during later Staff approval,
           but every stored acknowledgement must still belong to this space. */
        IF EXISTS
        (
            SELECT 1
            FROM dbo.BOOKING_ADVISORY_ACK AS a
            JOIN dbo.MAINTENANCERECORD AS m
              ON m.maintenance_id = a.maintenance_id
            WHERE a.booking_id = @BookingId
              AND m.space_code <> @LockedSpaceCode
        )
            THROW 51053,
                  'The booking contains an advisory acknowledgement for another space.',
                  1;

        /* Instant approval occurs in the submission transaction, so its
           acknowledgement set must still exactly match current advisories. */
        IF @ResolutionPath = 'Instant'
           AND
           (
               EXISTS
               (
                   SELECT 1
                   FROM dbo.MAINTENANCERECORD AS m
                   WHERE m.space_code = @LockedSpaceCode
                     AND m.maintenance_status IN ('Reported', 'In Progress')
                     AND m.impact_level = 'advisory'
                     AND m.start_time < @RequestedEnd
                     AND ISNULL(m.completion_time, CONVERT(DATETIME, '9999-12-31', 120)) > @RequestedStart
                     AND NOT EXISTS
                     (
                         SELECT 1
                         FROM dbo.BOOKING_ADVISORY_ACK AS a
                         WHERE a.booking_id = @BookingId
                           AND a.maintenance_id = m.maintenance_id
                     )
               )
               OR EXISTS
               (
                   SELECT 1
                   FROM dbo.BOOKING_ADVISORY_ACK AS a
                   LEFT JOIN dbo.MAINTENANCERECORD AS m
                     ON m.maintenance_id = a.maintenance_id
                    AND m.space_code = @LockedSpaceCode
                    AND m.maintenance_status IN ('Reported', 'In Progress')
                    AND m.impact_level = 'advisory'
                    AND m.start_time < @RequestedEnd
                    AND ISNULL(m.completion_time, CONVERT(DATETIME, '9999-12-31', 120)) > @RequestedStart
                   WHERE a.booking_id = @BookingId
                     AND m.maintenance_id IS NULL
               )
           )
            THROW 51054,
                  'Instant approval requires the exact active advisory acknowledgement set.',
                  1;

        UPDATE dbo.BOOKING
        SET booking_status = 'Approved',
            approver_id =
                CASE
                    WHEN @ResolutionPath = 'Staff'
                        THEN @ApproverId
                    ELSE NULL
                END,
            decision_time =
                CASE
                    WHEN @ResolutionPath = 'Instant'
                        THEN @CreatedAt
                    ELSE GETDATE()
                END,
            decision_note = @DecisionNote,
            rejection_reason = NULL
        WHERE booking_id = @BookingId;

        IF @StartedTransaction = 1
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @StartedTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        ELSE IF @StartedTransaction = 0 AND XACT_STATE() = 1
            ROLLBACK TRANSACTION sp_ApproveBookingSave;

        THROW;
    END CATCH;
END;
GO

/* =========================================================
   4. Protected maintenance escalation procedure
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_EscalateMaintenanceImpact
    @MaintenanceId INT,
    @ChangedByUserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SpaceCode VARCHAR(50);
    DECLARE @LockedSpaceCode VARCHAR(50);
    DECLARE @MaintenanceSpaceCode VARCHAR(50);
    DECLARE @MaintenanceStatus VARCHAR(20);
    DECLARE @ImpactLevel VARCHAR(20);
    DECLARE @StartTime DATETIME;
    DECLARE @CompletionTime DATETIME;

    IF @MaintenanceId IS NULL OR @ChangedByUserId IS NULL
        THROW 51030, 'MaintenanceId and ChangedByUserId are required.', 1;

    /* See the matching ownership rule in sp_ApproveBooking. */
    IF @@TRANCOUNT <> 0
        THROW 51022, 'sp_EscalateMaintenanceImpact cannot run inside a caller transaction.', 1;

    SELECT @SpaceCode = m.space_code
    FROM dbo.MAINTENANCERECORD AS m
    WHERE m.maintenance_id = @MaintenanceId;

    IF @SpaceCode IS NULL
        THROW 51015, 'Maintenance record not found.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* The same resource and lock order as sp_ApproveBooking: SPACE,
           then MAINTENANCERECORD and BOOKING. */
        SELECT @LockedSpaceCode = s.space_code
        FROM dbo.SPACE AS s WITH (UPDLOCK, HOLDLOCK)
        WHERE s.space_code = @SpaceCode;

        IF @LockedSpaceCode IS NULL
            THROW 51016, 'Space not found.', 1;

        SET @MaintenanceSpaceCode = NULL;
        SELECT
            @MaintenanceSpaceCode = m.space_code,
            @MaintenanceStatus = m.maintenance_status,
            @ImpactLevel = m.impact_level,
            @StartTime = m.start_time,
            @CompletionTime = m.completion_time
        FROM dbo.MAINTENANCERECORD AS m
        WHERE m.maintenance_id = @MaintenanceId;

        IF @MaintenanceSpaceCode IS NULL
            THROW 51015, 'Maintenance record not found.', 1;

        IF @MaintenanceSpaceCode <> @LockedSpaceCode
            THROW 51017, 'Maintenance space changed before escalation; retry the escalation.', 1;

        IF @MaintenanceStatus NOT IN ('Reported', 'In Progress')
            THROW 51018, 'Only open maintenance records may be escalated.', 1;

        IF @ImpactLevel <> 'advisory'
            THROW 51019, 'Only advisory maintenance may be escalated to out-of-service.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.[USER] AS u
            WHERE u.user_id = @ChangedByUserId
              AND u.account_status = 'Active'
              AND u.role IN ('Facility Staff', 'Facility Manager')
        )
            THROW 51020, 'ChangedByUserId must be an active Facility Staff or Facility Manager user.', 1;

        UPDATE dbo.MAINTENANCERECORD
        SET impact_level = 'out-of-service'
        WHERE maintenance_id = @MaintenanceId;

        INSERT INTO dbo.MAINTENANCE_IMPACT_HISTORY
            (maintenance_id, old_impact_level, new_impact_level, changed_at, changed_by_user_id)
        VALUES
            (@MaintenanceId, 'advisory', 'out-of-service', GETDATE(), @ChangedByUserId);

        /* Returned before commit while the space lock remains held, so this
           result cannot omit an approval that races with the escalation. */
        SELECT
            b.booking_id,
            b.requester_id,
            b.space_code,
            b.requested_start,
            b.requested_end,
            b.booking_status,
            @MaintenanceId AS maintenance_id
        FROM dbo.BOOKING AS b
        WHERE b.space_code = @LockedSpaceCode
          AND b.booking_status IN ('Approved', 'Checked In')
          AND b.requested_start < ISNULL(@CompletionTime, CONVERT(DATETIME, '9999-12-31', 120))
          AND b.requested_end > @StartTime
        ORDER BY b.requested_start, b.booking_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =========================================================
   5. Permission or access-path notes

   AppServiceRole may create and resolve bookings only through the protected
   procedures. Ownership chaining permits procedure-owned writes while direct
   INSERT and protected-column UPDATE attempts remain denied. Deadlock error
   1205 is surfaced for caller-managed retry outside the procedures.
   ========================================================= */
DENY INSERT
ON OBJECT::dbo.BOOKING
TO AppServiceRole;
GO

DENY UPDATE 
(
    booking_status,
    approver_id,
    decision_time,
    decision_note,
    resolution_path,
    rejection_reason,
    requester_id,
    space_code,
    requested_start,
    requested_end
)
ON OBJECT::dbo.BOOKING
TO AppServiceRole;
GO

DENY UPDATE
(
    impact_level
)
ON OBJECT::dbo.MAINTENANCERECORD
TO AppServiceRole;
GO

DENY INSERT
ON OBJECT::dbo.MAINTENANCE_IMPACT_HISTORY
TO AppServiceRole;
GO
DENY INSERT, UPDATE, DELETE
ON OBJECT::dbo.BOOKING_ADVISORY_ACK
TO AppServiceRole;
GO
GRANT EXECUTE, REFERENCES
ON TYPE::dbo.BookingAdvisoryAckListType
TO AppServiceRole;
GO
GRANT EXECUTE
ON OBJECT::dbo.sp_SubmitBooking
TO AppServiceRole;
GO
GRANT EXECUTE
ON OBJECT::dbo.sp_ApproveBooking
TO AppServiceRole;
GO

GRANT EXECUTE
ON OBJECT::dbo.sp_EscalateMaintenanceImpact
TO AppServiceRole;
GO

/*
Deployment note:
Add the actual application database user to AppServiceRole.

Example:
ALTER ROLE AppServiceRole ADD MEMBER AppServiceUser;

The application user must not be a member of db_owner or db_datawriter.
*/
/* =========================================================
   6. Verification queries for object creation
   ========================================================= */
SELECT
    p.name AS procedure_name,
    p.create_date,
    p.modify_date
FROM sys.procedures AS p
WHERE p.schema_id = SCHEMA_ID('dbo')
  AND p.name IN
      ('sp_SubmitBooking', 'sp_ApproveBooking', 'sp_EscalateMaintenanceImpact');

SELECT
    t.name AS trigger_name,
    t.is_disabled
FROM sys.triggers AS t
WHERE t.parent_id = OBJECT_ID('dbo.BOOKING')
  AND t.name = 'TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE';
GO

SELECT
    dp.state_desc AS permission_state,
    dp.permission_name,
    OBJECT_SCHEMA_NAME(dp.major_id) AS schema_name,
    OBJECT_NAME(dp.major_id) AS object_name,
    c.name AS column_name
FROM sys.database_permissions AS dp
JOIN sys.database_principals AS pr
    ON pr.principal_id = dp.grantee_principal_id
LEFT JOIN sys.columns AS c
    ON c.object_id = dp.major_id
   AND c.column_id = dp.minor_id
WHERE pr.name = 'AppServiceRole'
  AND dp.class_desc = 'OBJECT_OR_COLUMN'
  AND OBJECT_SCHEMA_NAME(dp.major_id) = 'dbo'
  AND OBJECT_NAME(dp.major_id) IN
       ('BOOKING', 'BOOKING_ADVISORY_ACK', 'MAINTENANCERECORD',
        'MAINTENANCE_IMPACT_HISTORY', 'sp_SubmitBooking',
        'sp_ApproveBooking', 'sp_EscalateMaintenanceImpact')
ORDER BY object_name, column_name, permission_state, dp.permission_name;
GO

SELECT
    dp.state_desc AS permission_state,
    dp.permission_name,
    SCHEMA_NAME(tt.schema_id) AS schema_name,
    tt.name AS type_name
FROM sys.database_permissions AS dp
JOIN sys.database_principals AS pr
  ON pr.principal_id = dp.grantee_principal_id
JOIN sys.table_types AS tt
  ON tt.user_type_id = dp.major_id
WHERE pr.name = 'AppServiceRole'
  AND dp.class_desc = 'TYPE'
  AND tt.user_type_id = TYPE_ID(N'dbo.BookingAdvisoryAckListType')
ORDER BY dp.permission_name;
GO

/* =========================================================
   7. Known limitations and Step 13 test handoff

   - This script contains no WAITFOR statements or multi-session tests.
   - Step 13 must demonstrate staff/staff, instant/instant, instant/staff,
     and approval-versus-escalation contention in separate sessions.
   - The per-space lock protects only submission, approval, and escalation
     calls that use these protected procedures; the permission policy above
     is required.
   ========================================================= */
