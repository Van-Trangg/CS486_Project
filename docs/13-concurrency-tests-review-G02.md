# 1. Review Summary

**Reviewed:** every SQL and Markdown file in `outputs/13-concurrency-tests-G02/` against the Phase 2 requirement, the Phase 1 logical and physical baselines, the Step 9 design, Step 10 migration, Step 11 concurrency design, Step 12 implementation, `docs/12-concurrency-implementation-review-G02.md`, other relevant reviews under `docs/`, and both Step 13 skill files.

**Execution status:** Partial runtime execution was performed on 2026-08-09 against SQL Server 16.0.1000.6 on `DESKTOP-MJJHKPQ`. The current Step 5, Step 10, and Step 12 artifacts were streamed unchanged except for replacing the hardcoded database name with disposable database `University_Step13Review_20260809`. Deployment succeeded, but `00-setup-test-data.sql` failed before creating test data with error `51021` from `dbo.TR_BOOKING_ADVISORY_ACK_IMMUTABLE`. No two-session scenario could be executed in this review. The failed setup left zero `T13-` rows and no helper tables; the disposable database was then dropped and its absence confirmed.

The existing `execution-results.md` and README Pass table were reviewed as submitted evidence, not reproduced results. They cannot be accepted against the approved artifact baseline because the exact baseline rejects setup. The live `University` database had the current Step 12 procedure signatures but lacked the two migrated audit-immutability triggers, so it was not used as proof of exact baseline compatibility.

**Most important strength:** Statically, the package provides all required files, deterministic two-window orchestration, all three approval pairings, both maintenance orderings, boundary cases, isolated identifiers, and final-state queries using the real Step 12 procedures.

**Most important risk:** Setup, pairing reconfiguration, and cleanup issue prohibited deletes against immutable audit tables. The package cannot start on the exact migrated schema, cannot be rerun as documented, and cannot produce credible current report evidence.

**Overall readiness:** The prepared concurrency logic is substantial, but the package is blocked by exact-schema incompatibility, an unmet Step 12 prerequisite, and execution claims that must be regenerated after correction.

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

| Test Area | Script(s) | Genuine Two-Session Test? | Expected Result Defined? | Actual Result Verified Against Exact Baseline? | Status |
| --- | --- | --- | --- | --- | --- |
| Unsafe overlap | 01, 02, 08 | Prepared: Yes | Yes | No | Blocked by setup |
| Protected overlap | 04, 05, 08, 11 | Prepared: Yes | Yes | No | Blocked by setup |
| Instant/instant | 04, 05, 08, 11 | Prepared: Yes; both call real submission | Yes | No | Blocked by setup and Step 12 prerequisite |
| Staff/staff | 04, 05, 08, 11 | Prepared: Yes; both call real approval | Yes | No | Blocked by setup |
| Instant/staff | 04, 05, 08, 11 | Prepared: Yes; real submission versus approval | Yes | No | Blocked by setup and Step 12 prerequisite |
| Approval-first escalation | 06, 07, 08 | Prepared: Yes | Yes | No | Blocked by setup |
| Escalation-first approval | 13, 14, 08 | Prepared: Yes | Yes | No | Blocked by setup |
| Same-space non-overlap | 10 | No; single-session boundary case | Yes | No | Blocked by setup |
| Different spaces, overlapping time | 10 | No; single-session boundary case | Yes | No | Blocked by setup |
| Adjacent intervals | 10 | No; single-session boundary case | Yes | No | Blocked by setup |
| Equal intervals | 10 | No; single-session rejection case | Yes | No | Blocked by setup |
| Out-of-Service maintenance | 10, 12, 13, 14 | Prepared: Yes in M2 | Yes | No | Blocked by setup |
| Advisory maintenance and acknowledgement | 00, 08, 10 | No; single-session functional case | Yes | No | Blocked by setup |
| Already finalized booking | 10 | No; single-session rejection case | Yes | No | Blocked by setup |
| Invariant checks | 08 | N/A | Yes | No | Not reached |
| Cleanup | 09 | N/A | Yes | Failed by design against immutable audit rows | Incompatible |

# 4. Interleaving Walkthrough

The following walkthroughs reconstruct the prepared scripts. They were not observed in this review because exact-baseline setup failed.

