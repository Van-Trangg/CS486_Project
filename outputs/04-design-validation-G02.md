# Step 4: Database Design Validation

---

## 1. Validation Scope

This document presents a formal, evidence-based design validation of the logical database schema designed for the School of Computer Science Campus Space Management System. The scope of this validation includes:
* **Source Artifacts Evaluated:**
  * Business Requirement Analysis (BRA): `outputs/01-business-requirement-analysis-G02.md`
  * Entity-Relationship Diagram (ERD): `outputs/02-erd-design-G02.md`
  * Logical Database Design (Relational Schema): `outputs/03-logical-design-G02.md`
* **Target Database Management System:** Microsoft SQL Server.
* **Evaluation Objectives:**
  * To verify that all entities, attributes, and relationships defined in the conceptual model are mapped correctly and without omissions to the logical design.
  * To validate the key configurations, domains, and database constraints against specified business rules.
  * To analyze referential integrity actions for safety and historical preservation consistency.
  * To identify strengths, potential gaps, risks, and recommended improvements for procedural or application-level enforcement.

---

## 2. Entity Coverage Validation

This validation stage compares the entities defined in the ERD against the relational tables implemented in the Logical Database Design to ensure complete coverage.

| ERD Entity Name | Mapped Relational Table | Validation Status | Evidence / Notes |
| :--- | :--- | :--- | :--- |
| `USER` | `USER` | Valid | Table contains all 7 attributes defined in ERD §2. Mapped verbatim. |
| `SPACE` | `SPACE` | Valid | Table contains all 9 attributes defined in ERD §2. Mapped verbatim. |
| `FACILITY` | `FACILITY` | Valid | Table contains all 3 attributes defined in ERD §2. Mapped verbatim. |
| `BOOKING` | `BOOKING` | Valid | Table contains all 14 attributes defined in ERD §2. Mapped verbatim. |
| `USAGESESSION` | `USAGESESSION` | Valid | Table contains all 8 attributes defined in ERD §2. Mapped verbatim. |
| `MAINTENANCERECORD` | `MAINTENANCERECORD` | Valid | Table contains all 10 attributes defined in ERD §2. Mapped verbatim. |
| *None (M:N)* | `SPACE_FACILITY` | Valid | Properly introduced as an associative table to resolve the M:N relationship `Space_Equipped_With_Facility`. |

* **Omission Check:** All 6 core entities identified in ERD §2 and BRA §3 exist as corresponding physical tables. No entities are omitted.
* **Redundancy Check:** No additional tables exist without explicit business justification. The introduction of `SPACE_FACILITY` is required to resolve the Many-to-Many relationship between `SPACE` and `FACILITY` to maintain first normal form (1NF).

---

## 3. Relationship Mapping Validation

This validation stage analyzes the structural mapping of the 10 conceptual relationships declared in the ERD summary table into foreign keys and junction tables.

