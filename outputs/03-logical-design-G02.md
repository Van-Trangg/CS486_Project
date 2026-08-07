# Logical Database Design — Campus Space Management System

---

## 1. Relational Schema Mapping Decisions

This logical database design translates the conceptual model (ERD) into a set of relational tables optimized for Microsoft SQL Server. The mapping decisions are outlined below:

* **Table and Column Naming Conventions**: Table names are in UPPERCASE singular (e.g., `USER`, `SPACE`, `BOOKING`, `USAGESESSION`, `MAINTENANCERECORD`), matching the entity declarations in the ERD. Columns are named in lowercase `snake_case`, matching the ERD attributes verbatim.
* **Many-to-Many (M:N) Relationship Resolution**: The M:N relationship `Space_Equipped_With_Facility` (BRA §5.4) between `SPACE` and `FACILITY` is resolved by introducing an associative (junction) table named `SPACE_FACILITY`. To ensure entity integrity and prevent duplicate assignments, it uses a composite primary key consisting of `(space_code, facility_id)`.
* **One-to-One (1:1) Relationship Mapping**: The 1:1 relationship `Booking_Has_UsageSession` between `BOOKING` and `USAGESESSION` is mapped by designating `booking_id` as the primary key of the `USAGESESSION` table. This `booking_id` also acts as a foreign key referencing `BOOKING(booking_id)`. This enforces that a booking has at most one usage session, and a usage session cannot exist without a booking.
* **Referential Integrity Actions (ON DELETE/ON UPDATE)**:
  - For the 1:1 relationship between `USAGESESSION` and `BOOKING`, `ON DELETE NO ACTION` and `ON UPDATE NO ACTION` are specified. If a booking request is deleted, its actual usage logs are protected and cannot be deleted.
  - For the junction table `SPACE_FACILITY`, `ON DELETE CASCADE` is set for foreign keys referencing both `SPACE` and `FACILITY`. This prevents orphaned rows in the junction table.
  - For all other tables referencing `USER` or `SPACE` (such as `BOOKING`, `USAGESESSION`, and `MAINTENANCERECORD`), `ON DELETE NO ACTION` and `ON UPDATE NO ACTION` are defined. This prevents deletion of users or spaces that have associated historical booking or maintenance logs, thereby protecting data auditability.
* **No Redundant Visual Diagrams**: In alignment with the project instructions, graphical schema diagrams are omitted from this document as the structural relationships have been fully conceptualized and validated in the preceding Step 2 ERD.
* **Procedural Enforcement Strategy**: Complex business rules that cannot be expressed through simple CHECK constraints are enforced using database triggers and user-defined functions. This includes overlap prevention (BR-11/12, BR-23), where only bookings currently reserving (`Approved`) or occupying (`Checked In`) a space are considered blocking, while `No-Show`, `Cancelled`, `Rejected`, and `Completed` bookings do not block new requests. `No-Show` bookings remain historically traceable as previously approved reservations but are excluded from active overlap checks. Other enforced rules include future-booking enforcement with role exemptions (BR-20), role-based permission validation (Assumption 1), booking modification locks (BR-22), usage session validation (Assumption 9), and booking cancellation state machine rules (BR-21).

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

*Table-level constraint:* the physical-location triple `(building, floor, room_number)` is unique (`UQ_SPACE_LOCATION`) — no two rooms may share the same building, floor, and room number. This makes the location triple an alternate candidate key alongside the surrogate `space_code`.

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
| `quantity` | `INT` | NOT NULL | - | DEFAULT 1, CHECK > 0 | Total number of units of the facility in this space. |
| `operation_status` | `VARCHAR(30)` | NOT NULL | - | DEFAULT 'Operational', CHECK | Operational status of the facility in this space. |
| `description` | `NVARCHAR(500)` | NULL | - | - | Optional free-text status details or fault logs. |

### 2.5. Table: BOOKING
Represents a space reservation request submitted by a user.