## U1 - Unsafe Check-Then-Act

1. Session A begins a transaction, checks isolated `STEP13_UNSAFE_BOOKING`, finds no overlap, and waits ten seconds.
2. Session B starts during A's wait, checks the same empty committed state, and waits three seconds.
3. B inserts and commits an Approved helper row before A inserts and commits its overlapping row.
4. `08-invariant-checks.sql` is designed to count and display the resulting pair using correct half-open overlap logic.
5. This is a coherent isolated demonstration of the Step 11 check-then-act race and does not weaken production objects, but it was not reached on the exact baseline.

## P1 - Staff/Staff

1. A calls real `dbo.sp_ApproveBooking` inside a caller transaction and holds the production `SPACE` lock for ten seconds.
2. B calls the same procedure for an overlapping Pending booking and should wait on that row.
3. After A commits, B should acquire the lock, freshly recheck, and receive `51012`.
4. The intended final state is one Staff/Approved row, one Staff/Pending row, both completion flags set, and zero protected overlaps.
5. The sequence would prove the Staff path if executed after a compatible setup.

## P2 - Instant/Instant

1. A holds a test-only `UPDLOCK, HOLDLOCK` gate on `T13-SPACE-A`.
2. B calls real `dbo.sp_SubmitBooking` and queues on the same space row.
3. A releases the gate and calls real submission; the queued operation is intended to acquire the production lock first and become Instant/Approved.
4. A should recheck afterward and insert its overlapping request as Staff/Pending rather than approve it.
5. This tests zero overlapping approvals, although the losing submission is a successful fallback rather than a procedure rejection. Its business eligibility remains subject to unresolved Step 12 review issue R12-1.

## P3 - Instant/Staff

1. A holds the same test-only space gate while B calls real Staff approval.
2. B queues first on the Step 12 resource.
3. A releases the gate and calls real submission; B should approve first.
4. A should recheck and create a Staff/Pending fallback.
5. The intended final invariant is zero occupying overlaps, subject to the same unresolved Instant-policy prerequisite.

## M1 - Approval First

1. A calls real approval and holds its transaction uncommitted.
2. B calls real escalation and should wait on the same production space lock.
3. A commits; escalation should continue, update the impact, insert history, and return the newly approved booking.
4. B separately recomputes the affected-booking predicate into a helper table.
5. The helper proves the final predicate, not by itself the rows returned by the procedure; no exact-baseline runtime result was reached.

## M2 - Escalation First

1. A holds a test-only space gate while B calls real escalation and queues first.
2. A releases the gate and calls real approval.
3. B should acquire the production lock, escalate, insert history, and commit with no affected Approved booking.
4. A should then acquire the lock, freshly see `out-of-service`, receive `51013`, and leave the booking Pending.
5. This is a coherent prepared ordering but was not executed in this review.

# 5. Issues Found

## Issue R13-1 - Immutable audit triggers make setup, reconfiguration, and cleanup non-executable

- **Severity:** Blocking
- **Issue:** The package deletes from audit tables whose approved Step 10 triggers prohibit deletion. The acknowledgement trigger throws unconditionally for every DELETE statement, including a delete that matches zero rows. The history trigger rejects cleanup once maintenance history exists.
- **Evidence:** `00-setup-test-data.sql:14-22`, `09-cleanup-test-data.sql:12-20`, and `11-configure-protected-pairing.sql:14-21` issue the deletes. `outputs/10-schema-migration-G02.sql:342-369` defines `TR_BOOKING_ADVISORY_ACK_IMMUTABLE` and `TR_MAINTENANCE_IMPACT_HISTORY_IMMUTABLE`. On the exact disposable Step 5 -> Step 10 -> Step 12 baseline, setup returned error `51021` before creating any `T13-` row or helper table.
- **Why this is a problem:** The package cannot perform initial setup, cannot run the documented fresh setup for each pairing, and cannot clean audit-bearing scenarios. Foreign keys then also prevent deleting related bookings and maintenance rows.
- **Impact on concurrency evidence:** Every U1, P1-P3, M1-M2, and B1 run is unreachable on the approved artifact baseline. Rerun safety and cleanup claims are false for that baseline.
- **Suggested correction:** Redesign the package around a disposable-database lifecycle or another approved strategy that preserves immutable audit records. Do not disable constraints or production triggers. Remove prohibited row-deletion assumptions, provide exact per-scenario recreation/reset instructions, and verify cleanup by dropping only the dedicated disposable test database or by another schema-compatible method.