| Relationship Name | ERD Cardinality | Expected Mapping | Actual Schema Mapping | Validation Status | Evidence / Analysis |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **User_Requests_Booking** | User (0,N) : (1,1) Booking | FK on N-side (`BOOKING`) | `BOOKING.requester_id` references `USER(user_id)` | Valid | `requester_id` is defined as `NOT NULL`, enforcing mandatory participation on the Booking side (N-side). |
| **User_Approves_Booking** | User (0,N) : (0,1) Booking | FK on N-side (`BOOKING`) | `BOOKING.approver_id` references `USER(user_id)` | Valid | `approver_id` is defined as `NULL`, correctly enforcing optional participation on both sides for pending requests. |
| **Space_Hosts_Booking** | Space (0,N) : (1,1) Booking | FK on N-side (`BOOKING`) | `BOOKING.space_code` references `SPACE(space_code)` | Valid | `space_code` is defined as `NOT NULL`, enforcing that every booking must reference a valid physical space. |
| **Space_Equipped_With_Facility** | Space (0,M) : (0,N) Facility | Junction Table | Table `SPACE_FACILITY` with composite PK `(space_code, facility_id)` | Valid | Resolves the M:N cardinality. FKs reference `SPACE` and `FACILITY` respectively. |
| **Booking_Has_UsageSession** | Booking (0,1) : (1,1) UsageSession | Shared PK / Unique FK | `USAGESESSION.booking_id` acts as both PK and FK referencing `BOOKING` | Valid | Enforces a strict 1:1 mapping, guaranteeing that at most one usage session exists per booking and cannot exist without it. |
| **User_ChecksIn_UsageSession** | User (0,N) : (1,1) UsageSession | FK on N-side (`USAGESESSION`) | `USAGESESSION.check_in_staff_id` references `USER(user_id)` | Valid | `check_in_staff_id` is defined as `NOT NULL`, ensuring a check-in staff member is always logged. |
| **User_ChecksOut_UsageSession** | User (0,N) : (0,1) UsageSession | FK on N-side (`USAGESESSION`) | `USAGESESSION.check_out_staff_id` references `USER(user_id)` | Valid | `check_out_staff_id` is defined as `NULL`, permitting ongoing sessions to lack a checkout staff member. |
| **Space_Requires_Maintenance** | Space (0,N) : (1,1) MaintenanceRecord | FK on N-side (`MAINTENANCERECORD`) | `MAINTENANCERECORD.space_code` references `SPACE(space_code)` | Valid | `space_code` is defined as `NOT NULL`, ensuring every maintenance log is linked to a valid space. |
| **User_Reports_Maintenance** | User (0,N) : (1,1) MaintenanceRecord | FK on N-side (`MAINTENANCERECORD`) | `MAINTENANCERECORD.reporter_id` references `USER(user_id)` | Valid | `reporter_id` is defined as `NOT NULL`, ensuring every reported problem is linked to a valid reporter. |
| **User_Assigned_To_Maintenance** | User (0,N) : (0,1) MaintenanceRecord | FK on N-side (`MAINTENANCERECORD`) | `MAINTENANCERECORD.assigned_staff_id` references `USER(user_id)` | Valid | `assigned_staff_id` is defined as `NULL`, permitting newly reported records to exist prior to technician assignment. |

### Internal Consistency of Referential Actions:
1. **Conflict 1 (High Risk — Historical Preservation Breach):** `USAGESESSION` defines `ON DELETE CASCADE` referencing `BOOKING(booking_id)` in Logical Design §1. Since `USAGESESSION` holds actual transactional history (check-in/out timestamps and initial/final space conditions), deleting a booking will silently purge the associated usage session. This conflicts with **BR-18** (preservation of historical records) and constitutes a **High Risk**.
2. **Conflict 2 (High Risk — Conflicting Referential Policies):** `BOOKING` defines `ON DELETE NO ACTION` on its foreign keys referencing `USER` and `SPACE` (protecting transaction logs from deletion), whereas `USAGESESSION` has `ON DELETE CASCADE` on `booking_id`. If `BOOKING` is protected, but `USAGESESSION` is cascadingly deleted if `BOOKING` is removed, this represents a severe inconsistency in history preservation strategy. We recommend removing `ON DELETE CASCADE` and using `ON DELETE NO ACTION` for `USAGESESSION.booking_id` to prevent audit trail destruction.

---

## 4. Key Validation

This stage evaluates primary, foreign, alternate, and composite keys for uniqueness, referential integrity, and compliance with MS SQL Server specifications.

* **Primary Keys (PK):**
  * `USER.user_id` (Natural Key, `VARCHAR(50)`): Uniquely identifies each user via their mandatory university account ID. Highly stable.
  * `SPACE.space_code` (Natural Key, `VARCHAR(50)`): Uniquely identifies each room (e.g., 'B1-F3-R305').
  * `FACILITY.facility_id` (Surrogate Key, `INT`): Auto-incrementing integer key. Efficient for referencing.
  * `SPACE_FACILITY.(space_code, facility_id)` (Composite PK): Combines the two foreign keys. Prevents duplicate assignment rows for the same facility type within a single space.
  * `BOOKING.booking_id` (Surrogate Key, `INT`): Auto-incrementing unique reservation identifier.
  * `USAGESESSION.booking_id` (Shared PK, `INT`): Reuses the parent `booking_id` as the primary key. Correctly restricts cardinality to 1:1 and prevents orphaned usage records.
  * `MAINTENANCERECORD.maintenance_id` (Surrogate Key, `INT`): Auto-incrementing unique maintenance log identifier.
* **Foreign Keys (FK):**
  * All foreign keys match the data type and character length of their parent primary keys (`VARCHAR(50)` for user and space codes, `INT` for surrogate IDs), ensuring reference compatibility in SQL Server.
