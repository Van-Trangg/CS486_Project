---
name: data-generator-step14-review
description: Review the Step 14 data generator output against the Phase 2 schema and determine whether the generated dataset is ready for Step 15 index tuning and Step 16 analytical queries.
compatibility: opencode
---

# Step 14 — Data Generator Review Skill

Use this skill after `outputs/14-data-generator-G02/01-generate-data.sql` has been executed and `outputs/14-data-generator-G02/02-validate-data.sql` has been run.

The review must determine whether the generated dataset faithfully covers all required scenarios, respects all schema constraints, achieves the required scale, and is suitable for meaningful index-tuning comparisons and analytical query testing.

Do not approve the dataset merely because it contains a large number of rows. Examine whether all required status values, approval paths, impact levels, and edge cases are represented and whether the data distribution provides enough selectivity variance for observable index effects.

---

## Review prompt

Examine the Step 14 generator output and validation results critically and answer:

> Is this dataset ready for Step 15 index tuning and Step 16 analytical queries without requiring the tester to regenerate data, repair constraint violations, add missing scenario coverage, or compensate for unrealistic distributions?

Compare the generated data against:

1. The complete Phase 2 requirements (`req/business-requirement-phase2.md`).
2. The approved Step 9 design and Step 10 migration.
3. The AGENTS.md §9 Step 14 requirements.
4. The actual current SQL Server schema.
5. The Step 14 generation skill, if available.
6. The validation script output.

If the dataset cannot support meaningful index comparisons, lacks required scenario coverage, or violates schema constraints, mark it as not ready.

---

## Input documents

### Required

Review targets:

- `outputs/14-data-generator-G02/01-generate-data.sql`
- `outputs/14-data-generator-G02/02-validate-data.sql`

Approved design and schema inputs:

- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`

Phase 2 requirement:

- `req/business-requirement-phase2.md`
- `AGENTS.md` (§9 Step 14 requirements)

### Optional

Read when available:

- Step 10 and Step 12 review files under `docs/`
- `.opencode/skills/14-data-generator/SKILL.md`
- Validation script execution output (if provided by user or captured in logs)

---

## Output file

Create or update:

`docs/14-data-generator-review-G02.md`

Do not directly modify files under `outputs/14-data-generator-G02/` unless the user explicitly requests automatic correction.

---

## Important review behavior

Before reviewing:

1. Run `ls -la`.
2. Verify that all required inputs exist.
3. Read the complete generator SQL file and validation SQL file.
4. If a SQL Server execution environment is available:
   - Execute the generator script on a fresh database (after Step 5 + Step 10).
   - Execute the validation script.
   - Capture row counts and PASS/FAIL results.
5. If execution is not available, perform a static review and clearly state that runtime behavior remains unverified.
6. Base every issue on requirement evidence, schema mismatch, missing coverage, data integrity violation, or downstream testing risk.
7. Distinguish:
   - Blocking issue
   - Major issue
   - Minor issue
   - Observation
8. Do not require performance indexes in Step 14; those belong in Step 15.
9. Do not treat comments as coverage when the actual data contradicts them.

---

# Review criteria

## 1. Row count and scale verification

Verify that:

- `[USER]` has at least 400 rows.
- `SPACE` has at least 50 rows.
- `FACILITY` has at least 10 rows.
- `SPACE_FACILITY` has at least 200 rows.
- `MAINTENANCERECORD` has at least 3,000 rows.
- `BOOKING` has at least 100,000 rows.
- `USAGESESSION` has at least 50,000 rows.
- `BOOKING_ADVISORY_ACK` has at least 5,000 rows.
- `MAINTENANCE_IMPACT_HISTORY` has at least 500 rows.

Report exact row counts.

---

## 2. Academic year coverage

Verify that:

- Booking `requested_start` dates span at least 3 distinct academic years.
- The date range covers approximately September 2023 to May 2026.
- Bookings are distributed across Fall, Spring, and Summer semesters.
- The distribution is not concentrated in a single month or year.

---

## 3. Enum and domain value coverage

For each CHECK-constrained column, verify that every allowed value appears at least once:

- `USER.role`: Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager
- `USER.account_status`: Active, Suspended, Inactive
- `SPACE.space_type`: Auditorium, Classroom, Computer Laboratory, Project Laboratory, Meeting Room, Student Workspace
- `SPACE.current_status`: Available, In Use, Under Maintenance, Temporarily Closed, Retired
- `SPACE_FACILITY.operation_status`: Operational, Partially Operational, Broken
- `BOOKING.booking_status`: Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-Show
- `BOOKING.purpose`: Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Administrative Event
- `BOOKING.approval_path`: Instant, Staff
- `MAINTENANCERECORD.maintenance_status`: Reported, In Progress, Resolved, Cancelled
- `MAINTENANCERECORD.problem_type`: Projector Failure, Air-Conditioning Issue, Cleaning Issue, Furniture Damage, Network Issue, Other
- `MAINTENANCERECORD.impact_level`: advisory, out-of-service
- `MAINTENANCE_IMPACT_HISTORY.old_impact_level`: advisory, out-of-service
- `MAINTENANCE_IMPACT_HISTORY.new_impact_level`: advisory, out-of-service

Report any missing values.

---

## 4. Scenario coverage

Verify that the dataset includes:

- Bookings with instant approval (approver_id IS NULL, approval_path = 'Instant').
- Bookings with staff approval (approver_id IS NOT NULL, approval_path = 'Staff').
- Rejected bookings with non-NULL rejection_reason.
- Cancelled bookings.
- No-Show bookings.
- Completed bookings with corresponding USAGESESSION records.
- Checked In bookings with corresponding USAGESESSION records (no check-out yet).
- Advisory maintenance records overlapping with bookings.
- Out-of-service maintenance records.
- Overlapping maintenance periods on the same space.
- Escalation events (advisory → out-of-service) in MAINTENANCE_IMPACT_HISTORY.
- Downgrade events (out-of-service → advisory) in MAINTENANCE_IMPACT_HISTORY.
- Advisory acknowledgement records in BOOKING_ADVISORY_ACK linking bookings to maintenance.
- Usage sessions with both check-in and check-out (Completed) and check-in only (Checked In).

---

## 5. Data integrity verification

Verify that:

- All FK references resolve to existing PK values.
- `expected_participants <= capacity` for every booking (join BOOKING to SPACE).
- `requested_end > requested_start` for every booking.
- `completion_time > start_time` for every maintenance record with non-NULL completion_time.
- `rejection_reason IS NOT NULL` for every booking with `booking_status = 'Rejected'`.
- `approver_id` references a user with role `Facility Staff` or `Facility Manager` (when not NULL).
- `check_in_staff_id` and `check_out_staff_id` reference users with staff/manager roles.
- `assigned_staff_id` references a user with staff/manager role (when not NULL).
- Every `Completed` or `Checked In` booking has exactly one USAGESESSION.
- No `Pending`, `Rejected`, `Cancelled`, or `No-Show` booking has a USAGESESSION.
- `BOOKING_ADVISORY_ACK.booking_id` and `maintenance_id` reference valid records.
- `MAINTENANCE_IMPACT_HISTORY` `changed_by_user_id` references valid user records.

---

## 6. Selectivity and index-observability

Verify that the data has enough variance for Step 15 index tuning:

- Some space codes have many bookings (high frequency / low selectivity).
- Some space codes have few bookings (low frequency / high selectivity).
- Bookings spread across multiple space types with different frequencies.
- Time-of-day distribution includes both peak and off-peak hours.
- Facility combinations vary across spaces.
- Maintenance records are distributed unevenly across spaces (some spaces have many, some have few).

---

## 7. Trigger safety

Verify that:

- All triggers listed in Step 5 are explicitly disabled before data insertion.
- All triggers are explicitly re-enabled after data insertion.
- No trigger is left disabled at the end of the script.
- The script names every trigger being disabled and enabled.
- The generated data would not cause trigger violations if triggers were active (business rules are enforced programmatically).

---

## 8. Idempotency and re-run safety

Verify that:

- The script cleans all existing data before inserting.
- Cleanup follows reverse FK dependency order.
- Identity seeds are reset before generation.
- Re-running the script produces a consistent dataset.
- No duplicate key violations occur on re-run.

---

## 9. Execution performance

Verify or report that:

- The generator completes in under 60 seconds on the target SQL Server.
- No cursor-based row-by-row insertion is used for large tables.
- Temp tables are created and dropped cleanly.
- Memory consumption is reasonable (batched inserts for very large tables).

---

## 10. Step 15/16 readiness examination

Answer explicitly:

1. Does the dataset contain enough approved bookings to test the booking-conflict-check query?
2. Does the dataset contain enough spaces with varied facility sets to test the room-finder query?
3. Are there enough completed bookings across multiple semesters for the total-hours report?
4. Are there enough bookings distributed by weekday and hour for the weekday/hour report?
5. Are there enough out-of-service maintenance escalations with overlapping approved bookings for Report 4?
6. Is the dataset large enough for index scan vs. seek differences to be observable?
7. Are the data distributions varied enough for non-trivial query results?

---

## 11. Quality assessment

Assign 0–10:

| Category | Evaluation focus |
|---|---|
| Scale | Row counts meet or exceed all minimums |
| Academic Coverage | Three academic years with realistic semester distribution |
| Enum Coverage | Every CHECK constraint value is represented |
| Scenario Coverage | All required scenarios are present and identifiable |
| Data Integrity | All FK, CHECK, and business-rule constraints are satisfied |
| Selectivity | Enough variance for observable index effects |
| Trigger Safety | All triggers correctly disabled and re-enabled |
| Idempotency | Safe to re-run without manual cleanup |
| Performance | Executes within time budget |
| Step 15/16 Readiness | Dataset supports meaningful tuning and analytical queries |

Do not inflate scores because the script is long or generates many rows.

---

# Output format

# 1. Review Summary

State:

- What was reviewed
- Whether runtime execution was performed
- Most important strength
- Most important risk
- Readiness for Step 15/16

# 2. Documents Reviewed

# 3. Row Count Audit

| Table | Required Minimum | Actual Count | Status |
|---|---|---|---|

# 4. Enum Coverage Audit

| Column | Required Values | Missing Values | Status |
|---|---|---|---|

# 5. Scenario Coverage Audit

| Scenario | Present? | Evidence |
|---|---|---|

# 6. Data Integrity Check

| Check | Result | Details |
|---|---|---|

# 7. Issues Found

For each issue:

## Issue R14-X — Short title

- **Severity:** Blocking / Major / Minor / Observation
- **Issue:**
- **Evidence:**
- **Why this is a problem:**
- **Downstream impact on Step 15/16:**
- **Suggested correction:**

# 8. Scores

| Category | Score |
|---|---|
| Scale | X/10 |
| Academic Coverage | X/10 |
| Enum Coverage | X/10 |
| Scenario Coverage | X/10 |
| Data Integrity | X/10 |
| Selectivity | X/10 |
| Trigger Safety | X/10 |
| Idempotency | X/10 |
| Performance | X/10 |
| Step 15/16 Readiness | X/10 |

# 9. Required Revisions Before Step 15

List only revisions required before index tuning and analytical queries.

If none:

`No blocking revisions are required before Step 15.`

# 10. Final Readiness Verdict

Choose exactly one:

- **READY FOR STEP 15**
- **READY FOR STEP 15 WITH MINOR REVISIONS**
- **NOT READY FOR STEP 15**

Provide a brief justification.

---

## Final response behavior

After creating the review:

1. State that `docs/14-data-generator-review-G02.md` was created or updated.
2. State the final readiness verdict.
3. Summarize only blocking and major issues.
4. Do not generate Step 15 or Step 16 artifacts automatically.
5. If not ready, instruct the user to revise the generator first.
