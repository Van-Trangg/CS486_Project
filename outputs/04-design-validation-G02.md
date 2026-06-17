# Step 4: Database Design Validation

---

## 1. Validation Scope

**Documents Reviewed:**
- `outputs/01-business-requirement-analysis-G02.md` (BRA) — 22 business rules, 6 entities, 10 relationships, 9 assumptions
- `outputs/02-erd-design-G02.md` (ERD) — 6 entities, 10 relationships in Mermaid `erDiagram` notation
- `outputs/03-logical-design-G02.md` (Logical Design) — 7 tables, 18 CHECK constraints, 3 UNIQUE constraints, 3 DEFAULT constraints, 9 triggers, 1 UDF

**Validation Objective:** Determine whether the Logical Database Design correctly represents the ERD, preserves BRA requirements, enforces business rules, and maintains traceability.

**DBMS Target:** Microsoft SQL Server

---

## 2. Entity Coverage Validation

### Entity-to-Table Mapping

| # | ERD Entity | Corresponding Table | Status | Notes |
|---|-----------|-------------------|--------|-------|
| 1 | `USER` | `USER` | ✅ Present | All attributes match ERD §2. |
| 2 | `SPACE` | `SPACE` | ✅ Present | All attributes match ERD §2. |
| 3 | `FACILITY` | `FACILITY` | ✅ Present | All attributes match ERD §2. |
| 4 | `BOOKING` | `BOOKING` | ✅ Present | All attributes match ERD §2. |
| 5 | `USAGESESSION` | `USAGESESSION` | ✅ Present | All attributes match ERD §2. |
| 6 | `MAINTENANCERECORD` | `MAINTENANCERECORD` | ✅ Present | All attributes match ERD §2. |
| — | *(none)* | `SPACE_FACILITY` | ✅ Justified | Junction table resolving the M:N `Space_Equipped_With_Facility` relationship (BRA §5.4). Standard relational mapping. Includes additional operational attributes (`quantity`, `operation_status`, `description`) not present in ERD — justified as they support facility inventory tracking. |

**Result:** All 6 ERD entities are fully covered. One additional table (`SPACE_FACILITY`) exists and is justified as the junction table for the M:N relationship. No omissions. No unjustified tables.

---

## 3. Relationship Mapping Validation

### ERD-to-Relational Mapping

| # | ERD Relationship | ERD Cardinality | Expected Mapping | Logical Design Implementation | Status | Notes |
|---|-----------------|----------------|-----------------|------------------------------|--------|-------|
| 1 | User_Requests_Booking | (0,N):(1,1) | FK on N-side (Booking) | `BOOKING.requester_id` FK → `USER(user_id)`, NOT NULL | ✅ Correct | |
| 2 | User_Approves_Booking | (0,N):(0,1) | FK on N-side (Booking) | `BOOKING.approver_id` FK → `USER(user_id)`, NULLABLE | ✅ Correct | Nullable FK correctly models optional participation |
| 3 | Space_Hosts_Booking | (0,N):(1,1) | FK on N-side (Booking) | `BOOKING.space_code` FK → `SPACE(space_code)`, NOT NULL | ✅ Correct | |
| 4 | Space_Equipped_With_Facility | (0,M):(0,N) | Junction Table | `SPACE_FACILITY(space_code, facility_id)` composite PK/FK | ✅ Correct | M:N correctly resolved via junction table |
| 5 | Booking_Has_UsageSession | (0,1):(1,1) | Shared PK or UNIQUE FK | `USAGESESSION.booking_id` as PK and FK → `BOOKING(booking_id)` | ✅ Correct | 1:1 mapped via shared primary key |
| 6 | User_ChecksIn_UsageSession | (0,N):(1,1) | FK on N-side (UsageSession) | `USAGESESSION.check_in_staff_id` FK → `USER(user_id)`, NOT NULL | ✅ Correct | |
| 7 | User_ChecksOut_UsageSession | (0,N):(0,1) | FK on N-side (UsageSession) | `USAGESESSION.check_out_staff_id` FK → `USER(user_id)`, NULLABLE | ✅ Correct | Nullable FK correctly models optional checkout |
| 8 | Space_Requires_Maintenance | (0,N):(1,1) | FK on N-side (MaintenanceRecord) | `MAINTENANCERECORD.space_code` FK → `SPACE(space_code)`, NOT NULL | ✅ Correct | |
| 9 | User_Reports_Maintenance | (0,N):(1,1) | FK on N-side (MaintenanceRecord) | `MAINTENANCERECORD.reporter_id` FK → `USER(user_id)`, NOT NULL | ✅ Correct | |
| 10 | User_Assigned_To_Maintenance | (0,N):(0,1) | FK on N-side (MaintenanceRecord) | `MAINTENANCERECORD.assigned_staff_id` FK → `USER(user_id)`, NULLABLE | ✅ Correct | Nullable FK models unassigned maintenance |

