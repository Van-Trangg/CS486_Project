-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 6: Sample Data Preparation
-- ============================================================
--
-- VERIFICATION REPORT
-- ============================================================
-- This script executes correctly if run before 2027-01-01.
-- All booking dates use 2026-09 through 2026-12 to remain in the
-- future relative to the project date (2026-07-01).
--
-- Enum Coverage Report:
--   USER.role:
--     Student[x], Lecturer[x], Teaching Assistant[x],
--     Facility Staff[x], Department Administrator[x],
--     Facility Manager[x] -> PASS
--   USER.account_status:
--     Active[x], Suspended[x], Inactive[x] -> PASS
--   SPACE.space_type:
--     Auditorium[x], Classroom[x], Computer Laboratory[x],
--     Project Laboratory[x], Meeting Room[x],
--     Student Workspace[x] -> PASS
--   SPACE.current_status:
--     Available[x], In Use[x], Under Maintenance[x],
--     Temporarily Closed[x], Retired[x] -> PASS
--   SPACE_FACILITY.operation_status:
--     Operational[x], Partially Operational[x],
--     Broken[x] -> PASS
--   BOOKING.purpose:
--     Lecture[x], Examination[x], Seminar[x],
--     Workshop[x], Meeting[x], Student Activity[x],
--     Administrative Event[x] -> PASS
--   BOOKING.booking_status:
--     Pending[x], Approved[x], Rejected[x], Cancelled[x],
--     Checked In[x], Completed[x], No-Show[x] -> PASS
--   MAINTENANCERECORD.maintenance_status:
--     Reported[x], In Progress[x], Resolved[x],
--     Cancelled[x] -> PASS
--   MAINTENANCERECORD.problem_type:
--     Projector Failure[x], Air-Conditioning Issue[x],
--     Cleaning Issue[x], Furniture Damage[x],
--     Network Issue[x], Other[x] -> PASS
--
-- Lookup Domain Coverage Report:
--   FACILITY (BRA §4.3 examples): Projector[x], Whiteboard[x],
--     Microphone[x], Computer[x], Air Conditioner[x],
--     Livestreaming Equipment[x] -> PASS (supplemented with
--     reasonable facilities for a CS department; BRA values are
--     illustrative with 'e.g.' not exhaustive)
--   BOOKING.purpose (BRA §4.4): Lecture[x], Examination[x],
--     Seminar[x], Workshop[x], Meeting[x], Student Activity[x],
--     Administrative Event[x] -> PASS
--   MAINTENANCERECORD.problem_type (BRA §4.6):
--     Projector Failure[x], Air-Conditioning Issue[x],
--     Cleaning Issue[x], Furniture Damage[x],
--     Network Issue[x], Other[x] -> PASS
--
-- Scenario Coverage:
-- [N1] Pending booking – request just submitted by a Student
-- [N2] Approved booking – room confirmed by Facility Staff
-- [N3] Fully processed lifecycle – Approved -> USAGESESSION -> Completed
-- [N4] Declined request – booking Rejected with reason
-- [N5] Cancelled booking – cancelled from Approved by requester
-- [N6] Many-to-many – Auditorium with 3 facilities; Projector in 6 spaces
-- [E1] Suspended user and Inactive user accounts
-- [E2] All optional fields populated (B8 – full decision metadata)
-- [E3] All optional fields left NULL (B1 – Pending, no approver)
-- [E4] Space under maintenance – Lecture 203 has active maintenance;
--      B9 for that space exists as Pending only (cannot be Approved)
-- [E5] Retired space – Small Auditorium B with current_status='Retired';
--      B10 for that space exists as Pending only
-- [E6] Role restrictions – Only Facility Staff/Manager approve (B2, B8, B11),
--      check in/out (US1, US2, US3), assigned to maintenance (M2, M6)
-- [E7] No-Show booking – B7 with status 'No-Show'
-- [E8] Checked In booking – B6 and B12 with status 'Checked In'
-- [E9] All maintenance statuses: Reported, In Progress, Resolved, Cancelled
-- [E10] Temporarily Closed space – Quiet Study Room
-- [E11] Nullable columns: some NULL, some populated in every nullable column
-- [E12] Space with 'In Use' status – Computer Lab A
--
-- Verification Checklist:
--   [x] Insertion order follows topological FK dependency order
--   [x] Every enum column has all its allowed values represented at least once
--   [x] Every lookup table that has a defined domain in the BRA contains
--       all values listed in the BRA
--   [x] Every nullable column has at least one NULL and one non-NULL row
--   [x] Every business scenario from Stage 3b is present and identifiable
--   [x] No two rows violate any uniqueness constraint
--   [x] All FK values resolve to existing PK values in parent tables
--   [x] All time orderings valid (end > start for non-NULL pairs)
--   [x] All conflict-prevention rules honoured (no overlapping approved bookings)
--   [x] All conditional field rules honoured
--   [x] All capacity or limit constraints satisfied
--   [x] IDENTITY_INSERT ON/OFF wraps all identity table inserts
--   [x] Aggregation queries on this data would return non-trivial results
--   [x] No placeholder or lorem-ipsum data present
--   [x] Bookings with status 'Completed' have corresponding USAGESESSION
--   [x] Lifecycle consistency: Cancelled/No-Show/Rejected/Pending bookings
--       have no child USAGESESSION rows
--   [x] TR_USAGESESSION_CHECK_BOOKING_STATUS workaround applied:
--       Completed/CheckedIn bookings inserted as 'Approved', USAGESESSION
--       added, then status updated
-- ============================================================