## Issue R13-2 - Submitted Pass evidence is contradicted by the approved baseline

- **Severity:** Blocking
- **Issue:** `README.md` and `execution-results.md` mark all scenarios Passed and state that the deployed contracts matched current Steps 10 and 12, but the exact current baseline cannot execute setup. The submitted evidence contains result summaries rather than retained raw session outputs that could explain the mismatch.
- **Evidence:** `README.md:83-95` and `execution-results.md:5-31` claim execution and cleanup. The disposable exact-baseline run failed with `51021`. Read-only inspection of live `University` found current procedure signatures but neither `TR_BOOKING_ADVISORY_ACK_IMMUTABLE` nor `TR_MAINTENANCE_IMPACT_HISTORY_IMMUTABLE`, proving that database was not an exact current migration state when inspected.
- **Why this is a problem:** Expected text and unrepeatable summaries cannot serve as actual concurrency evidence. The historical run may describe a different deployed schema, but it does not establish current artifact compatibility.
- **Impact on concurrency evidence:** Blocking durations, fresh rechecks, final states, invariant counts, and cleanup are not verified for the approved baseline. The existing Pass labels must not be integrated into the report as current Step 13 proof.
- **Suggested correction:** Mark actual results Pending until the package is corrected, then rerun all scenarios against a recorded exact Step 5 -> Step 10 -> Step 12 deployment. Retain auditable outputs for both sessions, invariant queries, object/version checks, and cleanup without fabricating timings or results.

## Issue R13-3 - Step 12 is not approved for Step 13 under the package's own prerequisite

- **Severity:** Blocking
- **Issue:** The README requires the Step 12 review verdict to be ready, but the approved review verdict is `NOT READY FOR STEP 13`. Instant eligibility omits required usage-policy evaluation, and Staff decision-note semantics remain unresolved.
- **Evidence:** `README.md:7`; `docs/12-concurrency-implementation-review-G02.md:70-86,164-175`; `req/business-requirement-phase2.md:20-26`; `outputs/09-updated-erd-and-logical-design-G02.md:56-62`.
- **Why this is a problem:** P2 and P3 would validate an unresolved Instant workflow interpretation as approved behavior. Passing concurrency mechanics cannot resolve the upstream policy contract.
- **Impact on concurrency evidence:** Staff locking tests remain conceptually useful, but the complete Step 13 package cannot be accepted for report integration while its production prerequisite is explicitly not ready.
- **Suggested correction:** Resolve and implement the authoritative machine-evaluable Instant eligibility and Staff decision-note contract, obtain a ready Step 12 review, align affected Step 13 expectations, and rerun the package.

## Issue R13-4 - Maintenance invariant does not fully assert returned and historical evidence

- **Severity:** Major
- **Issue:** M1 recomputes the affected predicate after the escalation procedure rather than capturing durable evidence of the procedure's returned result. The invariant displays `transition_count` but its M1/M2 result labels do not require exactly one advisory-to-out-of-service history transition.
- **Evidence:** `07-maintenance-race-session-b.sql:17-39` documents and performs the independent recomputation. `08-invariant-checks.sql:85-116` calculates `transition_count`, but the CASE at lines 95-109 does not test it.
- **Why this is a problem:** A final-state helper row can show that a booking now satisfies the affected predicate without proving it appeared in the procedure result. A maintenance result label can also report `_HOLDS` without asserting the expected history count.
- **Impact on concurrency evidence:** Maintenance final-state evidence is weaker than the report claims even after the setup blocker is fixed.
- **Suggested correction:** Record the actual escalation result through a schema-compatible test harness or retained session output, and make M1/M2 assertions require the exact impact value, booking status, affected count, and one matching history transition.

# 6. Invariant and Evidence Review

