# Logical Database Design — Campus Space Management System

---

## 1. Relational Schema Mapping Decisions

This logical database design translates the conceptual model (ERD) into a set of relational tables optimized for Microsoft SQL Server. The mapping decisions are outlined below:

* **Table and Column Naming Conventions**: Table names are in UPPERCASE singular (e.g., `USER`, `SPACE`, `BOOKING`, `USAGESESSION`, `MAINTENANCERECORD`), matching the entity declarations in the ERD. Columns are named in lowercase `snake_case`, matching the ERD attributes verbatim.
* **Many-to-Many (M:N) Relationship Resolution**: The M:N relationship `Space_Equipped_With_Facility` between `SPACE` and `FACILITY` is resolved by introducing an associative (junction) table named `SPACE_FACILITY`. To ensure entity integrity and prevent duplicate assignments, it uses a composite primary key consisting of `(space_code, facility_id)`.
* **One-to-One (1:1) Relationship Mapping**: The 1:1 relationship `Booking_Has_UsageSession` between `BOOKING` and `USAGESESSION` is mapped by designating `booking_id` as the primary key of the `USAGESESSION` table. This `booking_id` also acts as a foreign key referencing `BOOKING(booking_id)`. This enforces that a booking has at most one usage session, and a usage session cannot exist without a booking.
* **Referential Integrity Actions (ON DELETE/ON UPDATE)**:
  - For the 1:1 relationship between `USAGESESSION` and `BOOKING`, `ON DELETE CASCADE` and `ON UPDATE CASCADE` are specified. If a booking request is deleted, its actual usage logs are deleted in tandem.
  - For the junction table `SPACE_FACILITY`, `ON DELETE CASCADE` is set for foreign keys referencing both `SPACE` and `FACILITY`. This prevents orphaned rows in the junction table.
  - For all other tables referencing `USER` or `SPACE` (such as `BOOKING`, `USAGESESSION`, and `MAINTENANCERECORD`), `ON DELETE NO ACTION` and `ON UPDATE NO ACTION` are defined. This prevents deletion of users or spaces that have associated historical booking or maintenance logs, thereby protecting data auditability.
* **No Redundant Visual Diagrams**: In alignment with the project instructions, graphical schema diagrams are omitted from this document as the structural relationships have been fully conceptualized and validated in the preceding Step 2 ERD.

---

## 2. Table Schema Specifications

### 2.1. Table: USER
Represents any individual with a university account who interacts with the system.

| Column Name | SQL Server Data Type | Nullability | Key | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `user_id` | `VARCHAR(50)` | NOT NULL | PK | PRIMARY KEY | Unique university account identifier. |
| `email` | `VARCHAR(150)` | NOT NULL | - | UNIQUE | Unique university email address. |
| `full_name` | `VARCHAR(150)` | NOT NULL | - | - | User's full name. |
| `phone_number` | `VARCHAR(20)` | NULL | - | - | Contact phone number. |
| `role` | `VARCHAR(50)` | NOT NULL | - | CHECK | User role constraint (Student, Lecturer, TA, Staff, etc.). |
| `department` | `VARCHAR(100)` | NOT NULL | - | - | Associated department within the university. |
| `account_status` | `VARCHAR(20)` | NOT NULL | - | CHECK | Account status constraint (Active, Suspended, Inactive). |

### 2.2. Table: SPACE
Represents a physical room managed by the School of Computer Science.

| Column Name | SQL Server Data Type | Nullability | Key | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `space_code` | `VARCHAR(50)` | NOT NULL | PK | PRIMARY KEY | Unique room identifier (e.g., 'B1-F3-R305'). |
| `space_name` | `VARCHAR(100)` | NOT NULL | - | - | Friendly name of the space. |
| `space_type` | `VARCHAR(50)` | NOT NULL | - | CHECK | Space type constraint (Classroom, Lab, Auditorium, etc.). |
| `building` | `VARCHAR(50)` | NOT NULL | - | - | Campus building name or code. |
| `floor` | `VARCHAR(10)` | NOT NULL | - | - | Floor number where the space is located. |
| `room_number` | `VARCHAR(20)` | NOT NULL | - | - | Physical room number. |
| `capacity` | `INT` | NOT NULL | - | CHECK | Maximum occupancy (must be > 0). |
| `current_status` | `VARCHAR(20)` | NOT NULL | - | CHECK | Current space status constraint (Available, In Use, etc.). |
| `usage_policy` | `NVARCHAR(MAX)` | NOT NULL | - | - | Policy rules and priority guidelines for this space. |

