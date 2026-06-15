-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 6: Sample Data Preparation
-- ============================================================

-- ============================================================
-- Table: USER
-- Rows: 10
-- Scenarios covered: All roles, All account statuses
-- ============================================================
INSERT INTO [USER] (user_id, email, full_name, phone_number, role, department, account_status) VALUES
    ('STU2023001', 'alice.student@university.edu', 'Alice Student', '555-0101', 'Student', 'Computer Science', 'Active'),
    ('STU2023002', 'bob.student@university.edu', 'Bob Student', '555-0102', 'Student', 'Computer Science', 'Suspended'),
    ('LEC2023001', 'charlie.lec@university.edu', 'Charlie Lecturer', '555-0103', 'Lecturer', 'Computer Science', 'Active'),
    ('TA2023001', 'dave.ta@university.edu', 'Dave TA', '555-0104', 'Teaching Assistant', 'Computer Science', 'Active'),
    ('STAFF2023001', 'eve.staff@university.edu', 'Eve Staff', '555-0105', 'Facility Staff', 'Facilities', 'Active'),
    ('STAFF2023002', 'frank.staff@university.edu', 'Frank Staff', '555-0106', 'Facility Staff', 'Facilities', 'Active'),
    ('ADMIN2023001', 'grace.admin@university.edu', 'Grace Admin', '555-0107', 'Department Administrator', 'Admin', 'Active'),
    ('MGR2023001', 'heidi.mgr@university.edu', 'Heidi Manager', '555-0108', 'Facility Manager', 'Facilities', 'Active'),
    ('STU2023003', 'ivan.student@university.edu', 'Ivan Student', NULL, 'Student', 'Computer Science', 'Inactive'),
    ('LEC2023002', 'judy.lec@university.edu', 'Judy Lecturer', '555-0109', 'Lecturer', 'Computer Science', 'Active');
GO

-- ============================================================
-- Table: SPACE
-- Rows: 8
-- Scenarios covered: All space types, All space statuses
-- ============================================================
INSERT INTO [SPACE] (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy) VALUES
    ('B1-F3-R101', 'Main Auditorium', 'Auditorium', 'Building 1', 'F3', '101', 200, 'Available', 'Strictly for lectures and events.'),
    ('B1-F1-R102', 'Lab 102', 'Computer Laboratory', 'Building 1', 'F1', '102', 30, 'In Use', 'Student labs only.'),
    ('B1-F2-R103', 'Meeting Room A', 'Meeting Room', 'Building 1', 'F2', '103', 10, 'Available', 'Bookings required 24h in advance.'),
    ('B2-F1-R201', 'Project Lab 1', 'Project Laboratory', 'Building 2', 'F1', '201', 50, 'Under Maintenance', 'No access during maintenance.'),
    ('B2-F2-R202', 'Classroom 202', 'Classroom', 'Building 2', 'F2', '202', 60, 'Temporarily Closed', 'Closed for renovation.'),
    ('B2-F3-R203', 'Student Work Zone', 'Student Workspace', 'Building 2', 'F3', '203', 40, 'Available', 'Open study area.'),
    ('B1-F1-R104', 'Retired Room', 'Classroom', 'Building 1', 'F1', '104', 20, 'Retired', 'No longer in use.'),
    ('B2-F1-R204', 'Meeting Room B', 'Meeting Room', 'Building 2', 'F1', '204', 15, 'Available', 'Quiet meeting room.');
GO

-- ============================================================
-- Table: FACILITY
-- Rows: 5
-- Scenarios covered: Complete facility catalog
-- ============================================================
INSERT INTO [FACILITY] (facility_name, facility_description) VALUES
    ('Projector', 'High definition projector with HDMI input.'),
    ('Whiteboard', 'Large magnetic whiteboard.'),
    ('Microphone', 'Wireless handheld microphone.'),
    ('PC Station', 'Workstation with dual monitors.'),
    ('Video Conf', 'Video conferencing camera system.');
GO

-- ============================================================
-- Table: SPACE_FACILITY
-- Rows: 5
-- Scenarios covered: Multiple facilities per space
-- ============================================================
INSERT INTO [SPACE_FACILITY] (space_code, facility_id, quantity, operation_status, description) VALUES
    ('B1-F3-R101', 1, 1, 'Operational', 'Main auditorium projector.'),
    ('B1-F3-R101', 3, 2, 'Operational', 'Main auditorium microphones.'),
    ('B1-F1-R102', 4, 30, 'Operational', 'Lab PC stations.'),
    ('B1-F2-R103', 2, 1, 'Operational', 'Meeting room whiteboard.'),
    ('B2-F1-R201', 1, 1, 'Broken', 'Needs bulb replacement.');
GO

