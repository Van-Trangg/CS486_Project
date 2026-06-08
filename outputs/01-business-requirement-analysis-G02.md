# Step 1: Business Requirement Analysis

---

## 1. Business Purpose

The School of Computer Science manages several shared physical spaces, including auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces. These spaces support a wide variety of activities: teaching, seminars, examinations, workshops, student projects, research activities, and academic events.

Currently, the booking and usage tracking processes are manual, involving emails, phone calls, and in-person requests. Facility staff must manually inspect spreadsheets or shared calendars to check space availability, requester permissions, equipment needs, and maintenance schedules. 

As the volume of campus activities continues to grow, this manual approach has become highly inefficient, difficult to manage, and prone to scheduling conflicts or booking of unavailable spaces.

To solve these issues, the School of Computer Science is implementing a centralized database system.

### Main Objectives of the System:
1. **Fair Access:** Facilitate a structured process where eligible requesters (students, lecturers, teaching assistants, staff) can request spaces.
2. **Conflict Prevention:** Guarantee that the same physical space cannot have overlapping approved bookings at any given time.
3. **Availability Control:** Prevent bookings of spaces that are currently under maintenance, temporarily closed, or retired.
4. **Historical Logging:** Preserve complete and accurate historical records of space bookings, actual usage sessions, and maintenance activities for utilization analysis and audit trails.

---

## 2. Actors

The system supports several user roles with specific permissions and responsibilities. Every user must have a valid university account.

| Actor Name | Description | Responsibilities |
| :--- | :--- | :--- |
| **Student** | Active students within the university who require spaces for projects, group studies, or extracurricular activities. | <ul><li>Submit booking requests for student activities or project workspaces.</li><li>View own booking history and space avaibility.</li></ul> |
| **Lecturer** | Academic faculty members who require spaces for classes, seminars, or academic events. | <ul><li>Submit booking requests for lectures, exams, seminars, or workshops.</li><li>View own booking history and space availability.</li></ul> |
| **Teaching Assistant (TA)** | Academic support staff assisting lecturers in courses and student projects. | <ul><li>Submit booking requests for labs, tutorials, or student project consultations.</li><li>View own booking history and space availability.</li></ul> |
| **Facility Staff** | Dedicated personnel responsible for the day-to-day operations and upkeep of the campus spaces. | <ul><li>Review, approve, or reject standard booking requests.</li><li>Perform physical check-ins for arriving requesters, recording start times and initial room condition.</li><li>Record session completion, actual end times, and final room condition.</li><li>Report space issues and perform/resolve assigned maintenance.</li><li>View booking history, upcoming bookings, no-show bookings, and spaces under maintenance.</li></ul> |
| **Department Administrator** | Administrative staff coordinating departmental events and academic scheduling. | <ul><li>Submit booking requests for administrative events or departmental workshops.</li><li>View scheduled bookings and space availability.</li></ul> |
| **Facility Manager** | Administrative lead with full administrative oversight of all spaces, facilities, and personnel. | <ul><li>Configure spaces, facilities, and policies.</li><li>Review, approve, or reject high-priority or standard booking requests.</li><li>Assign facility staff to maintenance tasks.</li><li>Full access to booking history, maintenance logs, utilization reports, and system configuration.</li></ul> |

---

## 3. Entities

The following candidate entities have been identified based on the business requirements. Each entity is justified by direct references to the requirement description.

1. **User**
   - *Description:* Represents any individual with a university account who interacts with the system.
   - *Justification:* Necessary to store basic user details, roles, and status, and to identify booking requesters, approvers, check-in staff, maintenance reporters, and assigned technicians. (Requirement: "Each user must have a university account. The system stores basic user information...")
2. **Space**
   - *Description:* Represents a physical physical room managed by the School of Computer Science.
   - *Justification:* The core resource being managed and booked. The database must track space details, capacities, current statuses, and specific usage policies. (Requirement: "The School manages many bookable spaces. For each space, the system stores a unique space code...")
3. **Facility**
   - *Description:* A master catalog of standard equipment or items that can be equipped inside campus spaces.
   - *Justification:* Necessary to represent standard available facility items (such as projectors, whiteboards, microphones, etc.) to catalog what items can be tracked in the rooms. (Requirement: "Each space may have several facilities, such as a projector... The system should store the list of facilities...")