### 2.3. Table: FACILITY
A master catalog of equipment or items that can be equipped inside campus spaces.

| Column Name | SQL Server Data Type | Nullability | Key | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `facility_id` | `INT` | NOT NULL | PK | PRIMARY KEY | Unique auto-incrementing identifier. |
| `facility_name` | `VARCHAR(100)` | NOT NULL | - | UNIQUE | Unique descriptive name (e.g., 'Projector'). |
| `facility_description` | `NVARCHAR(MAX)` | NULL | - | - | Technical specifications or notes. |

### 2.4. Table: SPACE_FACILITY
Associative table resolving the M:N relationship between `SPACE` and `FACILITY`.

| Column Name | SQL Server Data Type | Nullability | Key | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `space_code` | `VARCHAR(50)` | NOT NULL | PK, FK | FK references `SPACE(space_code)` | Reference to the physical space. |
| `facility_id` | `INT` | NOT NULL | PK, FK | FK references `FACILITY(facility_id)` | Reference to the facility item. |

### 2.5. Table: BOOKING
Represents a space reservation request submitted by a user.

| Column Name | SQL Server Data Type | Nullability | Key | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `booking_id` | `INT` | NOT NULL | PK | PRIMARY KEY | Unique auto-incrementing identifier. |
| `space_code` | `VARCHAR(50)` | NOT NULL | FK | FK references `SPACE(space_code)` | The space being requested. |
| `requester_id` | `VARCHAR(50)` | NOT NULL | FK | FK references `USER(user_id)` | The user submitting the request. |
| `requested_start` | `DATETIME` | NOT NULL | - | - | Requested start timestamp. |
| `requested_end` | `DATETIME` | NOT NULL | - | CHECK | Requested end timestamp (must be > start). |
| `purpose` | `VARCHAR(100)` | NOT NULL | - | CHECK | Purpose of use constraint (Lecture, Meeting, Exam, etc.). |
| `expected_participants`| `INT` | NOT NULL | - | CHECK | Projected attendee count (must be > 0). |
| `booking_status` | `VARCHAR(30)` | NOT NULL | - | CHECK | Request processing status (Pending, Approved, Rejected, etc.). |
| `created_at` | `DATETIME` | NOT NULL | - | DEFAULT | Time request was created. Defaults to `GETDATE()`. |
| `approver_id` | `VARCHAR(50)` | NULL | FK | FK references `USER(user_id)` | Staff or manager who decided. Nullable. |
| `decision_time` | `DATETIME` | NULL | - | - | Time decision was recorded. Nullable. |
| `decision_note` | `NVARCHAR(MAX)` | NULL | - | - | Staff review notes. Nullable. |
| `rejection_reason` | `VARCHAR(255)` | NULL | - | - | Explanation of rejection. Nullable. |

### 2.6. Table: USAGESESSION
Tracks actual check-in and checkout details for approved bookings.

| Column Name | SQL Server Data Type | Nullability | Key | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `booking_id` | `INT` | NOT NULL | PK, FK | FK references `BOOKING(booking_id)` | Reference to the associated booking request. |
| `check_in_staff_id` | `VARCHAR(50)` | NOT NULL | FK | FK references `USER(user_id)` | Staff member who checked in the user. |
| `actual_start` | `DATETIME` | NOT NULL | - | - | Actual check-in timestamp. |
| `initial_condition` | `NVARCHAR(MAX)` | NOT NULL | - | - | Room physical state at check-in. |
| `check_out_staff_id` | `VARCHAR(50)` | NULL | FK | FK references `USER(user_id)` | Staff member who checked out the user. |
| `actual_end` | `DATETIME` | NULL | - | CHECK | Actual checkout timestamp (must be > start). |
| `final_condition` | `NVARCHAR(MAX)` | NULL | - | - | Room physical state at checkout. |
| `usage_notes` | `NVARCHAR(MAX)` | NULL | - | - | Post-session notes or remarks. |

