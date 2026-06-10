---
name: logical-design
description: Instructs the agent to produce a complete, 3NF logical database design document for MS SQL Server from the ERD.
compatibility: opencode
---

## 1. Purpose
This skill instructs the agent to produce a complete, correct, and normalized Logical Database Design document in Markdown format (`outputs/03-logical-design-G02.md`), derived from the ERD design (`outputs/02-erd-design-G02.md`) and Business Requirement Analysis (`outputs/01-business-requirement-analysis-G02.md`).

## 2. Required Inputs
Before starting, the agent must load and read:
- **Conceptual Design (ERD):** `outputs/02-erd-design-G02.md`
- **Business Requirement Analysis (BRA):** `outputs/01-business-requirement-analysis-G02.md`

## 3. Database Schema Rules (MS SQL Server)
1. **Naming Conventions**:
   - **Table Names**: UPPERCASE singular matching the ERD entities (e.g., `USER`, `SPACE`, `BOOKING`, `USAGESESSION`, `MAINTENANCERECORD`).
   - **Column Names**: Lowercase `snake_case` matching the ERD attributes verbatim.
   - **Junction Tables**: Name the junction table resolving many-to-many relationships in UPPERCASE singular (e.g., `SPACE_FACILITY`).
2. **Junction Table Design**:
   - Resolve the many-to-many relationship `Space_Equipped_With_Facility` using the junction table `SPACE_FACILITY`.
   - The primary key of `SPACE_FACILITY` must be a composite key `(space_code, facility_id)`.
3. **1:1 Relationship Mapping**:
   - For `BOOKING` to `USAGESESSION` (1:1), the primary key of `USAGESESSION` must be `booking_id`, which also serves as the foreign key referencing `BOOKING(booking_id)`.
4. **Referential Integrity Actions (ON DELETE/ON UPDATE)**:
   - For `USAGESESSION` referencing `BOOKING`: Use `ON DELETE CASCADE` and `ON UPDATE CASCADE`.
   - For `SPACE_FACILITY` referencing `SPACE` and `FACILITY`: Use `ON DELETE CASCADE`.
   - For other tables (where `USER` or `SPACE` are referenced): Use `ON DELETE NO ACTION` and `ON UPDATE NO ACTION` (to preserve historical logs).
5. **No Redundant Diagrams**:
   - Skip generating any graphical or text-based schema diagrams (Mermaid or similar) in the logical design document, as the structural relationships have already been fully defined and validated in the Step 2 ERD.

## 4. Constraint Mapping Rules
Ensure the logical design details the following constraints:
1. **Primary Keys (PK)**: Explicitly identify the PK columns for all tables.
2. **Foreign Keys (FK)**: Identify all FK columns, specifying the referenced table and column.
3. **Unique Constraints (UNIQUE)**:
   - `USER(email)`
   - `FACILITY(facility_name)`
4. **Default Constraints (DEFAULT)**:
   - `BOOKING(created_at)`: Defaults to `GETDATE()`.
5. **Check Constraints (CHECK)**:
   - **Value Enums**: Enforce valid role, type, purpose, and status values as defined in the BRA:
     - `USER(role)`: IN ('Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager')
     - `USER(account_status)`: IN ('Active', 'Suspended', 'Inactive')
     - `SPACE(space_type)`: IN ('Auditorium', 'Classroom', 'Computer Laboratory', 'Project Laboratory', 'Meeting Room', 'Student Workspace')
     - `SPACE(current_status)`: IN ('Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired')
     - `BOOKING(purpose)`: IN ('Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event')
     - `BOOKING(booking_status)`: IN ('Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-Show')
     - `MAINTENANCERECORD(problem_type)`: IN ('Projector Failure', 'Air-Conditioning Issue', 'Cleaning Issue', 'Furniture Damage', 'Network Issue', 'Other')
     - `MAINTENANCERECORD(maintenance_status)`: IN ('Reported', 'In Progress', 'Resolved', 'Cancelled')
   - **Range/Logic Rules**:
     - `SPACE(capacity)`: > 0
     - `BOOKING(expected_participants)`: > 0
     - `BOOKING(requested_end)`: > `requested_start`
     - `USAGESESSION(actual_end)`: > `actual_start` (if not NULL)
     - `MAINTENANCERECORD(completion_time)`: > `start_time` (if not NULL)

## 5. Output Format
Save the output to `outputs/03-logical-design-G02.md` using the following Markdown layout:

```markdown
# Step 3: Logical Database Design — Campus Space Management System

---

## 1. Relational Schema Mapping Decisions

<A paragraph summarizing the mapping strategy: table/column naming conventions, junction table resolution for M:N, 1:1 mapping design, and referential actions.>

---

## 2. Table Schema Specifications

### 2.1. Table: USER
| Column Name | SQL Server Data Type | Nullability | Key | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |

### 2.2. Table: SPACE
...
### 2.3. Table: FACILITY
...
### 2.4. Table: SPACE_FACILITY
...
### 2.5. Table: BOOKING
...
### 2.6. Table: USAGESESSION
...
### 2.7. Table: MAINTENANCERECORD
...

---

## 3. Check and Constraint Specifications
<List the SQL CHECK, UNIQUE, and DEFAULT constraint declarations for all tables.>

---

## 4. Traceability Matrix
| Table Name | Column Name | ERD Attribute Source | BRA Requirement Reference | Notes |
| :--- | :--- | :--- | :--- | :--- |
```