-- ============================================================
-- Cleanup
-- ============================================================
-- Delete in reverse FK dependency order
DELETE FROM MAINTENANCERECORD;
DELETE FROM USAGESESSION;
DELETE FROM BOOKING;
DELETE FROM SPACE_FACILITY;
DELETE FROM FACILITY;
DELETE FROM SPACE;
DELETE FROM [USER];
GO

-- ============================================================
-- Table: [USER]
-- Rows: 9
-- Scenarios: [N1]-[N6], [E1], [E3], [E6], [E11]
-- ============================================================
SET IDENTITY_INSERT [USER] OFF;
GO

INSERT INTO [USER] (user_id, email, full_name, phone_number, role, department, account_status) VALUES
    ('STU2024001', 'alice.tan@university.edu', 'Alice Tan', '91234567', 'Student', 'School of Computer Science', 'Active'),
    ('LEC2024001', 'james.mitchell@university.edu', 'Dr. James Mitchell', '82345678', 'Lecturer', 'School of Computer Science', 'Active'),
    ('TA2024001', 'sarah.chen@university.edu', 'Sarah Chen', NULL, 'Teaching Assistant', 'School of Computer Science', 'Active'),
    ('STF2024001', 'robert.lim@university.edu', 'Robert Lim', '83456789', 'Facility Staff', 'Facility Management', 'Active'),
    ('ADM2024001', 'priya.sharma@university.edu', 'Priya Sharma', '84567890', 'Department Administrator', 'School of Computer Science', 'Active'),
    ('MGR2024001', 'david.kumar@university.edu', 'David Kumar', NULL, 'Facility Manager', 'Facility Management', 'Active'),
    ('STU2024002', 'john.smith@university.edu', 'John Smith', NULL, 'Student', 'School of Computer Science', 'Suspended'),
    ('LEC2024002', 'emily.wong@university.edu', 'Prof. Emily Wong', '85678901', 'Lecturer', 'School of Computer Science', 'Inactive'),
    ('STF2024002', 'maria.garcia@university.edu', 'Maria Garcia', '86789012', 'Facility Staff', 'Facility Management', 'Active');
GO

