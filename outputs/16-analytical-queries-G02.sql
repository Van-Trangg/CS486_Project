/* ============================================================
   QUERY 4: APPROVED BOOKINGS AFFECTED BY MAINTENANCE ESCALATION
   ============================================================

   Business Question:
   Which approved bookings overlap the period of a selected maintenance
   record that has been escalated from advisory to out-of-service?

   Target User(s): Facility Staff; Facility Manager.

   Business Value:
   Identifies requesters for staff follow-up after an escalation. The result
   supports contact, relocation, cancellation, or other follow-up; it does
   not perform any of those actions.

   Related Requirement(s):
   Phase 2 maintenance-impact rule requiring already-approved, overlapping
   bookings to be identifiable when advisory maintenance is escalated to
   out-of-service.

   Parameters:
   @maintenance_id INT: selected dbo.MAINTENANCERECORD.maintenance_id.

   Schema Assumptions and Limitations:
   - dbo.MAINTENANCE_IMPACT_HISTORY records escalation events. This query
     requires at least one advisory-to-out-of-service history row and returns
     the latest such event for the selected maintenance record.
   - The selected record must currently have impact_level = 'out-of-service'.
     A maintenance record that was later downgraded is deliberately excluded.
   - NULL completion_time means open-ended maintenance and is treated as
     ending at 9999-12-31, consistent with Step 12.
   - The schema does not persist an affected-booking snapshot at escalation.
     Therefore, the result identifies rows whose current booking_status is
     'Approved'; it cannot prove a booking was approved at changed_at.
*/

USE University;
GO

SET NOCOUNT ON;
GO

-- SQL Statement
-- Replace 18 with the selected maintenance record ID. The deterministic
-- Step 14 generator creates an escalation-history candidate with this ID.
DECLARE @maintenance_id INT = 18;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.MAINTENANCERECORD AS m
    WHERE m.maintenance_id = @maintenance_id
      AND m.impact_level = 'out-of-service'
      AND EXISTS
      (
          SELECT 1
          FROM dbo.MAINTENANCE_IMPACT_HISTORY AS h
          WHERE h.maintenance_id = m.maintenance_id
            AND h.old_impact_level = 'advisory'
            AND h.new_impact_level = 'out-of-service'
      )
)
    THROW 51030,
          'MaintenanceId must identify a currently out-of-service record with a recorded advisory-to-out-of-service escalation.',
          1;

;WITH TargetMaintenance AS
(
    SELECT
        m.maintenance_id,
        m.space_code,
        m.start_time,
        m.completion_time,
        m.maintenance_status,
        m.impact_level,
        escalation.history_id AS escalation_history_id,
        escalation.changed_at AS escalated_at,
        escalation.changed_by_user_id
    FROM dbo.MAINTENANCERECORD AS m
    CROSS APPLY
    (
        SELECT TOP (1)
            h.history_id,
            h.changed_at,
            h.changed_by_user_id
        FROM dbo.MAINTENANCE_IMPACT_HISTORY AS h
        WHERE h.maintenance_id = m.maintenance_id
          AND h.old_impact_level = 'advisory'
          AND h.new_impact_level = 'out-of-service'
        ORDER BY h.changed_at DESC, h.history_id DESC
    ) AS escalation
    WHERE m.maintenance_id = @maintenance_id
      AND m.impact_level = 'out-of-service'
)
SELECT
    tm.maintenance_id,
    tm.escalation_history_id,
    tm.escalated_at,
    tm.changed_by_user_id AS escalated_by_user_id,
    tm.impact_level AS maintenance_impact_level,
    tm.maintenance_status,
    tm.start_time AS maintenance_start_time,
    tm.completion_time AS maintenance_completion_time,
    s.space_code,
    s.space_name,
    b.booking_id,
    b.requested_start,
    b.requested_end,
    b.booking_status,
    b.approval_path,
    b.purpose,
    b.expected_participants,
    u.user_id AS requester_id,
    u.full_name AS requester_name,
    u.email AS requester_email,
    u.phone_number AS requester_phone_number
FROM TargetMaintenance AS tm
JOIN dbo.SPACE AS s
    ON s.space_code = tm.space_code
JOIN dbo.BOOKING AS b
    ON b.space_code = tm.space_code
   AND b.booking_status = 'Approved'
   -- Half-open interval: adjacency is not an overlap.
   AND b.requested_start < ISNULL(tm.completion_time, CONVERT(DATETIME, '9999-12-31', 120))
   AND b.requested_end > tm.start_time
JOIN dbo.[USER] AS u
    ON u.user_id = b.requester_id
ORDER BY b.requested_start, b.booking_id;
GO

/*
   Expected Behavior:
   - Returns one row per currently approved booking on the selected
     maintenance record's space whose requested period overlaps maintenance.
   - Returns zero rows when the selected, qualifying escalation has no such
     approved booking.
   - Raises error 51030 when the maintenance ID is missing, advisory-only,
     currently downgraded, or has no recorded advisory-to-out-of-service event.

   Functional Test Cases (prepared; not executed here):
   1. Multiple affected bookings: create two approved overlapping bookings for
      one escalated maintenance record; expect two distinct booking_id values.
   2. No affected bookings: use a qualifying escalation with no approved
      overlap; expect zero rows.
   3. Advisory-only maintenance: use an advisory record without escalation;
      expect error 51030.
   4. Another space: add an approved overlapping-time booking on another
      space; expect it to be excluded.
   5. Booking ends at maintenance start: expect exclusion.
   6. Booking starts at maintenance completion: expect exclusion.
   7. Booking fully inside maintenance: expect inclusion.
   8. Maintenance fully inside booking: expect inclusion.
   9. Open-ended maintenance: set completion_time to NULL on a qualifying
      open record; expect any later approved booking on the same space to be
      included.
   10. Duplicate prevention: add advisory acknowledgements or multiple history
       rows; expect each affected booking_id once. The query joins neither
       acknowledgement rows nor raw history rows, and CROSS APPLY selects one
       latest escalation event.

   Step 13 M2 can provide an isolated runtime follow-up case: after
   12-maintenance-affected-booking.sql runs, set @maintenance_id to the
   T13-SPACE-A escalation record and expect its approved booking to appear.
*/