**Result:** All 10 ERD relationships are correctly mapped. Cardinality is preserved. Foreign key placement is correct. The M:N relationship uses a junction table; the 1:1 relationship uses shared primary key. No incorrect mappings identified.

---

## 4. Key Validation

### Primary Keys

| Table | Primary Key | Type | Validation | Notes |
|-------|------------|------|-----------|-------|
| `USER` | `user_id` (`VARCHAR(50)`) | Natural key | ✅ Valid | Unique university account identifier. Matches BRA §4.1. |
| `SPACE` | `space_code` (`VARCHAR(50)`) | Natural key | ✅ Valid | Unique room identifier. Matches BRA §4.2. |
| `FACILITY` | `facility_id` (`INT IDENTITY`) | Surrogate key | ✅ Valid | Auto-incrementing. Matches BRA §4.3. |
| `SPACE_FACILITY` | (`space_code`, `facility_id`) | Composite key | ✅ Valid | Both components are foreign keys. Prevents duplicate facility assignments. |
| `BOOKING` | `booking_id` (`INT IDENTITY`) | Surrogate key | ✅ Valid | Auto-incrementing. Matches BRA §4.4. |
| `USAGESESSION` | `booking_id` (`INT`) | Shared PK (FK) | ✅ Valid | Implements 1:1 relationship with BOOKING. Matches BRA §4.5. |
| `MAINTENANCERECORD` | `maintenance_id` (`INT IDENTITY`) | Surrogate key | ✅ Valid | Auto-incrementing. Matches BRA §4.6. |

### Foreign Keys

| Table | Foreign Key | References | Nullable | Validation | Notes |
|-------|-----------|-----------|----------|-----------|-------|
| `BOOKING` | `space_code` | `SPACE(space_code)` | No | ✅ Valid | |
| `BOOKING` | `requester_id` | `USER(user_id)` | No | ✅ Valid | |
| `BOOKING` | `approver_id` | `USER(user_id)` | Yes | ✅ Valid | Nullable until booking is reviewed |
| `USAGESESSION` | `booking_id` | `BOOKING(booking_id)` | No | ✅ Valid | Shared PK/FK for 1:1 |
| `USAGESESSION` | `check_in_staff_id` | `USER(user_id)` | No | ✅ Valid | |
| `USAGESESSION` | `check_out_staff_id` | `USER(user_id)` | Yes | ✅ Valid | Nullable until checkout occurs |
| `SPACE_FACILITY` | `space_code` | `SPACE(space_code)` | No | ✅ Valid | Composite PK part 1 |
| `SPACE_FACILITY` | `facility_id` | `FACILITY(facility_id)` | No | ✅ Valid | Composite PK part 2 |
| `MAINTENANCERECORD` | `space_code` | `SPACE(space_code)` | No | ✅ Valid | |
| `MAINTENANCERECORD` | `reporter_id` | `USER(user_id)` | No | ✅ Valid | |
| `MAINTENANCERECORD` | `assigned_staff_id` | `USER(user_id)` | Yes | ✅ Valid | Nullable until staff assigned |

### Candidate / Alternate Keys

| Table | Alternate Key | Constraint | Validation | Notes |
|-------|--------------|-----------|-----------|-------|
| `USER` | `email` | `UQ_USER_EMAIL` UNIQUE | ✅ Valid | Matches BRA §4.1 candidate identifier |
| `FACILITY` | `facility_name` | `UQ_FACILITY_NAME` UNIQUE | ✅ Valid | Matches BRA §4.3 candidate identifier |

**Result:** All keys are correctly defined. Primary keys uniquely identify records. Foreign keys correctly support relationships. The composite key in `SPACE_FACILITY` is appropriate for the junction table. Alternate keys are enforced with UNIQUE constraints.

---

## 5. Constraint Validation

### 5.1. NOT NULL Constraints

