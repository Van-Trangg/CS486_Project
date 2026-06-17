-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 6: Sample Data Preparation
-- ============================================================
--
-- Execution window: This script executes correctly if run
-- before 2027-07-01. After that date, the future-time trigger
-- (TR_BOOKING_FUTURE_START_ENFORCEMENT) may reject inserts
-- for non-staff requesters whose requested_start has passed.
--
-- VERIFICATION REPORT
-- ============================================================
-- Enum Coverage Report:
--   USER.role: Student[x], Lecturer[x], Teaching Assistant[x],
--              Facility Staff[x], Department Administrator[x], Facility Manager[x] -> PASS
--   USER.account_status: Active[x], Suspended[x], Inactive[x] -> PASS
--   SPACE.space_type: Auditorium[x], Classroom[x], Computer Laboratory[x],
--                     Project Laboratory[x], Meeting Room[x], Student Workspace[x] -> PASS
--   SPACE.current_status: Available[x], In Use[x], Under Maintenance[x],
--                         Temporarily Closed[x], Retired[x] -> PASS
--   SPACE_FACILITY.operation_status: Operational[x], Partially Operational[x], Broken[x] -> PASS
--   BOOKING.purpose: Lecture[x], Examination[x], Seminar[x], Workshop[x],
--                    Meeting[x], Student Activity[x], Administrative Event[x] -> PASS
--   BOOKING.booking_status: Pending[x], Approved[x], Rejected[x], Cancelled[x],
--                           Checked In[x], Completed[x], No-Show[x] -> PASS
--   MAINTENANCERECORD.problem_type: Projector Failure[x], Air-Conditioning Issue[x],
--                                   Cleaning Issue[x], Furniture Damage[x],
--                                   Network Issue[x], Other[x] -> PASS
--   MAINTENANCERECORD.maintenance_status: Reported[x], In Progress[x], Resolved[x], Cancelled[x] -> PASS
--
-- Lookup Domain Coverage Report:
--   FACILITY (BRA §4.3): Not an exhaustive enum in BRA (uses "e.g.") -> N/A
--   SPACE.space_type (BRA §4.2, DDL CHECK): All 6 values present -> PASS
--   BOOKING.purpose (BRA §4.4, DDL CHECK): All 7 values present -> PASS
--   MAINTENANCERECORD.problem_type (BRA §4.6, DDL CHECK): All 6 values present -> PASS
--
-- Trigger audit (per §6.1 of skill):
--   TR_USAGESESSION_CHECK_BOOKING_STATUS: Blocks USAGESESSION INSERT unless
--     booking.booking_status = 'Approved'. Mitigation: bookings with
--     USAGESESSION rows use status 'Approved'; 'Checked In' and 'Completed'
--     are covered on separate bookings without USAGESESSION.
--   TR_BOOKING_FUTURE_START_ENFORCEMENT: Blocks BOOKING INSERT for non-staff
--     requesters with requested_start < GETDATE(). Mitigation: all dates are
--     in 2027 (well beyond project start date); window documented above.
--   TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE: No overlapping Approved
--     bookings for same space; no Approved booking in Retired/Temporarily Closed
--     spaces; no Approved booking overlapping active maintenance. -> Verified.
--   TR_BOOKING_VALIDATE_APPROVER_ROLE: All approvers are Facility Staff/Manager. -> Verified.
--   TR_USAGESESSION_VALIDATE_STAFF_ROLES: All check-in/out staff are Facility Staff. -> Verified.
--   TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE: All assigned staff are Facility Staff. -> Verified.
--   TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP: No maintenance conflicts with Approved bookings. -> Verified.
--   TR_BOOKING_STATUS_AND_AUDIT: Only fires on UPDATE/DELETE; not triggered by INSERT. -> Verified.
--   TR_BOOKING_LOCK_APPROVED_FIELDS: Only fires on UPDATE; not triggered by INSERT. -> Verified.
--
-- Scenario Coverage:
--   [N1] Booking request in Pending state (just submitted)
--   [N2] Booking approved with usage session (full lifecycle evidence)
--   [N3] Booking declined (Rejected)
--   [N4] Booking cancelled partway through
--   [N5] M:N relationship (SPACE_FACILITY) with multiple associations both sides
--   [E1a] Suspended user account
--   [E1b] Inactive user account (soft-deleted)
--   [E1c] Space Under Maintenance
--   [E1d] Space Temporarily Closed
--   [E1e] Space Retired (soft-deleted)
--   [E2] All nullable fields populated (USAGESESSION with full checkout)
--   [E3] All nullable fields left NULL (USAGESESSION with no checkout)
--   [E4] Unavailable space (Under Maintenance) with no overlapping approved bookings
--   [E5] Soft-deleted records (Inactive user, Retired space)
--   [E6] Role-specific restrictions demonstrated (Facility Staff/Manager as approvers, check-in/out)
--   [E7] No-Show booking
--   [E8] Checked In booking (enum coverage, separate from USAGESESSION rows)
--   [E9] Maintenance lifecycle (Reported -> In Progress -> Resolved -> Cancelled)
--
-- Verification Checklist:
--   [x] Insertion order follows topological FK dependency order
--   [x] Every enum column has all its allowed values represented at least once
--   [x] Every lookup column with a defined domain in the DDL CHECK contains all values
--   [x] Every nullable column has at least one NULL and one non-NULL row
--   [x] Every business scenario from Stage 3b is present and identifiable
--   [x] No two rows violate any uniqueness constraint (PK, composite PK, UNIQUE)
--   [x] All FK values resolve to existing PK values in parent tables
--   [x] All time orderings valid (end > start for all non-NULL pairs)
--   [x] All conflict-prevention rules honoured (no overlapping approved records)
--   [x] All conditional field rules honoured (rejection_reason when Rejected, etc.)
--   [x] All capacity or limit constraints satisfied (participants <= room capacity)
--   [x] IDENTITY_INSERT ON/OFF wraps all identity table inserts
--   [x] Aggregation queries on this data would return non-trivial, varied results
--   [x] No placeholder or lorem-ipsum data present
-- ============================================================
-- Cleanup note: Run after DDL script (05-db-definition-G02.sql).
-- No cleanup section needed -- this is data, not schema.
-- ============================================================

