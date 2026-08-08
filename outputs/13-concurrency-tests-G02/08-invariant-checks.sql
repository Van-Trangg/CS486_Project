USE University;
GO
SET NOCOUNT ON;

/* After U1 before reset this count must be >= 1; after reset it must be 0. */
SELECT 'Unsafe approved overlap count' AS invariant_name, COUNT(*) AS overlap_count,
       CASE WHEN COUNT(*) >= 1 THEN 'UNSAFE_RACE_DEMONSTRATED' ELSE 'NO_UNSAFE_OVERLAP' END AS result
FROM dbo.STEP13_UNSAFE_BOOKING AS u1
JOIN dbo.STEP13_UNSAFE_BOOKING AS u2
  ON u1.unsafe_booking_id < u2.unsafe_booking_id
 AND u1.space_code = u2.space_code
 AND u1.requested_start < u2.requested_end
 AND u1.requested_end > u2.requested_start
WHERE u1.test_code = 'T13-UNSAFE'
  AND u2.test_code = 'T13-UNSAFE'
  AND u1.booking_status = 'Approved'
  AND u2.booking_status = 'Approved';

SELECT u1.unsafe_booking_id AS booking_1, u2.unsafe_booking_id AS booking_2,
       u1.space_code, u1.requested_start AS booking_1_start,
       u1.requested_end AS booking_1_end, u2.requested_start AS booking_2_start,
       u2.requested_end AS booking_2_end
FROM dbo.STEP13_UNSAFE_BOOKING AS u1
JOIN dbo.STEP13_UNSAFE_BOOKING AS u2
  ON u1.unsafe_booking_id < u2.unsafe_booking_id
 AND u1.space_code = u2.space_code
 AND u1.requested_start < u2.requested_end
 AND u1.requested_end > u2.requested_start
WHERE u1.test_code = 'T13-UNSAFE'
  AND u2.test_code = 'T13-UNSAFE'
  AND u1.booking_status = 'Approved'
  AND u2.booking_status = 'Approved';

/* Every protected scenario must leave this count at zero. */
SELECT 'Protected occupying overlap count' AS invariant_name, COUNT(*) AS overlap_count,
       CASE WHEN COUNT(*) = 0 THEN 'PROTECTED_INVARIANT_HOLDS' ELSE 'PROTECTED_INVARIANT_VIOLATED' END AS result
FROM dbo.BOOKING AS b1
JOIN dbo.BOOKING AS b2
  ON b1.booking_id < b2.booking_id
 AND b1.space_code = b2.space_code
 AND b1.requested_start < b2.requested_end
 AND b1.requested_end > b2.requested_start
WHERE b1.space_code LIKE 'T13-%'
  AND b2.space_code LIKE 'T13-%'
  AND b1.booking_status IN ('Approved', 'Checked In')
  AND b2.booking_status IN ('Approved', 'Checked In');

/* Evaluate the configured protected pairing only after both sessions finish. */
;WITH PairBookings AS
(
    SELECT c.config_id, c.pairing, c.session_a_finished, c.session_b_finished,
           b.booking_id, b.booking_status, b.resolution_path
    FROM dbo.STEP13_TEST_CONFIG AS c
    CROSS APPLY (VALUES (c.booking_a_id), (c.booking_b_id)) AS ids(booking_id)
    LEFT JOIN dbo.BOOKING AS b ON b.booking_id = ids.booking_id
    WHERE c.config_id = 1
)
SELECT pairing,
       MAX(CONVERT(INT, session_a_finished)) AS session_a_finished,
       MAX(CONVERT(INT, session_b_finished)) AS session_b_finished,
       SUM(CASE WHEN booking_status = 'Approved' THEN 1 ELSE 0 END) AS approved_count,
       SUM(CASE WHEN booking_status = 'Pending' THEN 1 ELSE 0 END) AS pending_count,
       SUM(CASE WHEN resolution_path = 'Instant' AND booking_status = 'Approved' THEN 1 ELSE 0 END) AS instant_approved_count,
       CASE
           WHEN MAX(CONVERT(INT, session_a_finished)) = 0
             OR MAX(CONVERT(INT, session_b_finished)) = 0
               THEN 'PAIRING_NOT_COMPLETED'
           WHEN pairing = 'StaffStaff'
            AND SUM(CASE WHEN booking_status = 'Approved' AND resolution_path = 'Staff' THEN 1 ELSE 0 END) = 1
            AND SUM(CASE WHEN booking_status = 'Pending' AND resolution_path = 'Staff' THEN 1 ELSE 0 END) = 1
               THEN 'STAFF_STAFF_HOLDS'
           WHEN pairing = 'InstantInstant'
            AND SUM(CASE WHEN booking_status = 'Approved' AND resolution_path = 'Instant' THEN 1 ELSE 0 END) = 1
            AND SUM(CASE WHEN booking_status = 'Pending' AND resolution_path = 'Staff' THEN 1 ELSE 0 END) = 1
               THEN 'INSTANT_INSTANT_HOLDS'
           WHEN pairing = 'InstantStaff'
            AND SUM(CASE WHEN booking_status = 'Approved' AND resolution_path = 'Staff' THEN 1 ELSE 0 END) = 1
            AND SUM(CASE WHEN booking_status = 'Pending' AND resolution_path = 'Staff' THEN 1 ELSE 0 END) = 1
               THEN 'INSTANT_STAFF_HOLDS'
           ELSE 'PAIRING_FINAL_STATE_INVALID'
       END AS pairing_result