| Table | Column | Nullable | Validation | Evidence |
|-------|--------|----------|-----------|----------|
| `USER` | `phone_number` | NULL | ✅ Aligns with BRA | BRA §4.1 specifies nullable contact phone |
| `USER` | All other columns | NOT NULL | ✅ Correct | Core identity fields mandatory |
| `SPACE` | All columns | NOT NULL | ✅ Correct | Core space information mandatory |
| `FACILITY` | `facility_description` | NULL | ✅ Aligns with BRA | BRA §4.3 allows nullable description |
| `FACILITY` | `facility_id`, `facility_name` | NOT NULL | ✅ Correct | |
| `BOOKING` | `approver_id`, `decision_time`, `decision_note`, `rejection_reason` | NULL | ✅ Aligns with BRA | Nullable until approval/rejection decision made |
| `USAGESESSION` | `check_out_staff_id`, `actual_end`, `final_condition`, `usage_notes` | NULL | ✅ Aligns with BRA | Nullable until checkout occurs |
| `MAINTENANCERECORD` | `assigned_staff_id`, `completion_time`, `result_note` | NULL | ✅ Aligns with BRA | Nullable until assignment/completion |

### 5.2. CHECK Constraints

| Constraint | Table | Rule | Validation | BRA Reference |
|-----------|-------|------|-----------|--------------|
| `CK_USER_ROLE` | `USER` | `role IN ('Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager')` | ✅ Correct | BR-3 (BRA §7.3) |
| `CK_USER_ACCOUNT_STATUS` | `USER` | `account_status IN ('Active', 'Suspended', 'Inactive')` | ✅ Correct | BR-2 (BRA §7.2) |
| `CK_SPACE_TYPE` | `SPACE` | `space_type IN ('Auditorium', 'Classroom', 'Computer Laboratory', 'Project Laboratory', 'Meeting Room', 'Student Workspace')` | ✅ Correct | BR-5 (BRA §7.5) |
| `CK_SPACE_CAPACITY` | `SPACE` | `capacity > 0` | ✅ Correct | BR-5 (BRA §7.5) |
| `CK_SPACE_CURRENT_STATUS` | `SPACE` | `current_status IN ('Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired')` | ✅ Correct | BR-6 (BRA §7.6) |
| `CK_SPACE_FACILITY_QUANTITY` | `SPACE_FACILITY` | `quantity > 0` | ✅ Correct | Operational attribute |
| `CK_SPACE_FACILITY_STATUS` | `SPACE_FACILITY` | `operation_status IN ('Operational', 'Partially Operational', 'Broken')` | ✅ Correct | Operational attribute |
| `CK_BOOKING_TIME_ORDER` | `BOOKING` | `requested_end > requested_start` | ✅ Correct | BR-8 (BRA §7.8), Assumption 6 |
| `CK_BOOKING_PARTICIPANTS` | `BOOKING` | `expected_participants > 0` | ✅ Correct | BR-8 (BRA §7.8) |
| `CK_BOOKING_PURPOSE` | `BOOKING` | `purpose IN ('Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event')` | ✅ Correct | BR-9 (BRA §7.9) |
| `CK_BOOKING_STATUS` | `BOOKING` | `booking_status IN ('Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-Show')` | ✅ Correct | BR-10 (BRA §7.10) |
| `CK_BOOKING_FUTURE_START` | `BOOKING` | `requested_start >= created_at` | ⚠️ Partial | BR-20 (BRA §7.20) — See §5.5 |
| `CK_BOOKING_REJECTION_REASON` | `BOOKING` | `booking_status <> 'Rejected' OR rejection_reason IS NOT NULL` | ✅ Correct | BR-14 (BRA §7.14) |
| `CK_BOOKING_CAPACITY_LIMIT` | `BOOKING` | `dbo.fn_CheckSpaceCapacity(space_code, expected_participants) = 1` | ✅ Correct | BR-19 (BRA §7.19) |
| `CK_USAGE_TIME_ORDER` | `USAGESESSION` | `actual_end > actual_start` | ✅ Correct | BR-16 (BRA §7.16) |
| `CK_MAINTENANCE_TIME_ORDER` | `MAINTENANCERECORD` | `completion_time > start_time` | ✅ Correct | BR-17 (BRA §7.17) |
| `CK_MAINTENANCE_STATUS` | `MAINTENANCERECORD` | `maintenance_status IN ('Reported', 'In Progress', 'Resolved', 'Cancelled')` | ✅ Correct | BR-17 (BRA §7.17) |
| `CK_MAINTENANCE_PROBLEM_TYPE` | `MAINTENANCERECORD` | `problem_type IN ('Projector Failure', 'Air-Conditioning Issue', 'Cleaning Issue', 'Furniture Damage', 'Network Issue', 'Other')` | ✅ Correct | BR-17 (BRA §7.17) |

### 5.3. DEFAULT Constraints

