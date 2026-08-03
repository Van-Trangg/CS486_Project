---
name: concurrency-implementation-step12
description: Implement the approved Step 11 concurrency design in Microsoft SQL Server and produce the Step 12 concurrency implementation script.
compatibility: opencode
---

# Step 12 — Concurrency Implementation Skill

Use this skill after the Phase 2 design update, schema migration, and concurrency design have been completed and reviewed.

The purpose of this step is to convert the approved Step 11 concurrency design into executable Microsoft SQL Server code. Do not redesign the concurrency strategy in this step unless the approved design cannot be implemented against the actual migrated schema.

## Required output

Create or update:

`outputs/12-concurrency-implementation-G02.sql`

Do not modify approved Phase 1 or earlier Phase 2 output files unless the user explicitly requests it.

---

## 1. Inspect the project before implementation

1. Run `ls -la` and inspect the project structure.
2. Locate and read the latest relevant artifacts fully:
   - `outputs/05-db-definition-G02.sql`
   - `outputs/09-updated-erd-and-logical-design-G02.md`
   - `outputs/10-schema-migration-G02.sql`
   - `outputs/11-concurrency-design-G02.md`
3. Read relevant review files under `docs/`, especially the Step 11 review if available.
4. Locate the current SQL Server schema and verify the exact names of:
   - `SPACE`
   - `BOOKING`
   - `MAINTENANCE_RECORD`
   - Booking status, approval, requester, time-range, and space-key columns
   - Maintenance impact-level, start-time, end-time, and status columns
5. Treat the approved Step 11 design and the migrated schema as the implementation baseline.
6. If an expected table, column, constraint, or procedure name is missing, report the inconsistency and use clearly marked placeholders only when implementation cannot proceed otherwise.

Do not guess physical names when the repository provides them.

---

## 2. Implementation scope

Implement the concurrency-control mechanisms approved in Step 11.

At minimum, the implementation must support:

1. Booking approval through one protected entry point.
2. A fresh conflict check at the moment approval is recorded.
3. A short transaction that begins before the per-space lock is acquired.
4. Per-space locking using the approved SQL Server mechanism.
5. Prevention of overlapping approved bookings for the same space.
6. Prevention of approval during overlapping `Out-of-Service` maintenance.
7. Safe rollback and error propagation.
8. Consistent locking order.
9. Maintenance escalation using the same per-space locking protocol when Step 11 requires it.

Do not write the Step 13 two-session demonstration scripts in this file.

---

## 3. Required protected approval procedure

Implement the procedure approved in Step 11, normally:

`dbo.sp_ApproveBooking`

Use the actual schema names from Steps 9 and 10.

### 3.1 Required transaction pattern

The procedure must follow this logical order:

1. Validate basic parameters that can be checked safely.
2. Execute `SET XACT_ABORT ON`.
3. Enter `TRY`.
4. Begin an explicit transaction.
5. Read and lock the relevant `SPACE` row using the approved per-space lock:
   - `WITH (UPDLOCK, HOLDLOCK)`
6. Verify that the space exists.
7. Read the booking being approved and verify that it exists and is currently eligible for approval.
8. Recheck whether another approved booking overlaps the requested interval.
9. Recheck whether `Out-of-Service` maintenance overlaps the requested interval.
10. Record approval fields only when all checks pass.
11. Commit immediately.
12. In `CATCH`, roll back when a transaction is active and rethrow the original error.

The lock must be acquired after `BEGIN TRANSACTION` and held until `COMMIT` or `ROLLBACK`.

### 3.2 Required overlap rule

Use the half-open interval rule unless the approved design explicitly states otherwise:

```sql
existing_start < requested_end
AND existing_end > requested_start
```

This must:

- Reject true overlaps.
- Allow adjacent bookings where one ends exactly when the other begins.
- Exclude the booking currently being approved when the procedure updates an existing pending row.

Do not replace this rule with `BETWEEN`, because `BETWEEN` commonly mishandles boundary cases.

### 3.3 Approval-state validation

The procedure must verify the approved workflow rules from the schema and Step 11, including where applicable:

- The booking exists.
- The booking is currently `Pending` or another explicitly approvable state.
- The requested start is earlier than the requested end.
- The space exists and is eligible.
- The booking has not already been approved, cancelled, rejected, completed, or otherwise finalized.
- The approval path is valid.
- Required staff decision fields are present for staff approval.
- Instant approval does not incorrectly require staff decision data unless the approved schema requires it.

Do not invent workflow states not supported by the Phase 1 or Phase 2 artifacts.

### 3.4 Result behavior

Use one consistent behavior for business-rule rejection:

- Either `THROW` a documented custom error, or
- Return a documented result code and message.

Prefer `THROW` when the surrounding project already uses exception-based SQL procedures.

Whichever approach is used, distinguish at least:

- Booking not found
- Space not found
- Booking not eligible for approval
- Overlapping approved booking exists
- Overlapping `Out-of-Service` maintenance exists

