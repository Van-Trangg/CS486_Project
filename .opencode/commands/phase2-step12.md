---
description: Run Phase 2 Step 12 concurrency implementation, review readiness, and revise the SQL before Step 13
---

Use the Step 12 concurrency implementation skill in:

`.opencode/skills/12-concurrency-implementation/SKILL.md`

Use the Step 12 review skill in:

`.opencode/skills/12-concurrency-implementation/Review-SKILL.md`

Treat the latest approved Phase 2 design and migrated schema as the implementation baseline, especially:

- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- Relevant review files under `docs/`

Use `$ARGUMENTS` only as optional additional instructions from the user. Do not treat it as a replacement for the approved project artifacts.

Run the following workflow:

1. Inspect the project and verify that the required schema, migration, and Step 11 design files exist.

2. Read the relevant files fully and verify the exact Microsoft SQL Server object names, including:
   - `SPACE`
   - `BOOKING`
   - `MAINTENANCE_RECORD`
   - Primary and foreign keys
   - Booking status and approval columns
   - Requested start and end columns
   - Maintenance impact level and maintenance period columns

3. Generate or update only:
   - `outputs/12-concurrency-implementation-G02.sql`

4. Implement the approved Step 11 concurrency design. At minimum:
   - Create or update the protected booking-approval procedure.
   - Begin the transaction before acquiring the per-space lock.
   - Acquire the `SPACE` row lock using the approved `UPDLOCK, HOLDLOCK` protocol.
   - Recheck overlapping approved bookings inside the same transaction.
   - Recheck overlapping `Out-of-Service` maintenance.
   - Approve only when all checks pass.
   - Use a short transaction with `SET XACT_ABORT ON`, `TRY...CATCH`, safe rollback, and `THROW`.
   - Keep deadlock retry outside the stored procedure.
   - Implement maintenance escalation with the same per-space lock if required by Step 11.
   - Use one consistent lock order: `SPACE` first, then related booking or maintenance data.

5. Keep Step 12 within scope:
   - Do not generate Step 13 two-session test scripts.
   - Do not add test-only `WAITFOR` statements to production procedures.
   - Do not perform Step 15 index tuning.
   - Do not make concurrency correctness depend on a new index.
   - Do not modify approved earlier outputs unless a blocking inconsistency is found and clearly reported.

6. Run the Step 12 review skill and create or update:
   - `docs/12-concurrency-implementation-review-G02.md`

7. Do not automatically start Step 13.

At the end, report:

- Files created or updated
- Stored procedures implemented
- Final Step 13 readiness verdict
- Whether runtime SQL execution was performed or the review was static only
- Remaining schema mismatches, assumptions, or unresolved blockers