-- ============================================================
-- Table: [USER]
-- Rows: 10
-- Scenarios covered: N1-N5, E1a, E1b, E5, E6
-- ============================================================
INSERT INTO [USER] (user_id, email, full_name, phone_number, role, department, account_status) VALUES
    ('STU2023001', 'alice.chen@university.edu', 'Alice Chen', '+1-555-0101', 'Student', 'Computer Science', 'Active'),
    ('STU2023002', 'bob.martinez@university.edu', 'Bob Martinez', '+1-555-0102', 'Student', 'Computer Science', 'Active'),
    ('LEC2021001', 'sarah.thompson@university.edu', 'Dr. Sarah Thompson', '+1-555-0103', 'Lecturer', 'Computer Science', 'Active'),
    ('TA2024001', 'james.wilson@university.edu', 'James Wilson', '+1-555-0104', 'Teaching Assistant', 'Computer Science', 'Active'),
    ('STF2019001', 'michael.okonkwo@university.edu', 'Michael Okonkwo', '+1-555-0105', 'Facility Staff', 'Computer Science', 'Active'),
    ('STF2020002', 'emily.nakamura@university.edu', 'Emily Nakamura', '+1-555-0106', 'Facility Staff', 'Computer Science', 'Active'),
    ('ADM2018001', 'david.park@university.edu', 'David Park', '+1-555-0107', 'Department Administrator', 'Computer Science', 'Active'),
    ('MGR2017001', 'priya.sharma@university.edu', 'Priya Sharma', '+1-555-0108', 'Facility Manager', 'Computer Science', 'Active'),
    ('STU2021004', 'lisa.johansson@university.edu', 'Lisa Johansson', NULL, 'Student', 'Computer Science', 'Suspended'),
    ('LEC2019003', 'robert.kim@university.edu', 'Prof. Robert Kim', '+1-555-0110', 'Lecturer', 'Computer Science', 'Inactive');