-- ============================================================
-- Table: SPACE
-- Rows: 9
-- Scenarios: [N1]-[N6], [E4], [E5], [E10], [E12]
-- ============================================================
INSERT INTO SPACE (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy) VALUES
    ('AUD-B1-F1-101', 'Main Auditorium', 'Auditorium', 'Building 1', '1', '101', 200, 'Available',
     'Priority given to lectures and examinations. Maximum booking 4 hours. No food or drinks.'),
    ('CLS-B2-F2-201', 'Lecture Room 201', 'Classroom', 'Building 2', '2', '201', 60, 'Available',
     'Standard classroom for lectures and tutorials. Whiteboard and projector available. Maximum 3-hour sessions.'),
    ('CLS-B2-F2-202', 'Computer Lab A', 'Computer Laboratory', 'Building 2', '2', '202', 40, 'In Use',
     'Computer laboratory for programming workshops and examinations. Users must log in with university credentials.'),
    ('PLAB-B3-F1-101', 'Project Lab Alpha', 'Project Laboratory', 'Building 3', '1', '101', 30, 'Available',
     'Dedicated project workspace for final-year and research students. 24-hour access with card.'),
    ('MTR-B1-F3-301', 'Meeting Room 301', 'Meeting Room', 'Building 1', '3', '301', 20, 'Available',
     'Meeting room for staff and group discussions. Video conferencing equipment available. Maximum 8 persons recommended.'),
    ('SWS-B2-F1-001', 'Student Hub', 'Student Workspace', 'Building 2', '1', '001', 80, 'Available',
     'Open student workspace for group study and student activities. Flexible seating.'),
    ('CLS-B2-F2-203', 'Lecture Room 203', 'Classroom', 'Building 2', '2', '203', 50, 'Under Maintenance',
     'Classroom temporarily unavailable. Projector maintenance and network upgrades in progress.'),
    ('SWS-B2-F1-002', 'Quiet Study Room', 'Student Workspace', 'Building 2', '1', '002', 15, 'Temporarily Closed',
     'Quiet study room closed for renovation. Expected reopening December 2026.'),
    ('AUD-B1-F2-201', 'Small Auditorium B', 'Auditorium', 'Building 1', '2', '201', 100, 'Retired',
     'This auditorium has been decommissioned. Not available for booking.');
GO

-- ============================================================
-- Table: FACILITY
-- Rows: 6
-- Scenarios: [N6] (M:N with SPACE via SPACE_FACILITY)
-- ============================================================
SET IDENTITY_INSERT FACILITY ON;
GO

INSERT INTO FACILITY (facility_id, facility_name, facility_description) VALUES
    (1, 'Projector', 'Standard HD projector, 1080p resolution with HDMI and VGA inputs'),
    (2, 'Whiteboard', 'Magnetic whiteboard, 2m x 1.2m with marker tray'),
    (3, 'Microphone', 'Wireless handheld microphone with lapel clip option'),
    (4, 'Computer', NULL),
    (5, 'Air Conditioner', NULL),
    (6, 'Livestreaming Equipment', '4K camera with tripod and USB capture card');
GO

SET IDENTITY_INSERT FACILITY OFF;
GO

-- ============================================================
-- Table: SPACE_FACILITY
-- Rows: 19
-- Scenarios: [N6] (M:N - Auditorium has 3 facilities;
--            Projector appears in 6 spaces), [E11] (some NULL desc)
-- ============================================================
INSERT INTO SPACE_FACILITY (space_code, facility_id, quantity, operation_status, description) VALUES
    -- Main Auditorium (3 facilities)
    ('AUD-B1-F1-101', 1, 2, DEFAULT, NULL),
    ('AUD-B1-F1-101', 3, 4, DEFAULT, NULL),
    ('AUD-B1-F1-101', 5, 3, DEFAULT, NULL),
    -- Lecture Room 201 (3 facilities)
    ('CLS-B2-F2-201', 1, 1, DEFAULT, NULL),
    ('CLS-B2-F2-201', 2, 1, DEFAULT, NULL),
    ('CLS-B2-F2-201', 5, 1, DEFAULT, NULL),
    -- Computer Lab A (4 facilities)
    ('CLS-B2-F2-202', 1, 1, DEFAULT, NULL),
    ('CLS-B2-F2-202', 4, 25, 'Partially Operational', '5 of 25 workstations have faulty keyboards; replacement order placed'),
    ('CLS-B2-F2-202', 2, 1, DEFAULT, NULL),
    ('CLS-B2-F2-202', 5, 1, DEFAULT, NULL),
    -- Project Lab Alpha (2 facilities)
    ('PLAB-B3-F1-101', 2, 1, DEFAULT, NULL),
    ('PLAB-B3-F1-101', 4, 10, DEFAULT, NULL),
    -- Meeting Room 301 (2 facilities)
    ('MTR-B1-F3-301', 1, 1, 'Broken', 'HDMI input port damaged and lamp requires replacement'),
    ('MTR-B1-F3-301', 2, 1, DEFAULT, NULL),
    -- Student Hub (1 facility)
    ('SWS-B2-F1-001', 2, 3, DEFAULT, NULL),
    -- Lecture Room 203 (2 facilities, under maintenance)
    ('CLS-B2-F2-203', 1, 1, 'Broken', 'Projector displaying distorted image; maintenance ticket CS-2024-047 filed'),
    ('CLS-B2-F2-203', 2, 1, DEFAULT, NULL),
    -- Small Auditorium B (2 facilities, retired)
    ('AUD-B1-F2-201', 1, 1, DEFAULT, NULL),
    ('AUD-B1-F2-201', 3, 2, DEFAULT, NULL);
