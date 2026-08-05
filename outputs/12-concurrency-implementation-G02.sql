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
            booking_status, approval_path, approver_id, decision_time,
            decision_note
   MAINTENANCERECORD: maintenance_id, space_code, start_time,
            completion_time, maintenance_status, impact_level

   Every transition of BOOKING.booking_status to Approved must call
   dbo.sp_ApproveBooking. Direct updates bypass the lock protocol and
   are prohibited by the access policy in section 4.
   ========================================================= */

IF OBJECT_ID('dbo.SPACE', 'U') IS NULL
   OR OBJECT_ID('dbo.BOOKING', 'U') IS NULL
   OR OBJECT_ID('dbo.MAINTENANCERECORD', 'U') IS NULL
   OR OBJECT_ID('dbo.MAINTENANCE_IMPACT_HISTORY', 'U') IS NULL
BEGIN
    THROW 51000, 'Step 12 requires the Phase 1 schema and Step 10 migration.', 1;
END;
GO

/* Phase 1 treated every open maintenance record as unavailable. Phase 2
   blocks only active out-of-service maintenance; advisory maintenance is
   disclosed and acknowledged at booking submission instead. */
CREATE OR ALTER TRIGGER dbo.TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE
ON dbo.BOOKING
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.SPACE AS s ON s.space_code = i.space_code
        WHERE i.booking_status = 'Approved'
          AND
          (
              s.current_status IN ('Retired', 'Temporarily Closed')
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.BOOKING AS b
                  WHERE b.space_code = i.space_code
                    AND b.booking_id <> i.booking_id
                    AND b.booking_status = 'Approved'
                    AND b.requested_start < i.requested_end
                    AND b.requested_end > i.requested_start
              )
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.MAINTENANCERECORD AS m
                  WHERE m.space_code = i.space_code
                    AND m.maintenance_status IN ('Reported', 'In Progress')
                    AND m.impact_level = 'out-of-service'
                    AND m.start_time < i.requested_end
                    AND ISNULL(m.completion_time, CONVERT(DATETIME, '9999-12-31', 120)) > i.requested_start
              )
          )
    )
    BEGIN
        THROW 51001, 'Approved bookings cannot overlap another approved booking, active out-of-service maintenance, or an unavailable space.', 1;
    END;
END;
GO

/* An escalation must be allowed to identify already-approved bookings for
   staff follow-up. The protected escalation procedure serializes this
   change with approval; the Phase 1 bidirectional-overlap trigger would
   reject the required escalation and is therefore removed. */
DROP TRIGGER IF EXISTS dbo.TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP;
GO

/* =========================================================
   2. Protected booking approval procedure
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
    DECLARE @CurrentSpaceStatus VARCHAR(30);  -- Added
    DECLARE @RequestedStart DATETIME;
    DECLARE @RequestedEnd DATETIME;
    DECLARE @BookingStatus VARCHAR(30);
    DECLARE @ApprovalPath VARCHAR(20);

    IF @BookingId IS NULL
        THROW 51002, 'BookingId is required.', 1;

    /*
        This procedure owns its short transaction.
        Calling it from an outer transaction could retain the per-space
        lock beyond this procedure.
    */
    IF @@TRANCOUNT <> 0
        THROW 51021,
              'sp_ApproveBooking cannot run inside a caller transaction.',
              1;

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
        BEGIN TRANSACTION;

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
            @BookingStatus = b.booking_status,
            @ApprovalPath = b.approval_path
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

        IF @ApprovalPath = 'Staff'
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
        ELSE IF @ApprovalPath = 'Instant'
        BEGIN
            IF @ApproverId IS NOT NULL
                THROW 51010,
                      'Instant approval must not specify an approver.',
                      1;
        END
        ELSE
        BEGIN
            THROW 51011,
                  'Booking has an invalid approval path.',
                  1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.BOOKING AS b
            WHERE b.space_code = @LockedSpaceCode
              AND b.booking_id <> @BookingId
              AND b.booking_status = 'Approved'
              AND b.requested_start < @RequestedEnd
              AND b.requested_end > @RequestedStart
        )
            THROW 51012,
                  'An overlapping approved booking exists for this space.',
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

        UPDATE dbo.BOOKING
        SET booking_status = 'Approved',
            approver_id =
                CASE
                    WHEN @ApprovalPath = 'Staff'
                        THEN @ApproverId
                    ELSE NULL
                END,
            decision_time = GETDATE(),
            decision_note = @DecisionNote,
            rejection_reason = NULL
        WHERE booking_id = @BookingId;

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
   3. Protected maintenance escalation procedure
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
        THROW 51014, 'MaintenanceId and ChangedByUserId are required.', 1;

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
          AND b.booking_status = 'Approved'
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
   4. Permission or access-path notes

   The repository defines no database users or roles. Deployment must grant
   application/workflow identities EXECUTE on these procedures and must not
   grant them UPDATE on dbo.BOOKING.booking_status, approver_id, decision_time,
   or decision_note. Instant and staff approval paths both invoke
   dbo.sp_ApproveBooking; callers retry deadlock error 1205 outside the proc.
   ========================================================= */
DENY UPDATE ON OBJECT::dbo.BOOKING
(
    booking_status,
    approver_id,
    decision_time,
    decision_note,
    approval_path
)
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
   5. Verification queries for object creation
   ========================================================= */
SELECT
    p.name AS procedure_name,
    p.create_date,
    p.modify_date
FROM sys.procedures AS p
WHERE p.schema_id = SCHEMA_ID('dbo')
  AND p.name IN ('sp_ApproveBooking', 'sp_EscalateMaintenanceImpact');

SELECT
    t.name AS trigger_name,
    t.is_disabled
FROM sys.triggers AS t
WHERE t.parent_id = OBJECT_ID('dbo.BOOKING')
  AND t.name = 'TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE';
GO

/* =========================================================
   6. Known limitations and Step 13 test handoff

   - This script contains no WAITFOR statements or multi-session tests.
   - Step 13 must demonstrate staff/staff, instant/instant, instant/staff,
     and approval-versus-escalation contention in separate sessions.
   - The per-space lock protects only approval and escalation calls that use
     these protected procedures; the permission policy above is required.
   ========================================================= */
