# Step 4: Database Design Validation

---

## 1. Validation Scope

This report validates the Logical Database Design (Step 3) against:
- **BRA**: `outputs/01-business-requirement-analysis-G02.md` — 6 entities, 10 relationships, 21 business rules, 9 assumptions.
- **ERD**: `outputs/02-erd-design-G02.md` — 6 entities, 10 relationships in Mermaid `erDiagram` crow's-foot notation.
- **Logical Design**: `outputs/03-logical-design-G02.md` — 7 tables (6 entity tables + 1 junction table), with full schema specs, constraints, procedural objects, and traceability matrix.

**Methodology**: Each stage evaluates a specific dimension (entity coverage, relationship mapping, key correctness, constraint validity, business rule enforcement, traceability) and concludes with evidence-based findings.

---

## 2. Entity Coverage Validation

### Stage 1.1 — ERD-to-Table Mapping

| # | ERD Entity | Corresponding Table | Status | Notes |
|---|------------|-------------------|--------|-------|
| 1 | `USER` | `USER` (§2.1) | ✅ Present | Direct mapping. |
| 2 | `SPACE` | `SPACE` (§2.2) | ✅ Present | Direct mapping. |
| 3 | `FACILITY` | `FACILITY` (§2.3) | ✅ Present | Direct mapping. |
| 4 | `BOOKING` | `BOOKING` (§2.5) | ✅ Present | Direct mapping. |
| 5 | `USAGESESSION` | `USAGESESSION` (§2.6) | ✅ Present | Direct mapping. |
| 6 | `MAINTENANCERECORD` | `MAINTENANCERECORD` (§2.7) | ✅ Present | Direct mapping. |
| — | *Junction Table* | `SPACE_FACILITY` (§2.4) | ✅ Justified | Resolves M:N relationship `Space_Contains_Facility` (BRA §5.4, §6.4). Adds `quantity`, `operation_status`, `description` beyond ERD — these are operational enrichments without direct BRA backing but are not contradictory. |

**Finding**: All 6 ERD entities have corresponding relational tables. No entity is omitted. The single additional table (`SPACE_FACILITY`) is a justified junction-table resolution of the M:N relationship. No unjustified table exists.

### Stage 1.2 — Internal Consistency of Referential Actions

Referential actions as specified in the logical design (§1 — Relational Schema Mapping Decisions):

| Foreign Key Context | Parent → Child | ON DELETE | ON UPDATE |
|---------------------|----------------|-----------|-----------|
| `BOOKING` → `SPACE` | `SPACE` → `BOOKING` | NO ACTION | NO ACTION |
| `BOOKING` → `USER` (requester) | `USER` → `BOOKING` | NO ACTION | NO ACTION |
| `BOOKING` → `USER` (approver) | `USER` → `BOOKING` | NO ACTION | NO ACTION |
| `USAGESESSION` → `BOOKING` | `BOOKING` → `USAGESESSION` | NO ACTION | NO ACTION |
| `USAGESESSION` → `USER` (check-in) | `USER` → `USAGESESSION` | NO ACTION | NO ACTION |
| `USAGESESSION` → `USER` (check-out) | `USER` → `USAGESESSION` | NO ACTION | NO ACTION |
| `MAINTENANCERECORD` → `SPACE` | `SPACE` → `MAINTENANCERECORD` | NO ACTION | NO ACTION |
| `MAINTENANCERECORD` → `USER` (reporter) | `USER` → `MAINTENANCERECORD` | NO ACTION | NO ACTION |
| `MAINTENANCERECORD` → `USER` (assigned) | `USER` → `MAINTENANCERECORD` | NO ACTION | NO ACTION |
| `SPACE_FACILITY` → `SPACE` | `SPACE` → `SPACE_FACILITY` | **CASCADE** | (not specified) |
| `SPACE_FACILITY` → `FACILITY` | `FACILITY` → `SPACE_FACILITY` | **CASCADE** | (not specified) |

**Analysis**:
- All history-preserving tables (`BOOKING`, `USAGESESSION`, `MAINTENANCERECORD`) consistently use `ON DELETE NO ACTION` for FKs referencing `USER` and `SPACE`. This aligns with BRA Requirements §18 (historical preservation) and Assumption 5 (soft deletion policy).
- `SPACE_FACILITY` uses `ON DELETE CASCADE` on both FKs. This is appropriate because junction rows have no independent business meaning; if a `SPACE` or `FACILITY` is retired or removed, the association should be cleaned up. Since soft deletion is the policy (Assumption 5), cascade only applies to physical deletion of master records.
- **No conflicting referential actions** between related tables. All child tables that reference the same parent consistently use the same action.