FROM PairBookings
GROUP BY pairing;

/* Scenario-specific maintenance and affected-booking assertion. */
SELECT b.booking_id, b.booking_status, m.maintenance_id, m.impact_level,
       (SELECT COUNT(*) FROM dbo.MAINTENANCE_IMPACT_HISTORY AS h
        WHERE h.maintenance_id = m.maintenance_id
          AND h.old_impact_level = 'advisory'
          AND h.new_impact_level = 'out-of-service') AS transition_count,
       (SELECT COUNT(*) FROM dbo.STEP13_MAINTENANCE_RESULT AS r
        WHERE r.test_code = 'M1-APPROVAL-FIRST'
          AND r.booking_id = b.booking_id
          AND r.maintenance_id = m.maintenance_id) AS affected_result_count,
       CASE
           WHEN m.impact_level = 'advisory' THEN 'MAINTENANCE_RACE_NOT_RUN'
           WHEN b.booking_status = 'Approved'
            AND EXISTS
                (SELECT 1 FROM dbo.STEP13_MAINTENANCE_RESULT AS r
                 WHERE r.test_code = 'M1-APPROVAL-FIRST'
                   AND r.booking_id = b.booking_id
                   AND r.maintenance_id = m.maintenance_id)
               THEN 'M1_APPROVAL_FIRST_HOLDS'
           WHEN b.booking_status = 'Pending'
            AND NOT EXISTS
                (SELECT 1 FROM dbo.STEP13_MAINTENANCE_RESULT AS r
                 WHERE r.maintenance_id = m.maintenance_id)
               THEN 'M2_ESCALATION_FIRST_HOLDS'
           ELSE 'MAINTENANCE_FINAL_STATE_INVALID'
       END AS maintenance_result
FROM dbo.BOOKING AS b
JOIN dbo.MAINTENANCERECORD AS m
  ON m.space_code = b.space_code
 AND m.problem_description = N'Escalation-race advisory.'
WHERE b.space_code = 'T13-SPACE-A'
  AND b.requested_start = '2035-07-01T09:00:00';

/* The November advisory must have exactly one applicable acknowledgement. */
SELECT b.booking_id, b.booking_status, COUNT(m.maintenance_id) AS applicable_ack_count,
       CASE WHEN COUNT(m.maintenance_id) = 1 THEN 'ADVISORY_ACK_HOLDS'
            ELSE 'ADVISORY_ACK_INVALID' END AS acknowledgement_result
FROM dbo.BOOKING AS b
LEFT JOIN dbo.BOOKING_ADVISORY_ACK AS a ON a.booking_id = b.booking_id
LEFT JOIN dbo.MAINTENANCERECORD AS m
  ON m.maintenance_id = a.maintenance_id
 AND m.problem_description = N'Advisory non-blocking test.'
WHERE b.space_code = 'T13-SPACE-A'
  AND b.requested_start = '2035-11-01T09:00:00'
GROUP BY b.booking_id, b.booking_status;

SELECT booking_id, space_code, requester_id, requested_start, requested_end,
       booking_status, resolution_path, approver_id, decision_time
FROM dbo.BOOKING
WHERE space_code LIKE 'T13-%'
ORDER BY requested_start, booking_id;

SELECT maintenance_id, space_code, problem_description, start_time,
       completion_time, maintenance_status, impact_level
FROM dbo.MAINTENANCERECORD
WHERE space_code LIKE 'T13-%'
ORDER BY maintenance_id;

SELECT h.history_id, h.maintenance_id, h.old_impact_level,
       h.new_impact_level, h.changed_by_user_id, h.changed_at
FROM dbo.MAINTENANCE_IMPACT_HISTORY AS h
JOIN dbo.MAINTENANCERECORD AS m ON m.maintenance_id = h.maintenance_id
WHERE m.space_code LIKE 'T13-%'
ORDER BY h.history_id;

SELECT a.booking_id, a.maintenance_id, a.acknowledged_at
FROM dbo.BOOKING_ADVISORY_ACK AS a
JOIN dbo.BOOKING AS b ON b.booking_id = a.booking_id
WHERE b.space_code LIKE 'T13-%'
ORDER BY a.booking_id, a.maintenance_id;

SELECT @@SPID AS current_session_id, @@TRANCOUNT AS current_open_transaction_count;
GO