GO

-- ============================================================
-- Table: BOOKING
-- Rows: 12
-- Scenarios: [N1] through [E8], [E11]
-- Note: Bookings that will later get USAGESESSION (B3, B6, B12)
-- are initially inserted with status 'Approved' to satisfy the
-- TR_USAGESESSION_CHECK_BOOKING_STATUS trigger. Their status is
-- updated to 'Completed'/'Checked In' after USAGESESSION insert.
-- ============================================================
SET IDENTITY_INSERT BOOKING ON;
GO

INSERT INTO BOOKING (booking_id, space_code, requester_id, requested_start, requested_end, purpose, expected_participants, booking_status, created_at, approver_id, decision_time, decision_note, rejection_reason) VALUES
    -- [N1] Pending booking - request just submitted by a Student
    (1, 'CLS-B2-F2-201', 'STU2024001', '2026-09-15 10:00:00', '2026-09-15 12:00:00', 'Lecture', 40, 'Pending', '2026-07-15 09:00:00', NULL, NULL, NULL, NULL),
    -- [N2] Approved booking - seminar confirmed by Facility Staff
    (2, 'MTR-B1-F3-301', 'LEC2024001', '2026-09-20 14:00:00', '2026-09-20 16:00:00', 'Seminar', 15, 'Approved', '2026-07-16 10:30:00', 'STF2024001', '2026-07-17 09:00:00', 'Approved for departmental research seminar. Room meets requirements.', NULL),
    -- [N3] Completed lifecycle - insert as Approved first; USAGESESSION added; then status updated to Completed
    (3, 'CLS-B2-F2-201', 'LEC2024001', '2026-10-15 08:00:00', '2026-10-15 10:00:00', 'Lecture', 50, 'Approved', '2026-07-20 11:00:00', 'STF2024001', '2026-07-21 14:00:00', 'Approved for CS486 lecture series.', NULL),
    -- [N4] Declined request - booking Rejected by Facility Staff with reason
    (4, 'SWS-B2-F1-001', 'STU2024001', '2026-09-22 09:00:00', '2026-09-22 11:00:00', 'Student Activity', 30, 'Rejected', '2026-07-18 08:00:00', 'STF2024001', '2026-07-19 10:00:00', 'Student Hub is reserved for open study during examination period.', 'Student Hub is reserved for open study during examination period. Please consider booking Meeting Room 301 instead.'),
    -- [N5] Cancelled booking - cancelled by requester after initial approval
    (5, 'CLS-B2-F2-202', 'TA2024001', '2026-09-25 13:00:00', '2026-09-25 15:00:00', 'Workshop', 20, 'Cancelled', '2026-07-22 09:00:00', 'STF2024001', '2026-07-23 11:00:00', 'Approved for Python workshop.', NULL),
    -- [E8] Checked In booking - insert as Approved first; USAGESESSION added; then status updated to Checked In
    (6, 'AUD-B1-F1-101', 'LEC2024001', '2026-10-18 09:00:00', '2026-10-18 12:00:00', 'Examination', 150, 'Approved', '2026-08-01 08:00:00', 'STF2024002', '2026-08-02 09:00:00', 'Approved for final year examination.', NULL),
    -- [E7] No-Show booking - requester did not arrive
    (7, 'SWS-B2-F1-001', 'LEC2024001', '2026-09-28 08:00:00', '2026-09-28 10:00:00', 'Lecture', 60, 'No-Show', '2026-07-25 14:00:00', 'STF2024001', '2026-09-28 08:35:00', 'Requester did not arrive within 30-minute check-in window. Marked as no-show.', NULL),
    -- [E2] All optional fields populated - Approved by Facility Manager with full decision metadata
    (8, 'MTR-B1-F3-301', 'ADM2024001', '2026-10-01 10:00:00', '2026-10-01 12:00:00', 'Administrative Event', 10, 'Approved', '2026-08-05 09:00:00', 'MGR2024001', '2026-08-06 15:30:00', 'Approved for department town hall planning meeting. Catering table requested.', NULL),
    -- [E4] Space under maintenance - Lecture 203 has active maintenance; booking can only be Pending
    (9, 'CLS-B2-F2-203', 'LEC2024001', '2026-10-05 09:00:00', '2026-10-05 11:00:00', 'Lecture', 30, 'Pending', '2026-08-10 10:00:00', NULL, NULL, NULL, NULL),
    -- [E5] Retired space booking attempt - can only be Pending (trigger blocks Approved)
    (10, 'AUD-B1-F2-201', 'STU2024002', '2026-10-08 10:00:00', '2026-10-08 12:00:00', 'Student Activity', 50, 'Pending', '2026-08-12 11:00:00', NULL, NULL, NULL, NULL),
    -- Additional Approved booking for many-to-many demonstration
    (11, 'MTR-B1-F3-301', 'TA2024001', '2026-10-10 14:00:00', '2026-10-10 16:00:00', 'Meeting', 5, 'Approved', '2026-08-15 09:00:00', 'STF2024002', '2026-08-16 10:00:00', 'Approved for TA coordination meeting.', NULL),
    -- [E8] Second Checked In booking - insert as Approved first; USAGESESSION added; then updated
    (12, 'PLAB-B3-F1-101', 'ADM2024001', '2026-10-12 09:00:00', '2026-10-12 11:00:00', 'Workshop', 25, 'Approved', '2026-08-20 08:00:00', 'STF2024001', '2026-08-21 09:00:00', 'Approved for research equipment training workshop.', NULL);