-- ============================================================
-- Table: BOOKING
-- Rows: 10
-- Scenarios covered: Normal (Pending, Approved), Lifecycle (Checked In, Completed), Edge (Rejected, Cancelled, No-Show)
-- ============================================================
SET IDENTITY_INSERT [BOOKING] ON;
INSERT INTO [BOOKING] (booking_id, space_code, requester_id, requested_start, requested_end, purpose, expected_participants, booking_status, approver_id, decision_time, decision_note, rejection_reason) VALUES
    (1, 'B1-F3-R101', 'LEC2023001', '2026-06-20 09:00:00', '2026-06-20 11:00:00', 'Lecture', 100, 'Approved', 'MGR2023001', '2026-06-18 10:00:00', 'Approved for class.', NULL),
    (2, 'B1-F1-R102', 'STU2023001', '2026-06-20 13:00:00', '2026-06-20 15:00:00', 'Student Activity', 20, 'Pending', NULL, NULL, NULL, NULL),
    (3, 'B1-F2-R103', 'TA2023001', '2026-06-20 10:00:00', '2026-06-20 11:00:00', 'Meeting', 5, 'Checked In', 'STAFF2023001', '2026-06-19 09:00:00', 'Approved.', NULL),
    (4, 'B1-F2-R103', 'STU2023002', '2026-06-20 12:00:00', '2026-06-20 13:00:00', 'Meeting', 5, 'Rejected', 'STAFF2023001', '2026-06-19 10:00:00', 'Rejected.', 'Space booked for another event.'),
    (5, 'B2-F3-R203', 'STU2023001', '2026-06-20 14:00:00', '2026-06-20 16:00:00', 'Student Activity', 10, 'Completed', 'STAFF2023001', '2026-06-19 11:00:00', 'Approved.', NULL),
    (6, 'B1-F3-R101', 'LEC2023001', '2026-06-21 09:00:00', '2026-06-21 11:00:00', 'Examination', 150, 'Cancelled', 'MGR2023001', '2026-06-18 10:00:00', 'Approved.', NULL),
    (7, 'B2-F1-R204', 'STU2023001', '2026-06-21 13:00:00', '2026-06-21 14:00:00', 'Meeting', 5, 'No-Show', 'STAFF2023001', '2026-06-20 09:00:00', 'Approved.', NULL),
    (8, 'B2-F1-R201', 'LEC2023001', '2026-06-22 09:00:00', '2026-06-22 10:00:00', 'Lecture', 20, 'Pending', NULL, NULL, NULL, NULL),
    (9, 'B2-F3-R203', 'STU2023001', '2026-06-22 10:00:00', '2026-06-22 11:00:00', 'Meeting', 2, 'Approved', 'STAFF2023001', '2026-06-21 09:00:00', 'Approved.', NULL),
    (10, 'B1-F3-R101', 'ADMIN2023001', '2026-06-23 10:00:00', '2026-06-23 12:00:00', 'Administrative Event', 50, 'Pending', NULL, NULL, NULL, NULL);
SET IDENTITY_INSERT [BOOKING] OFF;
GO

-- [N1] Pending booking
-- [N2] Approved booking
-- [N3] Completed booking (via usage session)
-- [E1] Rejected booking
-- [E2] Cancelled booking
-- [E3] No-Show booking

-- ============================================================
-- Table: USAGESESSION
-- Rows: 3
-- Scenarios covered: Check-in, Completed session
-- ============================================================
INSERT INTO [USAGESESSION] (booking_id, check_in_staff_id, actual_start, initial_condition, check_out_staff_id, actual_end, final_condition, usage_notes) VALUES
    (3, 'STAFF2023001', '2026-06-20 10:00:05', 'Clean', NULL, NULL, NULL, 'In progress.'),
    (5, 'STAFF2023002', '2026-06-20 14:00:00', 'Clean', 'STAFF2023002', '2026-06-20 16:00:00', 'Clean', 'Normal usage.'),
    (7, 'STAFF2023001', '2026-06-21 13:00:00', 'Clean', 'STAFF2023001', '2026-06-21 14:00:00', 'Messy', 'User did not show up on time.');
GO

-- ============================================================
-- Table: MAINTENANCERECORD
-- Rows: 3
-- Scenarios covered: Reported, In Progress, Resolved
-- ============================================================
SET IDENTITY_INSERT [MAINTENANCERECORD] ON;
INSERT INTO [MAINTENANCERECORD] (maintenance_id, space_code, reporter_id, assigned_staff_id, problem_type, problem_description, start_time, completion_time, maintenance_status, result_note) VALUES
    (1, 'B2-F1-R201', 'LEC2023001', 'STAFF2023001', 'Projector Failure', 'Projector not turning on.', '2026-06-15 08:00:00', NULL, 'Reported', NULL),
    (2, 'B2-F2-R202', 'STAFF2023001', 'STAFF2023002', 'Cleaning Issue', 'General cleanup needed.', '2026-06-16 09:00:00', '2026-06-16 11:00:00', 'Resolved', 'Cleanup completed.'),
    (3, 'B1-F1-R102', 'STU2023001', 'STAFF2023001', 'Network Issue', 'Slow internet connection.', '2026-06-17 10:00:00', NULL, 'In Progress', 'Investigating.');
SET IDENTITY_INSERT [MAINTENANCERECORD] OFF;
GO