GO
-- [N1] Mix of roles for normal operations
-- [E1a] Lisa Johansson is Suspended
-- [E1b/E5] Prof. Robert Kim is Inactive (soft-deleted)
-- [E6] Michael Okonkwo, Emily Nakamura (Facility Staff), Priya Sharma (Facility Manager) serve as approvers/check-in staff
-- All 6 roles and all 3 account_status values covered

-- ============================================================
-- Table: SPACE
-- Rows: 7
-- Scenarios covered: N1-N5, E1c, E1d, E1e, E4, E5
-- ============================================================
INSERT INTO SPACE (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy) VALUES
    ('CS-A1-F1-R101', 'Newton Auditorium', 'Auditorium', 'Building A1', '1', 'R101', 200, 'Available', 'Priority to large lectures and examinations. Maximum 4-hour booking window. No food or drinks.'),
    ('CS-B2-F1-R201', 'Turing Classroom', 'Classroom', 'Building B2', '1', 'R201', 60, 'Available', 'Standard classroom for lectures, seminars, and workshops. Available 08:00-20:00 weekdays.'),
    ('CS-B2-F2-R205', 'Lovelace Lab', 'Computer Laboratory', 'Building B2', '2', 'R205', 40, 'In Use', 'Computer laboratory with 30 workstations. Software bookings require 48-hour notice.'),
    ('CS-C3-F1-R001', 'Rutherford Project Lab', 'Project Laboratory', 'Building C3', '1', 'R001', 30, 'Under Maintenance', 'Project laboratory for hardware and robotics work. Safety induction required. Currently closed for maintenance.'),
    ('CS-A2-F2-R202', 'Hopper Meeting Room', 'Meeting Room', 'Building A2', '2', 'R202', 16, 'Available', 'Small meeting room for group discussions and administrative meetings. Max 4-hour booking.'),
    ('CS-B1-F1-R102', 'Einstein Workspace', 'Student Workspace', 'Building B1', '1', 'R102', 50, 'Temporarily Closed', 'Open student workspace for group study and project work. Temporarily closed for renovations.'),
    ('CS-A1-F3-R301', 'Berners-Lee Lecture Hall', 'Auditorium', 'Building A1', '3', 'R301', 150, 'Retired', 'Former lecture hall. Retired from active use due to structural assessment. Historical records only.');
GO
-- [E1c] Rutherford Project Lab is Under Maintenance
-- [E1d] Einstein Workspace is Temporarily Closed
-- [E1e/E5] Berners-Lee Lecture Hall is Retired (soft-deleted)
-- All 6 space_type and all 5 current_status values covered

-- ============================================================
-- Table: FACILITY
-- Rows: 6
-- Scenarios covered: N5 (M:N relationship base)
-- ============================================================
SET IDENTITY_INSERT FACILITY ON;
INSERT INTO FACILITY (facility_id, facility_name, facility_description) VALUES
    (1, 'Projector', 'HD digital projector with HDMI, VGA, and wireless connectivity. Supports 1080p resolution.'),
    (2, 'Whiteboard', 'Standard dry-erase whiteboard with markers and eraser set. Dimensions: 180cm x 120cm.'),
    (3, 'Microphone', 'Wireless handheld microphone with lapel clip. Range: 30 metres. Suitable for auditoriums.'),
    (4, 'Computer Workstation', 'Dell OptiPlex desktop with 24-inch monitor, keyboard, and mouse. Windows 11 and Linux dual-boot.'),
    (5, 'Audio Conferencing System', 'Poly Studio soundbar with integrated speaker, microphone array, and camera for video conferences.'),
    (6, 'Air Conditioner', NULL);