GO

SET IDENTITY_INSERT BOOKING OFF;
GO

-- ============================================================
-- Table: USAGESESSION
-- Rows: 3
-- Scenarios: [N3] (Completed - full check-in/out),
--            [E8] (Checked In - check-in only),
--            [E11] (nullable columns: some NULL some populated)
-- Note: TR_USAGESESSION_CHECK_BOOKING_STATUS requires the
-- referenced booking to have status 'Approved' at insert time.
-- The UPDATE statements after this block change booking status
-- to 'Completed' and 'Checked In' accordingly.
-- ============================================================
-- [N3] Booking 3 - completed lifecycle with full usage session
INSERT INTO USAGESESSION (booking_id, check_in_staff_id, actual_start, initial_condition, check_out_staff_id, actual_end, final_condition, usage_notes) VALUES
    (3, 'STF2024001', '2026-10-15 08:05:00',
     'Room clean. All desks arranged in lecture format. Projector powered on and functioning. Whiteboard clean.',
     'STF2024002', '2026-10-15 10:02:00',
     'Room tidy. Projector powered off. One marker left behind on the lectern.',
     'Session ran on time. 48 students attended. No issues reported.');
GO

-- [E8] Booking 6 - checked in, session in progress, no checkout yet
INSERT INTO USAGESESSION (booking_id, check_in_staff_id, actual_start, initial_condition, check_out_staff_id, actual_end, final_condition, usage_notes) VALUES
    (6, 'STF2024001', '2026-10-18 09:02:00',
     'Auditorium clean. All 150 seats arranged. Projector and microphone tested and working. Emergency exits clear.',
     NULL, NULL, NULL, NULL);
GO

-- [E8] Booking 12 - checked in, session in progress, no checkout yet
INSERT INTO USAGESESSION (booking_id, check_in_staff_id, actual_start, initial_condition, check_out_staff_id, actual_end, final_condition, usage_notes) VALUES
    (12, 'STF2024002', '2026-10-12 09:05:00',
     'Project lab clean. All 10 workstations powered on. Whiteboard clean. Network ports functional.',
     NULL, NULL, NULL, NULL);
GO

-- ============================================================
-- Update booking statuses for lifecycle progression
-- These updates occur AFTER USAGESESSION insertion so that
-- TR_USAGESESSION_CHECK_BOOKING_STATUS is satisfied.
-- ============================================================
-- [N3] Booking 3: Mark as Completed (was 'Approved' during USAGESESSION insert)
UPDATE BOOKING SET booking_status = 'Completed' WHERE booking_id = 3;
GO

-- [E8] Booking 6: Mark as Checked In (was 'Approved' during USAGESESSION insert)
UPDATE BOOKING SET booking_status = 'Checked In' WHERE booking_id = 6;
GO

-- [E8] Booking 12: Mark as Checked In (was 'Approved' during USAGESESSION insert)
UPDATE BOOKING SET booking_status = 'Checked In' WHERE booking_id = 12;
GO