| Constraint | Table | Column | Default Value | Validation |
|-----------|-------|--------|--------------|-----------|
| `DF_SPACE_FACILITY_QUANTITY` | `SPACE_FACILITY` | `quantity` | `1` | ✅ Correct |
| `DF_SPACE_FACILITY_STATUS` | `SPACE_FACILITY` | `operation_status` | `'Operational'` | ✅ Correct |
| `DF_BOOKING_CREATED_AT` | `BOOKING` | `created_at` | `GETDATE()` | ✅ Correct |

### 5.4. UNIQUE Constraints

| Constraint | Table | Column | Validation | Notes |
|-----------|-------|--------|-----------|-------|
| `UQ_USER_EMAIL` | `USER` | `email` | ✅ Correct | Alternate key per BRA §4.1 |
| `UQ_FACILITY_NAME` | `FACILITY` | `facility_name` | ✅ Correct | Alternate key per BRA §4.3 |

### 5.5. Referential Integrity Actions

| Parent Table | Child Table | FK Column(s) | Action | Validation |
|-------------|------------|-------------|--------|-----------|
| `BOOKING` | `USAGESESSION` | `booking_id` | ON DELETE NO ACTION, ON UPDATE NO ACTION | ✅ Correct — Protects historical usage session data |
| `SPACE` | `SPACE_FACILITY` | `space_code` | ON DELETE CASCADE, ON UPDATE NO ACTION | ✅ Correct — Junction table cleanup; aligns with soft-deletion policy (space records are never physically deleted; cascade only triggers on actual deletion) |
| `FACILITY` | `SPACE_FACILITY` | `facility_id` | ON DELETE CASCADE, ON UPDATE NO ACTION | ✅ Correct — Junction table cleanup |
| `USER` | `BOOKING` (requester) | `requester_id` | ON DELETE NO ACTION | ✅ Correct — Protects historical booking records |
| `USER` | `BOOKING` (approver) | `approver_id` | ON DELETE NO ACTION | ✅ Correct |
| `USER` | `USAGESESSION` (check-in) | `check_in_staff_id` | ON DELETE NO ACTION | ✅ Correct |
| `USER` | `USAGESESSION` (check-out) | `check_out_staff_id` | ON DELETE NO ACTION | ✅ Correct |
| `USER` | `MAINTENANCERECORD` (reporter) | `reporter_id` | ON DELETE NO ACTION | ✅ Correct |
| `USER` | `MAINTENANCERECORD` (assigned) | `assigned_staff_id` | ON DELETE NO ACTION | ✅ Correct |
| `SPACE` | `BOOKING` | `space_code` | ON DELETE NO ACTION | ✅ Correct — Protects historical booking records |
| `SPACE` | `MAINTENANCERECORD` | `space_code` | ON DELETE NO ACTION | ✅ Correct — Protects historical maintenance records |

**Conflict Check:** All referential actions are internally consistent. No conflicting rules found between related tables. The `ON DELETE CASCADE` on `SPACE_FACILITY` is appropriate for a junction table and does not conflict with history preservation because soft-deletion policy prevents physical deletion of parent records.

### 5.6. Referential Integrity & History Preservation (Stage 4.2)

**Tables storing transactional history:** `BOOKING`, `USAGESESSION`, `MAINTENANCERECORD`

**Assessment:** None of the foreign keys referencing these tables use `ON DELETE CASCADE`. All use `ON DELETE NO ACTION`, which aligns with the BRA requirement for historical record preservation (BR-18, BRA §7.18) and the soft-deletion policy (Assumption 5).

**Result: ✅ No high-risk findings.** Historical records are protected.

### 5.7. Future-Time Constraints (Stage 4.3)

**Column assessed:** `BOOKING.requested_start` — intended to represent a future scheduled booking time.

**Mechanisms present:**
1. `CK_BOOKING_FUTURE_START` CHECK constraint: `requested_start >= created_at` — this is a **weak approximation** because `created_at` defaults to `GETDATE()` but could be manually overridden.
2. `TR_BOOKING_FUTURE_START_ENFORCEMENT` trigger (AFTER INSERT, UPDATE): Enforces `requested_start < GETDATE()` only for non-staff users, with role exemption for `Facility Staff` and `Facility Manager` — aligns with BR-20 (BRA §7.20).

**Assessment:** The CHECK constraint alone would be insufficient, but the trigger provides the actual enforcement. In Microsoft SQL Server, `GETDATE()` cannot be used in CHECK constraints, so the trigger-based approach is correct.

**Risk Level: ⚠️ Medium** — The `CK_BOOKING_FUTURE_START` CHECK constraint is weakly defined (`requested_start >= created_at` lacks robustness if `created_at` is manually set). The trigger provides adequate enforcement for non-staff users. No constraint exists to prevent backdating of `MAINTENANCERECORD.start_time`, though no requirement explicitly demands this.

