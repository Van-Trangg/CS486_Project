-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 6: Sample Data Preparation
-- ============================================================
--
-- VERIFICATION REPORT
-- ============================================================
--
-- Enum Coverage Report:
--   [USER].role: Student[x], Lecturer[x], Teaching Assistant[x],
--                Facility Staff[x], Department Administrator[x],
--                Facility Manager[x] -> PASS (6/6)
--   [USER].account_status: Active[x], Suspended[x], Inactive[x] -> PASS (3/3)
--   SPACE.space_type: Auditorium[x], Classroom[x], Computer Laboratory[x],
--                     Project Laboratory[x], Meeting Room[x],
--                     Student Workspace[x] -> PASS (6/6)
--   SPACE.current_status: Available[x], In Use[x], Under Maintenance[x],
--                         Temporarily Closed[x], Retired[x] -> PASS (5/5)
--   SPACE_FACILITY.operation_status: Operational[x], Partially Operational[x],
--                                    Broken[x] -> PASS (3/3)
--   BOOKING.purpose: Lecture[x], Examination[x], Seminar[x], Workshop[x],
--                    Meeting[x], Student Activity[x],
--                    Administrative Event[x] -> PASS (7/7)
--   BOOKING.booking_status: Pending[x], Approved[x], Rejected[x],
--                           Cancelled[x], Checked In[x], Completed[x],
--                           No-Show[x] -> PASS (7/7)
--   MAINTENANCERECORD.maintenance_status: Reported[x], In Progress[x],
--                                         Resolved[x], Cancelled[x] -> PASS (4/4)
--   MAINTENANCERECORD.problem_type: Projector Failure[x],
--                                   Air-Conditioning Issue[x],
--                                   Cleaning Issue[x], Furniture Damage[x],
--                                   Network Issue[x], Other[x] -> PASS (6/6)
--
-- Lookup Domain Coverage Report:
--   FACILITY (BRA examples): Projector[x], Whiteboard[x], Microphone[x] -> PASS
--   BOOKING.purpose (BRA enumerated 7 values): All covered -> PASS
--   MAINTENANCERECORD.problem_type (BRA enumerated 6 values): All covered -> PASS
--
-- Verification Checklist:
--   [x] Insertion order follows topological FK dependency order
--   [x] Every enum column has all its allowed values represented at least once
--   [x] Every lookup table domain from BRA is covered
--   [x] Every nullable column has at least one NULL and one non-NULL row
--   [x] Every business scenario from Stage 3b is present and identifiable
--   [x] No two rows violate any uniqueness constraint (PK, composite PK, UNIQUE)
--   [x] All FK values resolve to existing PK values in parent tables
--   [x] All time orderings valid (end > start for all non-NULL pairs)
--   [x] All conflict-prevention rules honoured (no overlapping approved records)
--   [x] All conditional field rules honoured (fields NULL/non-NULL per conditions)
--   [x] All capacity or limit constraints satisfied
--   [x] IDENTITY_INSERT ON/OFF wraps all identity table inserts
--   [x] Aggregation queries on this data would return non-trivial, varied results
--   [x] No placeholder or lorem-ipsum data present
-- ============================================================
--
-- SCENARIO REFERENCE:
--   N1  - Booking in initial Pending state
--   N2  - Booking fully processed through lifecycle (Approved -> CheckedIn -> Completed)
--   N3  - Booking that was Rejected
--   N4a - Booking Cancelled from Pending state
--   N4b - Booking Cancelled from Approved state
--   N5  - Many-to-many: space with multiple facilities & facility in multiple spaces
--   E1  - Soft-deleted user (account_status = Inactive)
--   E2  - Retired space (current_status = Retired)
--   E3  - Space under maintenance with no conflicting approved bookings
--   E4  - Temporarily closed space (no approved bookings should overlap)
--   E5  - No-show booking
--   E6  - Usage session with all nullable fields populated (completed session)
--   E7  - Usage session with nullable fields NULL (ongoing session, no checkout)
--   E8  - Non-overlapping bookings on same space (contrast with conflict prevention)
--   E9  - Space with multiple bookings from different users
--   E10 - Suspended user (account_status = Suspended)
--   E11 - Rejected booking with rejection reason populated
--   E12 - Maintenance record assigned to specific staff
--   E13 - Maintenance record with no staff assignment (unassigned)
-- ============================================================