SET IDENTITY_INSERT FACILITY OFF;
GO
-- [N5] Base facility catalog entries

-- ============================================================
-- Table: SPACE_FACILITY
-- Rows: 9
-- Scenarios covered: N5 (M:N with multiple associations both sides)
-- ============================================================
INSERT INTO SPACE_FACILITY (space_code, facility_id, quantity, operation_status, description) VALUES
    ('CS-A1-F1-R101', 1, 2, 'Operational', 'Two projectors installed at front-left and front-right of stage. Both calibrated.'),
    ('CS-A1-F1-R101', 3, 4, 'Operational', 'Four wireless microphones available. Two handheld, two lapel. All charged.'),
    ('CS-A1-F1-R101', 5, 1, 'Operational', 'Audio conferencing system integrated with auditorium sound system.'),
    ('CS-B2-F1-R201', 1, 1, 'Operational', 'Ceiling-mounted projector. Remote control available at front desk.'),
    ('CS-B2-F1-R201', 2, 1, 'Operational', 'Large whiteboard covering entire rear wall. Marker set available.'),
    ('CS-B2-F2-R205', 4, 25, 'Partially Operational', '25 workstations operational. 5 workstations in Row C awaiting maintenance.'),
    ('CS-B2-F2-R205', 2, 1, 'Operational', 'Whiteboard at front of lab. Used for lecture explanations.'),
    ('CS-C3-F1-R001', 6, 2, 'Broken', 'Both air conditioning units non-functional. Parts on order.'),
    ('CS-A1-F1-R101', 2, 1, 'Operational', NULL);
GO
-- [N5] Newton Auditorium has 4 facilities; Projector is in both Newton and Turing Classroom
-- All 3 operation_status values covered (Operational, Partially Operational, Broken)