**Recommendation:** Consider adding an `AFTER INSERT, UPDATE` trigger on `MAINTENANCERECORD` to prevent backdated `start_time` values if this becomes a business requirement.

---

## 6. Business Rule Coverage Analysis

| # | Business Rule | BRA Reference | Enforcement Mechanism(s) | Enforcement Level | Justification |
|---|--------------|--------------|------------------------|-------------------|--------------|
| 1 | **Mandatory Account Rule** — Every user must have a valid university account | §7.1 (BR-1) | PK on `user_id` (NOT NULL), `UQ_USER_EMAIL` UNIQUE | ✅ **Fully Enforced** | PK ensures non-null, unique identifier. Email UNIQUE ensures alternate identification. |
| 2 | **Standard User Information** — Record user ID, name, email, phone, role, department, account status | §7.2 (BR-2) | Column definitions with NOT NULL/data types, CHECK constraints on `role` and `account_status` | ✅ **Fully Enforced** | All required columns present with appropriate types. Nullable `phone_number` aligns with BRA. |
| 3 | **User Roles** — Constrained to predefined set | §7.3 (BR-3) | `CK_USER_ROLE` CHECK constraint | ✅ **Fully Enforced** | |
| 4 | **Space Unique Code** — Each room has unique identifier | §7.4 (BR-4) | PK on `space_code` | ✅ **Fully Enforced** | |
| 5 | **Space Attributes** — Store name, type, building, floor, room, capacity, status, policy | §7.5 (BR-5) | Column definitions, `CK_SPACE_TYPE`, `CK_SPACE_CAPACITY`, `CK_SPACE_CURRENT_STATUS` | ✅ **Fully Enforced** | |
| 6 | **Space Statuses** — Predefined set | §7.6 (BR-6) | `CK_SPACE_CURRENT_STATUS` CHECK constraint | ✅ **Fully Enforced** | |
| 7 | **Facilities Catalog and Mapping** — Track facilities in spaces | §7.7 (BR-7) | `FACILITY` table + `SPACE_FACILITY` junction table with FKs | ✅ **Fully Enforced** | |
| 8 | **Booking Submission Requirements** — Space, start/end, purpose, participants | §7.8 (BR-8) | NOT NULL constraints on all required columns | ✅ **Fully Enforced** | |
| 9 | **Booking Purposes** — Predefined list | §7.9 (BR-9) | `CK_BOOKING_PURPOSE` CHECK constraint | ✅ **Fully Enforced** | |
| 10 | **Booking Status List** — Predefined set | §7.10 (BR-10) | `CK_BOOKING_STATUS` CHECK constraint | ✅ **Fully Enforced** | |
| 11 | **Double Booking Prevention** — No overlapping approved bookings for same space | §7.11 (BR-11) | `TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE` trigger | ✅ **Fully Enforced** | Enforced at DB level via trigger; application-level check recommended for UX. |
| 12 | **Unavailable Spaces Blocked** — No booking for maintenance/closed/retired spaces | §7.12 (BR-12) | `TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE` trigger (checking SPACE status + MAINTENANCERECORD overlap); `TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP` for bidirectional protection | ✅ **Fully Enforced** | Bidirectional overlap prevention between bookings and maintenance records. |
| 13 | **Approval Tracking** — Record approver, decision time, notes | §7.13 (BR-13) | Columns `approver_id`, `decision_time`, `decision_note`; `TR_BOOKING_VALIDATE_APPROVER_ROLE` for role enforcement | ✅ **Fully Enforced** | |
| 14 | **Rejection Justification** — Store reason for rejection | §7.14 (BR-14) | `CK_BOOKING_REJECTION_REASON` CHECK constraint | ✅ **Fully Enforced** | Guarantees non-null rejection_reason when status = 'Rejected'. |
| 15 | **Usage Session Check-in** — Log start time, staff, initial condition | §7.15 (BR-15) | `USAGESESSION` columns `check_in_staff_id`, `actual_start`, `initial_condition` (all NOT NULL); `TR_USAGESESSION_VALIDATE_STAFF_ROLES` for role enforcement | ✅ **Fully Enforced** | |
| 16 | **Usage Session Completion** — Log end time, final condition, usage notes | §7.16 (BR-16) | `USAGESESSION` columns `check_out_staff_id`, `actual_end`, `final_condition`, `usage_notes` (nullable); `CK_USAGE_TIME_ORDER` for temporal validity | ✅ **Fully Enforced** | |
| 17 | **Maintenance Logging** — Track space, reporter, assigned staff, timestamps, status, results | §7.17 (BR-17) | `MAINTENANCERECORD` table with CHECK constraints and `TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE` trigger | ✅ **Fully Enforced** | |
| 18 | **Historical and Operational Reports** — Preserve logs, support viewing history | §7.18 (BR-18) | `ON DELETE NO ACTION` on all historical FKs; `TR_BOOKING_STATUS_AND_AUDIT` prevents deletion of cancelled bookings | ⚠️ **Partially Enforced** | The database schema preserves data (prevents deletion). Actual report viewing, querying, and UI are application-layer responsibilities. The schema enables but does not enforce reporting. |
| 19 | **Capacity Limit Rule** — Participants ≤ space capacity | §7.19 (BR-19) | `CK_BOOKING_CAPACITY_LIMIT` via `dbo.fn_CheckSpaceCapacity` UDF | ✅ **Fully Enforced** | UDF integrated into CHECK constraint validates against current SPACE.capacity. |
| 20 | **Future Booking Requirement** — Non-staff users can only book future time slots | §7.20 (BR-20) | `CK_BOOKING_FUTURE_START` CHECK (weak); `TR_BOOKING_FUTURE_START_ENFORCEMENT` trigger (strong) with role exemption | ✅ **Fully Enforced** | Trigger provides actual enforcement. CHECK constraint is a secondary safeguard. |
| 21 | **Booking Cancellation Rule** — Cancel only from Pending/Approved; keep cancelled records | §7.21 (BR-21) | `TR_BOOKING_STATUS_AND_AUDIT` trigger | ✅ **Fully Enforced** | Trigger enforces state machine and protects deleted/cancelled records. |
| 22 | **Booking Modification Rule** — No changes to space/start/end after approval | §7.22 (BR-22) | `TR_BOOKING_LOCK_APPROVED_FIELDS` trigger | ✅ **Fully Enforced** | Trigger compares old/new values and blocks modification post-approval. |

