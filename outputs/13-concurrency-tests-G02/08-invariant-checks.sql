USE University;
GO
/* Run after U1 before reset: must show at least one row. After reset: zero. */
SELECT u1.unsafe_booking_id AS booking_1, u2.unsafe_booking_id AS booking_2, u1.space_code, u1.requested_start AS booking_1_start, u1.requested_end AS booking_1_end, u2.requested_start AS booking_2_start, u2.requested_end AS booking_2_end
FROM dbo.STEP13_UNSAFE_BOOKING AS u1
JOIN dbo.STEP13_UNSAFE_BOOKING AS u2 ON u1.unsafe_booking_id < u2.unsafe_booking_id AND u1.space_code = u2.space_code AND u1.requested_start < u2.requested_end AND u1.requested_end > u2.requested_start
WHERE u1.test_code = 'T13-UNSAFE' AND u2.test_code = 'T13-UNSAFE' AND u1.booking_status = 'Approved' AND u2.booking_status = 'Approved';

/* Protected test data must never contain an approved overlapping pair. */
SELECT b1.booking_id AS booking_1, b2.booking_id AS booking_2, b1.space_code, b1.requested_start AS booking_1_start, b1.requested_end AS booking_1_end, b2.requested_start AS booking_2_start, b2.requested_end AS booking_2_end
FROM dbo.BOOKING AS b1
JOIN dbo.BOOKING AS b2 ON b1.booking_id < b2.booking_id AND b1.space_code = b2.space_code AND b1.requested_start < b2.requested_end AND b1.requested_end > b2.requested_start
WHERE b1.space_code LIKE 'T13-%' AND b2.space_code LIKE 'T13-%' AND b1.booking_status = 'Approved' AND b2.booking_status = 'Approved';

SELECT booking_id, space_code, requested_start, requested_end, booking_status, approval_path, approver_id, decision_time
FROM dbo.BOOKING WHERE space_code LIKE 'T13-%' ORDER BY requested_start, booking_id;

SELECT maintenance_id, space_code, problem_description, start_time, completion_time, maintenance_status, impact_level
FROM dbo.MAINTENANCERECORD WHERE space_code LIKE 'T13-%' ORDER BY maintenance_id;

SELECT h.history_id, h.maintenance_id, h.old_impact_level, h.new_impact_level, h.changed_by_user_id, h.changed_at
FROM dbo.MAINTENANCE_IMPACT_HISTORY AS h
JOIN dbo.MAINTENANCERECORD AS m ON m.maintenance_id = h.maintenance_id
WHERE m.space_code LIKE 'T13-%';

SELECT @@SPID AS current_session_id, @@TRANCOUNT AS current_open_transaction_count;
GO