- **Unsafe-test invariant:** Statically correct and designed to return at least one isolated overlap pair, but not executed in this review because setup failed.
- **Protected-test invariant:** Correct half-open pair detection over test spaces and occupying statuses `Approved`/`Checked In`, but no current exact-baseline result was obtained.
- **Pairing results:** Expected labels and completion flags are defined. Current runtime evidence is pending.
- **Maintenance results:** Both orderings are prepared. Returned affected-booking evidence and exact history assertions require revision.
- **Boundary results:** Same-space non-overlap, different-space overlap, adjacency, equal intervals, `out-of-service`, advisory acknowledgement, and already-finalized behavior are all represented but were not reached.
- **Evidence type:** Partial actual runtime evidence only for deployment and setup failure. All concurrency outcomes in this review remain static expectations. Submitted historical summaries are not accepted as current exact-baseline proof.
- **Expected-versus-observed mismatch:** Setup was expected to succeed but observed error `51021`; therefore every later expected result remained unobserved.
- **Transactions and cleanup:** The failed setup rolled back and left zero test rows and no helper tables. External disposable-database removal succeeded. Package cleanup itself was not executable and was not credited.

# 7. Readiness Examination

1. **Is the unsafe race convincingly demonstrated?** Not as current evidence. The scripts form a valid prepared interleaving, but exact-baseline setup prevents execution.
2. **Is prevention tested through the real Step 12 procedure?** The prepared scripts call the exact procedures and parameters, but no protected scenario was reached in this review.
3. **Is final-state correctness verified?** Queries are prepared, but current final states are unverified; maintenance assertions are also incomplete.
4. **Are all scripts schema-compatible?** No. Audit-table deletes conflict with enabled migrated triggers.
5. **Is test data safely isolated?** Identifiers and helper tables are isolated, but cleanup is incompatible with immutable audit data.
6. **Are maintenance interactions tested when required?** Both orderings are prepared, but neither was executable on the exact baseline.
7. **Are valid non-conflicting operations covered?** They are prepared in B1 but not currently verified.
8. **Are actual and expected results clearly separated?** Separate files exist, but the actual Pass claims are contradicted by exact-baseline execution and must be reset.
9. **Can an independent evaluator reproduce the tests?** No. Following the documented prerequisites causes setup error `51021`.
10. **Are any blocking issues unresolved?** Yes: exact-schema setup/cleanup incompatibility, invalid current Pass evidence, and the not-ready Step 12 prerequisite.

**Ready evidence:** Complete file inventory; exact procedure, parameter, table, column, status, path, impact, and identifier references; coherent prepared interleavings; isolated naming; correct core overlap predicates.

**Blocking gaps:** Executable setup/reset/cleanup on the migrated schema, a ready Step 12 prerequisite, and newly observed two-session evidence against that corrected exact baseline.

**Non-blocking improvements:** Strengthen maintenance returned-result and history assertions.

# 8. Scores

| Category | Score |
| --- | --- |
| Completeness | 10/10 |
| Schema Compatibility | 3/10 |
| Concurrency Validity | 6/10 |
| Unsafe Demonstration | 6/10 |
| Prevention Evidence | 4/10 |
| Maintenance Interaction | 4/10 |
| Isolation and Cleanup | 2/10 |
| Reproducibility | 2/10 |
| Report Readiness | 1/10 |

# 9. Required Revisions

1. Replace the prohibited immutable-audit deletion strategy with a schema-compatible disposable test lifecycle; do not disable production triggers, foreign keys, or constraints.
2. Make setup, all three pairing configurations, both maintenance orderings, invariant checks, and cleanup reproducible under the exact current Step 5 -> Step 10 -> Step 12 deployment order.
3. Resolve the blocking Step 12 Instant-policy and Staff decision-note contract issues, align the tests, and obtain a ready Step 12 review before accepting P2/P3 evidence.
4. Remove or mark the current Pass claims as Pending, then rerun U1, P1, P2, P3, M1, M2, B1, invariants, and cleanup using genuine separate sessions. Record retained actual outputs and exact deployed-object checks.
5. Strengthen M1/M2 evidence to prove the actual procedure result and require exactly one matching impact-history transition.

# 10. Final Readiness Verdict

**NOT READY FOR STEP 14 OR REPORT INTEGRATION**

The package is structurally complete and its prepared interleavings largely match Step 11 and Step 12, but it cannot execute setup or cleanup against the approved migrated schema. Its submitted Pass claims therefore cannot be used as report evidence, and the Step 12 prerequisite remains explicitly not ready. Step 14 was not started.