-- ============================================================
-- Table: MAINTENANCERECORD
-- Rows: 8
-- Scenarios: [E4], [E9] (all 4 statuses), [E10] (all 6 problem types),
--            [E11] (nullable columns), [E6] (role restrictions)
-- ============================================================
SET IDENTITY_INSERT MAINTENANCERECORD ON;
GO

INSERT INTO MAINTENANCERECORD (maintenance_id, space_code, reporter_id, assigned_staff_id, problem_type, problem_description, start_time, completion_time, maintenance_status, result_note) VALUES
    -- [E4][E9] M1: Reported - Lecture 203 projector issue, unassigned
    (1, 'CLS-B2-F2-203', 'LEC2024001', NULL, 'Projector Failure',
     'Projector displays intermittent flickering during operation. After 15 minutes the image becomes distorted and eventually fades to a blue screen. Issue observed during three consecutive lectures.',
     '2026-08-01 09:00:00', NULL, 'Reported', NULL),
    -- [E9] M2: In Progress - Lecture 203 network issue, assigned to staff
    (2, 'CLS-B2-F2-203', 'LEC2024001', 'STF2024001', 'Network Issue',
     'Wired network ports 4 through 12 on the south wall are not providing connectivity. Wireless signal strength in the room is below acceptable levels for class-sized groups.',
     '2026-08-15 10:00:00', NULL, 'In Progress', NULL),
    -- [E9] M3: Resolved - Meeting Room 301 AC repair, completed
    (3, 'MTR-B1-F3-301', 'STF2024002', 'STF2024001', 'Air-Conditioning Issue',
     'Air conditioning unit in Meeting Room 301 is blowing warm air. Ambient temperature reached 31 degrees Celsius during afternoon use.',
     '2026-06-01 08:00:00', '2026-06-05 17:00:00', 'Resolved', 'Replaced faulty compressor relay and recharged refrigerant. Unit now maintaining 22 degrees Celsius.'),
    -- [E9] M4: Cancelled - Student Hub cleaning reported then cancelled
    (4, 'SWS-B2-F1-001', 'STU2024001', NULL, 'Cleaning Issue',
     'Spilled beverage near the east entrance sink area. Floor surface is sticky and attracting insects.',
     '2026-06-20 14:00:00', '2026-06-21 14:00:00', 'Cancelled', NULL),
    -- [E9] M5: Reported - Computer Lab A furniture damage, unassigned
    (5, 'CLS-B2-F2-202', 'TA2024001', NULL, 'Furniture Damage',
     'Workstation desk number 7 has a broken leg causing it to wobble. Chair number 12 has a torn seat cushion exposing foam padding.',
     '2026-08-20 09:00:00', NULL, 'Reported', NULL),
    -- [E9] M6: Resolved - Meeting Room 301 other issue
    (6, 'MTR-B1-F3-301', 'STF2024001', 'STF2024002', 'Other',
     'The ceiling-mounted occupancy sensor has detached on one side and is hanging by its wiring. Potential safety hazard.',
     '2026-08-10 09:00:00', '2026-08-11 17:00:00', 'Resolved', 'Sensor reattached and recalibrated. Wiring inspected, no damage found.'),
    -- [E9] M7: Resolved - Project Lab Alpha network issue
    (7, 'PLAB-B3-F1-101', 'LEC2024002', 'STF2024001', 'Network Issue',
     'All workstations in the project lab lost internet connectivity intermittently throughout the morning. DHCP server appears to be assigning duplicate IP addresses.',
     '2026-06-15 10:00:00', '2026-06-18 16:00:00', 'Resolved', 'DHCP scope conflict resolved. Reconfigured router to use a non-overlapping subnet. All 10 workstations reconnected.'),
    -- [E9] M8: Resolved - Main Auditorium projector failure
    (8, 'AUD-B1-F1-101', 'LEC2024001', 'STF2024002', 'Projector Failure',
     'Main auditorium projector displays a persistent yellow tint across the entire image. Colour calibration does not resolve the issue. Likely a failing colour wheel.',
     '2026-07-10 08:00:00', '2026-07-12 18:00:00', 'Resolved', 'Replaced projector colour wheel assembly and recalibrated. Image quality restored to factory specification.');
GO

SET IDENTITY_INSERT MAINTENANCERECORD OFF;
GO
