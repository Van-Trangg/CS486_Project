---
name: concurrency-tests-step13-review
description: Review the Step 13 two-session SQL Server concurrency test package and determine whether it convincingly demonstrates the conflict and its prevention.
compatibility: opencode
---

# Step 13 — Concurrency Tests Review Skill

Use this skill after `outputs/13-concurrency-tests-G02/` has been created or updated.

The review must determine whether the test package is reproducible, genuinely concurrent, isolated, faithful to the Step 11 design, and capable of proving that the Step 12 implementation prevents the identified races.

Do not approve the package because it contains two files named Session A and Session B. Verify that the scripts create a real problematic interleaving and that the final database state proves the expected outcome.

---

## Review prompt

Examine `outputs/13-concurrency-tests-G02/` critically and answer:

> Is this concurrency-test package ready to serve as credible evidence that the Step 11 race exists without protection and that the Step 12 implementation prevents it, without requiring the evaluator to guess execution order, repair test data, reinterpret ambiguous outputs, or trust unverified claims?

Compare the package with:

1. The Phase 2 concurrency requirement.
2. The approved Step 11 concurrency design.
3. The Step 12 implementation.
4. The actual migrated schema.
5. The Step 13 generation skill, if available.

A test package is not ready when it only runs sequential statements, merely shows blocking without checking the final invariant, fabricates results, or tests a different code path from the production procedure.

---

## Input documents

### Required

Test package:

- `outputs/13-concurrency-tests-G02/`

Design and implementation:

- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`

Schema:

- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`

Phase 2 requirement:

- `req/business-requirement-phase2.md`
- Or the actual Phase 2 requirement file found in the repository

### Optional

Read when available:

- `docs/11-concurrency-design-review-G02.md`
- `docs/12-concurrency-implementation-review-G02.md`
- `.opencode/skills/concurrency-tests-step13/SKILL.md`
- Test execution logs, screenshots, or exported result files

---

## Output file

Create or update:

`docs/13-concurrency-tests-review-G02.md`

Do not directly modify the Step 13 test scripts unless the user explicitly requests automatic correction.

---

## Important review behavior

Before reviewing:

1. Run `ls -la` and list the complete Step 13 directory.
2. Read every SQL and Markdown file in the package.
3. Verify all referenced objects against Step 12 and the migrated schema.
4. Distinguish prepared tests from executed tests.
5. Do not treat expected-result text as proof that the test passed.
6. If a SQL Server environment is available, execute tests in a safe database using two sessions.
7. If execution is unavailable, perform static review and clearly state that observed blocking and final states remain unverified.
8. Base issues on reproducibility, test validity, data safety, schema mismatch, or evidence weakness.
9. Distinguish:
   - Blocking issue
   - Major issue
   - Minor issue
   - Observation
10. Do not require fabricated timing numbers or screenshots.

---

# Review criteria

## 1. Directory completeness

Verify the package contains:

- README
- Setup script
- Unsafe Session A
- Unsafe Session B
- Reset after unsafe test
- Protected Session A
- Protected Session B
- Maintenance-race scripts when required
- Invariant checks
- Cleanup script

Additional files are acceptable.

Report missing or empty files.

---

## 2. Schema and implementation compatibility

Verify that:

- Table and column names match the migrated schema.
- Procedure names and parameters match Step 12.
- Status and impact-level values are valid.
- Test identifiers satisfy data types and foreign keys.
- Setup can create all required prerequisite rows.
- Scripts do not depend on undeclared session variables from another query window.

A test package that cannot execute against the Step 12 database is not ready.

---

## 3. Genuine concurrency

For each two-session test, verify that:

- Session A and Session B run in separate windows.
- Both transactions overlap in time.
- The scripts include deterministic timing or clear manual synchronization.
- The unsafe test lets both sessions check before either commits.
- The protected test causes one session to wait on the per-space lock.
- The second protected session performs its fresh recheck only after the first transaction releases the lock.
- Output timestamps or messages make the interleaving observable.

Two sequential procedure calls in one script do not satisfy this criterion.

---

## 4. Unsafe demonstration validity

Verify that the unsafe test:

- Represents the check-then-act race identified in Step 11.
- Uses the same space and overlapping periods.
- Does not call the protected procedure.
- Does not permanently weaken production permissions or procedures.
- Produces an incorrect final state in isolated test data, or another unambiguous proof of the race.
- Is reset before protected testing.

Ensure the unsafe demonstration is clearly labeled as intentionally incorrect test logic.

---

## 5. Protected approval proof

Verify that:

- Both sessions call the real Step 12 approval procedure.
- Both target the same space and overlapping periods.
- One approval succeeds.
- The other waits and then receives the expected business-rule rejection.
- The rejected session does not leave partial approval data.
- Final invariant checks return zero overlapping approved pairs.
- Tests cover or can be parameterized for:
  - Instant/instant
  - Staff/staff
  - Instant/staff

A test that only shows one session blocked temporarily is insufficient; the final state must be checked.

---

## 6. Maintenance race proof

When the selected design protects maintenance escalation, verify that tests demonstrate:

- Approval first:
  - Escalation waits.
  - The committed booking appears in the affected-booking result.
- Escalation first:
  - Approval waits.
  - Approval is rejected after seeing out-of-service maintenance.

If only one ordering is implemented, classify the missing second ordering according to the approved test scope.

Verify both procedures lock the same space.

---

## 7. Correctness and boundary coverage

Verify coverage of:

- Same space and overlapping time
- Same space and non-overlapping time
- Different spaces and overlapping time
- Adjacent intervals
- Equal intervals
- Out-of-service maintenance
- Advisory maintenance
- Already finalized booking