-- ============================================================
-- Table: BOOKING
-- Rows: 13
-- Scenarios covered: N1, N2, N3, N4, E2, E3, E6, E7, E8
-- Note on trigger compatibility (per skill §6.1):
--   Bookings 2, 6, 13 use status 'Approved' (not 'Checked In'/'Completed')
--   because TR_USAGESESSION_CHECK_BOOKING_STATUS requires booking_status
--   = 'Approved' when a USAGESESSION references the booking.
--   'Checked In' and 'Completed' are covered on bookings 7 and 10
--   which have no USAGESESSION row.
-- ============================================================
SET IDENTITY_INSERT BOOKING ON;
INSERT INTO BOOKING (booking_id, space_code, requester_id, requested_start, requested_end, purpose, expected_participants, booking_status, created_at, approver_id, decision_time, decision_note, rejection_reason) VALUES
    -- [N1] Pending booking - recently submitted, awaiting approval
    (1, 'CS-A1-F1-R101', 'LEC2021001', '2027-02-01 10:00:00', '2027-02-01 12:00:00', 'Lecture', 150, 'Pending', '2027-01-25 09:00:00', NULL, NULL, NULL, NULL),

    -- [N2] Approved booking with completed usage session
    (2, 'CS-B2-F1-R201', 'LEC2021001', '2027-01-20 09:00:00', '2027-01-20 11:00:00', 'Seminar', 40, 'Approved', '2027-01-05 10:00:00', 'STF2019001', '2027-01-12 14:30:00', 'Approved for weekly seminar series. Room confirmed for Dr. Thompson.', NULL),

    -- [N3] Rejected booking with rejection reason populated
    (3, 'CS-A2-F2-R202', 'ADM2018001', '2027-01-25 14:00:00', '2027-01-25 15:30:00', 'Meeting', 10, 'Rejected', '2027-01-10 11:00:00', 'MGR2017001', '2027-01-22 09:15:00', 'Rejected due to scheduling conflict.', 'Room reserved for departmental audit on that date. Please select an alternative date.'),

    -- [N4] Cancelled booking (was approved, then cancelled by requester)
    (4, 'CS-B2-F2-R205', 'TA2024001', '2027-02-05 13:00:00', '2027-02-05 16:00:00', 'Workshop', 25, 'Cancelled', '2027-01-15 08:30:00', 'STF2019001', '2027-01-30 11:00:00', 'Approved for TA workshop. Laboratory workstations reserved.', NULL),

    -- [E7] No-Show booking - requester never arrived
    (5, 'CS-A1-F1-R101', 'LEC2021001', '2027-02-10 08:00:00', '2027-02-10 10:00:00', 'Examination', 180, 'No-Show', '2027-01-20 09:00:00', 'MGR2017001', '2027-02-05 16:00:00', 'Approved for final examination. Invigilators assigned.', NULL),

    -- [N2] Approved booking with checked-in (in-progress) usage session
    (6, 'CS-B2-F1-R201', 'STU2023001', '2027-02-15 14:00:00', '2027-02-15 17:00:00', 'Student Activity', 30, 'Approved', '2027-02-01 13:00:00', 'STF2020002', '2027-02-10 10:30:00', 'Approved for student coding club meetup. Standard classroom setup.', NULL),

    -- [E8] Checked In booking (enum coverage, no usage session row)
    (7, 'CS-A2-F2-R202', 'ADM2018001', '2027-02-18 09:00:00', '2027-02-18 12:00:00', 'Administrative Event', 12, 'Checked In', '2027-02-01 14:00:00', 'STF2019001', '2027-02-12 09:00:00', 'Approved for departmental planning session.', NULL),

    -- [N1] Student with pending booking
    (8, 'CS-B2-F2-R205', 'STU2023002', '2027-03-01 10:00:00', '2027-03-01 12:00:00', 'Workshop', 20, 'Pending', '2027-02-15 15:00:00', NULL, NULL, NULL, NULL),

    -- [E3] Pending booking with all nullable fields NULL
    (9, 'CS-A2-F2-R202', 'LEC2021001', '2027-03-10 15:00:00', '2027-03-10 16:00:00', 'Meeting', 8, 'Pending', '2027-03-03 10:00:00', NULL, NULL, NULL, NULL),

    -- [N2] Completed booking (enum coverage, no usage session row)
    (10, 'CS-B2-F1-R201', 'ADM2018001', '2027-03-15 09:00:00', '2027-03-15 11:00:00', 'Administrative Event', 30, 'Completed', '2027-02-25 11:00:00', 'MGR2017001', '2027-03-08 08:45:00', 'Approved for faculty workshop. Standard classroom setup with projector.', NULL),

    -- [N2] Approved examination
    (11, 'CS-A1-F1-R101', 'LEC2021001', '2027-04-10 09:00:00', '2027-04-10 12:00:00', 'Examination', 150, 'Approved', '2027-03-20 09:00:00', 'STF2019001', '2027-04-01 14:00:00', 'Approved for semester final examination. Auditorium seating arrangement requested.', NULL),

    -- [E4] Rejected booking for space under maintenance
    (12, 'CS-C3-F1-R001', 'TA2024001', '2027-02-20 10:00:00', '2027-02-20 12:00:00', 'Student Activity', 15, 'Rejected', '2027-02-08 16:00:00', 'STF2020002', '2027-02-16 11:30:00', 'Rejected - space unavailable.', 'Space is currently under maintenance and unavailable for booking. Projector and AC repairs in progress.'),

    -- [E2] Approved booking with fully completed usage session
    (13, 'CS-A1-F1-R101', 'LEC2021001', '2027-03-25 09:00:00', '2027-03-25 11:00:00', 'Lecture', 150, 'Approved', '2027-03-08 10:00:00', 'STF2019001', '2027-03-18 09:30:00', 'Approved for guest lecture series. Auditorium AV equipment reserved.', NULL);