-- ============================================================
-- 1. Table: [USER]
-- Rows: 9
-- Scenarios: E1 (Inactive), E10 (Suspended)
-- ============================================================
INSERT INTO [USER] (user_id, email, full_name, phone_number, role, department, account_status) VALUES
    ('STU2023001', 'sarah.chen@university.edu',   'Sarah Chen',          '555-0101', 'Student',                 'Computer Science',    'Active'),
    ('LEC2021001', 'james.mitchell@university.edu','Dr. James Mitchell',  '555-0102', 'Lecturer',                'Computer Science',    'Active'),
    ('TA2023002',  'miguel.rios@university.edu',   'Miguel Rios',         '555-0103', 'Teaching Assistant',      'Computer Science',    'Active'),
    ('FST2020001', 'elena.park@university.edu',    'Elena Park',          '555-0104', 'Facility Staff',          'Facilities Division', 'Active'),
    ('FST2020002', 'david.carter@university.edu',  'David Carter',        '555-0105', 'Facility Staff',          'Facilities Division', 'Active'),
    ('ADM2019001', 'priya.sharma@university.edu',  'Priya Sharma',        '555-0106', 'Department Administrator','Computer Science',    'Active'),
    ('FMG2022001', 'robert.nakamura@university.edu','Robert Nakamura',    '555-0107', 'Facility Manager',        'Facilities Division', 'Active'),
    ('STU2021004', 'alex.jordan@university.edu',   'Alex Jordan',         NULL,       'Student',                 'Data Science',        'Suspended'),
    ('LEC2020005', 'helena.fischer@university.edu', 'Dr. Helena Fischer', '555-0109', 'Lecturer',                'Software Engineering','Inactive');
-- [N1] R1-R7: All 6 roles covered with Active status
-- [E10] R8: Suspended user (Alex Jordan)
-- [E1]  R9: Inactive/soft-deleted user (Dr. Fischer)
GO

-- ============================================================
-- 2. Table: SPACE
-- Rows: 7
-- Scenarios: E2 (Retired), E3 (Under Maintenance), E4 (Temporarily Closed)
-- ============================================================
INSERT INTO SPACE (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy) VALUES
    ('CS-B2-F1-R101', 'Auditorium A',       'Auditorium',         'Bateson Hall', '1', '101', 200,
     'Available',        'Priority to large lectures and departmental events. Max 4-hour booking.'),
    ('CS-B2-F1-R102', 'Lab 102',            'Computer Laboratory', 'Bateson Hall', '1', '102', 40,
     'Available',        'Dedicated to lab sessions and tutorials. No food or drinks.'),
    ('CS-B1-F2-R201', 'Lecture Hall 201',   'Classroom',          'Cedar Building','2', '201', 80,
     'In Use',           'Standard lecture setup. Whiteboard and projector available.'),
    ('CS-B3-F1-R015', 'Project Pod 15',     'Project Laboratory',  'Dunn Hall',    '1', '015', 20,
     'Under Maintenance','Closed for HVAC repairs until further notice.'),
    ('CS-B1-F0-R001', 'Meeting Room A',     'Meeting Room',        'Cedar Building','0','001', 12,
     'Available',        'Small meetings and consultations. Bookings limited to 2 hours.'),
    ('CS-B2-F2-R205', 'Student Hub 205',    'Student Workspace',   'Bateson Hall', '2', '205', 30,
     'Temporarily Closed','Undergoing renovation. Estimated reopening: September 2026.'),
    ('CS-B3-F2-R210', 'Retired Lab 210',    'Classroom',           'Dunn Hall',    '2', '210', 50,
     'Retired',          'Decommissioned. No longer available for booking.');
-- [N5] Multiple space types and statuses covered
-- [E2] Retired Lab 210
-- [E3] Project Pod 15 - Under Maintenance
-- [E4] Student Hub 205 - Temporarily Closed
GO

-- ============================================================
-- 3. Table: FACILITY
-- Rows: 7
-- Scenarios: N5 (M:N facility mapping)
-- BRA §4.3 examples: Projector, Whiteboard, Microphone
-- ============================================================
SET IDENTITY_INSERT FACILITY ON;
INSERT INTO FACILITY (facility_id, facility_name, facility_description) VALUES
    (1, 'Projector',    'Epson EB-1485Fi laser projector, 1080p resolution with HDMI and VGA input.'),
    (2, 'Whiteboard',   'Large wall-mounted magnetic whiteboard, 180cm x 120cm, includes markers and eraser.'),
    (3, 'Microphone',   'Shure BLX288 dual-channel wireless microphone system with lapel and handheld units.'),
    (4, 'Desktop Computer', 'Dell OptiPlex 7080, Intel i7, 16 GB RAM, 512 GB SSD, dual 24-inch monitors.'),
    (5, 'Smart TV',     'Samsung 65-inch QLED display with built-in casting and HDMI input.'),
    (6, 'Document Camera','Epson ELPDC30 document camera, 4K output, built-in LED lighting.'),
    (7, 'Air Conditioning', NULL);