**Verdict**: ✅ No issues.

---

## 3. Relationship Mapping Validation

For every ERD relationship, the cardinality, FK placement, and implementation pattern are validated.

| # | ERD Relationship | ERD Cardinality | Expected Mapping | Logical Implementation | Status |
|---|-----------------|-----------------|------------------|----------------------|--------|
| 1 | `User_Requests_Booking` | USER (0,N) : (1,1) BOOKING | FK on N-side (BOOKING) | `BOOKING.requester_id` FK → `USER(user_id)`, NOT NULL | ✅ Correct |
| 2 | `User_Approves_Booking` | USER (0,N) : (0,1) BOOKING | FK on N-side (BOOKING) | `BOOKING.approver_id` FK → `USER(user_id)`, NULL allowed | ✅ Correct |
| 3 | `Space_Hosts_Booking` | SPACE (0,N) : (1,1) BOOKING | FK on N-side (BOOKING) | `BOOKING.space_code` FK → `SPACE(space_code)`, NOT NULL | ✅ Correct |
| 4 | `Space_Contains_Facility` (aliased `Space_Equipped_With_Facility` in BRA §5.4) | SPACE (0,M) : (0,N) FACILITY | Junction Table | `SPACE_FACILITY` with composite PK `(space_code, facility_id)`, FKs to both parents | ✅ Correct |
| 5 | `Booking_Has_UsageSession` | BOOKING (0,1) : (1,1) USAGESESSION | Shared PK (1:1) | `USAGESESSION.booking_id` is PK and FK → `BOOKING(booking_id)` | ✅ Correct |
| 6 | `User_ChecksIn_UsageSession` | USER (0,N) : (1,1) USAGESESSION | FK on N-side (USAGESESSION) | `USAGESESSION.check_in_staff_id` FK → `USER(user_id)`, NOT NULL | ✅ Correct |
| 7 | `User_ChecksOut_UsageSession` | USER (0,N) : (0,1) USAGESESSION | FK on N-side (USAGESESSION) | `USAGESESSION.check_out_staff_id` FK → `USER(user_id)`, NULL allowed | ✅ Correct |
| 8 | `Space_Requires_Maintenance` | SPACE (0,N) : (1,1) MAINTENANCERECORD | FK on N-side (MAINTENANCERECORD) | `MAINTENANCERECORD.space_code` FK → `SPACE(space_code)`, NOT NULL | ✅ Correct |
| 9 | `User_Reports_Maintenance` | USER (0,N) : (1,1) MAINTENANCERECORD | FK on N-side (MAINTENANCERECORD) | `MAINTENANCERECORD.reporter_id` FK → `USER(user_id)`, NOT NULL | ✅ Correct |
| 10 | `User_Assigned_To_Maintenance` | USER (0,N) : (0,1) MAINTENANCERECORD | FK on N-side (MAINTENANCERECORD) | `MAINTENANCERECORD.assigned_staff_id` FK → `USER(user_id)`, NULL allowed | ✅ Correct |

**Naming Inconsistency (Minor)**: The BRA §5.4 names the Space–Facility relationship `Space_Equipped_With_Facility`, while the ERD Relationship Summary Table (§3) names it `Space_Contains_Facility`. The Mermaid label in the ERD uses `"contains"`. The meaning is identical and the logical implementation is unaffected.

**Verdict**: ✅ All 10 relationships are correctly mapped according to expected relational patterns (FK on N-side, junction table for M:N, shared PK for 1:1). No incorrect mappings identified.

---

## 4. Key Validation

### Primary Keys

