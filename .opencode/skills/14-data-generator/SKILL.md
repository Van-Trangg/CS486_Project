---
name: data-generator-step14
description: Generate a large-scale realistic dataset for the Campus Space Management System covering at least three academic years with 100,000+ booking records and all required Phase 2 scenario coverage.
compatibility: opencode
---

# Step 14 — Data Generator Skill

Use this skill after the Phase 2 schema migration (Step 10) and concurrency implementation (Step 12) have been completed and reviewed.

The purpose of this step is to generate a large, realistic, deterministic dataset that covers all required booking statuses, approval paths, maintenance impact levels, acknowledgement records, escalation history, and usage sessions. The dataset must be large enough for Step 15 index tuning to produce observable performance differences and for Step 16 analytical queries to return meaningful results.

## Required output

Create or update:

```
outputs/14-data-generator-G02/01-generate-data.sql
outputs/14-data-generator-G02/02-validate-data.sql
```

Do not modify approved Phase 1 or earlier Phase 2 output files unless the user explicitly requests it.

---

## 1. Inspect the project before generation

1. Run `ls -la` and inspect the project structure.
2. Locate and read the latest relevant artifacts fully:
   - `outputs/05-db-definition-G02.sql`
   - `outputs/09-updated-erd-and-logical-design-G02.md`
   - `outputs/10-schema-migration-G02.sql`
   - `outputs/12-concurrency-implementation-G02.sql`
3. Read relevant review files under `docs/`.
4. Identify the exact table, column, constraint, and trigger names in the migrated schema.
5. Verify all CHECK constraint domains:
   - `USER.role` values
   - `USER.account_status` values
   - `SPACE.space_type` values
   - `SPACE.current_status` values
   - `SPACE_FACILITY.operation_status` values
   - `BOOKING.purpose` values
   - `BOOKING.booking_status` values
   - `BOOKING.approval_path` values
   - `MAINTENANCERECORD.maintenance_status` values
   - `MAINTENANCERECORD.problem_type` values
   - `MAINTENANCERECORD.impact_level` values
   - `MAINTENANCE_IMPACT_HISTORY.old_impact_level` / `new_impact_level` values
6. Identify all triggers that fire on INSERT and UPDATE for BOOKING, MAINTENANCERECORD, and USAGESESSION.

Do not guess physical names or domain values when the repository provides them.

---

## 2. Data generation scope

### 2.1 Required coverage (from AGENTS.md §9 Step 14)

The generated dataset must cover at least:

- **Three academic years** spanning approximately September 2023 to May 2026.
- **100,000+ booking records** (target: 105,000).
- **All booking statuses**: `Pending`, `Approved`, `Rejected`, `Cancelled`, `Checked In`, `Completed`, `No-Show`.
- **Both approval paths**: `Instant` and `Staff`.
- **Maintenance records with both impact levels**: `advisory` and `out-of-service`.
- **Overlapping maintenance periods** on the same space.
- **Advisory acknowledgements** in `BOOKING_ADVISORY_ACK`.
- **Maintenance escalation/downgrade history** in `MAINTENANCE_IMPACT_HISTORY`.
- **Usage sessions** for `Completed` and `Checked In` bookings in `USAGESESSION`.
- **Cancellations and no-shows** with realistic distribution.
- **Enough selectivity variance** in space types, buildings, departments, time-of-day, and facility combinations to make index effects observable in Step 15.

### 2.2 Target row counts

| Table | Minimum Rows | Notes |
|---|---|---|
| `[USER]` | 400+ | All 6 roles, all 3 account statuses, multiple departments |
| `SPACE` | 50+ | All 6 space types, all 5 current statuses |
| `FACILITY` | 10+ | All BRA-documented facilities plus reasonable supplements |
| `SPACE_FACILITY` | 200+ | 3-6 facilities per space, all 3 operation statuses |
| `MAINTENANCERECORD` | 3,000+ | Both impact levels, all 4 maintenance statuses, all 6 problem types |
| `BOOKING` | 100,000+ | All 7 booking statuses, both approval paths, all 7 purposes |
| `USAGESESSION` | 50,000+ | One per `Completed` or `Checked In` booking |
| `BOOKING_ADVISORY_ACK` | 5,000+ | Junction records for bookings on spaces with active advisories |
| `MAINTENANCE_IMPACT_HISTORY` | 500+ | Escalation and downgrade audit records |

---

## 3. Generation method

### 3.1 Deterministic set-based T-SQL

Use pure T-SQL set-based generation with CTEs and `INSERT ... SELECT` patterns. Do not use cursors for bulk generation.

Use deterministic pseudo-random functions:
- `ABS(CHECKSUM(HASHBYTES('MD5', CAST(n AS VARCHAR)))) % range` for hash-based distribution
- Modular arithmetic (`n % k`) for deterministic status and type assignment

### 3.2 Trigger handling

Triggers defined in Step 5 (e.g., `TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE`, `TR_BOOKING_FUTURE_START_ENFORCEMENT`, `TR_USAGESESSION_CHECK_BOOKING_STATUS`) will reject bulk-loaded historical data because:

- Historical bookings have `requested_start` in the past (violates future-start enforcement).
- Multiple approved bookings may exist on the same space at different times but the trigger fires per-batch and may produce false positives with large inserts.
- Usage sessions require the booking to be `Approved` at insert time, but the generator creates bookings directly in final status.

