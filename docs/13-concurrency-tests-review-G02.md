# 1. Review Summary

**Reviewed:** every SQL and Markdown file in `outputs/13-concurrency-tests-G02/` against the Phase 2 requirement, the Phase 1 logical/physical baseline, the Step 9 migrated design, Steps 10-12, the Step 12 review, relevant review files under `docs/`, and both Step 13 skills.

**Execution status:** Executed on 2026-08-08 against SQL Server 16.0.1000.6, server `DESKTOP-MJJHKPQ`, database `University`. U1, P1, P2, P3, M1, and M2 used separate concurrent `sqlcmd` sessions. B1 and the optional M3 control were executed sequentially as documented. Cleanup completed and post-cleanup verification returned zero `T13-` users, spaces, bookings, and maintenance rows and NULL object IDs for all three helper tables.

**Most important strength:** The package exercises the actual Step 12 production paths for all three approval pairings and both maintenance orderings, then checks explicit final-state invariants rather than treating temporary blocking as proof.

**Most important risk:** The test-held `SPACE` gate used to deterministically queue short production procedures is test-only orchestration. It correctly targets the approved lock resource and does not alter production objects, but evidence proves the executed interleavings rather than every possible scheduler ordering.

**Overall readiness:** Complete, schema-compatible, reproducible, executed, and suitable as Step 13 report evidence.

# 2. Files Reviewed

- `README.md`
- `execution-results.md`
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
- `13-maintenance-escalation-first-session-a.sql`
- `14-maintenance-escalation-first-session-b.sql`

# 3. Scenario Coverage

| Test Area | Script(s) | Genuine Two-Session Test? | Expected Result Defined? | Actual Result Recorded? | Status |
| --- | --- | --- | --- | --- | --- |
| Unsafe overlap | 01, 02, 08 | Yes | Yes | Yes | Pass |
| Protected overlap | 04, 05, 08, 11 | Yes | Yes | Yes | Pass |
| Instant/instant | 04, 05, 08, 11 | Yes; both use real submission | Yes | Yes | Pass |
| Staff/staff | 04, 05, 08, 11 | Yes; both use real approval | Yes | Yes | Pass |
| Instant/staff | 04, 05, 08, 11 | Yes; real submission versus real approval | Yes | Yes | Pass |
| Approval-first escalation | 06, 07, 08 | Yes | Yes | Yes | Pass |
| Escalation-first approval | 13, 14, 08 | Yes | Yes | Yes | Pass |
| Same-space non-overlap | 10 | No; functional boundary test | Yes | Yes | Pass |
| Different spaces, overlapping time | 10 | No; functional boundary test | Yes | Yes | Pass |
| Adjacent intervals | 10 | No; functional boundary test | Yes | Yes | Pass |
| Equal intervals | 10 | No; functional rejection test | Yes | Yes | Pass |
| Out-of-Service maintenance | 10, 12, 13, 14 | Yes in M2; functional in B1/M3 | Yes | Yes | Pass |
| Advisory maintenance and acknowledgement | 00, 08, 10 | No; functional test | Yes | Yes | Pass |
| Already finalized booking | 10 | No; functional rejection test | Yes | Yes | Pass |
| Invariant checks | 08 | N/A | Yes | Yes | Pass |
| Cleanup | 09 | N/A | Yes | Yes | Pass |

# 4. Interleaving Walkthrough

## U1 - Unsafe Check-Then-Act

1. Session A began a transaction, checked the isolated unsafe table, found no overlap, and waited.
2. Session B began during A's wait, also checked before A committed, and found no visible overlap.
3. B inserted and committed an Approved row; A then inserted and committed its overlapping Approved row.
4. `08-invariant-checks.sql` returned unsafe overlap count `1` and displayed unsafe IDs `1` and `2` with overlapping periods.
5. The test genuinely demonstrates the Step 11 check-then-act race without weakening production procedures, permissions, triggers, or constraints.

## P1 - Staff/Staff

1. A called the real `dbo.sp_ApproveBooking`, approved booking `105234`, and held the caller transaction open while retaining the production `SPACE` lock.
2. B called the same procedure for overlapping booking `105235` and waited.
3. A committed. B acquired the lock, freshly reread availability, and received error `51012`.
4. Final state was one Staff/Approved row, one Staff/Pending row, both session-finished flags set, and protected overlap count `0`.
5. `STAFF_STAFF_HOLDS` proves the production Staff approval path preserves the invariant.

## P2 - Instant/Instant

1. A acquired a test-only `UPDLOCK, HOLDLOCK` gate on `T13-SPACE-A` and instructed B to start.
2. B called the real `dbo.sp_SubmitBooking` and queued on that `SPACE` row.
3. A released the gate and immediately called the real `dbo.sp_SubmitBooking`; B's already-queued transaction acquired the production lock first and created booking `105247` as Instant/Approved.
4. A's overlapping production submission waited, freshly rechecked the committed booking, and created booking `105248` as the valid Staff/Pending fallback.
5. Final result was `INSTANT_INSTANT_HOLDS` and protected overlap count `0`. No direct BOOKING insert or invalid Instant/Pending state was used.

## P3 - Instant/Staff

1. A held the same test-only `SPACE` gate while B called the real `dbo.sp_ApproveBooking` for Staff booking `105260`.
2. B queued on the approved Step 12 lock resource.
3. A released the gate and called the real `dbo.sp_SubmitBooking`; B acquired the lock first and committed Staff/Approved.
4. A waited, freshly rechecked, and created booking `105261` as Staff/Pending.
5. Final result was `INSTANT_STAFF_HOLDS` and protected overlap count `0`.

## M1 - Approval First

