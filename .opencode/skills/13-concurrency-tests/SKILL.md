---
name: concurrency-tests-step13
description: Create repeatable two-session SQL Server tests that demonstrate the identified concurrency conflict and prove that the Step 12 implementation prevents it.
compatibility: opencode
---

# Step 13 — Concurrency Tests Skill

Use this skill after the Step 12 concurrency implementation has been generated and reviewed.

The purpose of this step is to produce reproducible SQL Server test scripts that:

1. Demonstrate at least one real unsafe concurrency interleaving.
2. Demonstrate that the Step 12 protected implementation prevents the violation.
3. Verify the database invariant after each protected test.
4. Document exact execution order and expected results.

The tests must involve genuinely concurrent sessions. Two statements run sequentially in one session do not prove concurrency behavior.

## Required output directory

Create or update:

`outputs/13-concurrency-tests-G02/`

Do not place all tests in one undocumented SQL file.

## Existing Artifact Update Policy

Before creating any Step artifact, check whether the required output artifact or output directory already exists.

### When an artifact already exists

If the required Step artifact already exists:

1. **Update the existing artifact in place.**
2. Treat the current artifact as the baseline rather than creating a replacement.
3. Preserve all existing valid:
   - files,
   - test cases or generation logic,
   - comments,
   - naming conventions,
   - directory structure,
   - configuration,
   - documentation,
   - and previously correct behavior.
4. Modify only the parts affected by the latest upstream design, schema, implementation, or review findings.
5. Add missing coverage or logic only when required.
6. Do not duplicate functionality that the existing artifact already provides correctly.
7. Remove or rewrite existing content only when it is incompatible with the finalized upstream implementation or current requirements.
8. Keep the existing output path and filenames unless an upstream schema change makes a filename genuinely invalid.
9. Do not create parallel artifacts such as:
   - `new-*`
   - `updated-*`
   - `revised-*`
   - `*-v2`
   - duplicate Step directories
   when the required artifact already exists.
10. Before finishing, review the complete updated artifact to ensure that unchanged content still remains compatible with the latest upstream steps.

### Step-specific application

- **Step 13:** If `outputs/13-concurrency-tests-G02/` already exists, update the existing test package to match the finalized Step 12 procedures, parameters, permissions, locking rules, integrity rules, and protected workflows. Preserve valid existing concurrency tests and add or revise only the affected scenarios.

- **Step 14:** If `outputs/14-data-generator-G02/` already exists, update the existing generator package to match the finalized schema and Phase 2 rules. Preserve valid generator logic, configuration, validation SQL, and documentation, and modify only the portions affected by upstream changes.

### When no artifact exists

Only create the required Step artifact from scratch when the expected artifact or output directory does not already exist.

---

## 1. Inspect the project before testing

1. Run `ls -la`.
2. Read fully:
   - `req/business-requirement-phase2.md`
   - `outputs/01-business-req-analysis-G02.md`
   - `outputs/03-logical-design-G02.md`
   - `outputs/05-db-definition-G02.sql`
   - `outputs/09-updated-erd-and-logical-design-G02.md`
   - `outputs/10-schema-migration-G02.sql`
   - `outputs/11-concurrency-design-G02.md`
   - `outputs/12-concurrency-implementation-G02.sql`
   - `docs/13-concurrency-tests-review-G02.md`
3. Read Step 11 and Step 12 review files under `docs/` when available.
4. Verify the exact procedure names, parameters, table names, status values, and maintenance impact values.
5. Identify a safe test-data strategy that does not alter unrelated project data.
6. If the Step 12 implementation is not ready or cannot compile, stop and report the blocker instead of writing misleading tests.

---

## 2. Required folder structure

Create at least:

```text
outputs/13-concurrency-tests-G02/
├── README.md
├── 00-setup-test-data.sql
├── 01-unsafe-conflict-session-a.sql
├── 02-unsafe-conflict-session-b.sql
├── 03-reset-after-unsafe-test.sql
├── 04-protected-approval-session-a.sql
├── 05-protected-approval-session-b.sql
├── 06-maintenance-race-session-a.sql
├── 07-maintenance-race-session-b.sql
├── 08-invariant-checks.sql
└── 09-cleanup-test-data.sql
```