4. **SpaceFacility** (Associative Entity)
   - *Description:* Represents the specific quantity and condition of a standard facility catalog item within a particular bookable space.
   - *Justification:* Bridges Spaces and Facilities in a many-to-many relationship, tracking how many of a specific equipment type are present in a space and their operational condition. (Requirement: "The system should store the list of facilities available in each space.")
5. **Booking**
   - *Description:* Represents a reservation request submitted by a user for a physical space over a requested time slot.
   - *Justification:* Needed to track the request metadata, proposed timing, purposes, expected participants, and the entire approval/rejection decision details. (Requirement: "Users can submit booking requests... Each booking request has a status... records the staff member who made the decision, the decision time, and a decision note.")
6. **UsageSession**
   - *Description:* Represents the actual physical usage of a booked space, tracked by facility staff at check-in and checkout.
   - *Justification:* Distinct from a Booking request, this tracks real-world check-in/out timestamps, staff verifiers, and room conditions at arrival and departure. (Requirement: "When the requester arrives, facility staff can check in the booking... record actual start/end time, initial/final condition...")
7. **MaintenanceRecord**
   - *Description:* Tracks reported problems, repairs, and scheduled downtime for specific physical spaces.
   - *Justification:* Required to log maintenance tasks, identify reporters and assigned staff, describe problems, track repair duration, and enforce the rule that spaces under maintenance cannot be booked. (Requirement: "The system also supports basic maintenance management... Each maintenance record stores the related space, reporter, assigned staff member...")

---

## 4. Attributes

The attributes for each identified entity are listed below, grouped by Primary Key (PK), descriptive attributes, and candidate identifiers.

### 4.1. `User` Entity
| Attribute Name | Category | Data Type | Candidate Identifier | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `user_id` | PK / Identifier | VARCHAR(50) | Yes (Primary) | Unique university account identifier. |
| `email` | Descriptive | VARCHAR(150) | Yes (Alternate) | Unique university email address. |
| `full_name` | Descriptive | VARCHAR(150) | No | User's full name. |
| `phone_number` | Descriptive | VARCHAR(20) | No | Contact phone number. Nullable. |
| `role` | Descriptive | VARCHAR(50) | No | Restricted to: 'Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager'. |
| `department` | Descriptive | VARCHAR(100) | No | Associated department within the university. |
| `account_status` | Descriptive | VARCHAR(20) | No | Restricted to: 'Active', 'Suspended', 'Inactive'. |

### 4.2. `Space` Entity
| Attribute Name | Category | Data Type | Candidate Identifier | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `space_code` | PK / Identifier | VARCHAR(50) | Yes (Primary) | Unique identifier for the room (e.g., 'B1-F3-R305'). |
| `space_name` | Descriptive | VARCHAR(100) | No | Friendly name of the space. |
| `space_type` | Descriptive | VARCHAR(50) | No | Restricted to: 'Auditorium', 'Classroom', 'Computer Laboratory', 'Project Laboratory', 'Meeting Room', 'Student Workspace'. |
| `building` | Descriptive | VARCHAR(50) | No | Campus building name or code. |
| `floor` | Descriptive | INT | No | Floor number where the space is located. |
| `room_number` | Descriptive | VARCHAR(20) | No | Physical room number. |
| `capacity` | Descriptive | INT | No | Must be positive (> 0). Maximum allowed occupancy. |
| `current_status` | Descriptive | VARCHAR(20) | No | Restricted to: 'Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired'. |
| `usage_policy` | Descriptive | TEXT | No | Policy rules and priority guidelines for this space. |

### 4.3. `Facility` Entity
| Attribute Name | Category | Data Type | Candidate Identifier | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `facility_id` | PK / Identifier | INT (Identity) | Yes (Primary) | Auto-incrementing identifier. |
| `facility_name` | Descriptive | VARCHAR(100) | Yes (Alternate) | Unique name (e.g., 'Projector', 'Whiteboard', 'Microphone'). |
| `facility_description` | Descriptive | TEXT | No | General specifications or notes. |