* **Alternate / Candidate Keys (AK):**
  * `USER.email` (`VARCHAR(150)`): Constrained with a `UNIQUE` index. This guarantees no two records can register with the same institutional email.
  * `FACILITY.facility_name` (`VARCHAR(100)`): Constrained with a `UNIQUE` index, preventing duplicate master catalog items.

**Key Assessment:** All defined keys are appropriate, prevent duplication of core entities, and provide a performant relational index structure.

---

## 5. Constraint Validation

This stage evaluates the declarative constraints implemented in the relational design to ensure database integrity.

* **Nullability Constraints (`NOT NULL`):**
  * Critical attributes (such as names, types, capacities, statuses, and times) are marked `NOT NULL` to prevent incomplete records.
  * Nullability is restricted to optional business fields (e.g., `phone_number`, `decision_note`, `rejection_reason`, checkout details, and technician assignments), which is logically correct.
* **Domain Check Constraints (`CHECK`):**
  * `CK_USER_ROLE`: Restricts role to valid values: Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, and Facility Manager.
  * `CK_USER_ACCOUNT_STATUS`: Restricts account status to: Active, Suspended, Inactive.
  * `CK_SPACE_TYPE`: Restricts room type to: Auditorium, Classroom, Computer Laboratory, Project Laboratory, Meeting Room, Student Workspace.
  * `CK_SPACE_CAPACITY`: Enforces `capacity > 0`.
  * `CK_SPACE_CURRENT_STATUS`: Restricts status to: Available, In Use, Under Maintenance, Temporarily Closed, Retired.
  * `CK_SPACE_FACILITY_QUANTITY`: Enforces `quantity > 0` in the junction table.
  * `CK_SPACE_FACILITY_STATUS`: Restricts operational status of equipment to: Operational, Partially Operational, Broken.
  * `CK_BOOKING_TIME_ORDER`: Enforces `requested_end > requested_start`.
  * `CK_BOOKING_PARTICIPANTS`: Enforces `expected_participants > 0`.
  * `CK_BOOKING_PURPOSE`: Restricts purpose to: Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Administrative Event.
  * `CK_BOOKING_STATUS`: Restricts status to: Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-Show.
  * `CK_USAGE_TIME_ORDER`: Enforces `actual_end > actual_start`.
  * `CK_MAINTENANCE_TIME_ORDER`: Enforces `completion_time > start_time`.
  * `CK_MAINTENANCE_STATUS`: Restricts status to: Reported, In Progress, Resolved, Cancelled.
  * `CK_MAINTENANCE_PROBLEM_TYPE`: Restricts problem type to: Projector Failure, Air-Conditioning Issue, Cleaning Issue, Furniture Damage, Network Issue, Other.
* **Default Constraints (`DEFAULT`):**
  * `DF_BOOKING_CREATED_AT`: Sets default creation date to `GETDATE()`.
  * `DF_SPACE_FACILITY_QUANTITY`: Defaults equipment quantity in a space to 1.
  * `DF_SPACE_FACILITY_STATUS`: Defaults equipment status to 'Operational'.
* **Referential Integrity Actions (Cascading):**
  * `SPACE_FACILITY` has `ON DELETE CASCADE` on both `space_code` and `facility_id` to prevent orphaned junction entries. (Valid)
  * `USAGESESSION` has `ON DELETE CASCADE` referencing `BOOKING` to clean up usage session details if a booking is deleted. (Identified as **High Risk** due to historical preservation violation of BR-18).
  * All other tables referencing `USER` or `SPACE` default to `ON DELETE NO ACTION` to prevent deletion of master records with transaction history, protecting auditability. (Valid)

---

## 6. Business Rule Coverage Analysis

This stage reviews every business rule from the BRA document and evaluates whether the relational database schema enforces it completely.