Do not silently return without explaining why approval failed.

---

## 4. Maintenance escalation implementation

If Step 11 requires maintenance escalation to use the same per-space lock, implement a protected procedure, normally:

`dbo.sp_EscalateMaintenanceImpact`

The procedure must:

1. Start a short transaction.
2. Identify the maintenance record and related space.
3. Acquire the same `SPACE` row lock using the same lock order as booking approval.
4. Verify that the maintenance record exists and is still open.
5. Verify that the transition to `Out-of-Service` is valid.
6. Update the impact level.
7. Identify already-approved bookings whose time ranges overlap the maintenance period.
8. Return or expose the affected-booking result set required by the design.
9. Commit immediately.
10. Roll back and rethrow on error.

If the approved schema stores escalation history separately, update that history according to Step 9 and Step 10. Do not invent a history table in Step 12.

Both protected procedures must acquire locks in this order:

`SPACE` → related `BOOKING` or `MAINTENANCE_RECORD` data

Do not reverse this order in one procedure.

---

## 5. Access-path enforcement

The implementation must make clear that every operation capable of changing a booking to `Approved` must use the protected procedure.

Where compatible with the project’s security model:

- Grant application or workflow accounts permission to execute the procedure.
- Do not grant them direct permission to update approval-related columns.

If the repository does not define database users or roles, document the required permission policy in SQL comments instead of inventing security principals.

Do not use a trigger as the primary mechanism unless Step 11 explicitly selected it.

---

## 6. Index boundary

Step 12 implements concurrency control, not Step 15 index tuning.

Rules:

- Reuse existing indexes where present.
- Do not add new performance indexes merely because they may help the conflict check.
- Do not make correctness depend on a particular booking index.
- Clearly comment where Step 15 may later tune the conflict-check query.
- A missing index may affect performance and lock duration, but the per-space locking protocol must still protect correctness.

---

## 7. SQL quality and safety requirements

The script must:

- Target Microsoft SQL Server.
- Use schema-qualified object names such as `dbo.BOOKING`.
- Use `CREATE OR ALTER PROCEDURE` when supported by the project environment.
- Include `SET NOCOUNT ON` inside procedures.
- Include `SET XACT_ABORT ON`.
- Use `TRY...CATCH`.
- Roll back only when `XACT_STATE()` indicates an active or uncommittable transaction.
- Use `THROW;` to preserve the original error where appropriate.
- Avoid dynamic SQL unless it is genuinely required.
- Avoid `MERGE` for the protected approval workflow.
- Avoid long-running work inside the transaction.
- Avoid `WAITFOR` in production procedures; timing controls belong in Step 13 tests.
- Avoid swallowing deadlock error 1205.
- Keep retry policy outside the stored procedure.
- Be rerunnable without requiring manual deletion of procedures.
- Use comments to explain the locking protocol and protected invariant.

Do not include fake performance numbers or claim that concurrency tests passed before Step 13 is executed.

---

## 8. Required output structure

The SQL file must contain clearly marked sections:

```sql
/* =========================================================
   STEP 12 — CONCURRENCY IMPLEMENTATION
   ========================================================= */

/* 1. Implementation assumptions and object mapping */

/* 2. Protected booking approval procedure */

/* 3. Protected maintenance escalation procedure */

/* 4. Permission or access-path notes */

/* 5. Verification queries for object creation */

/* 6. Known limitations and Step 13 test handoff */
```

At the top of the file, state:

- Which Step 11 design was implemented.
- Which schema artifacts were used.
- Any unresolved mismatch between design and schema.
- That test-only delays and two-session scripts are intentionally deferred to Step 13.

---

## 9. Self-review checklist

Before finalizing, verify that:

- The implementation matches the approved Step 11 strategy.
- The transaction starts before the `SPACE` row lock.
- The same per-space lock is used consistently.
- The overlap predicate is correct.
- The current booking is excluded from its own conflict check.
- Adjacent bookings are allowed.
- Approved overlapping bookings are rejected.
- `Out-of-Service` maintenance is rechecked inside the approval transaction.
- Advisory maintenance does not incorrectly block approval.
- Maintenance escalation uses the same locking protocol when required.
- Lock order is consistent across procedures.
- All error paths roll back safely.
- Deadlocks are surfaced to the caller.
- No procedure holds a lock during human review.
- Direct approval outside the protected path is prohibited or clearly documented as prohibited.
- No Step 15 index tuning has been performed prematurely.
- The file is executable against the migrated schema without unresolved object-name guesses.

---

## 10. Final response behavior

After generating the file:

1. State that `outputs/12-concurrency-implementation-G02.sql` was created or updated.
2. Summarize the protected procedures implemented.
3. List any schema mismatch or unresolved assumption.
4. State whether the script is ready for Step 12 review.
5. Do not create Step 13 tests unless the user explicitly requests the next step.
