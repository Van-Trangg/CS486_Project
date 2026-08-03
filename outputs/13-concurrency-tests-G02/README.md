# Step 13 Concurrency Tests

## Environment

- DBMS: Microsoft SQL Server.
- Database: `University` in a disposable test database or a controlled copy of the project database. Do not run the unsafe demonstration against production data.
- Prerequisites: run Steps 05, 10, and 12 successfully. The tests require `dbo.sp_ApproveBooking` and `dbo.sp_EscalateMaintenanceImpact`.
- Test rows use the `T13-` prefix. Setup also creates a disposable `dbo.STEP13_UNSAFE_BOOKING` table solely for the unsafe demonstration; cleanup drops it.

## Test Safety

- `00-setup-test-data.sql` deletes only rows whose IDs or codes begin with `T13-` and then recreates them.
- Run `09-cleanup-test-data.sql` when testing is complete.
- The unsafe test intentionally uses a separate test-only table. It does not alter, disable, or bypass the production booking procedure, trigger, foreign keys, or permissions.
- Each session script commits or rolls back its own transaction. Do not run either protected procedure inside a caller-owned transaction because Step 12 correctly rejects that usage.

## Execution Order

1. Run `00-setup-test-data.sql` once.
2. For the unsafe demonstration, run `01-unsafe-conflict-session-a.sql`, wait for its `checked availability` message, then run `02-unsafe-conflict-session-b.sql` in a second query window. Run `08-invariant-checks.sql`, then `03-reset-after-unsafe-test.sql`.
3. For protected approval, optionally run `11-configure-protected-pairing.sql` to choose instant/instant, staff/staff, or instant/staff. Open two windows, start `04-protected-approval-session-a.sql`, and immediately start `05-protected-approval-session-b.sql` when A reports that it holds the test space lock. Run `08-invariant-checks.sql` after both complete.
4. For the maintenance race, reset with `00-setup-test-data.sql`, start `06-maintenance-race-session-a.sql`, then start `07-maintenance-race-session-b.sql` while Session A reports that it holds the lock. Run `08-invariant-checks.sql` after both complete.
5. Reset with setup, run `12-maintenance-affected-booking.sql` to verify the approval-first affected-booking result, then reset again. Run `10-boundary-and-maintenance-cases.sql`, inspect its output and `08-invariant-checks.sql`, then run `09-cleanup-test-data.sql`.

Session B should start during the stated `WAITFOR` period. The protected sessions use the actual Step 12 procedures; the short test-only lock held before a procedure call makes the same `SPACE` resource contention visible without inserting a delay into production code. The protected approval winner can vary after the test lock releases, but exactly one overlapping booking must be approved.

## Expected Results

| Test ID | Scenario | Session A Expected | Session B Expected | Final Invariant |
| --- | --- | --- | --- | --- |
| U1 | Unsafe check-then-act | Sees no approved overlap; commits test-only approval | Sees no approved overlap; commits test-only approval | At least one `STEP13_UNSAFE_BOOKING` overlap |
| P1 | Protected instant/instant overlap | Calls `sp_ApproveBooking` | Waits for `SPACE` lock, then one caller receives error 51012 | Zero `T13-PROT-%` approved overlaps |
| P2 | Staff/staff variation | Change `T13-PROT-A/B` to `Staff`; call with `T13-STAFF` in both windows | Same as P1 | Zero overlaps |
| P3 | Instant/staff variation | Leave A `Instant`; set B `Staff` and pass `T13-STAFF` | Same as P1 | Zero overlaps |
| M1 | Escalation first after lock release | Calls `sp_ApproveBooking` after releasing test lock | `sp_EscalateMaintenanceImpact` waits, escalates, returns no affected rows | `T13-MAINT-APP` remains Pending; maintenance is out-of-service |
| M2 | Approval first follow-up | Approves the overlap before escalation | Escalation returns the approved booking as affected | Maintenance impact history records advisory to out-of-service |
| B1 | Valid boundaries and maintenance | Sequential procedure calls | Expected successes/rejections printed | Valid non-conflicting bookings approved; OOS blocked; advisory allowed |

## Actual Result Recording

Actual results are **Pending execution**. Do not mark a row passed until the commands are run in two actual SQL Server sessions and output or screenshots are retained.

| Test ID | Date/Time | Tester | Actual Result | Evidence | Pass/Fail |
| --- | --- | --- | --- | --- |
| U1 | Pending execution |  |  |  |  |
| P1 | Pending execution |  |  |  |  |
| M1 | Pending execution |  |  |  |  |
| B1 | Pending execution |  |  |  |  |