### 2.7. Table: MAINTENANCERECORD
Logs reported issues, scheduled downtime, and repair tasks for physical spaces.

| Column Name | SQL Server Data Type | Nullability | Key | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `maintenance_id` | `INT` | NOT NULL | PK | PRIMARY KEY | Unique auto-incrementing identifier. |
| `space_code` | `VARCHAR(50)` | NOT NULL | FK | FK references `SPACE(space_code)` | Space undergoing maintenance. |
| `reporter_id` | `VARCHAR(50)` | NOT NULL | FK | FK references `USER(user_id)` | User who reported the problem. |
| `assigned_staff_id` | `VARCHAR(50)` | NULL | FK | FK references `USER(user_id)` | Staff technician assigned to resolve. Nullable. |
| `problem_type` | `VARCHAR(50)` | NOT NULL | - | CHECK | Problem type constraint (Projector Failure, etc.). |
| `problem_description` | `NVARCHAR(MAX)` | NOT NULL | - | - | Free-text details of the issue. |
| `start_time` | `DATETIME` | NOT NULL | - | - | Timestamp when maintenance started. |
| `completion_time` | `DATETIME` | NULL | - | CHECK | Timestamp when maintenance resolved (must be > start). |
| `maintenance_status` | `VARCHAR(20)` | NOT NULL | - | CHECK | Maintenance stage constraint (Reported, Resolved, etc.). |
| `result_note` | `NVARCHAR(MAX)` | NULL | - | - | Summary of repairs or outcomes. Nullable. |

---

## 3. Check and Constraint Specifications

The following SQL Server-compatible constraint declarations enforce domain validity and business rules at the database level:

```sql
-- 1. USER Table Constraints
ALTER TABLE USER ADD CONSTRAINT UQ_USER_EMAIL UNIQUE (email);

ALTER TABLE USER ADD CONSTRAINT CK_USER_ROLE CHECK (
    role IN ('Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager')
);

ALTER TABLE USER ADD CONSTRAINT CK_USER_ACCOUNT_STATUS CHECK (
    account_status IN ('Active', 'Suspended', 'Inactive')
);

-- 2. SPACE Table Constraints
ALTER TABLE SPACE ADD CONSTRAINT CK_SPACE_TYPE CHECK (
    space_type IN ('Auditorium', 'Classroom', 'Computer Laboratory', 'Project Laboratory', 'Meeting Room', 'Student Workspace')
);

ALTER TABLE SPACE ADD CONSTRAINT CK_SPACE_CAPACITY CHECK (capacity > 0);

ALTER TABLE SPACE ADD CONSTRAINT CK_SPACE_CURRENT_STATUS CHECK (
    current_status IN ('Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired')
);

-- 3. FACILITY Table Constraints
ALTER TABLE FACILITY ADD CONSTRAINT UQ_FACILITY_NAME UNIQUE (facility_name);

-- 4. BOOKING Table Constraints
ALTER TABLE BOOKING ADD CONSTRAINT DF_BOOKING_CREATED_AT DEFAULT GETDATE() FOR created_at;

ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_TIME_ORDER CHECK (requested_end > requested_start);

ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_PARTICIPANTS CHECK (expected_participants > 0);

ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_PURPOSE CHECK (
    purpose IN ('Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event')
);

ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_STATUS CHECK (
    booking_status IN ('Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-Show')
);

-- 5. USAGESESSION Table Constraints
ALTER TABLE USAGESESSION ADD CONSTRAINT CK_USAGE_TIME_ORDER CHECK (actual_end > actual_start);

-- 6. MAINTENANCERECORD Table Constraints
ALTER TABLE MAINTENANCERECORD ADD CONSTRAINT CK_MAINTENANCE_TIME_ORDER CHECK (completion_time > start_time);

ALTER TABLE MAINTENANCERECORD ADD CONSTRAINT CK_MAINTENANCE_STATUS CHECK (
    maintenance_status IN ('Reported', 'In Progress', 'Resolved', 'Cancelled')
);

ALTER TABLE MAINTENANCERECORD ADD CONSTRAINT CK_MAINTENANCE_PROBLEM_TYPE CHECK (
    problem_type IN ('Projector Failure', 'Air-Conditioning Issue', 'Cleaning Issue', 'Furniture Damage', 'Network Issue', 'Other')
);
```

