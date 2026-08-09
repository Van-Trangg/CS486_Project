# Step 13 Concurrency Tests

## Environment

- DBMS: Microsoft SQL Server.
- Database: one fresh disposable database per scenario, named `Step13G02_*`.
- Baseline: apply Step 05, then Step 10, then Step 12 to the disposable database, or restore/clone a verified database with that exact final schema and procedure set.
- Protected procedures: `dbo.sp_SubmitBooking`, `dbo.sp_ApproveBooking`, and `dbo.sp_EscalateMaintenanceImpact`.
- Physical tables: `dbo.SPACE`, `dbo.BOOKING`, and `dbo.MAINTENANCERECORD`; the schema does not define `MAINTENANCE_RECORD`.
- Required SQLCMD variables: `DatabaseName` for every SQL file and `Pairing` for `11-configure-protected-pairing.sql`.
- Use SQLCMD mode or `sqlcmd -I` so `QUOTED_IDENTIFIER ON` is retained.
- Every concurrent worker explicitly uses `READ COMMITTED`; setup records the database snapshot-isolation options in its evidence output.

The user has accepted Step 12 as the authoritative implementation for this Step 13 run. Step 13 therefore tests the current procedure behavior and does not reopen older Step 12 review findings.

## Disposable Database Lifecycle

The migrated schema makes `BOOKING_ADVISORY_ACK` and `MAINTENANCE_IMPACT_HISTORY` immutable. Row-level setup/cleanup cannot safely delete those audit rows. Each scenario therefore has this lifecycle:

1. Create or restore a fresh database named `Step13G02_<scenario>` with the exact Step 05 -> Step 10 -> Step 12 baseline.
2. Run `00-setup-test-data.sql` once with `-v DatabaseName=<name>`. Setup verifies migrated columns, exact protected parameter signatures, required `UPDLOCK`/`HOLDLOCK` definitions, enabled immutable triggers, and absence of production `WAITFOR` statements.
3. Run only that scenario and its invariant checks.
4. Preserve the session outputs needed as evidence.
5. Run `09-cleanup-test-data.sql` from `master`; it drops only the exact `Step13G02_*` database supplied through `DatabaseName`.

Do not reuse one scenario database for another scenario. Setup rejects existing `T13-` state instead of deleting immutable audit records.

## Test Safety

- Run only in a disposable database or controlled test copy, never production.
- The database name guard rejects names outside `Step13G02_*`.
- Test users, spaces, bookings, maintenance, acknowledgements, and history use `T13-` identifiers.
- Helper tables are `dbo.STEP13_UNSAFE_BOOKING`, `dbo.STEP13_TEST_CONFIG`, and `dbo.STEP13_MAINTENANCE_RESULT`.
- No production procedure, trigger, constraint, foreign key, or permission is altered or disabled.
- `WAITFOR` appears only in Step 13 scripts. Every explicit transaction commits or rolls back after success or error.
- `03-reset-after-unsafe-test.sql` deletes only rows from the isolated unsafe helper table.
- `09-cleanup-test-data.sql` drops only the prefix-guarded disposable database; it performs no audit-row deletes.

## Common Commands

Replace `<db>` with the scenario database name:

```powershell
sqlcmd -S localhost -E -C -b -I -v DatabaseName=<db> -i 00-setup-test-data.sql
sqlcmd -S localhost -E -C -b -I -v DatabaseName=<db> -i 08-invariant-checks.sql
sqlcmd -S localhost -E -C -b -I -v DatabaseName=<db> -i 09-cleanup-test-data.sql
```

## Execution Instructions

### U1: Unsafe Check-Then-Act

1. Prepare `Step13G02_U1` and run setup.
2. Open two SQLCMD-mode windows. Run `01-unsafe-conflict-session-a.sql`; when A prints `checked availability`, run `02-unsafe-conflict-session-b.sql`.
3. Wait for both sessions to commit, then run `08-invariant-checks.sql`.
4. Confirm unsafe overlap count is at least one and rows for both overlapping intervals are shown.
5. Run `03-reset-after-unsafe-test.sql`, confirm the count becomes zero, then drop the database with cleanup.

### P1-P3: Protected Approval Pairings

Use a fresh database for each pairing. After setup, configure exactly once:

```powershell
sqlcmd -S localhost -E -C -b -I -v DatabaseName=Step13G02_P1 Pairing=StaffStaff -i 11-configure-protected-pairing.sql
sqlcmd -S localhost -E -C -b -I -v DatabaseName=Step13G02_P2 Pairing=InstantInstant -i 11-configure-protected-pairing.sql
sqlcmd -S localhost -E -C -b -I -v DatabaseName=Step13G02_P3 Pairing=InstantStaff -i 11-configure-protected-pairing.sql
```

1. Run `04-protected-approval-session-a.sql` in Session A.
2. When A prints its coordination message, run `05-protected-approval-session-b.sql` in Session B.
3. Wait for both sessions, then run `08-invariant-checks.sql`.
4. Confirm protected overlap count is zero, both completion flags are one, and the pairing result ends in `_HOLDS`.
5. Preserve output and drop that pairing's disposable database.