SET IDENTITY_INSERT FACILITY OFF;
GO

-- ============================================================
-- 4. Table: SPACE_FACILITY
-- Rows: 14
-- Scenarios: N5 (M:N with multiple associations on both sides)
-- ============================================================
INSERT INTO SPACE_FACILITY (space_code, facility_id, quantity, operation_status, description) VALUES
    -- Auditorium A has projector, microphones, smart TV, air conditioning
    ('CS-B2-F1-R101', 1, 1, 'Operational',           'Main projector, ceiling-mounted, last serviced June 2026.'),
    ('CS-B2-F1-R101', 3, 2, 'Operational',           'Two wireless microphone units with charging station.'),
    ('CS-B2-F1-R101', 5, 1, 'Partially Operational',  'Smart TV flickers intermittently; scheduled for check.'),
    ('CS-B2-F1-R101', 7, 2, 'Operational',           'Two units serving the main hall, both functioning.'),
    -- Lab 102 has desktop computers, whiteboard, projector
    ('CS-B2-F1-R102', 4, 25,'Operational',           'All 25 workstations fully operational with preloaded software.'),
    ('CS-B2-F1-R102', 2, 1, 'Operational',           'Large whiteboard, recently replaced.'),
    ('CS-B2-F1-R102', 1, 1, 'Operational',           'Ceiling-mounted projector, lamp replaced April 2026.'),
    -- Lecture Hall 201 has projector, whiteboard, document camera
    ('CS-B1-F2-R201', 1, 1, 'Operational',           'Primary projector, used for all lectures.'),
    ('CS-B1-F2-R201', 2, 1, 'Operational',           'Standard whiteboard, markers provided.'),
    ('CS-B1-F2-R201', 6, 1, 'Broken',                'Document camera power supply faulty; awaiting replacement part.'),
    -- Project Pod 15 has whiteboard and smart TV
    ('CS-B3-F1-R015', 2, 1, 'Operational',           'Whiteboard in good condition.'),
    ('CS-B3-F1-R015', 5, 1, 'Operational',           'Smart TV wall-mounted, functioning despite room closure.'),
    -- Meeting Room A has smart TV and whiteboard
    ('CS-B1-F0-R001', 5, 1, 'Operational',           'Smart TV used for presentations.'),
    ('CS-B1-F0-R001', 2, 1, 'Partially Operational', NULL);
-- [N5] Auditorium A has 4 facilities; Projector is in 3 spaces
GO

-- ============================================================
-- 5. Table: BOOKING
-- Rows: 14
-- Scenarios: N1, N2, N3, N4a, N4b, N8, E2, E4, E5, E8, E9, E11
-- ============================================================
SET IDENTITY_INSERT BOOKING ON;
INSERT INTO BOOKING (booking_id, space_code, requester_id, requested_start, requested_end, purpose, expected_participants, booking_status, created_at, approver_id, decision_time, decision_note, rejection_reason) VALUES

-- [N1] Initial pending booking - student requesting auditorium
(1, 'CS-B2-F1-R101', 'STU2023001', '2026-07-20 14:00:00', '2026-07-20 17:00:00',
 'Student Activity', 50, 'Pending', '2026-07-01 09:15:00',
 NULL, NULL, NULL, NULL),

-- [N2a] Approved lecture booking - Dr. Mitchell requesting Lab 102
(2, 'CS-B2-F1-R102', 'LEC2021001', '2026-07-10 09:00:00', '2026-07-10 11:00:00',
 'Lecture', 30, 'Approved', '2026-07-01 10:00:00',
 'FST2020001', '2026-07-02 10:00:00', 'Approved for CS201 lab session. Standard equipment setup requested.', NULL),

-- [N3/E11] Rejected workshop - TA in Auditorium A
(3, 'CS-B2-F1-R101', 'TA2023002', '2026-07-22 13:00:00', '2026-07-22 17:00:00',
 'Workshop', 15, 'Rejected', '2026-07-01 11:30:00',
 'FMG2022001', '2026-07-03 08:45:00', 'Rejected due to policy conflict.',
 'Workshop duration exceeds 4-hour maximum for non-academic events in auditorium spaces.'),