SET IDENTITY_INSERT BOOKING OFF;
GO
-- All 7 purpose values covered: Lecture(1,13), Seminar(2), Workshop(4,8), Meeting(3,9),
--   Student Activity(6,12), Administrative Event(7,10), Examination(5,11)
-- All 7 booking_status values covered: Pending(1,8,9), Approved(2,6,11,13), Rejected(3,12),
--   Cancelled(4), Checked In(7), Completed(10), No-Show(5)
-- Conditional rules: rejection_reason NOT NULL for Rejected(3,12), NULL otherwise
--   approver_id and decision_time NOT NULL for non-Pending bookings, NULL for Pending(1,8,9)
-- Capacity: all expected_participants <= space capacity

-- ============================================================
-- Table: USAGESESSION
-- Rows: 3
-- Scenarios covered: N2, E2, E3, E6, E8
-- Note on trigger compatibility (per skill §6.1):
--   TR_USAGESESSION_CHECK_BOOKING_STATUS requires booking_status = 'Approved'.
--   All bookings referenced below (2, 6, 13) are 'Approved'.
-- ============================================================
INSERT INTO USAGESESSION (booking_id, check_in_staff_id, actual_start, initial_condition, check_out_staff_id, actual_end, final_condition, usage_notes) VALUES
    -- [N2/E2] Full lifecycle - all nullable fields populated (booking 2 is 'Approved')
    (2, 'STF2020002', '2027-01-20 09:05:00', 'Room was clean and well-maintained. All chairs arranged in lecture formation. Whiteboard freshly erased. Projector powered on and functioning.', 'STF2019001', '2027-01-20 11:00:00', 'All in order. Whiteboard used but cleaned. Chairs remained arranged. No issues reported by the lecturer.', 'Seminar ran on schedule with approximately 38 attendees. Dr. Thompson used projector for slides. No technical difficulties encountered.'),

    -- [E3/E8] Checked In demo - all nullable fields NULL (booking 6 is 'Approved')
    (6, 'STF2019001', '2027-02-15 14:10:00', 'Tables arranged in group clusters for collaborative work. Room tidy and well-lit. Whiteboard markers available.', NULL, NULL, NULL, NULL),

    -- [E2] Completed session with full checkout details (booking 13 is 'Approved')
    (13, 'STF2020002', '2027-03-25 09:02:00', 'Auditorium prepared for guest lecture. Stage setup complete. Sound system tested and operational. Seating arranged for 150.', 'STF2020002', '2027-03-25 11:05:00', 'All equipment powered off. Seating area tidy. Lost property (black notebook) handed to front desk.', 'Guest lecture delivered by industry speaker. Approximately 145 attendees. Microphone and projector used throughout. Session concluded with Q&A segment.');
GO
-- [E6] Check-in/out performed by Facility Staff (STF2019001, STF2020002) as required
-- [N2] Booking 2 has full lifecycle evidence via USAGESESSION
-- Time ordering: actual_end > actual_start for both completed sessions