| Table | PK Column(s) | Type | Uniquely Identifies? | Correctly Supports Relationships? | Matches ERD? |
|-------|-------------|------|---------------------|----------------------------------|--------------|
| `USER` | `user_id` | Natural (VARCHAR(50)) | ✅ University account ID is unique per BR-1 | ✅ Referenced by BOOKING, USAGESESSION, MAINTENANCERECORD | ✅ |
| `SPACE` | `space_code` | Natural (VARCHAR(50)) | ✅ Room code is unique per BR-4 | ✅ Referenced by BOOKING, MAINTENANCERECORD, SPACE_FACILITY | ✅ |
| `FACILITY` | `facility_id` | Surrogate (INT IDENTITY) | ✅ Auto-increment guarantees uniqueness | ✅ Referenced by SPACE_FACILITY | ✅ |
| `SPACE_FACILITY` | `(space_code, facility_id)` | Composite (natural + surrogate) | ✅ Prevents duplicate assignments | ✅ Junction FKs reference both parents | ✅ (M:N resolution) |
| `BOOKING` | `booking_id` | Surrogate (INT IDENTITY) | ✅ Auto-increment guarantees uniqueness | ✅ Referenced by USAGESESSION | ✅ |
| `USAGESESSION` | `booking_id` | Shared PK/FK (INT) | ✅ 1:1 — each booking has at most one session | ✅ FK → BOOKING enforces existence | ✅ |
| `MAINTENANCERECORD` | `maintenance_id` | Surrogate (INT IDENTITY) | ✅ Auto-increment guarantees uniqueness | ✅ Referenced by (none) — leaf table | ✅ |

### Foreign Keys

| FK Column(s) | Source Table | Referenced Table | Correct Placement? |
|-------------|-------------|-----------------|-------------------|
| `space_code` | BOOKING | SPACE | ✅ N-side of 1:N |
| `requester_id` | BOOKING | USER | ✅ N-side of 1:N |
| `approver_id` (nullable) | BOOKING | USER | ✅ N-side of 1:N |
| `booking_id` (PK/FK) | USAGESESSION | BOOKING | ✅ Shared PK for 1:1 |
| `check_in_staff_id` | USAGESESSION | USER | ✅ N-side of 1:N |
| `check_out_staff_id` (nullable) | USAGESESSION | USER | ✅ N-side of 1:N |
| `space_code` | MAINTENANCERECORD | SPACE | ✅ N-side of 1:N |
| `reporter_id` | MAINTENANCERECORD | USER | ✅ N-side of 1:N |
| `assigned_staff_id` (nullable) | MAINTENANCERECORD | USER | ✅ N-side of 1:N |
| `space_code` (composite PK part) | SPACE_FACILITY | SPACE | ✅ Junction FK |
| `facility_id` (composite PK part) | SPACE_FACILITY | FACILITY | ✅ Junction FK |

### Candidate / Alternate Keys

| Table | Alternate Key | Mechanism | Status |
|-------|--------------|-----------|--------|
| `USER` | `email` | `UNIQUE` constraint on `email` | ✅ Enforced |
| `FACILITY` | `facility_name` | `UNIQUE` constraint on `facility_name` | ✅ Enforced |

**Verdict**: ✅ All keys are correctly chosen, uniquely identify records, and support relationships as designed in the ERD.

---

## 5. Constraint Validation

### Stage 4.1 — NOT NULL, UNIQUE, CHECK, DEFAULT, Referential Integrity

**NOT NULL**: All PK columns and mandatory descriptive columns have `NOT NULL` as specified. Nullable columns (`phone_number`, `approver_id`, `decision_time`, `decision_note`, `rejection_reason`, `check_out_staff_id`, `actual_end`, `final_condition`, `usage_notes`, `assigned_staff_id`, `completion_time`, `result_note`, `facility_description`, `description`) correctly allow NULLs per their semantics.

**UNIQUE**: Two UNIQUE constraints defined:
- `UQ_USER_EMAIL` on `USER(email)` — enforces BR-2 alternate identifier requirement. ✅
- `UQ_FACILITY_NAME` on `FACILITY(facility_name)` — enforces unique facility catalog names per BR-7. ✅

**CHECK constraints**: All 15 CHECK constraints (as listed in §3 of the logical design) are evaluated:

| Constraint | Table | Purpose | Valid? |
|-----------|-------|---------|--------|
| `CK_USER_ROLE` | USER | Restrict role to predefined set (BR-3) | ✅ |
| `CK_USER_ACCOUNT_STATUS` | USER | Restrict account status values | ✅ |
| `CK_SPACE_TYPE` | SPACE | Restrict space type to predefined set (BR-5/6) | ✅ |
| `CK_SPACE_CAPACITY` | SPACE | Enforce capacity > 0 (BR-5) | ✅ |
| `CK_SPACE_CURRENT_STATUS` | SPACE | Restrict status values (BR-6) | ✅ |
| `CK_SPACE_FACILITY_QUANTITY` | SPACE_FACILITY | Quantity > 0 | ✅ |
| `CK_SPACE_FACILITY_STATUS` | SPACE_FACILITY | Restrict operation_status values | ✅ |
| `CK_BOOKING_TIME_ORDER` | BOOKING | `requested_end > requested_start` (Assumption 6) | ✅ |
| `CK_BOOKING_PARTICIPANTS` | BOOKING | `expected_participants > 0` | ✅ |
| `CK_BOOKING_PURPOSE` | BOOKING | Restrict purpose to predefined list (BR-9) | ✅ |
| `CK_BOOKING_STATUS` | BOOKING | Restrict status to predefined list (BR-10) | ✅ |
| `CK_BOOKING_FUTURE_START` | BOOKING | `requested_start >= created_at` (BR-20) | ⚠️ Partially effective (see 4.3) |
| `CK_BOOKING_REJECTION_REASON` | BOOKING | Rejected bookings must have reason (BR-14) | ✅ |
| `CK_BOOKING_CAPACITY_LIMIT` | BOOKING | `expected_participants <= space.capacity` via UDF (BR-19) | ✅ |
| `CK_USAGE_TIME_ORDER` | USAGESESSION | `actual_end > actual_start` (Assumption 6) | ✅ |
| `CK_MAINTENANCE_TIME_ORDER` | MAINTENANCERECORD | `completion_time > start_time` (Assumption 6) | ✅ |
| `CK_MAINTENANCE_STATUS` | MAINTENANCERECORD | Restrict maintenance status values (BR-17) | ✅ |
| `CK_MAINTENANCE_PROBLEM_TYPE` | MAINTENANCERECORD | Restrict problem type values (BR-17) | ✅ |

**DEFAULT constraints**:
- `DF_BOOKING_CREATED_AT` → `GETDATE()` for `created_at` ✅
- `DF_SPACE_FACILITY_QUANTITY` → `1` for `quantity` ✅
- `DF_SPACE_FACILITY_STATUS` → `'Operational'` for `operation_status` ✅

**Referential Integrity**: All FKs correctly defined with appropriate referential actions (see Stage 1.2). ✅

### Stage 4.2 — Referential Integrity & History Preservation

Transactional/historical tables: `BOOKING`, `USAGESESSION`, `MAINTENANCERECORD`.

- All FKs referencing these historical tables use `ON DELETE NO ACTION`, preventing cascade deletion of historical records.
- The only `CASCADE` rules are on the junction table `SPACE_FACILITY`, which has no historical significance — if a `SPACE` or `FACILITY` is removed, the association rows should be cleaned up.
- **BRA Requirement §18** explicitly states "The system must preserve historical records." The referential actions are fully consistent with this requirement.

**Verdict**: ✅ No high-risk findings. The design correctly preserves historical records.

### Stage 4.3 — Future-Time Constraints (No Past-Dated Events)

**Column evaluated**: `BOOKING.requested_start`

**Constraint**: `CK_BOOKING_FUTURE_START CHECK (requested_start >= created_at)`

**Analysis**:
- This constraint uses a column-to-column comparison (no non-deterministic function in the CHECK), which is valid in SQL Server.
- At INSERT time, `created_at` defaults to `GETDATE()`, so `requested_start >= GETDATE()` is effectively enforced for new records.
- However, `created_at` is immutable after creation (no UPDATE trigger changes it). On UPDATE of a booking record, the constraint only checks `requested_start >= created_at` (the original creation timestamp), NOT `requested_start >= current_timestamp`. This means an UPDATE could set `requested_start` to a value that is after the original creation time but before the current time.
- **BRA Requirement BR-20**: "Students and lecturers may only submit booking requests for future time periods."

**Risk level**: Medium Risk

**Recommendation**: Add an `AFTER INSERT, UPDATE` trigger on `BOOKING` that compares `requested_start` against `GETDATE()` and rolls back if `requested_start < GETDATE()`. Since SQL Server does not allow `GETDATE()` in CHECK constraints, a trigger is the appropriate DB-level mechanism. Alternatively, enforce this rule entirely at the application layer.

**Other columns checked for future-time relevance**:
- `MAINTENANCERECORD.start_time` — used for maintenance scheduling; no future-time constraint exists. Not flagged because the BRA does not explicitly require future-dated maintenance records. However, if maintenance scheduling requires future-only dates, the same trigger pattern should be applied.
- `USAGESESSION.actual_start` — records real check-in time, not a future-scheduled time. No future-time constraint needed.

---