Therefore the generator must:

1. **Disable all triggers** before data insertion.
2. **Enforce all business rules programmatically** within the generation logic:
   - `expected_participants <= capacity`
   - `requested_end > requested_start`
   - `created_at <= requested_start`
   - Rejection reason populated when `booking_status = 'Rejected'`
   - Approver has staff/manager role
   - Check-in/check-out staff have staff/manager role
   - Assigned maintenance staff have staff/manager role
   - Foreign key integrity for all references
3. **Re-enable all triggers** after data insertion.

List all triggers being disabled and re-enabled explicitly in the script.

### 3.3 Identity column handling

Use `DBCC CHECKIDENT` to reset identity seeds before generation. Use `SET IDENTITY_INSERT ON/OFF` only for tables where explicit IDs are required (e.g., `FACILITY`).

### 3.4 Data cleanup

The generator must clean all existing data in reverse FK dependency order before inserting new data, making it safe to re-run.

---

## 4. Data distribution requirements

### 4.1 Booking status distribution

Target a realistic distribution that ensures all statuses are well-represented:

| Status | Approximate % | Notes |
|---|---|---|
| Completed | 50-60% | Largest group; these get USAGESESSION records |
| Approved | 12-18% | Future bookings awaiting check-in |
| Rejected | 8-12% | Must have `rejection_reason` populated |
| Cancelled | 6-10% | Cancelled from Pending or Approved |
| No-Show | 4-6% | Requester did not arrive |
| Checked In | 3-5% | In-progress sessions; get USAGESESSION records |
| Pending | 2-4% | Awaiting decision |

### 4.2 Approval path distribution

- **Staff** (60-70%): Standard workflow with `approver_id` set to a staff/manager user.
- **Instant** (30-40%): For qualifying space types (Student Workspace, Meeting Room). `approver_id` is NULL for instant approvals.

### 4.3 Maintenance impact level distribution

- **advisory** (65-75%): Space usable but with equipment issues.
- **out-of-service** (25-35%): Space blocked from booking.

### 4.4 Time distribution

Spread bookings across all three academic years with realistic semester weighting:
- Fall and Spring semesters receive more bookings than Summer.
- Business hours (08:00–18:00) are heavily weighted.
- Duration: 1–4 hours per booking.

---

## 5. Validation script requirements

Create `02-validate-data.sql` that verifies:

1. **Row count audit**: Every table meets minimum row counts.
2. **Academic year coverage**: Bookings span at least 3 distinct academic years.
3. **Enum coverage**: Every allowed value in every CHECK-constrained column is populated at least once.
4. **Approval path coverage**: Both `Instant` and `Staff` paths are present.
5. **Impact level coverage**: Both `advisory` and `out-of-service` are present.
6. **Usage session alignment**: Every `Completed` and `Checked In` booking has exactly one USAGESESSION.
7. **Advisory acknowledgement audit**: `BOOKING_ADVISORY_ACK` records exist and reference valid bookings and maintenance records.
8. **Impact history audit**: `MAINTENANCE_IMPACT_HISTORY` records exist with both escalation and downgrade events.
9. **Constraint integrity**: `rejection_reason IS NOT NULL` for all `Rejected` bookings.
10. **Capacity constraint**: `expected_participants <= capacity` for all bookings.
11. **Time ordering**: `requested_end > requested_start` for all bookings.

Format results as a clear PASS/FAIL report with counts.

---

## 6. SQL quality and safety requirements

The scripts must:

- Target Microsoft SQL Server.
- Use schema-qualified object names (`dbo.BOOKING`).
- Use `SET NOCOUNT ON` and `SET XACT_ABORT ON`.
- Use `GO` batch separators appropriately.
- Avoid dynamic SQL unless required for deferred compilation.
- Handle temp tables cleanly (create and drop within the script).
- Be executable via `sqlcmd -S localhost -E -C -i <file>`.
- Be rerunnable (idempotent cleanup at the start).
- Complete in under 60 seconds on a standard developer machine.

---

## 7. Self-review checklist

Before finalizing, verify that:

- All 9 tables receive data.
- Row counts meet or exceed the minimums specified in Section 2.2.
- Every CHECK constraint domain value is represented.
- Both approval paths are represented.
- Both maintenance impact levels are represented.
- Overlapping maintenance periods exist on at least some spaces.
- `USAGESESSION` records exist only for `Completed` and `Checked In` bookings.
- `BOOKING_ADVISORY_ACK` records link bookings to advisory maintenance with temporal overlap.
- `MAINTENANCE_IMPACT_HISTORY` records include both escalation and downgrade events.
- All FK references are valid.
- `rejection_reason` is populated for all `Rejected` bookings.
- `expected_participants` does not exceed `capacity` for any booking.
- Triggers are disabled before insertion and re-enabled after insertion.
- The script completes without errors on a fresh database after Step 5 + Step 10.
- The validation script runs and all checks pass.

---

## 8. Final response behavior

After generating the files:

1. State that `outputs/14-data-generator-G02/01-generate-data.sql` and `outputs/14-data-generator-G02/02-validate-data.sql` were created or updated.
2. Execute the generator on the local SQL Server instance.
3. Execute the validation script and report results.
4. Summarize row counts and scenario coverage.
5. State whether the dataset is ready for Step 14 review.
6. Do not create Step 15 or Step 16 artifacts unless the user explicitly requests the next step.