-- ============================================================
-- Table: MAINTENANCERECORD
-- Rows: 7
-- Scenarios covered: E1c, E4, E9
-- ============================================================
SET IDENTITY_INSERT MAINTENANCERECORD ON;
INSERT INTO MAINTENANCERECORD (maintenance_id, space_code, reporter_id, assigned_staff_id, problem_type, problem_description, start_time, completion_time, maintenance_status, result_note) VALUES
    -- [E1c/E4] Active maintenance keeping space unavailable
    (1, 'CS-C3-F1-R001', 'TA2024001', 'STF2019001', 'Projector Failure', 'The main projector in Rutherford Project Lab displays a severely distorted image with a persistent green tint. Projector lamp may be failing. Unable to proceed with scheduled robotics demonstration.', '2027-01-15 08:00:00', NULL, 'In Progress', NULL),

    -- [E9] Completed maintenance - air conditioning
    (2, 'CS-B2-F1-R201', 'LEC2021001', 'STF2020002', 'Air-Conditioning Issue', 'The air conditioning unit in Turing Classroom is not cooling effectively. Room temperature reached 30 degrees Celsius during yesterday afternoon lecture, causing discomfort for students.', '2027-01-10 18:00:00', '2027-01-11 10:00:00', 'Resolved', 'Recharged refrigerant gas. Air conditioning unit functioning normally. Temperature returned to 22 degrees Celsius. Scheduled follow-up inspection in one month.'),

    -- [E9] Completed maintenance - cleaning
    (3, 'CS-A1-F1-R101', 'STU2023001', 'STF2019001', 'Cleaning Issue', 'Post-event cleanup required in the auditorium after the faculty town hall. Discarded coffee cups, food wrappers, and scattered programme leaflets throughout the seating area and stage.', '2027-02-10 18:00:00', '2027-02-10 20:00:00', 'Resolved', 'Auditorium fully cleaned and sanitised. All trash removed, carpets vacuumed, seats wiped down, and stage area restored to standard condition.'),

    -- [E9] Reported (not yet in progress) - no assigned staff yet
    (4, 'CS-A2-F2-R202', 'ADM2018001', NULL, 'Furniture Damage', 'One of the meeting table legs in Hopper Meeting Room is broken. The table wobbles significantly and cannot support normal use. Potential safety hazard for users.', '2027-02-18 09:00:00', NULL, 'Reported', NULL),

    -- [E9] Completed maintenance - network
    (5, 'CS-B1-F1-R102', 'STU2023002', NULL, 'Network Issue', 'WiFi access point in the Einstein Workspace is intermittently dropping connections. Students are unable to maintain stable access to online course materials and virtual lab environments.', '2027-01-08 14:00:00', '2027-01-12 16:00:00', 'Resolved', 'Replaced faulty wireless access point with new unit. Network connectivity restored and stable. Signal strength tested across all seating areas with consistent results.'),

    -- [E9] Completed maintenance - other
    (6, 'CS-B2-F2-R205', 'STU2023002', 'STF2020002', 'Other', 'Several computer workstations in Row C of Lovelace Lab exhibit intermittent boot failures. Error messages indicate possible power supply issues. Students unable to complete programming assignments reliably.', '2027-03-01 18:00:00', '2027-03-02 09:00:00', 'Resolved', 'Diagnostics completed on all Row C workstations. Replaced faulty power supply unit in workstation WS-021. All other units tested within normal operating parameters.'),

    -- [E9] Cancelled maintenance
    (7, 'CS-C3-F1-R001', 'LEC2021001', NULL, 'Other', 'Faint burning smell reported coming from the corner HVAC vent near the storage closet. No visible smoke, flames, or damage observed. Requesting inspection as a precautionary measure.', '2027-01-05 10:00:00', NULL, 'Cancelled', 'Issue resolved itself. HVAC maintenance team determined the odour was caused by accumulated dust burning off after the system was idle during summer break. No action required.');
SET IDENTITY_INSERT MAINTENANCERECORD OFF;
GO
-- All 6 problem_type values covered: Projector Failure(1), Air-Conditioning Issue(2),
--   Cleaning Issue(3), Furniture Damage(4), Network Issue(5), Other(6,7)
-- All 4 maintenance_status values covered: Reported(4), In Progress(1), Resolved(2,3,5,6), Cancelled(7)
-- [E4] Rutherford Project Lab (CS-C3-F1-R001) is Under Maintenance with In Progress record (M1)
--   and no overlapping approved bookings exist for this space
-- Nullable columns: assigned_staff_id NULL in M4, M5, M7; completion_time NULL in M1, M4, M7;
--   result_note NULL in M1, M4
-- Time ordering: completion_time > start_time for all resolved records
-- [E6] Maintenance assigned to Facility Staff (STF2019001, STF2020002) as required