## 6. Business Rule Coverage Analysis

Each business rule from BRA §7 is evaluated for enforcement mechanism and coverage.

| # | Business Rule | BRA Source | Enforcement Mechanism | Status | Notes |
|---|--------------|-----------|----------------------|--------|-------|
| BR-1 | Mandatory university account | §7.1 | PK on `user_id` (NOT NULL) | ✅ Fully Enforced | User ID as PK ensures every user has a university account identifier. |
| BR-2 | Record user info (ID, name, email, phone, role, dept, status) | §7.2 | All required columns present in `USER` table with NOT NULL constraints | ✅ Fully Enforced | `phone_number` is the only nullable field, which matches the BRA description. |
| BR-3 | User roles constrained to predefined list | §7.3 | `CK_USER_ROLE` CHECK constraint | ✅ Fully Enforced | CHECK validates against the exact list of 6 roles from BRA §4.1. |
| BR-4 | Unique space code | §7.4 | PK on `space_code` | ✅ Fully Enforced | |
| BR-5 | Space attributes (name, type, building, floor, room, capacity, status, policy) | §7.5 | All required columns present in `SPACE` table with NOT NULL | ✅ Fully Enforced | |
| BR-6 | Space status constrained to predefined set | §7.6 | `CK_SPACE_CURRENT_STATUS` CHECK | ✅ Fully Enforced | Includes all 5 statuses from BRA §4.2. |
| BR-7 | Facilities catalog and space mapping | §7.7 | `FACILITY` table + `SPACE_FACILITY` junction table | ✅ Fully Enforced | Catalog stores facility types; junction table maps spaces to facilities. |
| BR-8 | Booking requires space, start/end, purpose, participants | §7.8 | `BOOKING` table with NOT NULL constraints on all required columns | ✅ Fully Enforced | |
| BR-9 | Booking purpose constrained to predefined list | §7.9 | `CK_BOOKING_PURPOSE` CHECK | ✅ Fully Enforced | CHECK matches the 7 purposes from BRA §4.4. |
| BR-10 | Booking status constrained to predefined set | §7.10 | `CK_BOOKING_STATUS` CHECK | ✅ Fully Enforced | CHECK matches the 7 statuses from BRA §4.4. |
| BR-11 | Double booking prevention | §7.11 | `TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE` trigger on INSERT, UPDATE | ✅ Fully Enforced | Trigger checks all approved bookings for time-range overlap on the same space. |
| BR-12 | Block unavailable spaces (maintenance/closed/retired) | §7.12 | Same trigger as BR-11 | ⚠️ Partially Enforced | The trigger prevents booking insertion/update when overlapping maintenance exists. However, the check is **unidirectional**: it only fires on BOOKING changes, not on MAINTENANCERECORD changes. If a maintenance record is INSERTED or UPDATED that overlaps with existing approved bookings, those bookings are not flagged or rejected. |
| BR-13 | Approval tracking (approver, time, note) | §7.13 | `approver_id`, `decision_time`, `decision_note` columns in `BOOKING` | ✅ Fully Enforced | Columns present and nullable to allow pending state. |
| BR-14 | Rejection justification required | §7.14 | `CK_BOOKING_REJECTION_REASON` CHECK constraint | ✅ Fully Enforced | CHECK enforces: `booking_status <> 'Rejected' OR rejection_reason IS NOT NULL`. |
| BR-15 | Usage session check-in (start, staff, condition) | §7.15 | `USAGESESSION` table with NOT NULL on `check_in_staff_id`, `actual_start`, `initial_condition` | ✅ Fully Enforced | No trigger prevents creating a USAGESESSION for a non-approved booking — this is implicit trust in application workflow per Assumption 9. |
| BR-16 | Usage session completion (end, condition, notes) | §7.16 | Nullable columns `actual_end`, `final_condition`, `usage_notes` in `USAGESESSION` | ✅ Fully Enforced | |
| BR-17 | Maintenance logging (space, reporter, assigned, desc, times, status, result) | §7.17 | All required columns present in `MAINTENANCERECORD` | ✅ Fully Enforced | CHECK constraints on `maintenance_status` and `problem_type`. |
| BR-18 | Historical record preservation | §7.18 | `ON DELETE NO ACTION` on all FKs referencing transactional tables; soft-deletion assumption (Assumption 5) | ✅ Fully Enforced | BR-21 trigger also prevents deletion of cancelled bookings. Referential integrity actions protect against data loss. |
| BR-19 | Capacity limit (participants ≤ space capacity) | §7.19 | `CK_BOOKING_CAPACITY_LIMIT` via `dbo.fn_CheckSpaceCapacity` UDF | ✅ Fully Enforced | UDF looks up `SPACE.capacity` and compares. |
| BR-20 | Future booking (requested_start must be in future) | §7.20 | `CK_BOOKING_FUTURE_START CHECK (requested_start >= created_at)` | ⚠️ Partially Enforced | Works at INSERT (created_at = GETDATE()), but does not prevent UPDATE from setting past requested_start. See Stage 4.3. |
| BR-21 | Cancel only from Pending/Approved; keep cancelled records | §7.21 | `TR_BOOKING_STATUS_AND_AUDIT` trigger on UPDATE, DELETE | ✅ Fully Enforced | Trigger verifies source status before cancellation and blocks deletion of cancelled records. |