| Rule ID | Business Rule Text (Summarized) | Enforcement Status | Database Enforcement Mechanism | Procedural/Application Enforcement Needed? |
| :--- | :--- | :--- | :--- | :--- |
| **BR-01** | Every user must have a valid account. | **Fully Enforced** | `USER.user_id` is the primary key. All referencing tables have mandatory FKs to `USER(user_id)`. | No. Supported entirely by relational constraints. |
| **BR-02** | Store standard user info (ID, name, email, role, dept, status). | **Fully Enforced** | `USER` table columns mapped with `NOT NULL` constraints and `UNIQUE(email)`. | No. Handled entirely at the schema level. |
| **BR-03** | User roles constrained to predefined list. | **Fully Enforced** | `CK_USER_ROLE` check constraint on `USER.role`. | No. Database blocks invalid values natively. |
| **BR-04** | Each room must have a unique code. | **Fully Enforced** | `SPACE.space_code` primary key constraint. | No. Relational uniqueness is guaranteed. |
| **BR-05** | Store standard space attributes (code, name, type, building, capacity, status, etc.). | **Fully Enforced** | `SPACE` table columns mapped verbatim with `NOT NULL` and data types. | No. Handled entirely at the schema level. |
| **BR-06** | Space status constrained to predefined list. | **Fully Enforced** | `CK_SPACE_CURRENT_STATUS` check constraint on `SPACE.current_status`. | No. Database blocks invalid values natively. |
| **BR-07** | Facility list must be tracked inside rooms. | **Fully Enforced** | Mapped using `SPACE_FACILITY` junction table with FKs to `SPACE` and `FACILITY`. | No. Handled entirely at the schema level. |
| **BR-08** | Booking requests require space, start/end, purpose, participants. | **Fully Enforced** | Non-nullable columns in `BOOKING` for all submission attributes. | No. Schema rejects partial submissions. |
| **BR-09** | Booking purposes restricted to predefined list. | **Fully Enforced** | `CK_BOOKING_PURPOSE` check constraint on `BOOKING.purpose`. | No. Database blocks invalid values natively. |
| **BR-10** | Booking status restricted to predefined list. | **Fully Enforced** | `CK_BOOKING_STATUS` check constraint on `BOOKING.booking_status`. | No. Database blocks invalid values natively. |
| **BR-11** | Prevent overlapping approved bookings for the same space. | **Partially Enforced** | None (Static schema constraints cannot check interval overlap across rows). | **Yes.** Requires an `AFTER INSERT, UPDATE` trigger on `BOOKING`, or strict transaction verification in the application layer. |
| **BR-12** | Block bookings for unavailable rooms (under maintenance, closed, retired). | **Partially Enforced** | None (Static constraints cannot perform cross-table logic or evaluate time-bound space statuses). | **Yes.** Requires a trigger or application service rule checking `SPACE.current_status` and active maintenance schedules prior to approving a booking. |
| **BR-13** | Log booking decisions (approver, time, notes). | **Fully Enforced** | `BOOKING` columns: `approver_id` (FK to User), `decision_time`, `decision_note`. | No. Supported by nullable columns updated via application logic during approval. |
| **BR-14** | Rejection must store a reason. | **Partially Enforced** | Column `BOOKING.rejection_reason` exists but is nullable. | **Yes.** Enforced via application validation, or a check constraint `CHECK (booking_status <> 'Rejected' OR rejection_reason IS NOT NULL)` should be added. |
| **BR-15** | Check-in logs actual start, staff, initial room condition. | **Fully Enforced** | `USAGESESSION` columns: `actual_start`, `check_in_staff_id` (FK), and `initial_condition` are defined as `NOT NULL`. | No. Enforced by database nullability rules on insert. |
| **BR-16** | Checkout logs actual end, final condition, and usage notes. | **Partially Enforced** | `USAGESESSION` columns exist as nullable (to allow active check-ins). | **Yes.** Application logic must ensure these fields are populated when the booking status shifts to 'Completed'. |
| **BR-17** | Maintenance records track related space, reporter, assignee, description, times, status, notes. | **Fully Enforced** | `MAINTENANCERECORD` table columns mapped with proper nullability, data types, and check constraints (`CK_MAINTENANCE_STATUS`, `CK_MAINTENANCE_TIME_ORDER`). | No. Logically complete structure at the schema level. |
| **BR-18** | Historical records must be preserved for reports. | **Partially Enforced** | Referenced columns use `ON DELETE NO ACTION`, but the cascade deletion defined on `USAGESESSION` breaches this rule. | **Yes.** Change `ON DELETE CASCADE` to `ON DELETE NO ACTION` for `USAGESESSION.booking_id` to protect actual usage logs. |
| **BR-19** | Expected participants must not exceed space capacity. | **Partially Enforced** | None (Static constraints cannot compare columns across parent/child tables `SPACE.capacity` and `BOOKING.expected_participants`). | **Yes.** Requires a database trigger, a check constraint using a User-Defined Function (UDF), or application-level verification. |