| Column Name | SQL Server Data Type | Nullability | Key | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `booking_id` | `INT` | NOT NULL | PK | PRIMARY KEY | Unique auto-incrementing identifier. |
| `space_code` | `VARCHAR(50)` | NOT NULL | FK | FK references `SPACE(space_code)` | The space being requested. |
| `requester_id` | `VARCHAR(50)` | NOT NULL | FK | FK references `USER(user_id)` | The user submitting the request. |
| `requested_start` | `DATETIME` | NOT NULL | - | CHECK | Requested start timestamp (must be >= created_at). |
| `requested_end` | `DATETIME` | NOT NULL | - | CHECK | Requested end timestamp (must be > start). |
| `purpose` | `VARCHAR(100)` | NOT NULL | - | CHECK | Purpose of use constraint (Lecture, Meeting, Exam, etc.). |
| `expected_participants`| `INT` | NOT NULL | - | CHECK | Projected attendee count (must be > 0 and <= space capacity). |
| `booking_status` | `VARCHAR(30)` | NOT NULL | - | CHECK | Request processing status (Pending, Approved, Rejected, etc.). |
| `created_at` | `DATETIME` | NOT NULL | - | DEFAULT | Time request was created. Defaults to `GETDATE()`. |
| `approver_id` | `VARCHAR(50)` | NULL | FK | FK references `USER(user_id)` | Staff or manager who decided. Nullable. |
| `decision_time` | `DATETIME` | NULL | - | - | Time decision was recorded. Nullable. |
| `decision_note` | `NVARCHAR(MAX)` | NULL | - | - | Staff review notes. Nullable. |
| `rejection_reason` | `VARCHAR(255)` | NULL | - | CHECK | Explanation of rejection (mandatory if status is Rejected). Nullable. |

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

ALTER TABLE SPACE ADD CONSTRAINT UQ_SPACE_LOCATION UNIQUE (building, floor, room_number);

-- 3. FACILITY Table Constraints
ALTER TABLE FACILITY ADD CONSTRAINT UQ_FACILITY_NAME UNIQUE (facility_name);

-- 4. SPACE_FACILITY Table Constraints
ALTER TABLE SPACE_FACILITY ADD CONSTRAINT DF_SPACE_FACILITY_QUANTITY DEFAULT 1 FOR quantity;
ALTER TABLE SPACE_FACILITY ADD CONSTRAINT CK_SPACE_FACILITY_QUANTITY CHECK (quantity > 0);
ALTER TABLE SPACE_FACILITY ADD CONSTRAINT DF_SPACE_FACILITY_STATUS DEFAULT 'Operational' FOR operation_status;
ALTER TABLE SPACE_FACILITY ADD CONSTRAINT CK_SPACE_FACILITY_STATUS CHECK (
    operation_status IN ('Operational', 'Partially Operational', 'Broken')
);

-- 5. BOOKING Table Constraints
ALTER TABLE BOOKING ADD CONSTRAINT DF_BOOKING_CREATED_AT DEFAULT GETDATE() FOR created_at;

ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_TIME_ORDER CHECK (requested_end > requested_start);

ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_PARTICIPANTS CHECK (expected_participants > 0);

ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_PURPOSE CHECK (
    purpose IN ('Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event')
);

ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_STATUS CHECK (
    booking_status IN ('Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-Show')
);

-- Additional BOOKING Check Constraints
ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_FUTURE_START CHECK (requested_start >= created_at);
ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_REJECTION_REASON CHECK (booking_status <> 'Rejected' OR rejection_reason IS NOT NULL);
ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_CAPACITY_LIMIT CHECK (dbo.fn_CheckSpaceCapacity(space_code, expected_participants) = 1);

-- 6. USAGESESSION Table Constraints
ALTER TABLE USAGESESSION ADD CONSTRAINT CK_USAGE_TIME_ORDER CHECK (actual_end > actual_start);

-- 7. MAINTENANCERECORD Table Constraints
ALTER TABLE MAINTENANCERECORD ADD CONSTRAINT CK_MAINTENANCE_TIME_ORDER CHECK (completion_time > start_time);

ALTER TABLE MAINTENANCERECORD ADD CONSTRAINT CK_MAINTENANCE_STATUS CHECK (
    maintenance_status IN ('Reported', 'In Progress', 'Resolved', 'Cancelled')
);