### Business Rules Not Enforced at Database Level

The following business-related rules from the BRA and Assumptions are not enforced by the schema:

| Rule | Source | Details |
|------|--------|---------|
| **Role-based permission for approval/check-in** | Assumption 1 (§8) | Only `Facility Staff` or `Facility Manager` should review/decide bookings, check in/out, and be assigned to maintenance. Not enforced by any constraint or trigger. An application-layer check is required. |
| **Check-in/No-Show window** | Assumption 3 (§8) | No database enforcement of the 30-minute check-in window. Application-layer logic required. |
| **Auto status change for maintenance** | Assumption 4 (§8) | No trigger automatically sets `SPACE.current_status = 'Under Maintenance'` when an active maintenance record exists. Application or scheduled process required. |
| **Booking check-in allowed only for Approved bookings** | Assumption 9 (§8) | No trigger prevents creating a `USAGESESSION` for a `BOOKING` that is not in `'Approved'` status. Application-layer workflow assumed. |

---

## 7. Traceability Validation

### Requirement → ERD → Relational Schema → Constraint

| BRA Requirement | ERD Element | Relational Schema Element | Constraint(s) | Traceable? |
|----------------|-------------|--------------------------|---------------|-----------|
| §4.1 User attributes | USER entity | USER table | PK, UQ_USER_EMAIL, CK_USER_ROLE, CK_USER_ACCOUNT_STATUS | ✅ Full |
| §4.2 Space attributes | SPACE entity | SPACE table | PK, CK_SPACE_TYPE, CK_SPACE_CAPACITY, CK_SPACE_CURRENT_STATUS | ✅ Full |
| §4.3 Facility attributes | FACILITY entity | FACILITY table | PK, UQ_FACILITY_NAME | ✅ Full |
| §4.4 Booking attributes | BOOKING entity | BOOKING table | PK, FKs, CK_BOOKING_* (6 constraints), DF_BOOKING_CREATED_AT, Triggers | ✅ Full |
| §4.5 UsageSession attributes | USAGESESSION entity | USAGESESSION table | PK/FK, FKs, CK_USAGE_TIME_ORDER | ✅ Full |
| §4.6 MaintenanceRecord attributes | MAINTENANCERECORD entity | MAINTENANCERECORD table | PK, FKs, CK_MAINTENANCE_* (3 constraints) | ✅ Full |
| §5.1 User requests Booking | USER→BOOKING (1:N) | booking.requester_id → USER | FK, NOT NULL | ✅ Full |
| §5.2 User approves Booking | USER→BOOKING (1:N) | booking.approver_id → USER | FK, nullable | ✅ Full |
| §5.3 Space hosts Booking | SPACE→BOOKING (1:N) | booking.space_code → SPACE | FK, NOT NULL | ✅ Full |
| §5.4 Space contains Facility | SPACE↔FACILITY (M:N) | SPACE_FACILITY junction table | Composite PK, FKs, CK constraints on quantity/status | ✅ Full (junction table resolves M:N) |
| §5.5 Booking has UsageSession | BOOKING→USAGESESSION (1:1) | USAGESESSION.booking_id → BOOKING | PK/FK, NOT NULL | ✅ Full |
| §5.6 User checks in Session | USER→USAGESESSION (1:N) | USAGESESSION.check_in_staff_id → USER | FK, NOT NULL | ✅ Full |
| §5.7 User checks out Session | USER→USAGESESSION (1:N) | USAGESESSION.check_out_staff_id → USER | FK, nullable | ✅ Full |
| §5.8 Space requires Maintenance | SPACE→MAINTENANCERECORD (1:N) | MAINTENANCERECORD.space_code → SPACE | FK, NOT NULL | ✅ Full |
| §5.9 User reports Maintenance | USER→MAINTENANCERECORD (1:N) | MAINTENANCERECORD.reporter_id → USER | FK, NOT NULL | ✅ Full |
| §5.10 User assigned to Maintenance | USER→MAINTENANCERECORD (1:N) | MAINTENANCERECORD.assigned_staff_id → USER | FK, nullable | ✅ Full |
| §6.1–§6.10 Cardinalities | All cardinalities in ERD | All FKs, nullability, PK choices | Consistent with cardinality notation | ✅ Full |

