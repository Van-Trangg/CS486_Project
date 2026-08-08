# Step 13 Concurrency Tests

## Environment

- DBMS: Microsoft SQL Server.
- Database: `University` in a disposable database or controlled project-database copy.
- Prerequisites: apply Steps 05, 10, and 12. Step 12 review verdict must be `READY FOR STEP 13`.
- Protected procedures: `dbo.sp_SubmitBooking`, `dbo.sp_ApproveBooking`, and `dbo.sp_EscalateMaintenanceImpact`.
- Physical tables: `dbo.SPACE`, `dbo.BOOKING`, and `dbo.MAINTENANCERECORD` (not `MAINTENANCE_RECORD`).
- Use SQLCMD mode for `11-configure-protected-pairing.sql`. When deploying Step 12 with `sqlcmd`, use `-I` so procedures retain `QUOTED_IDENTIFIER ON`.

## Test Safety

- Run in a disposable database or controlled project copy, never against production data.
- Test users, spaces, bookings, maintenance, acknowledgements, and history use the `T13-` prefix or reference a `T13-` space.
- Helper tables are `dbo.STEP13_UNSAFE_BOOKING`, `dbo.STEP13_TEST_CONFIG`, and `dbo.STEP13_MAINTENANCE_RESULT`.
- No production procedure, trigger, constraint, foreign key, or permission is altered or disabled.
- `WAITFOR` appears only in Step 13 scripts. Every explicit transaction commits or rolls back on success or error.
- `09-cleanup-test-data.sql` deletes only `T13-` data and drops only the three Step 13 helper tables.

## Execution Instructions

### U1: Unsafe Check-Then-Act

1. Run `00-setup-test-data.sql`.
2. Open two SQL Server windows and run `01-unsafe-conflict-session-a.sql` in Session A.
3. When A prints `checked availability`, run `02-unsafe-conflict-session-b.sql` in Session B.
4. After both commit, run `08-invariant-checks.sql`; unsafe overlap count must be at least one.
5. Run `03-reset-after-unsafe-test.sql` before protected testing.

### P1-P3: Protected Approval Pairings

For each pairing, run fresh setup and configure exactly one value:

```text
sqlcmd -S localhost -E -b -I -v Pairing=StaffStaff -i 11-configure-protected-pairing.sql
sqlcmd -S localhost -E -b -I -v Pairing=InstantInstant -i 11-configure-protected-pairing.sql
sqlcmd -S localhost -E -b -I -v Pairing=InstantStaff -i 11-configure-protected-pairing.sql
```

1. Open two SQL Server windows and run `04-protected-approval-session-a.sql` in Session A.
2. When A prints its coordination message, run `05-protected-approval-session-b.sql` in Session B.
3. Wait for both sessions to finish, then run `08-invariant-checks.sql`.
4. Protected overlap count must be zero, both session-finished flags must be one, and the pairing result must end in `_HOLDS`.
5. Run fresh setup before configuring the next pairing.

`StaffStaff` calls `dbo.sp_ApproveBooking` in both sessions. `InstantInstant` calls the real `dbo.sp_SubmitBooking` in both sessions. `InstantStaff` calls `dbo.sp_SubmitBooking` in A and `dbo.sp_ApproveBooking` in B. For the instant pairings, A temporarily holds the same `SPACE` row only to queue B; after A releases the test gate, both real production operations contend for the Step 12 lock. The queued winner becomes Approved, while the losing instant candidate is validly inserted as `Staff`/`Pending` after its fresh recheck.

### M1: Approval First

1. Run fresh setup, then run `06-maintenance-race-session-a.sql` in Session A.
2. When A reports its approval is uncommitted, run `07-maintenance-race-session-b.sql` in Session B.
3. Escalation must wait, then return A's committed booking as affected.
4. Run `08-invariant-checks.sql`; it must return `M1_APPROVAL_FIRST_HOLDS`.

### M2: Escalation First

1. Run fresh setup, then run `13-maintenance-escalation-first-session-a.sql` in Session A.
2. When A reports that it holds the test gate, run `14-maintenance-escalation-first-session-b.sql` in Session B.
3. Escalation queues first. After A releases the gate, escalation commits and A's real approval must wait/recheck and receive error `51013`.
4. Run `08-invariant-checks.sql`; it must return `M2_ESCALATION_FIRST_HOLDS`.

`12-maintenance-affected-booking.sql` is an optional sequential control for the escalation-first fresh recheck. It is not concurrency evidence.

### B1: Boundaries and Maintenance

Run fresh setup, then `10-boundary-and-maintenance-cases.sql` and `08-invariant-checks.sql`. B1 asserts same-space non-overlap, different-space overlap, adjacent intervals, equal-interval rejection, Out-of-Service rejection, advisory approval with one applicable acknowledgement, and safe re-approval rejection.

Run `09-cleanup-test-data.sql` after all scenarios.

## Expected Results

| Test ID | Scenario | Session A Expected | Session B Expected | Final Invariant |
| --- | --- | --- | --- | --- |
| U1 | Unsafe check-then-act | Checks empty state, then inserts Approved | Checks before A commits, then inserts Approved | Unsafe overlap count >= 1 |
| P1 | Staff/Staff | Approves and holds transaction | Waits, rechecks, receives 51012 | `STAFF_STAFF_HOLDS`; zero protected overlaps |
| P2 | Instant/Instant | Real submission waits/rechecks and becomes Staff/Pending | Queued real submission becomes Instant/Approved | `INSTANT_INSTANT_HOLDS`; zero protected overlaps |
| P3 | Instant/Staff | Real submission waits/rechecks and becomes Staff/Pending | Queued Staff approval becomes Approved | `INSTANT_STAFF_HOLDS`; zero protected overlaps |
| M1 | Approval first | Approves and holds transaction | Escalation waits, then returns affected booking | `M1_APPROVAL_FIRST_HOLDS` |
| M2 | Escalation first | Approval waits/rechecks and receives 51013 | Queued escalation commits | `M2_ESCALATION_FIRST_HOLDS` |
| B1 | Boundaries and maintenance | Valid cases succeed | Invalid cases return 51012, 51013, or 51006 | `BOUNDARY_CASES_HOLD`; zero protected overlaps |

## Actual Result Recording

Actual results are recorded only after execution. See `execution-results.md` for the server, observed rows, errors, invariant outputs, and cleanup result.

| Test ID | Date | Tester | Actual Result | Evidence | Pass/Fail |
| --- | --- | --- | --- | --- | --- |
| U1 | 2026-08-08 | OpenCode agent | One unsafe approved overlap pair observed | `execution-results.md` | Pass |
| P1 | 2026-08-08 | OpenCode agent | A Approved; B waited and received 51012 | `execution-results.md` | Pass |
| P2 | 2026-08-08 | OpenCode agent | B Instant/Approved; A Staff/Pending | `execution-results.md` | Pass |
| P3 | 2026-08-08 | OpenCode agent | B Staff/Approved; A Staff/Pending | `execution-results.md` | Pass |
| M1 | 2026-08-08 | OpenCode agent | Escalation waited and returned approved booking | `execution-results.md` | Pass |
| M2 | 2026-08-08 | OpenCode agent | Escalation won; approval waited and received 51013 | `execution-results.md` | Pass |
| B1 | 2026-08-08 | OpenCode agent | All asserted boundary outcomes matched | `execution-results.md` | Pass |