Additional scripts may be added for staff/staff, instant/staff, boundary, rollback, or deadlock tests.

Do not remove the README.

---

## 3. Test-data isolation

Use clearly identifiable test records.

Requirements:

- Use dedicated test IDs or a documented test prefix.
- Use one or more test spaces that are not referenced by unrelated data.
- Ensure foreign-key prerequisites exist.
- Keep setup rerunnable.
- Delete or reset previous test rows before inserting new ones.
- Do not disable foreign keys or production constraints merely to make tests pass.
- Do not delete non-test project data.
- Document whether tests should run in a disposable database or the project database.

If identity keys prevent fixed IDs, capture generated IDs in a safe, documented way or use lookup keys that remain stable across the scripts.

---

## 4. Unsafe conflict demonstration

The unsafe test exists to demonstrate the race identified in Step 11. It must not alter the protected production procedure.

Create two scripts to be run in two SQL Server query windows.

### Required behavior

Both sessions must:

1. Target the same space.
2. Use overlapping requested time ranges.
3. Check availability before either session records its final result.
4. Be coordinated with `WAITFOR DELAY`, explicit transactions, or clear manual timing instructions.
5. Show that under the unsafe check-then-act logic both sessions can conclude that the space is available.
6. Record conflicting approved bookings in a disposable test scenario, or otherwise demonstrate the violation without weakening the production implementation.

The README must state clearly:

- Open Session A and Session B in separate windows.
- Which script to start first.
- When to start the second script.
- Which output messages to observe.
- What incorrect final state proves the race.

Do not use the protected `sp_ApproveBooking` procedure in the unsafe test, because that would prevent the conflict by design.

Do not permanently introduce a bypass into production code. The unsafe path must exist only in the isolated test scripts.

---

## 5. Protected approval tests

At minimum, implement a two-session protected test for overlapping bookings on the same space.

Both sessions must call the Step 12 protected approval path.

Expected result:

- One transaction approves successfully.
- The other waits, rechecks after the first commits, and is rejected because an approved overlap now exists.
- The final invariant query returns zero conflicting approved pairs.

Where practical, cover all three pairings named in Step 11:

1. Instant approval versus instant approval
2. Staff approval versus staff approval
3. Instant approval versus staff approval

If separate scripts are not created for all three, parameterize or document how the same scripts can exercise each pairing.

---

## 6. Maintenance escalation race test

When Step 11 and Step 12 protect maintenance escalation with the same per-space lock, create a two-session test involving:

- One booking approval operation
- One escalation from `Advisory` to `Out-of-Service`
- The same space
- Overlapping time ranges

Test and document at least one ordering:

### Approval acquires the lock first

Expected:

- Escalation waits.
- Approval commits.
- Escalation continues and identifies the newly approved booking as affected.

### Escalation acquires the lock first

Expected:

- Approval waits.
- Approval rechecks maintenance after escalation commits.
- Approval is rejected because `Out-of-Service` maintenance overlaps.

Ideally provide a repeatable way to test both orderings.

---

## 7. Non-conflict and boundary tests

Provide either executable scripts or clearly documented parameter changes for:

- Same space, non-overlapping times → both may be approved.
- Different spaces, overlapping times → both may be approved concurrently.
- One booking ends exactly when another begins → both may be approved.
- Existing out-of-service maintenance overlaps → approval rejected.
- Advisory maintenance overlaps → approval allowed, subject to the acknowledgement design.
- Already finalized booking submitted for approval → rejected safely.

These tests verify that the protection does not over-block valid operations.

---

## 8. Invariant checks

Create `08-invariant-checks.sql`.

It must include a query equivalent to:

```sql
SELECT
    b1.booking_id AS booking_1,
    b2.booking_id AS booking_2,
    b1.space_code
FROM dbo.BOOKING AS b1
JOIN dbo.BOOKING AS b2
    ON b1.space_code = b2.space_code
   AND b1.booking_id < b2.booking_id
   AND b1.requested_start < b2.requested_end
   AND b1.requested_end > b2.requested_start
WHERE b1.booking_status = 'Approved'
  AND b2.booking_status = 'Approved';
```

Adapt names to the actual schema.

Expected results:

- After the unsafe demonstration: at least one conflicting pair in the isolated test data.
- After resetting and running protected tests: zero conflicting approved pairs.

Also include checks for:

- Current test bookings and statuses
- Maintenance impact state
- Affected-booking output after escalation
- Leftover open transactions when observable

Restrict invariant queries to test data when necessary to avoid confusing unrelated historical records with the test result.

---

## 9. README requirements

`README.md` must contain:

# Step 13 Concurrency Tests

## Environment

- DBMS and version if known
- Database name placeholder or actual test database
- Required setup scripts
- Required Step 12 procedures

## Test safety

- Test-data prefix or IDs
- Cleanup behavior
- Warning against running unsafe tests on production data

## Execution instructions

For every two-session test:

1. Reset or set up data.
2. Open two SQL query windows.
3. Run Session A.
4. Wait for the documented message or delay.
5. Run Session B.
6. Observe blocking, success, or rejection.
7. Run invariant checks.
8. Record actual results.

## Expected results

Use a table:

| Test ID | Scenario | Session A Expected | Session B Expected | Final Invariant |
| --- | --- | --- | --- | --- |

## Actual result recording

Provide a table or template:

| Test ID | Date/Time | Tester | Actual Result | Evidence | Pass/Fail |
| --- | --- | --- | --- | --- | --- |

Do not fabricate execution times, screenshots, or pass results.

---

## 10. Test quality rules

- Use two actual sessions for concurrent behavior.
- Make interleavings deterministic enough to reproduce.
- Use `WAITFOR` only in test scripts, never in Step 12 production procedures.
- Include `PRINT` or timestamped `SELECT` output to make session order visible.
- Do not rely only on visual blocking; verify final database state.
- Clean up after unsafe demonstrations before protected tests.
- Do not leave transactions open unintentionally.
- Use `TRY...CATCH` in test scripts where an expected procedure error would otherwise stop cleanup.
- Clearly distinguish expected rejection from unexpected SQL failure.
- Do not claim a test passed unless it was executed.
- When execution cannot be performed by the agent, create the scripts and mark actual results as pending.

---

## 11. Minimum acceptance criteria

The test package is complete only when:

- The unsafe race is demonstrated through two sessions.
- The protected version uses the real Step 12 procedure.
- Exactly one of two overlapping protected approvals succeeds.
- The other session rejects only after a fresh recheck.
- Protected tests leave zero approved overlapping pairs.
- Valid non-overlapping or different-space operations are not incorrectly blocked.
- Maintenance escalation interaction is tested when it is part of Step 11.
- Setup and cleanup are rerunnable and isolated.
- Execution order and expected output are documented.
- Actual results are not fabricated.

---

## 12. Self-review checklist

Confirm:

- Every script uses actual schema names.
- The folder contains a README.
- The unsafe test does not weaken production code.
- The two sessions truly overlap in time.
- Session order is reproducible.
- Protected tests call the Step 12 procedure.
- Invariant checks verify the final state.
- Boundary cases are included.
- Maintenance interaction is included when required.
- Test data can be safely removed.
- No unrelated data is deleted.
- Actual results remain marked pending until executed.
- The package is ready for independent review.

---

## 13. Final response behavior

After creating the directory:

1. State that `outputs/13-concurrency-tests-G02/` was created or updated.
2. List the included test scenarios.
3. Explain how to run the first two-session test in no more than five steps.
4. State whether tests were actually executed or only prepared.
5. State whether the package is ready for Step 13 review.
6. Do not proceed to Step 14 automatically.