### Summary

| Enforcement Level | Count | Business Rules |
|-----------------|-------|---------------|
| ✅ **Fully Enforced** | 21 | BR-1 through BR-17, BR-19 through BR-22 |
| ⚠️ **Partially Enforced** | 1 | BR-18 (Historical and Operational Reports) |
| ❌ **Not Enforced** | 0 | — |

**BR-18 Justification:** The database preserves historical records through referential integrity (`ON DELETE NO ACTION`) and prevents deletion of cancelled bookings (trigger). However, "viewing booking history, upcoming bookings, spaces under maintenance, and no-show bookings" (BRA §7.18) requires application-layer query logic and UI. The schema enables these queries but cannot enforce them at the database level. This is an inherent limitation of database design — reporting is an application responsibility.

---

## 7. Traceability Validation

### Requirement → ERD → Schema → Constraint

| BRA Requirement | ERD Entity/Relationship | Relational Table(s) | Key Constraints | Status |
|----------------|------------------------|-------------------|----------------|--------|
| §3.1 User account | USER (entity) | USER | PK, UNIQUE(email), CHECK(role), CHECK(account_status) | ✅ Complete |
| §3.2 Space catalog | SPACE (entity) | SPACE | PK, CHECK(type), CHECK(capacity), CHECK(status) | ✅ Complete |
| §3.3 Facility catalog | FACILITY (entity) | FACILITY | PK, UNIQUE(name) | ✅ Complete |
| §3.4 Booking requests | BOOKING (entity) | BOOKING | PK, FKs, CHECK(status), CHECK(purpose), CHECK(time_order), CHECK(capacity) | ✅ Complete |
| §3.5 Usage sessions | USAGESESSION (entity) | USAGESESSION | PK/FK(booking_id), FKs(user), CHECK(time_order) | ✅ Complete |
| §3.6 Maintenance | MAINTENANCERECORD (entity) | MAINTENANCERECORD | PK, FKs, CHECK(status), CHECK(problem_type), CHECK(time_order) | ✅ Complete |
| §5.1 User_Requests_Booking | Relationship 1 | BOOKING.requester_id → USER | FK, NOT NULL | ✅ Complete |
| §5.2 User_Approves_Booking | Relationship 2 | BOOKING.approver_id → USER | FK, NULLABLE, TR_BOOKING_VALIDATE_APPROVER_ROLE | ✅ Complete |
| §5.3 Space_Hosts_Booking | Relationship 3 | BOOKING.space_code → SPACE | FK, NOT NULL | ✅ Complete |
| §5.4 Space_Contains_Facility | Relationship 4 | SPACE_FACILITY | Composite PK/FK, CASCADE | ✅ Complete |
| §5.5 Booking_Has_UsageSession | Relationship 5 | USAGESESSION.booking_id → BOOKING | PK/FK, NO ACTION | ✅ Complete |
| §5.6 User_ChecksIn_UsageSession | Relationship 6 | USAGESESSION.check_in_staff_id → USER | FK, NOT NULL, TR_USAGESESSION_VALIDATE_STAFF_ROLES | ✅ Complete |
| §5.7 User_ChecksOut_UsageSession | Relationship 7 | USAGESESSION.check_out_staff_id → USER | FK, NULLABLE, TR_USAGESESSION_VALIDATE_STAFF_ROLES | ✅ Complete |
| §5.8 Space_Requires_Maintenance | Relationship 8 | MAINTENANCERECORD.space_code → SPACE | FK, NOT NULL | ✅ Complete |
| §5.9 User_Reports_Maintenance | Relationship 9 | MAINTENANCERECORD.reporter_id → USER | FK, NOT NULL | ✅ Complete |
| §5.10 User_Assigned_To_Maintenance | Relationship 10 | MAINTENANCERECORD.assigned_staff_id → USER | FK, NULLABLE, TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE | ✅ Complete |
| §7.11 BR-11 (Double booking) | Relationship 3 | BOOKING | TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE | ✅ Complete |
| §7.12 BR-12 (Unavailable spaces) | Relationships 3, 8 | BOOKING, MAINTENANCERECORD | TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE, TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP | ✅ Complete |
| §7.19 BR-19 (Capacity) | SPACE.capacity, BOOKING.expected_participants | BOOKING | CK_BOOKING_CAPACITY_LIMIT using fn_CheckSpaceCapacity | ✅ Complete |
| §7.20 BR-20 (Future booking) | BOOKING.requested_start | BOOKING | CK_BOOKING_FUTURE_START, TR_BOOKING_FUTURE_START_ENFORCEMENT | ✅ Complete |
| §7.21 BR-21 (Cancellation) | BOOKING.booking_status | BOOKING | TR_BOOKING_STATUS_AND_AUDIT | ✅ Complete |
| §7.22 BR-22 (Modification lock) | BOOKING | BOOKING | TR_BOOKING_LOCK_APPROVED_FIELDS | ✅ Complete |
| Assumption 1 (Role-based permissions) | Multiple relationships | BOOKING, USAGESESSION, MAINTENANCERECORD | TR_BOOKING_VALIDATE_APPROVER_ROLE, TR_USAGESESSION_VALIDATE_STAFF_ROLES, TR_MAINTENANCE_VALIDATE_ASSIGNED_ROLE | ✅ Complete |
| Assumption 9 (UsageSession creation) | USAGESESSION | USAGESESSION | TR_USAGESESSION_CHECK_BOOKING_STATUS | ✅ Complete |