### Additional Attributes in SPACE_FACILITY Without Direct BRA Trace

| Column | BRA Trace | Notes |
|--------|----------|-------|
| `quantity` | None | No explicit BRA requirement. Reasonable extension to track unit counts. |
| `operation_status` | None | No explicit BRA requirement. Reasonable extension for operational tracking. |
| `description` | None | No explicit BRA requirement. Optional free-text. |

**Verdict**: ✅ Full traceability exists for all core entity attributes and relationships. The three additional SPACE_FACILITY columns are not traced to BRA requirements but are reasonable operational extensions that do not contradict any stated requirement.

---

## 8. Strengths

1. **Complete Entity Coverage**: All 6 BRA-identified entities are mapped to relational tables without omission. The M:N Space–Facility relationship is correctly resolved via a junction table.

2. **Accurate Relationship Mapping**: All 10 ERD relationships are correctly implemented using appropriate patterns (FK on N-side, junction table for M:N, shared PK for 1:1). Cardinalities are preserved.

3. **Robust Key Selection**: Natural keys (`user_id`, `space_code`) are used where business identifiers exist; surrogate keys (IDENTITY) are used where no natural key is available. Composite PK on `SPACE_FACILITY` correctly prevents duplicate assignments. Alternate keys (`email`, `facility_name`) are enforced via UNIQUE constraints.

4. **Comprehensive CHECK Constraints**: 18 CHECK constraints enforce domain value restrictions across all tables, ensuring data integrity for role, status, type, and purpose fields.

5. **Procedural Enforcement of Complex Rules**: The design appropriately uses triggers for:
   - Double-booking prevention (BR-11)
   - Unavailable space blocking (BR-12, partially)
   - Capacity validation via UDF (BR-19)
   - Cancellation state machine rules (BR-21)
   - Deletion protection for cancelled bookings (BR-18)

6. **History Preservation**: Consistent use of `ON DELETE NO ACTION` on all FKs referencing transactional/historical tables, aligned with BRA Requirement §18 and Assumption 5 (soft deletion).

7. **Detailed Traceability Matrix**: The logical design (§4) provides a thorough Table → Column → ERD Attribute → BRA Requirement trace for every schema element.

---

## 9. Issues and Risks

### High Risk

None identified.

### Medium Risk

| # | Risk Description | Evidence | Impact |
|---|-----------------|----------|--------|
| **R1** | **Unidirectional overlap check**: The trigger `TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE` only fires on `BOOKING.INSERT, UPDATE`. If a `MAINTENANCERECORD` is inserted/updated that overlaps with an existing approved booking, the booking is not flagged or rejected. | Logical Design §3.1 (Trigger 2): trigger scope is only `ON BOOKING AFTER INSERT, UPDATE`; no trigger exists on `MAINTENANCERECORD`. BR-12 requires that "a booking request must not overlap with any active or scheduled maintenance period." | A maintenance crew could be scheduled for a room that already has an approved booking, leading to conflicting resource allocation. |
| **R2** | **Incomplete future-date enforcement for bookings on UPDATE**: `CK_BOOKING_FUTURE_START CHECK (requested_start >= created_at)` only prevents past-dated `requested_start` relative to the immutable `created_at` timestamp, not relative to the current system clock. On UPDATE, this constraint does not prevent setting `requested_start` to a past time. | Logical Design §3 (`CK_BOOKING_FUTURE_START`); BR-20 (§7.20) requires "Booking requests with a requested start time earlier than the current system time are not permitted." | A booking's start time could be updated to the past, bypassing the future-only requirement. |
| **R3** | **Role-based permissions not enforced at DB level**: The BRA (Assumption 1) states only Facility Staff and Facility Manager can approve, check in/out, or be assigned to maintenance. No CHECK constraint or trigger validates that `approver_id`, `check_in_staff_id`, `check_out_staff_id`, or `assigned_staff_id` reference users with appropriate roles. | BRA §8, Assumption 1; Logical Design §2 — no role-based constraints on FKs to USER. | A Student could theoretically be set as an approver or check-in staff at the DB level if application logic fails. |
| **R4** | **Usage session not validated against booking status**: No trigger enforces that a `USAGESESSION` can only be created for a `BOOKING` with `booking_status = 'Approved'`. | BRA Assumption 9; Logical Design §2.6 — no procedural check on USAGESESSION INSERT. | A usage session could be recorded for a booking that was never approved. |

