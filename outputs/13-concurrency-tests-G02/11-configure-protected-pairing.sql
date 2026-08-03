/* Run after setup and before P1. Set one supported pairing, then run the two P1 session scripts. */
USE University;
GO
DECLARE @Pairing VARCHAR(20) = 'InstantInstant';
/* Supported values: InstantInstant, StaffStaff, InstantStaff. */
IF @Pairing NOT IN ('InstantInstant', 'StaffStaff', 'InstantStaff') THROW 52010, 'Unsupported protected approval pairing.', 1;

UPDATE b
SET approval_path = CASE
        WHEN @Pairing = 'StaffStaff' THEN 'Staff'
        WHEN @Pairing = 'InstantStaff' AND b.requested_start = '2035-06-01T10:00:00' THEN 'Staff'
        ELSE 'Instant'
    END,
    booking_status = 'Pending', approver_id = NULL, decision_time = NULL, decision_note = NULL, rejection_reason = NULL
FROM dbo.BOOKING AS b
WHERE b.space_code = 'T13-SPACE-A'
  AND b.requested_start IN ('2035-06-01T09:00:00', '2035-06-01T10:00:00');
PRINT 'Configured protected pairing: ' + @Pairing + '.';
GO