### 4.4. `SpaceFacility` Entity
| Attribute Name | Category | Data Type | Candidate Identifier | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `space_code` | PK / FK | VARCHAR(50) | Yes (Composite) | Reference to `Space`. |
| `facility_id` | PK / FK | INT | Yes (Composite) | Reference to `Facility`. |
| `quantity` | Descriptive | INT | No | Count of this facility in the room. Must be > 0. |
| `operational_status` | Descriptive | VARCHAR(20) | No | Restricted to: 'Operational', 'Faulty', 'Missing'. |

### 4.5. `Booking` Entity
| Attribute Name | Category | Data Type | Candidate Identifier | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `booking_id` | PK / Identifier | INT (Identity) | Yes (Primary) | Auto-incrementing identifier. |
| `space_code` | FK | VARCHAR(50) | No | Reference to `Space`. |
| `requester_id` | FK | VARCHAR(50) | No | Reference to `User` (requester). |
| `requested_start` | Descriptive | DATETIME | No | Requested start timestamp. |
| `requested_end` | Descriptive | DATETIME | No | Requested end timestamp (must be > `requested_start`). |
| `purpose` | Descriptive | VARCHAR(100) | No | Restricted to: 'Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event'. |
| `expected_participants`| Descriptive | INT | No | Projected attendee count (must be > 0). |
| `booking_status` | Descriptive | VARCHAR(30) | No | Restricted to: 'Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-Show'. |
| `created_at` | Descriptive | DATETIME | No | Default: Current database time (`GETDATE()`). |
| `approver_id` | FK | VARCHAR(50) | No | Reference to `User` (approving staff/manager). Nullable. |
| `decision_time` | Descriptive | DATETIME | No | Time decision was made. Nullable. |
| `decision_note` | Descriptive | TEXT | No | Staff decision notes. Nullable. |
| `rejection_reason` | Descriptive | VARCHAR(255) | No | Populated if `booking_status` = 'Rejected'. Nullable. |

### 4.6. `UsageSession` Entity
| Attribute Name | Category | Data Type | Candidate Identifier | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `booking_id` | PK / FK | INT | Yes (Primary) | Reference to `Booking`. Establishes 1-to-1 mapping. |
| `check_in_staff_id` | FK | VARCHAR(50) | No | Reference to `User` (staff checking in). |
| `actual_start` | Descriptive | DATETIME | No | Physical start timestamp at check-in. Nullable|
| `initial_condition` | Descriptive | TEXT | No | Room state at arrival. Nullable |
| `actual_end` | Descriptive | DATETIME | No | Physical exit timestamp at checkout. Nullable. |
| `final_condition` | Descriptive | TEXT | No | Room state at departure. Nullable. |
| `usage_notes` | Descriptive | TEXT | No | Post-session notes or remarks. Nullable. |

### 4.7. `MaintenanceRecord` Entity
| Attribute Name | Category | Data Type | Candidate Identifier | Description / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `maintenance_id` | PK / Identifier | INT (Identity) | Yes (Primary) | Auto-incrementing identifier. |
| `space_code` | FK | VARCHAR(50) | No | Reference to `Space`. |
| `reporter_id` | FK | VARCHAR(50) | No | Reference to `User` who reported the issue. |
| `assigned_staff_id` | FK | VARCHAR(50) | No | Reference to `User` (facility staff technician). Nullable. |
| `problem_description` | Descriptive | TEXT | No | Details about the issue. |
| `start_time` | Descriptive | DATETIME | No | Maintenance beginning timestamp. |
| `completion_time` | Descriptive | DATETIME | No | Maintenance completion timestamp (must be > `start_time`). Nullable. |
| `maintenance_status` | Descriptive | VARCHAR(20) | No | Restricted to: 'Reported', 'In Progress', 'Resolved', 'Cancelled'. |
| `result_note` | Descriptive | TEXT | No | Summary of repairs or outcomes. Nullable. |

---

## 5. Relationships

The relationships established between entities are detailed below.

1. **User Submits Booking (`User_Requests_Booking`)**
   - *Participating Entities:* `User` (1) and `Booking` (0..N)
   - *Business Meaning:* A university user submits booking requests. Each booking request belongs to exactly one requesting user.