### Minor Issues

| # | Issue | Evidence |
|---|-------|----------|
| **I1** | **Naming inconsistency**: BRA §5.4 uses `Space_Equipped_With_Facility` while ERD Relationship Summary uses `Space_Contains_Facility`. | BRA §5.4 vs ERD §3, row 4. |
| **I2** | **No future-time constraint on MAINTENANCERECORD.start_time**: If maintenance scheduling requires future-only dates, no DB-level enforcement exists. | Logical Design §2.7 — no CHECK or trigger on `start_time`. |

---

## 10. Recommendations

| # | Recommendation | Addressed Risk | Priority |
|---|---------------|----------------|----------|
| REC-1 | Add a trigger `TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP` on `MAINTENANCERECORD AFTER INSERT, UPDATE` that checks whether the new/maintenance overlaps with existing approved bookings and raises an error (or transitions the conflicting bookings to `Cancelled`). | R1 | High |
| REC-2 | Add an `AFTER INSERT, UPDATE` trigger on `BOOKING` that compares `requested_start` against `GETDATE()` and rolls back if `requested_start < GETDATE()`. Remove or keep `CK_BOOKING_FUTURE_START` as a secondary check. | R2 | Medium |
| REC-3 | Add a trigger or application-level validation that checks the `role` of user IDs assigned as `approver_id`, `check_in_staff_id`, `check_out_staff_id`, and `assigned_staff_id` against the set `{'Facility Staff', 'Facility Manager'}`. If implemented at DB level, an `INSTEAD OF INSERT` trigger on the relevant tables is recommended. | R3 | Medium |
| REC-4 | Add a trigger `TR_USAGESESSION_CHECK_BOOKING_STATUS` on `USAGESESSION AFTER INSERT` that verifies `BOOKING.booking_status = 'Approved'` and rolls back if not. | R4 | Medium |
| REC-5 | (Optional) If maintenance scheduling requires future-only dates, apply the same trigger pattern from REC-2 to `MAINTENANCERECORD.start_time`. | I2 | Low |
| REC-6 | Rename the relationship and table references to use a single consistent name (`Space_Equipped_With_Facility` or `Space_Contains_Facility`) across BRA, ERD, and logical design documents. | I1 | Low |

---

## 11. Conclusion

| Criterion | Assessment |
|-----------|-----------|
| Entity Coverage | ✅ Full — all 6 entities mapped; 1 justified junction table |
| Relationship Mapping | ✅ Correct — all 10 relationships use appropriate patterns |
| Key Selection | ✅ Correct — PKs, FKs, composite keys, alternate keys all appropriate |
| Constraint Definition | ✅ Comprehensive — 18 CHECK constraints, 3 DEFAULTs, 2 triggers, 1 UDF |
| Business Rule Enforcement | ✅ 19 of 21 business rules fully enforced; 2 partially enforced (BR-12, BR-20) |
| Traceability | ✅ Full traceability from BRA → ERD → relational schema → constraint |

**Verdict: Conditionally Valid**

The database design is fundamentally correct and well-structured. All entities, relationships, keys, and most constraints are properly implemented. The two triggers (`TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE` and `TR_BOOKING_STATUS_AND_AUDIT`) demonstrate sophisticated understanding of procedural enforcement for complex business rules.

The design is **conditionally valid** because:
1. The overlap-prevention mechanism is unidirectional (bookings checked against maintenance, but not vice versa) — **R1**.
2. The future-date constraint is only partially effective on UPDATE — **R2**.
3. Role-based permission enforcement is absent at the database level — **R3**.
4. Usage session creation is not validated against booking approval status — **R4**.

These conditions are addressable through the recommendations in §10 without requiring structural redesign of the schema.
