---
name: concurrency-implementation-step12-review
description: Review the Step 12 SQL Server concurrency implementation against the approved Step 11 design and determine whether it is ready for Step 13 two-session testing.
compatibility: opencode
---

# Step 12 — Concurrency Implementation Review Skill

Use this skill after `outputs/12-concurrency-implementation-G02.sql` has been generated or updated.

The review must determine whether the implementation is faithful to the approved Step 11 design, executable against the migrated schema, transactionally safe, and ready for meaningful Step 13 concurrency testing.

Do not approve the script merely because it contains transactions, lock hints, or stored procedures. Examine whether concurrent approval and maintenance operations can still violate the required invariants.

---

## Review prompt

Examine `outputs/12-concurrency-implementation-G02.sql` critically and answer:

> Is this implementation ready for Step 13 two-session testing without requiring the tester to guess how approval is protected, repair transaction handling, bypass schema mismatches, or compensate for a locking protocol that does not actually prevent the identified races?

Compare the implementation with:

1. The complete Phase 2 requirements.
2. The approved Step 9 design and Step 10 migration.
3. The approved Step 11 concurrency design.
4. The actual current SQL Server schema.
5. The Step 12 generation skill, if available.

If the implementation cannot be executed, does not enforce the selected protocol, or leaves a bypass that invalidates the test, mark it as not ready.

---

## Input documents

### Required

Review target:

- `outputs/12-concurrency-implementation-G02.sql`

Approved design and schema inputs:

- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`

Current database baseline:

- `outputs/05-db-definition-G02.sql`

Phase 2 requirement:

- `req/business-requirement-phase2.md`
- Or the actual Phase 2 requirement file found under `req/` or `docs/`

### Optional

Read when available:

- Step 9, Step 10, and Step 11 review files under `docs/`
- `.opencode/skills/concurrency-implementation-step12/SKILL.md`
- Existing database setup or deployment scripts

---

## Output file

Create or update:

`docs/12-concurrency-implementation-review-G02.md`

Do not directly modify `outputs/12-concurrency-implementation-G02.sql` unless the user explicitly requests automatic correction.

---

## Important review behavior

Before reviewing:

1. Run `ls -la`.
2. Verify that all required inputs exist.
3. Read the complete Step 12 SQL file and the approved Step 11 design.
4. Verify object and column names against the migrated schema.
5. If a SQL Server execution environment is available, compile or execute the script in a safe test database.
6. If execution is not available, perform a static review and clearly state that runtime behavior remains unverified.
7. Base every issue on requirement evidence, schema mismatch, transactional weakness, SQL error, or downstream testing risk.
8. Distinguish:
   - Blocking issue
   - Major issue
   - Minor issue
   - Observation
9. Do not require performance indexes in Step 12.
10. Do not treat comments as enforcement when the SQL code contradicts them.

---

# Review criteria

## 1. File and object completeness

Verify that the script:

- Creates or alters the protected booking-approval procedure.
- Implements maintenance escalation locking when required by Step 11.
- Includes transaction and error-handling code.
- Uses schema-qualified names.
- Contains no unresolved placeholders.
- Can be rerun safely.
- Does not contain Step 13 timing scripts mixed into production procedures.

Report missing or duplicate objects and unusable sections.

---

## 2. Schema compatibility

Verify every referenced:

- Table
- Column
- Constraint
- Status value
- Impact-level value
- Approval-path value
- Procedure parameter
- Data type

against Steps 9 and 10 and the actual schema.

Check especially:

- Space primary key type and name
- Booking primary key and space foreign key
- Requested start and requested end columns
- Booking status values
- Approval staff, time, note, and path columns
- Maintenance impact level
- Maintenance open/closed state
- Maintenance period representation

A script with incorrect names or incompatible data types is not ready for Step 13.

---

## 3. Transaction boundary

Verify that:

- `SET XACT_ABORT ON` is used.
- The explicit transaction begins before the per-space lock.
- The lock is held until commit or rollback.
- No human review or external delay is placed inside the production transaction.
- All approval checks and the final approval update occur inside the same transaction.
- Maintenance escalation follows the same principle.
- Every error path safely ends the transaction.
- A procedure called inside an existing transaction does not accidentally commit work it does not own, if nested transaction use is supported by the project.

Report transactions that begin too late, commit too early, or leak on error.

---

## 4. Locking-protocol correctness

Verify that:

- The procedure locks the correct `SPACE` row.
- `UPDLOCK, HOLDLOCK` or the approved equivalent is used.
- The lock lookup is guaranteed to target one existing space row.
- Every protected approval path uses the same locking protocol.
- Maintenance escalation uses the same per-space lock when required.
- Lock order is consistent:
  - `SPACE` first
  - Related booking or maintenance rows second
- Procedures for different spaces can proceed independently.
- The implementation does not claim that a booking index alone enforces correctness.

Actively search for paths that read conflicts before acquiring the lock.

---

## 5. Booking-conflict logic

Verify that the implementation correctly detects an existing approved overlap using:

```sql
existing_start < requested_end
AND existing_end > requested_start
```

Check that:

- The current booking is excluded from its own conflict check.
- Only statuses that actually occupy the space are included.
- Adjacent bookings are permitted.
- A booking fully containing another is detected.
- A booking fully contained by another is detected.
- Equal time ranges are detected.
- Null or invalid time ranges cannot bypass the check.
- The same-space predicate is present.

Report any use of `BETWEEN` or incomplete endpoint logic that misses valid overlaps.

---

## 6. Maintenance rule enforcement

Verify that booking approval:

- Blocks overlapping `Out-of-Service` maintenance.
- Does not block merely because advisory maintenance exists.
- Uses the actual maintenance period and open-state logic.
- Handles an open-ended maintenance completion time according to the approved schema.

Verify that escalation:

- Locks the same space.
- Validates the transition.
- Identifies already-approved overlapping bookings after serialization.
- Does not miss a booking committed immediately before escalation.
- Does not permit a new approval to slip in after the affected-booking set is calculated.

---

## 7. Workflow and bypass protection

Verify that:

- Instant approval and staff approval both call the same protected procedure.
- The procedure validates which fields are required for each approval path.
- The SQL or documented security policy prevents application workflows from directly setting status to `Approved`.
- A direct-update bypass is not used by another script in the repository.
- Re-approval of an already finalized booking is rejected or handled safely.
- The procedure does not overwrite prior decision data incorrectly.

Comments alone are not sufficient when repository scripts still approve directly.

---

## 8. Error handling and result semantics

Verify that:

- Errors are specific enough to explain rejection.
- Rollback occurs when needed.
- `THROW` preserves errors where appropriate.
- Error 1205 is not swallowed.
- Retry is not performed indefinitely inside the procedure.
- Business-rule rejection is distinguishable from system failure.
- Partial approval data cannot remain after an error.
- Maintenance escalation cannot partially update its state and then fail before affected bookings are identified.

---

## 9. Indexing boundary and performance sanity

Verify that:

- Step 12 does not prematurely perform full Step 15 tuning.
- Correctness does not depend on a newly invented booking index.
- Queries are at least logically sargable where possible.
- The implementation avoids scanning unrelated spaces after the per-space lock is acquired.
- No obviously unnecessary long-running operation is included inside the transaction.

A performance concern is not automatically blocking unless it makes Step 13 impractical or changes lock behavior materially.

---

## 10. Executability check

When a SQL Server test environment is available:

1. Apply the required schema and migration.
2. Execute the Step 12 script.
3. Verify the procedures exist.
4. Run one non-concurrent success case.
5. Run one non-concurrent conflict case.
6. Run one maintenance-block case.
7. Confirm rollback behavior on a forced validation error.

Do not claim that concurrency is proven here; that belongs to Step 13.

When execution is unavailable, list the exact runtime checks still required.

---

## 11. Step 13 readiness examination

Answer explicitly:

1. Can Session A and Session B both call a clearly defined protected operation?
2. Is the transaction boundary visible and correct?
3. Is the lock acquired before the protected checks?
4. Are approval and maintenance escalation serialized consistently?
5. Can tests distinguish unsafe behavior from protected behavior?
6. Are expected business-rule errors observable?
7. Are object names stable enough for test scripts?
8. Are there any direct-update bypasses that would invalidate prevention tests?
9. Are there unresolved blocking schema mismatches?
10. Would a tester need to modify production SQL before testing?

Then provide:

- **Ready elements**
- **Blocking gaps**
- **Non-blocking improvements**

---

## 12. Quality assessment

Assign 0–10:

| Category | Evaluation focus |
| --- | --- |
| Completeness | Required procedures and sections exist |
| Schema Compatibility | SQL matches the migrated database |
| Transaction Safety | Begin, commit, rollback, and error paths are correct |
| Locking Correctness | The selected per-space protocol is implemented faithfully |
| Conflict Detection | Overlap logic is complete and correct |
| Maintenance Interaction | Approval and escalation are serialized correctly |
| Workflow Enforcement | All approval paths use the protected entry point |
| Step 13 Readiness | Two-session tests can run without repairing the implementation |

Do not inflate scores because the SQL is lengthy.

---

# Output format

# 1. Review Summary

State:

- What was reviewed
- Whether runtime execution was performed
- Most important strength
- Most important risk
- Readiness for Step 13

# 2. Documents Reviewed

# 3. Implementation Mapping

| Step 11 Decision | Implemented In | Correct? | Evidence | Gap |
| --- | --- | --- | --- | --- |

Include at least:

- Per-space lock
- Short transaction
- Fresh conflict recheck
- Unified approval procedure
- Maintenance escalation lock
- Consistent lock order
- Caller-owned deadlock retry

# 4. SQL and Schema Compatibility Check

| Object or Rule | Expected | Actual | Status | Notes |
| --- | --- | --- | --- | --- |

# 5. Issues Found

For each issue:

## Issue R12-X — Short title

- **Severity:** Blocking / Major / Minor / Observation
- **Issue:**
- **Evidence:**
- **Why this is a problem:**
- **Downstream impact on Step 13:**
- **Suggested correction:**

# 6. Transaction and Locking Walkthrough

Walk through:

1. Successful approval
2. Rejected overlapping approval
3. Approval blocked by out-of-service maintenance
4. Maintenance escalation concurrent with approval

State where the lock is acquired and released in each case.

# 7. Step 13 Readiness Examination

Answer all readiness questions explicitly.

# 8. Scores

| Category | Score |
| --- | --- |
| Completeness | X/10 |
| Schema Compatibility | X/10 |
| Transaction Safety | X/10 |
| Locking Correctness | X/10 |
| Conflict Detection | X/10 |
| Maintenance Interaction | X/10 |
| Workflow Enforcement | X/10 |
| Step 13 Readiness | X/10 |

# 9. Required Revisions Before Step 13

List only revisions required before concurrency testing.

If none:

`No blocking revisions are required before Step 13.`

# 10. Final Readiness Verdict

Choose exactly one:

- **READY FOR STEP 13**
- **READY FOR STEP 13 WITH MINOR REVISIONS**
- **NOT READY FOR STEP 13**

Provide a brief justification.

---

## Final response behavior

After creating the review:

1. State that `docs/12-concurrency-implementation-review-G02.md` was created or updated.
2. State the final readiness verdict.
3. Summarize only blocking and major issues.
4. Do not generate Step 13 tests automatically.
5. If not ready, instruct the user to revise Step 12 first.