2. **User Approves Booking (`User_Approves_Booking`)**
   - *Participating Entities:* `User` (0..1) and `Booking` (0..N)
   - *Business Meaning:* A booking request is reviewed and approved/rejected by a staff member or manager (approver). A booking has at most one approver. A staff member or manager can approve multiple bookings.
3. **Space Hosts Booking (`Space_Hosts_Booking`)**
   - *Participating Entities:* `Space` (1) and `Booking` (0..N)
   - *Business Meaning:* A physical space is reserved for multiple scheduled bookings. Each booking request is for exactly one physical space.
4. **Space Contains Facility Mapping (`Space_Has_SpaceFacilities`)**
   - *Participating Entities:* `Space` (1) and `SpaceFacility` (0..N)
   - *Business Meaning:* A physical space is linked to its inventory of equipment. Each inventory record is associated with exactly one space.
5. **Facility Catalog Mapped to Space (`Facility_Has_SpaceFacilities`)**
   - *Participating Entities:* `Facility` (1) and `SpaceFacility` (0..N)
   - *Business Meaning:* A cataloged item (e.g., 'Projector') can be present in multiple spaces. Each inventory record links to exactly one cataloged item.
6. **Booking Tracked by Usage Session (`Booking_Has_UsageSession`)**
   - *Participating Entities:* `Booking` (1) and `UsageSession` (0..1)
   - *Business Meaning:* An approved booking has at most one physical usage session tracking actual entry and exit. A usage session corresponds to exactly one specific booking request.
7. **User Checks In Usage Session (`User_ChecksIn_UsageSession`)**
   - *Participating Entities:* `User` (1) and `UsageSession` (0..N)
   - *Business Meaning:* Facility staff physically check in and complete the usage session. Each usage session must have a checking-in staff member.
8. **Space Requires Maintenance (`Space_Requires_Maintenance`)**
   - *Participating Entities:* `Space` (1) and `MaintenanceRecord` (0..N)
   - *Business Meaning:* A space can undergo multiple maintenance procedures. Each maintenance record refers to exactly one physical space.
9. **User Reports Maintenance (`User_Reports_Maintenance`)**
   - *Participating Entities:* `User` (1) and `MaintenanceRecord` (0..N)
   - *Business Meaning:* Any user can report physical space problems. Each maintenance record is reported by exactly one user.
10. **User Assigned to Maintenance (`User_Assigned_To_Maintenance`)**
    - *Participating Entities:* `User` (0..1) and `MaintenanceRecord` (0..N)
    - *Business Meaning:* A maintenance record can be assigned to a specific facility staff member (technician). A staff member can be assigned to multiple maintenance records.

---

## 6. Cardinalities

The cardinality and participation constraints for each relationship are justified below.

### 6.1. `User` to `Booking` (Requester) — **1 : 0..N**
- **Justification:** A user (such as a newly registered student) may have submitted 0 booking requests, or can submit many (N) bookings over time. Every booking record *must* be requested by exactly 1 user (`requester_id` is mandatory). Participation is optional on the User side and mandatory on the Booking side.

### 6.2. `User` to `Booking` (Approver) — **0..1 : 0..N**
- **Justification:** A booking in the `'Pending'` state does not have an approver yet (0). Once processed, it is reviewed by exactly 1 staff member or manager. A facility staff member or manager can approve 0 or many bookings. Participation is optional on both sides (`approver_id` is nullable).

### 6.3. `Space` to `Booking` — **1 : 0..N**
- **Justification:** A physical space (e.g., a newly configured classroom) can have 0 bookings initially, or can host many (N) bookings. Every booking request must specify exactly 1 physical space (`space_code` is mandatory). Participation is optional on the Space side and mandatory on the Booking side.

### 6.4. `Space` to `Facility` (via `SpaceFacility`) — **M : N**
- **Justification:** A space can contain multiple facilities, and a specific facility catalog type can be equipped in multiple spaces. This is implemented via the associative entity `SpaceFacility`.
  - `Space` to `SpaceFacility` is **1 : 0..N** (A space has 0 or more physical facility instances mapped; each bridge row links to exactly 1 space).
  - `Facility` to `SpaceFacility` is **1 : 0..N** (A facility catalog item can be mapped to 0 or more rooms; each bridge row links to exactly 1 facility type).