Check that valid operations are not incorrectly rejected.

---

## 8. Invariant and evidence quality

Verify that invariant checks:

- Detect every pair of approved overlaps.
- Use correct interval logic.
- Restrict to test data when appropriate.
- Show booking IDs, space, time ranges, and statuses clearly.
- Check maintenance and affected-booking outcomes.
- Are run after unsafe and protected scenarios.

Review execution evidence:

- Actual results are separated from expected results.
- Pass/fail is supported by outputs.
- Dates, testers, and evidence references are recorded when execution occurred.
- No result is claimed as observed when it is only predicted.

---

## 9. Test isolation and cleanup

Verify that:

- Setup is rerunnable.
- Test rows are uniquely identifiable.
- Cleanup removes only test data.
- Foreign-key delete order is safe.
- Unsafe overlapping rows do not contaminate protected tests.
- No transaction remains open after a script completes or errors.
- A failed expected procedure call does not skip cleanup permanently.
- Tests are not recommended for production data.

A cleanup script containing broad unfiltered deletes is a blocking issue.

---

## 10. Reproducibility and documentation

Verify that README instructions state:

- Required database and prerequisites
- Exact script order
- When to open Session B
- What messages or blocking behavior to observe
- Which invariant query to run
- Expected results
- Reset and cleanup steps
- Whether actual execution was completed

An independent evaluator should be able to reproduce the test without asking the author how to coordinate the sessions.

---

## 11. Step 14 and report-readiness examination

Although Step 14 data generation may proceed independently, determine whether the Step 13 package is ready to be used as concurrency evidence in the final report.

Answer explicitly:

1. Is the unsafe race convincingly demonstrated?
2. Is prevention tested through the real Step 12 procedure?
3. Is final-state correctness verified?
4. Are all scripts schema-compatible?
5. Is test data safely isolated?
6. Are maintenance interactions tested when required?
7. Are valid non-conflicting operations covered?
8. Are actual and expected results clearly separated?
9. Can an independent evaluator reproduce the tests?
10. Are any blocking issues unresolved?

Provide:

- **Ready evidence**
- **Blocking gaps**
- **Non-blocking improvements**

---

## 12. Quality assessment

Assign 0–10:

| Category | Evaluation focus |
| --- | --- |
| Completeness | Required test files and scenarios exist |
| Schema Compatibility | Scripts match Step 12 and the migrated schema |
| Concurrency Validity | Tests create genuine concurrent interleavings |
| Unsafe Demonstration | The original race is shown correctly |
| Prevention Evidence | The protected procedure preserves the invariant |
| Maintenance Interaction | Escalation race is tested correctly |
| Isolation and Cleanup | Tests are safe and rerunnable |
| Reproducibility | An independent evaluator can run the package |
| Report Readiness | Results can support the final Phase 2 report |

Do not inflate scores because the folder contains many files.

---

# Output format

# 1. Review Summary

State:

- What was reviewed
- Whether tests were actually executed
- Most important strength
- Most important risk
- Overall readiness

# 2. Files Reviewed

List every file in the Step 13 directory.

# 3. Scenario Coverage

| Test Area | Script(s) | Genuine Two-Session Test? | Expected Result Defined? | Actual Result Recorded? | Status |
| --- | --- | --- | --- | --- | --- |

Include:

- Unsafe overlap
- Protected overlap
- Instant/instant
- Staff/staff
- Instant/staff
- Approval versus escalation
- Non-overlap
- Different spaces
- Adjacent intervals
- Maintenance impact cases
- Invariant checks
- Cleanup

# 4. Interleaving Walkthrough

For each main two-session test, reconstruct:

1. Session A action
2. Session B action
3. Lock or read state
4. Commit/recheck order
5. Final database state

State whether the interleaving actually proves the intended claim.

# 5. Issues Found

For each issue:

## Issue R13-X — Short title

- **Severity:** Blocking / Major / Minor / Observation
- **Issue:**
- **Evidence:**
- **Why this is a problem:**
- **Impact on concurrency evidence:**
- **Suggested correction:**

# 6. Invariant and Evidence Review

State:

- Unsafe-test invariant result
- Protected-test invariant result
- Maintenance-race result
- Whether evidence is actual or pending
- Any mismatch between expected and observed results

# 7. Readiness Examination

Answer all ten readiness questions explicitly.

# 8. Scores

| Category | Score |
| --- | --- |
| Completeness | X/10 |
| Schema Compatibility | X/10 |
| Concurrency Validity | X/10 |
| Unsafe Demonstration | X/10 |
| Prevention Evidence | X/10 |
| Maintenance Interaction | X/10 |
| Isolation and Cleanup | X/10 |
| Reproducibility | X/10 |
| Report Readiness | X/10 |

# 9. Required Revisions

List only revisions required before the tests can be accepted as concurrency evidence.

If none:

`No blocking revisions are required before using Step 13 results in the Phase 2 report.`

# 10. Final Readiness Verdict

Choose exactly one:

- **READY FOR STEP 14 AND REPORT INTEGRATION**
- **READY WITH MINOR REVISIONS**
- **NOT READY FOR STEP 14 OR REPORT INTEGRATION**

Provide a brief justification.

---

## Final response behavior

After creating the review:

1. State that `docs/13-concurrency-tests-review-G02.md` was created or updated.
2. State the final readiness verdict.
3. State whether tests were actually executed or only reviewed statically.
4. Summarize only blocking and major issues.
5. Do not proceed to Step 14 automatically.