**Result:** All BRA requirements, ERD entities, and ERD relationships are fully traceable to their schema-level counterparts. The logical design's traceability matrix (§4) covers every column and constraint. No missing traceability links identified.

---

## 8. Strengths

1. **Complete Entity Coverage:** All 6 ERD entities map directly to relational tables with matching attribute sets.

2. **Correct Relationship Resolution:** All 10 ERD relationships are mapped with correct cardinality, FK placement, and participation handling.
   - M:N (Space ↔ Facility) correctly resolved via `SPACE_FACILITY` junction table.
   - 1:1 (Booking ↔ UsageSession) correctly mapped via shared primary key.

3. **Comprehensive Trigger Coverage:** Complex business rules are enforced at the database level through 9 triggers:
   - Overlap prevention (bidirectional between bookings and maintenance)
   - Role-based permission validation (approvers, check-in/out staff, assigned technicians)
   - Cancellation state machine enforcement
   - Booking modification locks post-approval
   - Future booking enforcement with role exemption
   - Usage session booking status validation

4. **Appropriate Referential Integrity:** Historical records are protected through `ON DELETE NO ACTION` on all transactional tables. `ON DELETE CASCADE` is limited to the junction table (`SPACE_FACILITY`) where it is semantically appropriate.

5. **UDF-Integrated Capacity Check:** The `dbo.fn_CheckSpaceCapacity` function is embedded in a CHECK constraint, providing robust participant validation against current space capacity.

6. **Domain Integrity:** All constrained values (roles, statuses, purposes, problem types) are validated through CHECK constraints with the exact enumerated values from the BRA.

7. **Strong Traceability:** The logical design includes a detailed traceability matrix tracing every column and procedural object back to specific BRA sections and ERD elements.

---

## 9. Issues and Risks

### ⚠️ Medium Risk: `CK_BOOKING_FUTURE_START` CHECK constraint is weakly defined