---

## 4. Normalization Assessment (3NF Verification)

### 4.1. Table: USER
- **1NF**: Every cell contains atomic values. Column data types are standardized, and there are no repeating groups.
- **2NF**: The primary key is a single column (`user_id`). Therefore, partial dependencies are mathematically impossible; all non-key columns (`email`, `full_name`, `phone_number`, `role`, `department`, `account_status`) are fully dependent on `user_id`.
- **3NF**: There are no transitive dependencies. While `role` or `department` describe attributes of a user, they do not determine any other non-key attributes (e.g., knowing a user's department does not determine their name or email). All non-key attributes depend solely and directly on `user_id`.

### 4.2. Table: SPACE
- **1NF**: All columns contain atomic attributes. There are no multi-valued attributes or repeating groups.
- **2NF**: The primary key is single-column (`space_code`). No partial dependencies exist. All columns (`space_name`, `space_type`, `building`, `floor`, `room_number`, `capacity`, `current_status`, `usage_policy`) are fully dependent on the PK.
- **3NF**: There are no transitive dependencies. For instance, `capacity` or `current_status` depend directly on `space_code`. While `building` and `floor` are geographic attributes, they are descriptive properties of the room and do not determine other columns like `capacity` or `usage_policy`. All attributes are non-transitively dependent on the PK.

### 4.3. Table: FACILITY
- **1NF**: All fields are atomic (e.g., names are plain strings and descriptions are texts).
- **2NF**: Single-column PK (`facility_id`). No partial dependencies are possible.
- **3NF**: The only non-key columns are `facility_name` (which is unique) and `facility_description`. Neither column determines the other, and both depend directly on `facility_id`. No transitive dependencies exist.

### 4.4. Table: SPACE_FACILITY
- **1NF**: The table structures a binary relationship mapping. All values are atomic.
- **2NF**: The PK is composite: `(space_code, facility_id)`. There are no non-key columns in this table (both columns are parts of the PK). Thus, partial dependencies cannot exist.
- **3NF**: Since there are no non-key columns, transitive dependencies are impossible. The table is automatically in 3NF.

### 4.5. Table: BOOKING
- **1NF**: All attributes (dates, integers, status strings) are atomic.
- **2NF**: The PK is a single auto-incrementing integer `booking_id`. All non-key columns (`space_code`, `requester_id`, `requested_start`, `requested_end`, `purpose`, `expected_participants`, `booking_status`, `created_at`, `approver_id`, `decision_time`, `decision_note`, `rejection_reason`) are fully functionally dependent on `booking_id`.
- **3NF**: There are no transitive dependencies between non-key fields. For example, `approver_id` (representing the staff member) and `rejection_reason` depend directly on `booking_id` (the booking request). Although `rejection_reason` is only populated when `booking_status` = 'Rejected', this is a conditional business rule validation, not a functional dependency (a status of 'Rejected' does not determine the specific rejection text itself). All non-key columns depend only on the PK.

### 4.6. Table: USAGESESSION
- **1NF**: All timestamps, conditions, and notes are atomic.
- **2NF**: The primary key is `booking_id`. Because the PK is a single column, no partial dependencies exist. All attributes depend fully on `booking_id`.
- **3NF**: All columns (`check_in_staff_id`, `actual_start`, `initial_condition`, `check_out_staff_id`, `actual_end`, `final_condition`, `usage_notes`) depend directly on the booking event (`booking_id`). There is no transitive relationship where one staff member determines the checkout conditions or timestamps. All fields are directly dependent on the PK.

### 4.7. Table: MAINTENANCERECORD
- **1NF**: All columns (descriptions, timestamps, statuses, result notes) are atomic.
- **2NF**: The PK is single-column `maintenance_id`. All non-key fields depend on the entire PK.
- **3NF**: No transitive dependencies exist. The `assigned_staff_id` or `maintenance_status` depend directly on `maintenance_id` (the task record). While `completion_time` is only set when `maintenance_status` = 'Resolved', this is a process flow constraint, not a functional dependency. Every non-key attribute is dependent only on the PK.

---

## 5. Traceability Matrix

This matrix traces each mapped table, column, and constraint back to its source ERD attribute and BRA requirement section:

| Table Name | Column Name | ERD Attribute Source | BRA Requirement Reference | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `USER` | `user_id` | `USER.user_id` | §4.1, §3.1 | Primary Key. Represents university account ID. |
| `USER` | `email` | `USER.email` | §4.1, §3.1 | Alternate candidate key. |
| `USER` | `full_name` | `USER.full_name` | §4.1, §3.1 | Mandatory attribute. |
| `USER` | `phone_number` | `USER.phone_number` | §4.1, §3.1 | Nullable attribute. |
| `USER` | `role` | `USER.role` | §4.1, §3.1 | CHECK constraint checks list of roles. |
| `USER` | `department` | `USER.department` | §4.1, §3.1 | Mandatory attribute. |
| `USER` | `account_status` | `USER.account_status` | §4.1, §3.1 | CHECK constraint checks account status. |
| `SPACE` | `space_code` | `SPACE.space_code` | §4.2, §3.2 | Primary Key. Room identifier. |
| `SPACE` | `space_name` | `SPACE.space_name` | §4.2, §3.2 | Mandatory friendly name. |
| `SPACE` | `space_type` | `SPACE.space_type` | §4.2, §3.2 | CHECK constraint checks space types. |
| `SPACE` | `building` | `SPACE.building` | §4.2, §3.2 | Room location attribute. |
| `SPACE` | `floor` | `SPACE.floor` | §4.2, §3.2 | Room location attribute. |
| `SPACE` | `room_number` | `SPACE.room_number` | §4.2, §3.2 | Room location attribute. |
| `SPACE` | `capacity` | `SPACE.capacity` | §4.2, §3.2 | CHECK constraint enforces capacity > 0. |
| `SPACE` | `current_status` | `SPACE.current_status` | §4.2, §3.2 | CHECK constraint checks current status. |
| `SPACE` | `usage_policy` | `SPACE.usage_policy` | §4.2, §3.2 | Policies text. |
| `FACILITY` | `facility_id` | `FACILITY.facility_id` | §4.3, §3.3 | Primary Key. Auto-increment. |
| `FACILITY` | `facility_name` | `FACILITY.facility_name` | §4.3, §3.3 | Alternate key. UNIQUE constraint. |
| `FACILITY` | `facility_description` | `FACILITY.facility_description`| §4.3, §3.3 | Description of facility. Nullable. |
| `SPACE_FACILITY`| `space_code` | - | §5.4, §6.4 | Composite PK Part 1, FK references SPACE. |
| `SPACE_FACILITY`| `facility_id` | - | §5.4, §6.4 | Composite PK Part 2, FK references FACILITY. |
| `BOOKING` | `booking_id` | `BOOKING.booking_id` | §4.4, §3.4 | Primary Key. Auto-increment. |
| `BOOKING` | `space_code` | `BOOKING.space_code` | §4.4, §3.4 | FK references SPACE. |
| `BOOKING` | `requester_id` | `BOOKING.requester_id` | §4.4, §3.4 | FK references USER. |
| `BOOKING` | `requested_start`| `BOOKING.requested_start` | §4.4, §3.4 | Requested start time. |
| `BOOKING` | `requested_end` | `BOOKING.requested_end` | §4.4, §3.4 | Requested end time. CHECK order constraint. |
| `BOOKING` | `purpose` | `BOOKING.purpose` | §4.4, §3.4 | CHECK constraint checks purpose enums. |
| `BOOKING` | `expected_participants`| `BOOKING.expected_participants`| §4.4, §3.4 | CHECK constraint enforces count > 0. |
| `BOOKING` | `booking_status`| `BOOKING.booking_status` | §4.4, §3.4 | CHECK constraint checks status enums. |
| `BOOKING` | `created_at` | `BOOKING.created_at` | §4.4, §3.4 | DEFAULT constraint `GETDATE()`. |
| `BOOKING` | `approver_id` | `BOOKING.approver_id` | §4.4, §3.4 | FK references USER. Nullable. |
| `BOOKING` | `decision_time` | `BOOKING.decision_time` | §4.4, §3.4 | Nullable decision time. |
| `BOOKING` | `decision_note` | `BOOKING.decision_note` | §4.4, §3.4 | Nullable staff comments. |
| `BOOKING` | `rejection_reason`| `BOOKING.rejection_reason` | §4.4, §3.4 | Nullable rejection explanation. |
| `USAGESESSION` | `booking_id` | `USAGESESSION.booking_id` | §4.5, §3.5 | PK, FK references BOOKING. 1:1 relationship. |
| `USAGESESSION` | `check_in_staff_id`| `USAGESESSION.check_in_staff_id`| §4.5, §3.5 | FK references USER (staff). |
| `USAGESESSION` | `actual_start` | `USAGESESSION.actual_start` | §4.5, §3.5 | Physical start time. |
| `USAGESESSION` | `initial_condition`| `USAGESESSION.initial_condition`| §4.5, §3.5 | Room condition at check-in. |
| `USAGESESSION` | `check_out_staff_id`| `USAGESESSION.check_out_staff_id`| §4.5, §3.5 | FK references USER (staff). Nullable. |
| `USAGESESSION` | `actual_end` | `USAGESESSION.actual_end` | §4.5, §3.5 | Nullable end. CHECK order constraint. |
| `USAGESESSION` | `final_condition`| `USAGESESSION.final_condition`| §4.5, §3.5 | Nullable room condition at exit. |
| `USAGESESSION` | `usage_notes` | `USAGESESSION.usage_notes` | §4.5, §3.5 | Nullable usage session notes. |
| `MAINTENANCERECORD`| `maintenance_id`| `MAINTENANCERECORD.maintenance_id`| §4.6, §3.6 | Primary Key. Auto-increment. |
| `MAINTENANCERECORD`| `space_code` | `MAINTENANCERECORD.space_code` | §4.6, §3.6 | FK references SPACE. |
| `MAINTENANCERECORD`| `reporter_id` | `MAINTENANCERECORD.reporter_id`| §4.6, §3.6 | FK references USER. |
| `MAINTENANCERECORD`| `assigned_staff_id`| `MAINTENANCERECORD.assigned_staff_id`| §4.6, §3.6 | FK references USER. Nullable. |
| `MAINTENANCERECORD`| `problem_type` | `MAINTENANCERECORD.problem_type`| §4.6, §3.6 | CHECK constraint checks problem type enums. |
| `MAINTENANCERECORD`| `problem_description`| `MAINTENANCERECORD.problem_description`| §4.6, §3.6 | Problem details. |
| `MAINTENANCERECORD`| `start_time` | `MAINTENANCERECORD.start_time`| §4.6, §3.6 | Timestamp of maintenance start. |
| `MAINTENANCERECORD`| `completion_time`| `MAINTENANCERECORD.completion_time`| §4.6, §3.6 | Nullable. CHECK completion > start constraint. |
| `MAINTENANCERECORD`| `maintenance_status`| `MAINTENANCERECORD.maintenance_status`| §4.6, §3.6 | CHECK constraint checks status enums. |
| `MAINTENANCERECORD`| `result_note` | `MAINTENANCERECORD.result_note`| §4.6, §3.6 | Nullable outcome notes. |

---

## 6. Assumptions and Open Questions

### 6.1. Design Assumptions
1. **Soft Deletion Integrity**: To preserve historical logs (Requirement §18), users and spaces are never physically deleted. However, to cover database schema logic, mandatory foreign keys use `ON DELETE NO ACTION` to block invalid deletions, and nullable ones default to RESTRICT behavior.
2. **Date Comparison Ordering**: Timestamps (`requested_start`, `requested_end`, `actual_start`, `actual_end`, `start_time`, `completion_time`) are assumed to be stored in standard database timezone formatting, verified by CHECK constraints preventing logical overlaps or negative durations.
3. **Surrogate Key Auto-Incrementation**: `booking_id`, `facility_id`, and `maintenance_id` are designated as auto-incrementing identity values (`INT IDENTITY` in MS SQL Server) in the physical phase to guarantee unique primary keys.

### 6.2. Open Questions
*No open questions remain as naming conventions, junction table keys, and referential behaviors have been explicitly resolved and approved by the stakeholders during the conceptual-to-logical design transition.*