### 6.5. `Booking` to `UsageSession` — **1 : 0..1**
- **Justification:** A booking request in `'Pending'`, `'Rejected'`, or `'Cancelled'` states will have 0 actual usage sessions. If approved and checked in, it will have exactly 1 usage session. A usage session cannot exist without a valid booking. Therefore, participation is optional on the Booking side, and mandatory on the UsageSession side. This represents a 1-to-1 relationship with the primary key `booking_id` as a foreign key.

### 6.6. `User` to `UsageSession` (Staff) — **1 : 0..N**
- **Justification:** A facility staff member can check in or check out 0 or many actual usage sessions. Every usage session must be physically checked in by exactly 1 staff member (`check_in_staff_id` is mandatory). Participation is optional on the User side and mandatory on the UsageSession side.

### 6.7. `Space` to `MaintenanceRecord` — **1 : 0..N**
- **Justification:** A physical space may have had 0 maintenance activities, or can have many (N) reported problems over its lifespan. Each maintenance record must belong to exactly 1 space (`space_code` is mandatory). Participation is optional on the Space side and mandatory on the Maintenance Record side.

### 6.8. `User` to `MaintenanceRecord` (Reporter) — **1 : 0..N**
- **Justification:** A user (student, lecturer, or staff) can report 0 or many maintenance issues. Every maintenance record must be submitted by exactly 1 reporting user (`reporter_id` is mandatory). Participation is optional on the User side and mandatory on the Maintenance Record side.

### 6.9. `User` to `MaintenanceRecord` (Assigned Staff) — **0..1 : 0..N**
- **Justification:** When a problem is newly reported, it might not be assigned to a technician immediately (0). Once assigned, it is handled by exactly 1 facility staff member. A technician can be assigned to 0 or many maintenance records. Participation is optional on both sides (`assigned_staff_id` is nullable).

---

## 7. Business Rules

The following explicit business rules are derived directly from the requirement text.

1. **Mandatory Account Rule:** Every system user must have a valid university account.
   - *Requirement Text:* "Each user must have a university account." (line 10)
2. **Standard User Information:** The system must record unique user IDs, names, emails, phones, roles, departments, and account status.
   - *Requirement Text:* "The system stores basic user information, including user ID, full name, email, phone number, role, department, and account status." (line 10)
3. **User Roles:** The user roles are constrained to a predefined set.
   - *Requirement Text:* "A user may be a student, lecturer, teaching assistant, facility staff, department administrator, or facility manager." (line 10)
4. **Space Unique Code:** Each bookable room must have a unique identifier.
   - *Requirement Text:* "For each space, the system stores a unique space code..." (line 11)
5. **Space Attributes:** The system must store name, type, building, floor, room number, capacity, current status, and usage policy for every space.
   - *Requirement Text:* "For each space, the system stores a unique space code, space name, space type, building, floor, room number, capacity, current status, and usage policy." (line 11)
6. **Space Statuses:** The space status must belong to a predefined set.
   - *Requirement Text:* "A space may be available, in use, under maintenance, temporarily closed, or retired." (line 11)
7. **Facilities Catalog and Mapping:** Standard facilities must be tracked inside bookable spaces.
   - *Requirement Text:* "Each space may have several facilities, such as a projector... The system should store the list of facilities available in each space." (line 12)
8. **Booking Submission Requirements:** Booking requests require selecting a space, start/end times, purpose, and participant counts.
   - *Requirement Text:* "Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants." (line 13)
9. **Booking Purposes:** Booking purpose must belong to a predefined list.
   - *Requirement Text:* "A booking may be for a lecture, examination, seminar, workshop, meeting, student activity, or administrative event." (line 13)
10. **Booking Status List:** Booking statuses must belong to a predefined set.
    - *Requirement Text:* "Each booking request has a status, such as pending, approved, rejected, cancelled, checked in, completed, or no-show." (line 14)
11. **Double Booking Prevention:** Overlapping approved bookings for the same space are strictly forbidden.
    - *Requirement Text:* "The system must prevent conflicting bookings. The same space cannot have two approved bookings with overlapping time periods." (line 14)