`StaffStaff` calls `dbo.sp_ApproveBooking` in both sessions. `InstantInstant` calls the real `dbo.sp_SubmitBooking` in both sessions. `InstantStaff` calls `dbo.sp_SubmitBooking` in A and `dbo.sp_ApproveBooking` in B. In instant pairings, a test-only `SPACE` lock queues B; after the gate releases, both real Step 12 operations contend on the production lock. The queued winner is Approved and the losing instant candidate is inserted as `Staff`/`Pending` after its fresh recheck.

### M1: Approval First

1. Prepare `Step13G02_M1` and run setup.
2. Run `06-maintenance-race-session-a.sql` in A; when it reports the approval is uncommitted, run `07-maintenance-race-session-b.sql` in B.
3. B must wait, then the rows between `M1_PROCEDURE_RESULT_BEGIN` and `M1_PROCEDURE_RESULT_END` must include A's committed booking.
4. Run invariant checks; require `M1_APPROVAL_FIRST_HOLDS`, affected helper count `1`, transition count `1`, and zero protected overlaps.
5. Preserve both session outputs and drop the database.

### M2: Escalation First

1. Prepare `Step13G02_M2` and run setup.
2. Run `13-maintenance-escalation-first-session-a.sql` in A; when it holds the test gate, run `14-maintenance-escalation-first-session-b.sql` in B.
3. The procedure-result markers in B must contain no affected booking row; A must later receive error `51013`.
4. Run invariant checks; require `M2_ESCALATION_FIRST_HOLDS`, affected count `0`, transition count `1`, and zero protected overlaps.
5. Preserve outputs and drop the database.

`12-maintenance-affected-booking.sql` is an optional sequential control. It is not concurrency evidence.

### B1: Boundaries and Maintenance

Prepare `Step13G02_B1`, run setup, then `10-boundary-and-maintenance-cases.sql` and invariant checks. B1 covers same-space non-overlap, different-space overlap, adjacency, equal-interval rejection, out-of-service rejection, advisory approval with acknowledgement, and safe rejection of re-approval.

## Expected Results

| Test ID | Scenario | Session A Expected | Session B Expected | Final Invariant |
| --- | --- | --- | --- | --- |
| U1 | Unsafe check-then-act | Checks empty state, waits, inserts Approved | Checks before A commits, inserts Approved | Unsafe overlap count >= 1 |
| P1 | Staff/Staff | Approves and holds transaction | Waits, rechecks, receives `51012` | `STAFF_STAFF_HOLDS`; zero protected overlaps |
| P2 | Instant/Instant | Real submission waits/rechecks and becomes Staff/Pending | Queued real submission becomes Instant/Approved | `INSTANT_INSTANT_HOLDS`; zero protected overlaps |
| P3 | Instant/Staff | Real submission waits/rechecks and becomes Staff/Pending | Queued Staff approval becomes Approved | `INSTANT_STAFF_HOLDS`; zero protected overlaps |
| M1 | Approval first | Approves and holds transaction | Escalation waits and returns the approved booking | `M1_APPROVAL_FIRST_HOLDS`; one transition |
| M2 | Escalation first | Approval waits/rechecks and receives `51013` | Queued escalation commits with no affected row | `M2_ESCALATION_FIRST_HOLDS`; one transition |
| B1 | Boundaries and maintenance | Valid cases succeed | Invalid cases return `51012`, `51013`, or `51006` | `BOUNDARY_CASES_HOLD`; zero protected overlaps |

## Actual Result Recording

Actual results belong in `execution-results.md` only after execution against an exact-baseline disposable database.

| Test ID | Date/Time | Tester | Actual Result | Evidence | Pass/Fail |
| --- | --- | --- | --- | --- | --- |
| U1 | 2026-08-09 | OpenCode agent | Two unsafe Approved rows overlapped | `runtime-evidence/U1-*.txt` | Pass |
| P1 | 2026-08-09 | OpenCode agent | A Approved; B waited/rechecked and received `51012` | `runtime-evidence/P1-*.txt` | Pass |
| P2 | 2026-08-09 | OpenCode agent | B Instant/Approved; A Staff/Pending | `runtime-evidence/P2-*.txt` | Pass |
| P3 | 2026-08-09 | OpenCode agent | B Staff/Approved; A Staff/Pending | `runtime-evidence/P3-*.txt` | Pass |
| M1 | 2026-08-09 | OpenCode agent | Procedure returned the approval-first affected booking | `runtime-evidence/M1-*.txt` | Pass |
| M2 | 2026-08-09 | OpenCode agent | Empty affected result; approval received `51013` | `runtime-evidence/M2-*.txt` | Pass |
| B1 | 2026-08-09 | OpenCode agent | Valid boundaries allowed; invalid cases rejected | `runtime-evidence/B1-*.txt` | Pass |
