# 1. Review Summary

**Reviewed:** the complete `outputs/13-concurrency-tests-G02/` package against the Phase 2 requirement, Steps 11-12, and the migrated schema.

**Execution status:** Prepared and statically reviewed only. No SQL Server instance is available in this workspace, so no blocking duration, procedure result, or invariant output is claimed as observed.

**Most important strength:** The package uses two actual query windows and deterministic test-only `SPACE` lock holds to queue the real Step 12 procedures. Its unsafe test is isolated in a disposable table rather than weakening production controls.

**Most important risk:** The package is not yet report evidence. An evaluator must execute U1, P1, M1, M2, and B1 in a disposable SQL Server database and retain the outputs.

**Overall readiness:** Ready to execute, with runtime evidence still required before final-report use.

# 2. Files Reviewed

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
- `10-boundary-and-maintenance-cases.sql`
- `11-configure-protected-pairing.sql`
- `12-maintenance-affected-booking.sql`

# 3. Scenario Coverage

| Test Area | Script(s) | Genuine Two-Session Test? | Expected Result Defined? | Actual Result Recorded? | Status |
| --- | --- | --- | --- | --- | --- |
| Unsafe overlap | 01, 02, 08 | Yes | Yes | Pending execution | Ready |
| Protected overlap | 04, 05, 08 | Yes | Yes | Pending execution | Ready |
| Instant/instant | 04, 05 | Yes | Yes | Pending execution | Ready |
| Staff/staff | 04, 05, 11 | Yes | Yes | Pending execution | Ready |
| Instant/staff | 04, 05, 11 | Yes | Yes | Pending execution | Ready |
| Approval versus escalation | 06, 07, 08 | Yes | Yes | Pending execution | Ready |
| Approval-first affected booking | 12 | No, deterministic follow-up | Yes | Pending execution | Ready |
| Non-overlap | 10 | No, boundary case | Yes | Pending execution | Ready |
| Different spaces | 10 | No, boundary case | Yes | Pending execution | Ready |
| Adjacent intervals | 10 | No, boundary case | Yes | Pending execution | Ready |
| Maintenance impact cases | 10, 12 | No, boundary/follow-up | Yes | Pending execution | Ready |
| Invariant checks | 08 | N/A | Yes | Pending execution | Ready |
| Cleanup | 09 | N/A | Yes | Pending execution | Ready |

# 4. Interleaving Walkthrough

## U1 -- Unsafe Check-Then-Act

1. Session A checks the disposable unsafe table, finds no approved overlap, and waits ten seconds inside its transaction.
2. Session B starts during that wait, checks the same table under read committed, cannot see A's uncommitted state, waits three seconds, then inserts and commits an overlapping approved row.
3. Session A inserts and commits its own overlapping row after its delay.
4. `08-invariant-checks.sql` detects the pair in `dbo.STEP13_UNSAFE_BOOKING`.
5. This correctly models Step 11's phantom check-then-act race without altering production objects.

## P1 -- Protected Approval

1. Session A holds `T13-SPACE-A` with the same `UPDLOCK, HOLDLOCK` protocol used by Step 12, giving Session B a visible window to enter `dbo.sp_ApproveBooking`.
2. Session B calls the actual protected procedure and waits on that space lock.
3. A releases the test lock and calls the actual protected procedure for an overlapping booking.
4. The two procedure calls serialize on the same `SPACE` row. One records `Approved`; the other rechecks and receives error 51012.
5. The invariant query must return zero approved overlaps for `T13-` bookings. Which session succeeds can vary, but the final invariant cannot.

## M1 -- Escalation First

1. Session A holds the same space lock while Session B enters `dbo.sp_EscalateMaintenanceImpact` and waits.
2. A releases the test lock, waits one second to allow the queued escalation to take the lock, then calls `dbo.sp_ApproveBooking`.
3. B changes the maintenance impact to `out-of-service` and commits.
4. A obtains the lock afterward, rechecks maintenance, and must receive error 51013.
5. The maintenance is out-of-service and the pending booking remains unapproved.

## M2 -- Approval First Follow-Up