1. A called the real approval procedure for booking `105275` and held the approved transaction uncommitted.
2. B called the real escalation procedure for maintenance `3569` and waited on the same production `SPACE` lock.
3. A committed. B acquired the lock, escalated to `out-of-service`, wrote history row `954`, and returned approved booking `105275` as affected.
4. The helper table independently recorded the same post-commit affected predicate because Step 12 intentionally rejects `INSERT...EXEC` caller transactions.
5. Final result was `M1_APPROVAL_FIRST_HOLDS`, affected count `1`, and protected overlap count `0`.

## M2 - Escalation First

1. A acquired the test-only `SPACE` gate and instructed B to start escalation.
2. B called the real escalation procedure and queued first.
3. A released the gate and called the real approval procedure. B acquired the production lock, escalated maintenance `3572`, wrote history row `955`, and committed with no affected booking.
4. A acquired the lock afterward, freshly saw `out-of-service` maintenance, received error `51013`, and left booking `105286` Pending.
5. Final result was `M2_ESCALATION_FIRST_HOLDS`, affected count `0`, and protected overlap count `0`.

# 5. Issues Found

No blocking, major, or minor issues were found in the corrected and executed package.

## Issue R13-1 - Scope of execution evidence

- **Severity:** Observation
- **Issue:** The evidence demonstrates the deliberately coordinated interleavings that were executed; it is not an exhaustive scheduler-state proof.
- **Evidence:** `README.md` documents deterministic `WAITFOR` coordination and test-held `SPACE` gates, and `execution-results.md` explicitly limits its claim to executed interleavings.
- **Why this is a problem:** It is not a defect; it defines the proper evidentiary scope of concurrency tests.
- **Impact on concurrency evidence:** None. Each required race ordering and final invariant was observed using the real protected procedures.
- **Suggested correction:** None.

# 6. Invariant and Evidence Review

- **Unsafe-test invariant:** Actually observed. Unsafe approved overlap count was `1`, with one overlapping pair displayed.
- **Protected-test invariant:** Actually observed after P1, P2, P3, M1, M2, and B1. Protected occupying overlap count was `0` in every run.
- **Pairing results:** `STAFF_STAFF_HOLDS`, `INSTANT_INSTANT_HOLDS`, and `INSTANT_STAFF_HOLDS` were observed with both session-finished flags equal to one.
- **Maintenance results:** `M1_APPROVAL_FIRST_HOLDS` was observed with one affected booking and one advisory-to-out-of-service transition. `M2_ESCALATION_FIRST_HOLDS` was observed with a Pending booking, zero affected bookings, and error `51013` after the fresh recheck.
- **Boundary results:** `BOUNDARY_CASES_HOLD` and `ADVISORY_ACK_HOLDS` were observed; expected errors were `51012`, `51013`, and `51006`.
- **Evidence type:** Actual runtime evidence, separately documented from expected results in `README.md` and `execution-results.md`.
- **Expected-versus-observed mismatch:** None in the corrected package.
- **Transactions and cleanup:** Invariant runs reported current-session transaction count `0`. Final cleanup verification found zero test rows and no helper tables.

# 7. Readiness Examination

1. **Is the unsafe race convincingly demonstrated?** Yes. Both sessions checked before A committed, and the final isolated state contained an approved overlap pair.
2. **Is prevention tested through the real Step 12 procedure?** Yes. Staff paths use `dbo.sp_ApproveBooking`; instant paths use `dbo.sp_SubmitBooking`, which owns submission and invokes protected instant approval when eligible; maintenance paths use `dbo.sp_EscalateMaintenanceImpact`.
3. **Is final-state correctness verified?** Yes. Pairing, overlap, maintenance, history, affected-booking, acknowledgement, and boundary outcomes have explicit result labels.
4. **Are all scripts schema-compatible?** Yes. All files compiled and executed against `dbo.SPACE`, `dbo.BOOKING`, physical `dbo.MAINTENANCERECORD`, migrated columns, TVP type, and exact Step 12 parameters.
5. **Is test data safely isolated?** Yes. Data uses `T13-` identifiers or test-space references; helpers are dedicated Step 13 tables; no production control is disabled.
6. **Are maintenance interactions tested when required?** Yes. Both approval-first and escalation-first orderings are genuine two-session tests using the shared lock resource.
7. **Are valid non-conflicting operations covered?** Yes. Same-space non-overlap, different-space overlap, adjacency, and advisory maintenance succeeded.
8. **Are actual and expected results clearly separated?** Yes. README defines expectations; `execution-results.md` records observed IDs, errors, invariants, environment, and cleanup.
9. **Can an independent evaluator reproduce the tests?** Yes. README gives prerequisites, SQLCMD pairing commands, exact two-window order, coordination messages, invariant checks, reset, and cleanup.
10. **Are any blocking issues unresolved?** No.

**Ready evidence:** Unsafe race, all three protected pairings, both maintenance orderings, valid boundaries, explicit invariants, advisory acknowledgement, rerunnable setup, and verified cleanup.

**Blocking gaps:** None.

**Non-blocking improvements:** None required for acceptance.

# 8. Scores

| Category | Score |
| --- | --- |
| Completeness | 10/10 |
| Schema Compatibility | 10/10 |
| Concurrency Validity | 10/10 |
| Unsafe Demonstration | 10/10 |
| Prevention Evidence | 10/10 |
| Maintenance Interaction | 10/10 |
| Isolation and Cleanup | 10/10 |
| Reproducibility | 10/10 |
| Report Readiness | 10/10 |

# 9. Required Revisions

No blocking revisions are required before using Step 13 results in the Phase 2 report.

# 10. Final Readiness Verdict

**READY FOR STEP 14 AND REPORT INTEGRATION**

The corrected package executes every required concurrency and boundary scenario against the real Step 12 paths, records actual evidence, verifies final invariants, and cleans up all isolated test data. Step 14 was not started.