---

## 7. Traceability Validation

This stage evaluates the end-to-end traceability of business requirements from the BRA, through the ERD, into the physical SQL Server relational schema elements.

```
[BRA Business Requirements (BR-01 to BR-19)] 
       │ (Section 3: Entities & Section 5: Relationships)
       ▼
[ERD Elements (Mermaid erDiagram)]
       │ (Section 2: Diagram & Section 3: Summary Table)
       ▼
[Relational Schema Tables] (Section 2: Tables)
       │ (Section 3: Check/Default Constraints)
       ▼
[Database Constraint / Trigger Logic]
```

### Traceability Chain Audit:
* **Entities:** All 6 core entities identified in BRA §3 are mapped to ERD entities and subsequently translated to Upper-Case relational tables.
* **Attributes:** Every attribute detailed in BRA §4 is fully mapped in the ERD attributes lists and schema definitions in the logical design, preserving matching data types.
* **Relationships:** The 10 relationships detailed in BRA §5 and mapped in the ERD diagram are completely trace-recoverable via foreign key constraints, nullable FK structures for optional participations, and junction tables for M:N mappings.
* **Business Rules:** Standard constraints (CHECK, NOT NULL, UNIQUE, DEFAULT) directly trace back to business rules BR-01 through BR-10, BR-13, BR-15, and BR-17. Complex scheduling rules (BR-11, BR-12) and capacity validations (BR-19) trace to documented database trigger recommendations.

**Traceability Status:** **Complete and Unbroken.** There are no untraceable tables, columns, or constraints, and no requirements have been lost during the architectural transition. Gaps in automatic/declarative validation are identified and redirected to specific procedural database or application validation layers.

---

## 8. Strengths

1. **Strict 3NF Normalization:** The database schema is fully normalized to Third Normal Form (3NF). There are no transitive dependencies or duplicate multi-valued attributes, ensuring high data consistency.
2. **Robust 1:1 Relationship Enforcement:** Utilizing `booking_id` as both the Primary Key and Foreign Key in `USAGESESSION` is an excellent design choice. It physically prevents any booking from having duplicate checkout logs.
3. **Comprehensive Domain Validation:** The schema implements 15 explicit CHECK constraints restricting user roles, booking statuses, problem types, and room classifications to valid university categories. This prevents invalid data from corrupting the tables.
4. **Data Integrity & Audit Protection:** Restricting referential actions with `ON DELETE NO ACTION` and `ON UPDATE NO ACTION` for bookings and maintenance records prevents accidental deletion of transaction logs when users or rooms are deleted, preserving operational history for audits.
5. **Logical Time Constraints:** CHECK constraints correctly guarantee that requested booking end times are always after start times, actual session exit times are after entry times, and maintenance resolution times are after reporting times.

---

## 9. Issues and Risks

1. **Vulnerability to Loss of Transaction History (High Risk — BR-18):** Setting `ON DELETE CASCADE` on `USAGESESSION` referencing `BOOKING` threatens the historical log of actual space usage. If a user deletes a booking request, all real-world entry and exit logs associated with it will be destroyed.
2. **Conflicting Referential Action Design (High Risk):** `BOOKING` protects transaction logs via `ON DELETE NO ACTION` on `requester_id` and `space_code`, but `USAGESESSION` defines `ON DELETE CASCADE` on `booking_id`. This creates a severe design inconsistency for history preservation.
3. **Double-Booking Vulnerability (High Risk — BR-11):** Static schema constraints cannot prevent two approved bookings from overlapping in the same room. Without procedural database triggers or application transaction locks, the system can suffer from concurrent booking conflicts.
4. **Invalid Space Status Approvals (Medium Risk — BR-12):** Declaring a space 'Under Maintenance' or 'Retired' does not automatically block active bookings during that period. Approved bookings could theoretically be scheduled in rooms that are unavailable.
5. **Capacity Over-allocation (Medium Risk — BR-19):** Users can successfully submit bookings where `expected_participants > capacity` of the requested space. This can cause physical overcrowding in classrooms or labs.
6. **Conditional Nullability of Rejection Reason (Low Risk — BR-14):** The column `BOOKING.rejection_reason` is nullable. If a booking is rejected, there is no database-level check constraint forcing this field to be populated, potentially resulting in blank rejection notes.