1. A fresh setup creates the advisory and pending booking.
2. `12-maintenance-affected-booking.sql` approves the overlapping booking through the actual protected procedure.
3. The same script escalates the advisory through the actual protected procedure.
4. The escalation result set must include the approved booking, and impact history must record `advisory` to `out-of-service`.
5. M2 validates the required affected-booking result; M1 supplies the genuine concurrent ordering.

# 5. Issues Found

## Issue R13-1 -- Runtime evidence is pending

- **Severity:** Minor
- **Issue:** The scripts could not be executed because no SQL Server instance is reachable from this workspace.
- **Evidence:** LocalDB connection attempts time out; README and result template correctly label all results pending.
- **Why this is a problem:** Expected states and timing are not proof of observed locking behavior.
- **Impact on concurrency evidence:** The package cannot yet be cited as completed test evidence in the final report.
- **Suggested correction:** Execute the scripts using two SSMS or `sqlcmd` sessions in a disposable `University` database, retain output for U1, P1, M1, M2, B1, and populate the README results table.

# 6. Invariant and Evidence Review

- **Unsafe-test invariant:** Pending execution. After U1 and before reset, the isolated-table query must return at least one overlapping approved pair.
- **Protected-test invariant:** Pending execution. After P1, the `dbo.BOOKING` test-prefix overlap query must return zero rows.
- **Maintenance-race result:** Pending execution. M1 must leave the booking pending and maintenance out-of-service; M2 must return the pre-approved booking in its affected-booking result.
- **Evidence type:** Expected only; no actual result, timestamp, screenshot, or duration has been fabricated.
- **Observed-versus-expected mismatch:** None can be assessed until execution.

# 7. Readiness Examination

1. **Is the unsafe race convincingly demonstrated?** Yes, when executed in two sessions; its interleaving is deterministic and final state is queried.
2. **Is prevention tested through the real Step 12 procedure?** Yes, P1 and M1 use the actual procedure names and parameters.
3. **Is final-state correctness verified?** Yes, `08-invariant-checks.sql` checks unsafe and protected overlap states, bookings, maintenance, history, and current-session transaction count.
4. **Are all scripts schema-compatible?** Yes. They use the migrated `BOOKING`, `SPACE`, `MAINTENANCERECORD`, `MAINTENANCE_IMPACT_HISTORY`, and Step 12 procedure contracts.
5. **Is test data safely isolated?** Yes. Identifiers use `T13-`; cleanup predicates are restricted to that prefix and drops only the dedicated unsafe table.
6. **Are maintenance interactions tested when required?** Yes. M1 covers a genuine escalation-first race and M2 covers the approval-first affected-booking result.
7. **Are valid non-conflicting operations covered?** Yes: non-overlap, different spaces, adjacency, advisory maintenance, and finalized-booking rejection are covered in script 10.
8. **Are actual and expected results clearly separated?** Yes. Expected outcomes are documented and actual results are explicitly pending.
9. **Can an independent evaluator reproduce the tests?** Yes. README supplies prerequisites, exact order, two-window coordination points, reset, cleanup, expected results, and a recording template.
10. **Are any blocking issues unresolved?** No.

**Ready evidence:** isolated unsafe race design, real protected-procedure calls, deterministic two-session coordination, affected-booking follow-up, bounded invariant checks, and rerunnable cleanup.

**Blocking gaps:** None.

**Non-blocking improvements:** Record real output and lock-wait observations before relying on the package as final-report evidence.

# 8. Scores

| Category | Score |
| --- | --- |
| Completeness | 10/10 |
| Schema Compatibility | 10/10 |
| Concurrency Validity | 9/10 |
| Unsafe Demonstration | 10/10 |
| Prevention Evidence | 9/10 |
| Maintenance Interaction | 9/10 |
| Isolation and Cleanup | 10/10 |
| Reproducibility | 10/10 |
| Report Readiness | 7/10 |

# 9. Required Revisions

No blocking revisions are required before using Step 13 results in the Phase 2 report.

Runtime execution evidence must be collected before describing those results as observed in the report.

# 10. Final Readiness Verdict

**READY WITH MINOR REVISIONS**

The package is complete, isolated, and ready for genuine two-session execution. The sole remaining revision is to run it and record actual evidence; no production SQL or test-script repair is required.