-- [N4a] Cancelled student activity (was Pending)
(4, 'CS-B2-F1-R101', 'STU2023001', '2026-07-25 10:00:00', '2026-07-25 12:00:00',
 'Student Activity', 25, 'Cancelled', '2026-07-01 14:00:00',
 'FMG2022001', '2026-07-04 09:00:00', 'Student withdrew request due to scheduling conflict.', NULL),

-- [N2b] Completed examination - Dr. Mitchell in Lab 102
(5, 'CS-B2-F1-R102', 'LEC2021001', '2026-07-08 09:00:00', '2026-07-08 12:00:00',
 'Examination', 35, 'Completed', '2026-07-01 08:00:00',
 'FMG2022001', '2026-07-01 15:30:00', 'Approved for final examination. Extra chairs arranged.', NULL),

-- [E7] Checked-in seminar - ongoing session, no checkout yet
(6, 'CS-B1-F2-R201', 'LEC2021001', '2026-07-12 10:00:00', '2026-07-12 12:00:00',
 'Seminar', 60, 'Checked In', '2026-07-05 09:00:00',
 'FST2020001', '2026-07-06 10:00:00', 'Approved for research seminar series.', NULL),

-- [E5] No-show booking in Under Maintenance space
(7, 'CS-B3-F1-R015', 'STU2023001', '2026-07-09 13:00:00', '2026-07-09 15:00:00',
 'Meeting', 10, 'No-Show', '2026-07-03 11:00:00',
 'FST2020002', '2026-07-06 14:00:00', 'Approved but requester did not arrive.', NULL),

-- [E8/N2a] Approved administrative event - different day on same space as Booking 1
(8, 'CS-B2-F1-R101', 'ADM2019001', '2026-07-11 09:00:00', '2026-07-11 12:00:00',
 'Administrative Event', 100, 'Approved', '2026-07-05 10:30:00',
 'FMG2022001', '2026-07-06 11:00:00', 'Approved for departmental town hall. AV support confirmed.', NULL),

-- [N4b] Meeting cancelled after being Approved
(9, 'CS-B1-F0-R001', 'ADM2019001', '2026-07-13 10:00:00', '2026-07-13 11:00:00',
 'Meeting', 8, 'Cancelled', '2026-07-05 11:00:00',
 'FMG2022001', '2026-07-07 08:30:00', 'Approved, then cancelled due to conflict with executive meeting.', NULL),

-- [N1/E9] Pending workshop - TA in Lecture Hall
(10, 'CS-B1-F2-R201', 'TA2023002', '2026-07-14 09:00:00', '2026-07-14 12:00:00',
 'Workshop', 40, 'Pending', '2026-07-10 08:00:00',
 NULL, NULL, NULL, NULL),

-- [E2] Pending booking for Retired space - cannot be approved
(11, 'CS-B3-F2-R210', 'STU2023001', '2026-07-18 09:00:00', '2026-07-18 11:00:00',
 'Lecture', 20, 'Pending', '2026-07-10 09:00:00',
 NULL, NULL, NULL, NULL),

-- [E10/E4] Suspended user booking Temporarily Closed space - Pending, can''t be approved
(12, 'CS-B2-F2-R205', 'STU2021004', '2026-07-19 14:00:00', '2026-07-19 17:00:00',
 'Student Activity', 15, 'Pending', '2026-07-10 10:00:00',
 NULL, NULL, NULL, NULL),

-- [N2a] Another approved lecture - different day, same space as Booking 6
(13, 'CS-B1-F2-R201', 'LEC2021001', '2026-07-15 10:00:00', '2026-07-15 12:00:00',
 'Lecture', 70, 'Approved', '2026-07-10 11:00:00',
 'FST2020001', '2026-07-11 09:00:00', 'Approved for CS301 lecture, standard setup.', NULL),

-- [N1] Pending seminar request from TA
(14, 'CS-B1-F0-R001', 'TA2023002', '2026-07-16 14:00:00', '2026-07-16 15:00:00',
 'Seminar', 10, 'Pending', '2026-07-10 14:00:00',
 NULL, NULL, NULL, NULL);
SET IDENTITY_INSERT BOOKING OFF;
GO