ALTER TABLE MAINTENANCERECORD ADD CONSTRAINT CK_MAINTENANCE_PROBLEM_TYPE CHECK (
    problem_type IN ('Projector Failure', 'Air-Conditioning Issue', 'Cleaning Issue', 'Furniture Damage', 'Network Issue', 'Other')
);
```

### 3.1. Procedural Constraints (Functions & Triggers)

The following database-level procedural objects enforce complex business rules that cannot be verified by simple column constraints:

```sql
-- 1. Space Capacity Verification Function (BR-19)
CREATE FUNCTION dbo.fn_CheckSpaceCapacity (@SpaceCode VARCHAR(50), @Participants INT)
RETURNS BIT
AS
BEGIN
    DECLARE @Capacity INT;
    DECLARE @Result BIT = 1;
    
    SELECT @Capacity = capacity FROM SPACE WHERE space_code = @SpaceCode;
    
    IF @Participants > @Capacity
        SET @Result = 0;
        
    RETURN @Result;
END;
GO

-- 2. Overlapping Bookings & Maintenance Trigger (BR-11, BR-12, BR-23)
--    Only Approved (reserving) and Checked In (occupying) bookings block space.
--    No-Show, Cancelled, Rejected, and Completed bookings do not block new requests.
CREATE TRIGGER TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE
ON BOOKING
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 
        FROM inserted i
        JOIN SPACE s ON i.space_code = s.space_code
        WHERE i.booking_status IN ('Approved', 'Checked In')
          AND (
              s.current_status IN ('Retired', 'Temporarily Closed')
              OR EXISTS (
                  SELECT 1 FROM BOOKING b
                  WHERE b.space_code = i.space_code AND b.booking_id <> i.booking_id
                    AND b.booking_status IN ('Approved', 'Checked In')
                    AND i.requested_start < b.requested_end AND i.requested_end > b.requested_start
              )
              OR EXISTS (
                  SELECT 1 FROM MAINTENANCERECORD m
                  WHERE m.space_code = i.space_code
                    AND m.maintenance_status IN ('Reported', 'In Progress')
                    AND (i.requested_start < m.completion_time OR m.completion_time IS NULL)
                    AND i.requested_end > m.start_time
              )
          )
    )
    BEGIN
        RAISERROR ('Double booking, scheduling during maintenance, or booking retired/closed spaces is forbidden.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 3. Booking Status Transition & Audit Trigger (BR-15, BR-16, BR-21)
CREATE TRIGGER TR_BOOKING_STATUS_AND_AUDIT
ON BOOKING
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Enforce Cancellation Rule: Can only cancel if status was 'Pending' or 'Approved'
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON i.booking_id = d.booking_id
        WHERE i.booking_status = 'Cancelled'
          AND d.booking_status NOT IN ('Pending', 'Approved')
    )
    BEGIN
        RAISERROR ('A booking may be cancelled only if the booking status is Pending or Approved.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Enforce Check-In Rule: Status can only be set to 'Checked In' if a UsageSession with actual_start exists
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.booking_status = 'Checked In'
          AND NOT EXISTS (
              SELECT 1 FROM USAGESESSION u
              WHERE u.booking_id = i.booking_id AND u.actual_start IS NOT NULL
          )
    )
    BEGIN
        RAISERROR ('A booking can only have status Checked In if a UsageSession with actual_start exists.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Enforce Completion Rule: Status can only be set to 'Completed' if a UsageSession with actual_end exists
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.booking_status = 'Completed'
          AND NOT EXISTS (
              SELECT 1 FROM USAGESESSION u
              WHERE u.booking_id = i.booking_id AND u.actual_end IS NOT NULL
          )
    )
    BEGIN
        RAISERROR ('A booking can only have status Completed if a UsageSession with actual_end (checkout) exists.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Enforce Cancellation Audit Rule: Cancelled bookings cannot be deleted
    IF EXISTS (
        SELECT 1
        FROM deleted
        WHERE booking_status = 'Cancelled'
          AND NOT EXISTS (SELECT 1 FROM inserted)
    )
    BEGIN
        RAISERROR ('Cancelled bookings must remain stored in the system to preserve historical records and auditability.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- 4. Maintenance-to-Booking Overlap Prevention Trigger (BR-12, REC-1)
--    Enforces bidirectional overlap check: when a maintenance record is created or
--    updated, verify it does not conflict with any existing approved or checked-in booking.
CREATE TRIGGER TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP
ON MAINTENANCERECORD
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN BOOKING b ON b.space_code = i.space_code
        WHERE i.maintenance_status IN ('Reported', 'In Progress')
          AND b.booking_status IN ('Approved', 'Checked In')
          AND b.requested_start < ISNULL(i.completion_time, '9999-12-31')
          AND b.requested_end > i.start_time
    )
    BEGIN
        RAISERROR ('Maintenance record conflicts with an existing approved or checked-in booking for the same space and time period.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 5. Future Booking Enforcement Trigger with Role Exemption (BR-20, REC-2)
--    Users whose role is NOT Facility Staff or Facility Manager may only submit
--    booking requests for future time periods. The existing CK_BOOKING_FUTURE_START
--    CHECK constraint is retained as a secondary safeguard.
CREATE TRIGGER TR_BOOKING_FUTURE_START_ENFORCEMENT
ON BOOKING
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN [USER] u ON i.requester_id = u.user_id
        WHERE i.requested_start < GETDATE()
          AND u.role NOT IN ('Facility Staff', 'Facility Manager')
    )
    BEGIN
        RAISERROR ('Non-staff users may only submit booking requests for future time periods.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 6. Role-Based Permission Validation Triggers (Assumption 1, REC-3)
--    Validates that approver_id, check_in/out staff, and assigned_staff reference
--    users with role 'Facility Staff' or 'Facility Manager'.

-- 6a. Booking: validate approver role
CREATE TRIGGER TR_BOOKING_VALIDATE_APPROVER_ROLE
ON BOOKING
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN [USER] u ON i.approver_id = u.user_id
        WHERE u.role NOT IN ('Facility Staff', 'Facility Manager')
    )
    BEGIN
        RAISERROR ('Only Facility Staff or Facility Manager may approve or reject bookings.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 6b. UsageSession: validate check-in and check-out staff roles
CREATE TRIGGER TR_USAGESESSION_VALIDATE_STAFF_ROLES
ON USAGESESSION
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN [USER] u ON i.check_in_staff_id = u.user_id
        WHERE u.role NOT IN ('Facility Staff', 'Facility Manager')
    )
    BEGIN
        RAISERROR ('Only Facility Staff or Facility Manager may perform check-in operations.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN [USER] u ON i.check_out_staff_id = u.user_id
        WHERE u.role NOT IN ('Facility Staff', 'Facility Manager')
    )
    BEGIN
        RAISERROR ('Only Facility Staff or Facility Manager may perform check-out operations.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 6c. MaintenanceRecord: validate assigned staff role
CREATE TRIGGER TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE
ON MAINTENANCERECORD
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN [USER] u ON i.assigned_staff_id = u.user_id
        WHERE u.role NOT IN ('Facility Staff', 'Facility Manager')
    )
    BEGIN
        RAISERROR ('Only Facility Staff or Facility Manager may be assigned to maintenance tasks.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 7. Usage Session Booking Status Validation Trigger (Assumption 9, REC-4)
--    Ensures that a usage session can only be created for a booking with
--    booking_status = 'Approved'.
CREATE TRIGGER TR_USAGESESSION_CHECK_BOOKING_STATUS
ON USAGESESSION
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN BOOKING b ON i.booking_id = b.booking_id
        WHERE b.booking_status <> 'Approved'
    )
    BEGIN
        RAISERROR ('A usage session can only be created for a booking with status Approved.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 8. Booking Modification Lock After Approval Trigger (BR-22)
--    Once a booking has been approved, the requested space, requested start time,
--    and requested end time shall not be modified. Changes require cancellation
--    and resubmission.
CREATE TRIGGER TR_BOOKING_LOCK_APPROVED_FIELDS
ON BOOKING
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON i.booking_id = d.booking_id
        WHERE d.booking_status <> 'Pending'
          AND (
              i.space_code <> d.space_code
              OR i.requested_start <> d.requested_start
              OR i.requested_end <> d.requested_end
          )
    )
    BEGIN
        RAISERROR ('Once a booking has been approved or checked in, the space, start time, and end time cannot be modified. Cancel and resubmit instead.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO
```

## 4. Traceability Matrix

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
| `SPACE` | `building` | `SPACE.building` | §4.2, §3.2 | Room location attribute. Part of table-level UNIQUE `UQ_SPACE_LOCATION` `(building, floor, room_number)`. |
| `SPACE` | `floor` | `SPACE.floor` | §4.2, §3.2 | Room location attribute. Part of table-level UNIQUE `UQ_SPACE_LOCATION` `(building, floor, room_number)`. |
| `SPACE` | `room_number` | `SPACE.room_number` | §4.2, §3.2 | Room location attribute. Part of table-level UNIQUE `UQ_SPACE_LOCATION` `(building, floor, room_number)`. |
| `SPACE` | `capacity` | `SPACE.capacity` | §4.2, §3.2 | CHECK constraint enforces capacity > 0. |
| `SPACE` | `current_status` | `SPACE.current_status` | §4.2, §3.2 | CHECK constraint checks current status. |
| `SPACE` | `usage_policy` | `SPACE.usage_policy` | §4.2, §3.2 | Policies text. |
| `FACILITY` | `facility_id` | `FACILITY.facility_id` | §4.3, §3.3 | Primary Key. Auto-increment. |
| `FACILITY` | `facility_name` | `FACILITY.facility_name` | §4.3, §3.3 | Alternate key. UNIQUE constraint. |
| `FACILITY` | `facility_description` | `FACILITY.facility_description`| §4.3, §3.3 | Description of facility. Nullable. |
| `SPACE_FACILITY`| `space_code` | - | §5.4, §6.4 | Composite PK Part 1, FK references SPACE. |
| `SPACE_FACILITY`| `facility_id` | - | §5.4, §6.4 | Composite PK Part 2, FK references FACILITY. |
| `SPACE_FACILITY`| `quantity` | - | - | Quantity of this facility type in the space. Default 1. CHECK > 0. |
| `SPACE_FACILITY`| `operation_status`| - | - | Overall status of this facility type in the space. Default 'Operational'. CHECK constraint. |
| `SPACE_FACILITY`| `description` | - | - | Optional free-text details about the facility's condition. |
| `BOOKING` | `booking_id` | `BOOKING.booking_id` | §4.4, §3.4 | Primary Key. Auto-increment. |
| `BOOKING` | `space_code` | `BOOKING.space_code` | §4.4, §3.4 | FK references SPACE. |
| `BOOKING` | `requester_id` | `BOOKING.requester_id` | §4.4, §3.4 | FK references USER. |
| `BOOKING` | `requested_start`| `BOOKING.requested_start` | §4.4, §3.4, §7.20 | CHECK constraint enforces future start (BR-20). Trigger `TR_BOOKING_FUTURE_START_ENFORCEMENT` enforces future-only rule with role exemption for Facility Staff/Manager. |
| `BOOKING` | `requested_end` | `BOOKING.requested_end` | §4.4, §3.4 | Requested end time. CHECK order constraint. |
| `BOOKING` | `purpose` | `BOOKING.purpose` | §4.4, §3.4 | CHECK constraint checks purpose enums. |
| `BOOKING` | `expected_participants`| `BOOKING.expected_participants`| §4.4, §3.4 | CHECK enforces count > 0 and <= capacity via UDF. |
| `BOOKING` | `booking_status`| `BOOKING.booking_status` | §4.4, §3.4, §7.21, §7.22 | CHECK constraint checks status enums. Trigger prevents overlap if 'Approved' or 'Checked In'. Trigger `TR_BOOKING_STATUS_AND_AUDIT` enforces cancellation and audit rules (BR-21). Trigger `TR_BOOKING_LOCK_APPROVED_FIELDS` prevents modification of space/start/end once approved or checked in (BR-22). |
| `BOOKING` | `created_at` | `BOOKING.created_at` | §4.4, §3.4 | DEFAULT constraint `GETDATE()`. |
| `BOOKING` | `approver_id` | `BOOKING.approver_id` | §4.4, §3.4, §8.1 | FK references USER. Nullable. Trigger `TR_BOOKING_VALIDATE_APPROVER_ROLE` enforces that approver must be Facility Staff or Manager (Assumption 1). |
| `BOOKING` | `decision_time` | `BOOKING.decision_time` | §4.4, §3.4 | Nullable decision time. |
| `BOOKING` | `decision_note` | `BOOKING.decision_note` | §4.4, §3.4 | Nullable staff comments. |
| `BOOKING` | `rejection_reason`| `BOOKING.rejection_reason` | §4.4, §3.4 | CHECK constraint forces non-null if rejected. |
| `USAGESESSION` | `booking_id` | `USAGESESSION.booking_id` | §4.5, §3.5 | PK, FK references BOOKING. 1:1 relationship. |
| `USAGESESSION` | `check_in_staff_id`| `USAGESESSION.check_in_staff_id`| §4.5, §3.5, §8.1 | FK references USER (staff). Trigger `TR_USAGESESSION_VALIDATE_STAFF_ROLES` enforces staff role (Assumption 1). |
| `USAGESESSION` | `actual_start` | `USAGESESSION.actual_start` | §4.5, §3.5 | Physical start time. |
| `USAGESESSION` | `initial_condition`| `USAGESESSION.initial_condition`| §4.5, §3.5 | Room condition at check-in. |
| `USAGESESSION` | `check_out_staff_id`| `USAGESESSION.check_out_staff_id`| §4.5, §3.5, §8.1 | FK references USER (staff). Nullable. Trigger `TR_USAGESESSION_VALIDATE_STAFF_ROLES` enforces staff role (Assumption 1). |
| `USAGESESSION` | `actual_end` | `USAGESESSION.actual_end` | §4.5, §3.5 | Nullable end. CHECK order constraint. |
| `USAGESESSION` | `final_condition`| `USAGESESSION.final_condition`| §4.5, §3.5 | Nullable room condition at exit. |
| `USAGESESSION` | `usage_notes` | `USAGESESSION.usage_notes` | §4.5, §3.5 | Nullable usage session notes. |
| `MAINTENANCERECORD`| `maintenance_id`| `MAINTENANCERECORD.maintenance_id`| §4.6, §3.6 | Primary Key. Auto-increment. |
| `MAINTENANCERECORD`| `space_code` | `MAINTENANCERECORD.space_code` | §4.6, §3.6 | FK references SPACE. |
| `MAINTENANCERECORD`| `reporter_id` | `MAINTENANCERECORD.reporter_id`| §4.6, §3.6 | FK references USER. |
| `MAINTENANCERECORD`| `assigned_staff_id`| `MAINTENANCERECORD.assigned_staff_id`| §4.6, §3.6, §8.1 | FK references USER. Nullable. Trigger `TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE` enforces staff role (Assumption 1). |
| `MAINTENANCERECORD`| `problem_type` | `MAINTENANCERECORD.problem_type`| §4.6, §3.6 | CHECK constraint checks problem type enums. |
| `MAINTENANCERECORD`| `problem_description`| `MAINTENANCERECORD.problem_description`| §4.6, §3.6 | Problem details. |
| `MAINTENANCERECORD`| `start_time` | `MAINTENANCERECORD.start_time`| §4.6, §3.6 | Timestamp of maintenance start. |
| `MAINTENANCERECORD`| `completion_time`| `MAINTENANCERECORD.completion_time`| §4.6, §3.6 | Nullable. CHECK completion > start constraint. |
| `MAINTENANCERECORD`| `maintenance_status`| `MAINTENANCERECORD.maintenance_status`| §4.6, §3.6 | CHECK constraint checks status enums. |
| `MAINTENANCERECORD`| `result_note` | `MAINTENANCERECORD.result_note`| §4.6, §3.6 | Nullable outcome notes. |

### 4.1. Procedural Constraint Traceability

| Procedural Object | Type | Table | BRA / Assumption Reference | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `dbo.fn_CheckSpaceCapacity` | UDF | `BOOKING` (via CHECK) | §7.19 (BR-19) | Validates expected participants ≤ space capacity. |
| `TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE` | Trigger (AFTER INSERT, UPDATE) | `BOOKING` | §7.11 (BR-11), §7.12 (BR-12) | Prevents double booking, scheduling during maintenance, and booking of retired/closed spaces. |
| `TR_BOOKING_STATUS_AND_AUDIT` | Trigger (AFTER UPDATE, DELETE) | `BOOKING` | §7.21 (BR-21) | Enforces cancellation state transitions and prevents deletion of cancelled bookings. |
| `TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP` | Trigger (AFTER INSERT, UPDATE) | `MAINTENANCERECORD` | §7.12 (BR-12), REC-1 | Bidirectional overlap check: prevents maintenance from conflicting with Approved or Checked In bookings. |
| `TR_BOOKING_FUTURE_START_ENFORCEMENT` | Trigger (AFTER INSERT, UPDATE) | `BOOKING` | §7.20 (BR-20), REC-2 | Enforces future-only booking start with role exemption for Facility Staff/Manager. |
| `TR_BOOKING_VALIDATE_APPROVER_ROLE` | Trigger (AFTER INSERT, UPDATE) | `BOOKING` | §8.1 (Assumption 1), REC-3 | Validates that the approver has Facility Staff or Facility Manager role. |
| `TR_USAGESESSION_VALIDATE_STAFF_ROLES` | Trigger (AFTER INSERT, UPDATE) | `USAGESESSION` | §8.1 (Assumption 1), REC-3 | Validates check-in/out staff have Facility Staff or Facility Manager role. |
| `TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE` | Trigger (AFTER INSERT, UPDATE) | `MAINTENANCERECORD` | §8.1 (Assumption 1), REC-3 | Validates assigned staff has Facility Staff or Facility Manager role. |
| `TR_USAGESESSION_CHECK_BOOKING_STATUS` | Trigger (AFTER INSERT) | `USAGESESSION` | §8.9 (Assumption 9), REC-4 | Ensures usage session creation only for bookings with status 'Approved'. |
| `TR_BOOKING_LOCK_APPROVED_FIELDS` | Trigger (AFTER UPDATE) | `BOOKING` | §7.22 (BR-22) | Prevents modification of space_code, requested_start, and requested_end once booking is approved or checked in. |

---

## 5. Assumptions and Open Questions

### 5.1. Design Assumptions
1. **Soft Deletion Integrity**: To preserve historical logs (Requirement §18), users and spaces are never physically deleted. However, to cover database schema logic, mandatory foreign keys use `ON DELETE NO ACTION` to block invalid deletions, and nullable ones default to RESTRICT behavior.
2. **Date Comparison Ordering**: Timestamps (`requested_start`, `requested_end`, `actual_start`, `actual_end`, `start_time`, `completion_time`) are assumed to be stored in standard database timezone formatting, verified by CHECK constraints preventing logical overlaps or negative durations.
3. **Surrogate Key Auto-Incrementation**: `booking_id`, `facility_id`, and `maintenance_id` are designated as auto-incrementing identity values (`INT IDENTITY` in MS SQL Server) in the physical phase to guarantee unique primary keys.
4. **Role-Based Permission Enforcement**: Per Assumption 1 and REC-3 from the design validation, role-based permissions for approval, check-in/out, and maintenance assignment are enforced at the database level through triggers (`TR_BOOKING_VALIDATE_APPROVER_ROLE`, `TR_USAGESESSION_VALIDATE_STAFF_ROLES`, `TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE`).
5. **Usage Session Booking Status Validation**: Per Assumption 9 and REC-4 from the design validation, usage sessions can only be created for bookings with `booking_status = 'Approved'`, enforced by trigger `TR_USAGESESSION_CHECK_BOOKING_STATUS`.
6. **Bidirectional Overlap Prevention**: Per REC-1 from the design validation, overlap prevention is bidirectional — both booking and maintenance record changes are checked against each other for time conflicts.

### 5.2. Open Questions
*No open questions remain as naming conventions, junction table keys, and referential behaviors have been explicitly resolved and approved by the stakeholders during the conceptual-to-logical design transition.*