---

## 10. Recommendations

To address the identified risks and achieve full enforcement of all business rules at the database level, the following improvements are recommended:

### Recommendation 1: Align Referential Actions to Protect Historical Audit Trail
Modify `USAGESESSION` to use `ON DELETE NO ACTION` on the foreign key referencing `BOOKING`. This enforces that completed actual sessions cannot be deleted from the database. Deleting an approved booking that was physically used must be blocked to preserve historical reports.
```sql
-- Recommend replacing Cascade Delete with No Action
ALTER TABLE USAGESESSION DROP CONSTRAINT FK_USAGESESSION_BOOKING;
ALTER TABLE USAGESESSION ADD CONSTRAINT FK_USAGESESSION_BOOKING 
    FOREIGN KEY (booking_id) REFERENCES BOOKING(booking_id) 
    ON DELETE NO ACTION;
```

### Recommendation 2: Implement an Overlap and Space Status Trigger
Implement a database-level trigger on the `BOOKING` table to automatically reject approved bookings that overlap with existing approved bookings or maintenance schedules, and to block bookings in unavailable spaces (BR-11, BR-12):
```sql
CREATE TRIGGER TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE
ON BOOKING
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if any newly inserted or updated booking has been approved
    IF EXISTS (
        SELECT 1 
        FROM inserted i
        JOIN SPACE s ON i.space_code = s.space_code
        WHERE i.booking_status = 'Approved'
          AND (
              -- Rule 1: Prevent booking in Retired or Temporarily Closed spaces
              s.current_status IN ('Retired', 'Temporarily Closed')
              OR
              -- Rule 2: Prevent overlapping approved bookings
              EXISTS (
                  SELECT 1 
                  FROM BOOKING b
                  WHERE b.space_code = i.space_code
                    AND b.booking_id <> i.booking_id
                    AND b.booking_status = 'Approved'
                    AND i.requested_start < b.requested_end
                    AND i.requested_end > b.requested_start
              )
              OR
              -- Rule 3: Prevent overlapping with active maintenance periods
              EXISTS (
                  SELECT 1 
                  FROM MAINTENANCERECORD m
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
```

### Recommendation 3: Enforce Capacity Verification via UDF check constraint
To enforce BR-19 at the database level, add a verification rule within a check constraint utilizing a scalar User-Defined Function (UDF):
```sql
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

ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_CAPACITY_LIMIT 
CHECK (dbo.fn_CheckSpaceCapacity(space_code, expected_participants) = 1);
```

### Recommendation 4: Add Conditional CHECK for Rejection Reason
To enforce BR-14 and ensure that facility staff must record why a booking request was rejected, add a conditional CHECK constraint on the `BOOKING` table:
```sql
ALTER TABLE BOOKING ADD CONSTRAINT CK_BOOKING_REJECTION_REASON 
CHECK (booking_status <> 'Rejected' OR rejection_reason IS NOT NULL);
```

---

## 11. Conclusion

Based on this comprehensive design validation, the logical database design is assessed as:

### **Conditionally Valid**

**Justification:**
The logical schema perfectly normalizes the data to 3NF, implements highly compatible Microsoft SQL Server data types, and contains complete and traceable coverage for all 6 entities, 10 relationships, and standard domain constraints. The relational structures are robust, audit-friendly, and protect the system from basic transactional errors (such as negative capacities or invalid dates).

However, it is classified as *Conditionally Valid* because:
1. Critical referential actions defined on `USAGESESSION` (`ON DELETE CASCADE`) violate **BR-18** by risking the loss of historical space usage logs.
2. Advanced scheduling and operational validations (double-booking prevention, maintenance blocking, and room capacity limits) cannot be enforced through declarative column constraints alone.

The design becomes **Fully Valid** once:
* The `USAGESESSION` referential delete action is changed to `ON DELETE NO ACTION`.
* The database triggers, scalar function constraints, and conditional check constraints detailed in Section 10 are implemented either directly in the database engine or strictly encapsulated within the application service layer.