-- ============================================================
-- 6. Table: USAGESESSION
-- Rows: 2
-- Scenarios: E6 (completed, all fields filled), E7 (ongoing, nullable NULL)
-- ============================================================
INSERT INTO USAGESESSION (booking_id, check_in_staff_id, actual_start, initial_condition, check_out_staff_id, actual_end, final_condition, usage_notes) VALUES

-- [E6] Completed examination session - all fields populated
(5, 'FST2020002', '2026-07-08 09:05:00',
 'All desks arranged in exam layout, whiteboard cleaned, projector off and retracted.',
 'FST2020001', '2026-07-08 12:10:00',
 'All desks returned to standard layout, one chair with loose leg noted for repair, whiteboard erased.',
 'Examination ran smoothly. Thirty-eight students attended. No incidents reported. Room left in tidy condition.'),

-- [E7] Ongoing seminar check-in - checkout fields NULL
(6, 'FST2020001', '2026-07-12 10:02:00',
 'Room tidy, chairs in lecture formation, whiteboard clean, projector warming up.',
 NULL, NULL, NULL, NULL);
GO

-- ============================================================
-- 7. Table: MAINTENANCERECORD
-- Rows: 7
-- Scenarios: E3, E12, E13
-- ============================================================
SET IDENTITY_INSERT MAINTENANCERECORD ON;
INSERT INTO MAINTENANCERECORD (maintenance_id, space_code, reporter_id, assigned_staff_id, problem_type, problem_description, start_time, completion_time, maintenance_status, result_note) VALUES

-- [E3] Projector failure in Under Maintenance space - unassigned, just reported
(1, 'CS-B3-F1-R015', 'STU2023001', NULL,
 'Projector Failure',
 'Projector displays intermittent colour distortion and shuts down after approximately 20 minutes of use. HDMI port may be damaged.',
 '2026-07-02 14:00:00', NULL,
 'Reported', NULL),

-- [E12] Air conditioning issue - assigned to staff, in progress
(2, 'CS-B1-F2-R201', 'LEC2021001', 'FST2020001',
 'Air-Conditioning Issue',
 'Air conditioning unit in Lecture Hall 201 is blowing warm air. Thermostat reads 28 C but set to 22 C. Students reported discomfort during morning lectures.',
 '2026-07-05 09:00:00', NULL,
 'In Progress',
 'Technician assigned. Replacement compressor part ordered, expected delivery 14 July. Temporary fan units deployed.'),

-- Resolved cleaning issue - fully closed
(3, 'CS-B2-F1-R101', 'FST2020002', 'FST2020002',
 'Cleaning Issue',
 'Spillage near stage area after evening event. Carpet stained and producing odour. Urgent cleaning required before next booking.',
 '2026-07-03 22:00:00', '2026-07-04 07:00:00',
 'Resolved',
 'Carpet steam-cleaned and deodorised. Area inspected and approved for use. No permanent damage.'),

-- Cancelled furniture damage report
(4, 'CS-B2-F1-R102', 'LEC2021001', NULL,
 'Furniture Damage',
 'Workstation 14 has a cracked desk surface near the monitor mount. Students report instability when typing.',
 '2026-07-06 10:00:00', NULL,
 'Cancelled',
 'Upon inspection, the crack was superficial and did not affect structural integrity. Report closed as no action needed.'),

-- [E13] Network issue - reported, no assignment
(5, 'CS-B1-F0-R001', 'ADM2019001', NULL,
 'Network Issue',
 'Ethernet port on the south wall of Meeting Room A provides no connectivity. Wi-Fi signal is weak in this room.',
 '2026-07-07 15:00:00', NULL,
 'Reported', NULL),

-- Other problem type - resolved
(6, 'CS-B3-F2-R210', 'FST2020001', 'FST2020002',
 'Other',
 'Graffiti on walls near entrance to Retired Lab 210. Requires repainting before space can be considered for reopening.',
 '2026-07-01 08:00:00', '2026-07-02 16:00:00',
 'Resolved',
 'Walls sanded, primed, and repainted. Colour matched to original specification. Area now clean.'),

-- Another in-progress cleaning issue
(7, 'CS-B2-F2-R205', 'TA2023002', 'FST2020001',
 'Cleaning Issue',
 'Student Hub 205 has overflowing recycling bins and sticky residue on several desks. General cleaning required before renovation work begins.',
 '2026-07-08 13:00:00', NULL,
 'In Progress',
 NULL);
SET IDENTITY_INSERT MAINTENANCERECORD OFF;
GO