- **Finding:** Constraint `CK_BOOKING_FUTURE_START` enforces `requested_start >= created_at`. While `created_at` defaults to `GETDATE()`, it could be manually overridden, bypassing the future-time check.
- **Mitigation:** The trigger `TR_BOOKING_FUTURE_START_ENFORCEMENT` provides actual enforcement against `GETDATE()` for non-staff users. The CHECK constraint is a secondary safeguard.
- **Recommendation:** Acceptable as-is. The trigger provides the primary enforcement. The CHECK constraint serves as a belt-and-suspenders mechanism. No schema change needed.

### ⚠️ Medium Risk: No future-time constraint on `MAINTENANCERECORD.start_time`

- **Finding:** `MAINTENANCERECORD.start_time` has no mechanism preventing past-dated entries. Maintenance records could theoretically be backdated.
- **Context:** The BRA does not explicitly require future-only maintenance start times. Maintenance can be logged retroactively (e.g., reporting an issue after it began).
- **Recommendation:** Add an AFTER INSERT, UPDATE trigger if stakeholder requirements evolve to require future-only maintenance scheduling.

### ✅ Low Risk: `SPACE_FACILITY` uses `ON DELETE CASCADE`

- **Finding:** The junction table uses `ON DELETE CASCADE` on foreign keys to both `SPACE` and `FACILITY`.
- **Context:** The soft-deletion policy (Assumption 5) prevents physical deletion of spaces and facilities, so CASCADE will not trigger in normal operation. The CASCADE is only activated during administrative cleanup.
- **Recommendation:** No change needed. The CASCADE correctly prevents orphaned junction records.

### ✅ Low Risk: `TR_BOOKING_STATUS_AND_AUDIT` DELETE detection pattern

- **Finding:** The trigger detects DELETE operations via `NOT EXISTS (SELECT 1 FROM inserted)`, which is a standard and correct SQL trigger pattern.
- **Recommendation:** No change needed. This is a well-established technique.

---

## 10. Recommendations

| # | Recommendation | Priority | Affected Component | Justification |
|---|---------------|----------|-------------------|--------------|
| 1 | **No schema changes required** | — | — | The logical design is valid as-is. All recommendations below are optional enhancements. |
| 2 | Consider adding a trigger-level future-time check on `MAINTENANCERECORD.start_time` if business requirements evolve | Low | `MAINTENANCERECORD` | Currently no requirement prohibits backdating maintenance records, but adding this check would ensure consistency with the booking future-time pattern. |
| 3 | Ensure the application layer enforces the check-in window (30 minutes) and "No-Show" timeout (Assumption 3) | Medium | Application Logic | These are procedural rules that cannot be enforced at the database level. The application must implement the timeout and status transition logic. |
| 4 | Confirm the `CK_BOOKING_FUTURE_START` CHECK constraint is retained in DDL despite being a weaker constraint | Low | `BOOKING` | The constraint is harmless and provides defense-in-depth alongside the trigger. Retain it in the DDL. |
| 5 | Validate that the `fn_CheckSpaceCapacity` UDF handles the null/missing space scenario gracefully (returns 0 or prevents insert) | Low | `BOOKING` | The UDF selects `capacity` from `SPACE` — if `space_code` is invalid, `@Capacity` will be NULL and `@Participants > NULL` evaluates to UNKNOWN, so `@Result` stays 1. Consider adding a NULL check in the UDF. |

---

## 11. Conclusion

### Validation Verdict: ✅ **Fully Valid**

The Logical Database Design is **fully valid** with no blocking issues.

**Basis for Verdict:**

| Criterion | Status |
|-----------|--------|
| Entity Coverage | ✅ All 6 ERD entities present; 1 justified additional table |
| Relationship Mapping | ✅ All 10 relationships correctly mapped |
| Key Selection | ✅ All primary, foreign, and alternate keys correctly defined |
| Constraint Completeness | ✅ 18 CHECK, 3 DEFAULT, 3 UNIQUE constraints, 9 triggers, 1 UDF |
| Referential Integrity | ✅ Consistent; historical data protected via ON DELETE NO ACTION |
| Business Rule Enforcement | ✅ 21 of 22 rules fully enforced at DB level; 1 partially enforced (reporting — inherent application layer responsibility) |
| Traceability | ✅ Complete traceability from BRA → ERD → Schema → Constraint |

The design is ready to proceed to **Step 5: Database Implementation (DDL)** with no mandatory fixes required. The two medium-risk findings (weak future-start CHECK constraint, no future-time check on maintenance) are acceptable given existing trigger mitigation and the absence of explicit requirements for maintenance backdating prevention.