12. **Unavailable Spaces Blocked:** Bookings cannot be approved for unavailable, closed, or retired rooms.
    - *Requirement Text:* "A space that is under maintenance, closed, or retired cannot be booked." (line 14)
13. **Approval Tracking:** Decisions on booking approvals must record the staff/manager who decided, decision time, and feedback notes.
    - *Requirement Text:* "When a booking is approved or rejected, the system records the staff member who made the decision, the decision time, and a decision note." (line 15)
14. **Rejection Justification:** Rejected bookings must store the specific reason.
    - *Requirement Text:* "If the booking is rejected, the rejection reason should be stored." (line 15)
15. **Usage Session Check-in:** Arrival of requesters must log actual start time, check-in staff, and starting room condition.
    - *Requirement Text:* "When the requester arrives, facility staff can check in the booking. The system records the actual start time, the person who checked in the booking, and the initial condition of the space." (line 16)
16. **Usage Session Completion:** Ending a session must log actual end time, final room condition, and usage notes.
    - *Requirement Text:* "When the session ends, facility staff can complete the booking by recording the actual end time, the final condition of the space, and any usage notes." (line 16)
17. **Maintenance Logging:** Maintenance records must track the related space, reporter, assigned staff, description, start, end, status, and result notes.
    - *Requirement Text:* "Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note." (line 17)
18. **Maintenance Booking Block:** A space currently under maintenance cannot accept bookings.
    - *Requirement Text:* "A space under maintenance cannot be booked." (line 17)
19. **Historical and Operational Reports:** The system must preserve logs and support viewing booking history, upcoming events, active maintenance, and no-show counts.
    - *Requirement Text:* "The system should keep historical records of bookings and maintenance activities. Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings." (line 18)

---

## 8. Assumptions

The following operational and data design assumptions are defined to supplement the requirements.

1. **Role-Based Booking Permission:** Only users with roles `Facility Staff` or `Facility Manager` can review/decide bookings, check in users, complete sessions, or be assigned to maintenance records.
2. **Overlap Definition (Interval Intersection):** Two booking periods overlap if and only if:
   `BookingA.RequestedStart < BookingB.RequestedEnd AND BookingA.RequestedEnd > BookingB.RequestedStart`
3. **Check-in/No-Show Window:** Requesters are expected to check in within a reasonable time window (e.g., within 30 minutes of `RequestedStart`). If they do not, facility staff can change the booking status to `'No-Show'`.
4. **Maintenance Blocking Mechanics:** If a space has an active/approved maintenance record, its status should be set to `'Under Maintenance'`, and no new booking requests can overlap with that maintenance timeframe.
5. **Soft Deletion Policy:** To preserve historical booking and maintenance records, rows in `User` and `Space` are never physically deleted. Instead, they are soft-deleted by setting `User.account_status = 'Inactive'` and `Space.current_status = 'Retired'`.
6. **Time Order Constraint:** Booking requested start must be strictly before requested end (`requested_end > requested_start`). Similarly, actual start must be strictly before actual end, and maintenance start must be before completion.
7. **Capacity Enforcements:** Expected participant count for a booking should not exceed the physical capacity of the selected space (`expected_participants <= Space.capacity`).

---

## 9. Open Questions

The following questions represent design ambiguities that would be clarified with stakeholders:

1. **Recurring Booking Support:** Does the database need to support recurring bookings (e.g., weekly lectures for an entire semester)?
   - *Working Assumption:* No. Recurring bookings are handled at the application layer by generating multiple individual booking rows.
2. **Priority Overrides:** Can a Facility Manager or Lecturer override/cancel an existing student booking if they need a space?
   - *Working Assumption:* Yes, but this is executed by manually cancelling the existing booking (and notifying the student) and creating a new booking request.
3. **No-Show Threshold:** Is there an automatic timeout where a booking is marked as `'No-Show'` if a user fails to check in (e.g., 30 minutes after start)?
   - *Working Assumption:* Checked in manually by facility staff, or processed by an application-level cron job based on the assumed check-in window.
4. **Independent Equipment Booking:** Can facilities/equipment (like a microphone or laptop) be booked separately from a space?
   - *Working Assumption:* No. Equipment is booked implicitly as part of the room containing it.
