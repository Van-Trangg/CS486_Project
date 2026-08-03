---
description: Run Phase 2 Step 13 concurrency tests, review the evidence, and revise the test package before Step 14
---

Use the Step 13 concurrency tests skill in:

`.opencode/skills/13-concurrency-tests/SKILL.md`

Use the Step 13 review skill in:

`.opencode/skills/13-concurrency-tests/review-SKILL.md`

Treat the latest approved concurrency design, implementation, and migrated schema as the testing baseline, especially:

- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `docs/12-concurrency-implementation-review-G02.md`
- Relevant review files under `docs/`

Use `$ARGUMENTS` only as optional additional instructions from the user. Do not treat it as a replacement for the approved project artifacts.

Run the following workflow:

1. Inspect the project and verify that the required schema, migration, Step 11 design, Step 12 implementation, and Step 12 review files exist.

2. Read the relevant files fully and verify the exact Microsoft SQL Server object names, including:
   - Protected booking-approval procedure and parameters
   - Protected maintenance-escalation procedure and parameters, if implemented
   - `SPACE`, `BOOKING`, and `MAINTENANCE_RECORD`
   - Primary and foreign keys
   - Booking status and approval-path values
   - Requested start and end columns
   - Maintenance impact-level and maintenance-period columns

3. Check the Step 12 review verdict before generating tests:
   - If Step 12 is `NOT READY FOR STEP 13`, stop and report the blocking issues.
   - Do not generate misleading tests for an implementation that is not ready.
   - If Step 12 is ready with only non-blocking revisions, continue only when the test package can use the implementation without repairing production SQL.

4. Create or update only:
   - `outputs/13-concurrency-tests-G02/`

5. The Step 13 directory must contain at least:
   - `README.md`
   - `00-setup-test-data.sql`
   - `01-unsafe-conflict-session-a.sql`
   - `02-unsafe-conflict-session-b.sql`
   - `03-reset-after-unsafe-test.sql`
   - `04-protected-approval-session-a.sql`
   - `05-protected-approval-session-b.sql`
   - `06-maintenance-race-session-a.sql`
   - `07-maintenance-race-session-b.sql`
   - `08-invariant-checks.sql`
   - `09-cleanup-test-data.sql`

6. Implement the required test scenarios:
   - Unsafe check-then-act race using two SQL Server sessions.
   - Protected overlapping approvals using the real Step 12 procedure.
   - Instant/instant, staff/staff, and instant/staff pairings, either as separate tests or documented parameter variations.
   - Approval versus maintenance escalation when Step 11 and Step 12 protect this race.
   - Same space with non-overlapping times.
   - Different spaces with overlapping times.
   - Adjacent bookings where one ends exactly when the other begins.
   - Overlapping `Out-of-Service` maintenance.
   - Overlapping advisory maintenance.
   - Re-approval of an already finalized booking.

7. Keep Step 13 tests safe and reproducible:
   - Use clearly identifiable test-only records.
   - Do not delete or modify unrelated project data.
   - Do not disable foreign keys or production constraints.
   - Use two actual sessions for concurrency tests.
   - Use `WAITFOR` only inside test scripts, never inside Step 12 production procedures.
   - Make execution order clear in `README.md`.
   - Add timestamped `PRINT` or `SELECT` output where useful.
   - Reset unsafe test data before protected tests.
   - Ensure cleanup removes only test records.
   - Do not leave transactions open after success or error.

8. Add invariant checks that verify:
   - The unsafe test can produce at least one approved overlapping pair in isolated test data.
   - Protected tests leave zero approved overlapping pairs.
   - Valid non-overlapping or different-space operations are still allowed.
   - Maintenance escalation produces the expected affected-booking result.
   - Test booking and maintenance states match the expected outcomes.

9. Distinguish expected results from actual results:
   - Do not claim tests passed unless they were executed.
   - If a SQL Server runtime is available, execute the tests using two sessions and record the actual results.
   - If runtime execution is unavailable, prepare the scripts and mark actual results as `Pending execution`.
   - Do not fabricate execution times, screenshots, blocking duration, or pass/fail evidence.

10. Run the Step 13 review skill and create or update:
    - `docs/13-concurrency-tests-review-G02.md`

11. Do not automatically start Step 14.

At the end, report:

- Files created or updated
- Test scenarios included
- Final Step 13 readiness verdict
- Whether tests were actually executed or only prepared
- The result of the unsafe and protected invariant checks, if executed
- Remaining schema mismatches, assumptions, or unresolved blockers
