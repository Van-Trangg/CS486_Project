# 1. Review Summary

**Reviewed:** `outputs/12-concurrency-implementation-G02.sql` against the Phase 1 logical and physical baselines, the approved Step 9 design, Step 10 migration, Step 11 concurrency design, Phase 2 requirement, and relevant reviews under `docs/`.

**Execution status:** Static review only. No SQL Server execution was performed in this review. Complete current-script compilation, non-concurrent approval success, overlap rejection, Out-of-Service rejection, rollback behavior, and effective `AppServiceRole` permission behavior remain runtime-unverified.

**Most important strength:** The executable concurrency protocol faithfully uses a transaction-held per-space `UPDLOCK, HOLDLOCK`, followed by fresh half-open conflict and Out-of-Service checks, for both Staff and Instant approval. Escalation uses the same lock resource and lock order.

**Most important risk:** Instant eligibility does not evaluate `SPACE.usage_policy`, although the Phase 2 requirement and approved Step 9 design make policy satisfaction part of automatic approval. No machine-evaluable policy grammar or configuration exists, so Step 12 explicitly omits a load-bearing condition rather than implementing it.

**Issue counts:** Blocking: 1; Major: 1; Minor: 0; Observation: 1.

**Readiness:** Blocked pending contract revisions. The locking mechanism is testable, but the Instant path and Staff decision contract are not fully aligned with the approved requirements. A Step 13 tester would otherwise validate an unresolved workflow interpretation as if it were approved behavior.

# 2. Documents Reviewed

- `.opencode/skills/12-concurrency-implementation/Review-SKILL.md`
- `.opencode/skills/12-concurrency-implementation/SKILL.md`
- `req/business-requirement-phase2.md`
- `outputs/01-business-req-analysis-G02.md` for unchanged Phase 1 approval rules cited by later reviews
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `docs/09-updated-erd-and-logical-design-review-G02.md`
- `docs/09-new-updated-erd-and-logical-design-review-G02.md`
- `docs/10-schema-migration-review-G02.md`
- Existing `docs/12-concurrency-implementation-review-G02.md`
- `docs/feedback_step12.md`
- `docs/13-concurrency-tests-review-G02.md` as historical downstream execution evidence, not as runtime execution performed by this review

# 3. Implementation Mapping

| Step 11 Decision | Implemented In | Correct? | Evidence | Gap |
| --- | --- | --- | --- | --- |
| Per-space lock | Submission, approval, and escalation lock `dbo.SPACE` by `space_code` with `UPDLOCK, HOLDLOCK` | Yes | Step 12 lines 131-141, 318-340, 576-583 | None in locking mechanism |
| Short transaction | Submission and escalation own short explicit transactions; approval owns one when standalone and uses a savepoint when called by submission | Yes | Lines 128-132, 258-278, 318-327, 529-539, 565-577, 646-652 | Caller-owned approval transaction duration remains caller-controlled |
| Fresh conflict recheck | Approval rereads the booking after the space lock and checks current occupying rows | Yes | Lines 356-430 | None |
| Unified approval procedure | Staff calls `sp_ApproveBooking`; Instant submission invokes the same procedure | Yes | Lines 258-264, 285-540 | Instant eligibility contract is incomplete; see R12-1 |
| Maintenance escalation lock | Escalation locks the same `SPACE` row before rereading and updating maintenance | Yes | Lines 569-627 | No concurrency gap for the approved escalation path |
| Consistent lock order | Protected operations acquire `SPACE` before transaction-held BOOKING or MAINTENANCERECORD work | Yes | Lines 131-256, 318-527, 576-644 | Preliminary lock-target reads hold no transaction-duration related-row lock |
| Caller-owned deadlock retry | Procedures rethrow; no internal retry or swallowed error 1205 | Yes | Lines 273-278, 532-539, 648-652, 659-662 | Caller must roll back an uncommittable caller-owned transaction |

# 4. SQL and Schema Compatibility Check

| Object or Rule | Expected | Actual | Status | Notes |
| --- | --- | --- | --- | --- |
| Space table and PK | `dbo.SPACE(space_code VARCHAR(50))`, `PK_SPACE` | Exact object/key used | Pass | Step 5 lines 65-88; Step 12 lock predicates use `space_code` |
| Booking table and PK/FKs | `dbo.BOOKING`, `booking_id INT` PK, `space_code VARCHAR(50)` FK to SPACE, requester/approver FKs to USER | Exact names and compatible types used | Pass | Step 5 lines 150-190 |
| Requested period | `requested_start DATETIME`, `requested_end DATETIME` | Exact names/types and half-open predicates used | Pass | Step 12 lines 297-298, 421-449 |
| Occupying statuses | `Approved`, `Checked In` | Both included in conflict and affected-booking queries | Pass | Step 3 line 17; Step 12 lines 421-430, 639-644 |
| Resolution paths | `Instant`, `Staff`; `resolution_path VARCHAR(20)` | Exact values/type used | Pass | Step 9 lines 38-42, 240; Step 12 lines 118, 230-237, 382-419 |
| Decision fields | Staff decision records approver, time, and note; Step 9 matrix says note optional | Procedure requires approver but permits NULL note | Conflict | Unchanged Phase 1 rule and Step 9 matrix disagree; see R12-2 |
| Physical maintenance table name | `dbo.MAINTENANCERECORD` | Exact physical name used | Pass | The repository does not define `MAINTENANCE_RECORD`; Step 3, Step 5, Step 9, and Step 10 consistently use `MAINTENANCERECORD` |
| Maintenance PK/FKs | `maintenance_id INT` PK, `space_code VARCHAR(50)` FK | Exact names/types used | Pass | Step 5 lines 219-248 |
| Maintenance state and period | Open states `Reported`, `In Progress`; `start_time`; nullable `completion_time` | Exact values/columns used; NULL completion treated as open-ended | Pass | Step 9 lines 50-54, 242-257; Step 12 lines 435-449 |
| Impact level | `impact_level VARCHAR(20)` with `advisory`, `out-of-service` | Exact column/domain used | Pass | Step 10 lines 50-66; Step 12 lines 442, 607-627 |
| Acknowledgement relation | `BOOKING_ADVISORY_ACK` with booking/maintenance FKs and timestamp | Exact columns used atomically during submission | Pass | Step 10 lines 109-130; Step 12 lines 169-202, 239-256 |
| Impact history relation | `MAINTENANCE_IMPACT_HISTORY` with maintenance/user FKs and transition fields | Escalation updates current impact and inserts history in one transaction | Pass for escalation path | Broader Step 10 history-integrity gaps remain upstream |
| Approval procedure | `dbo.sp_ApproveBooking` | Created with exact protected checks | Pass | Step 12 lines 285-540 |
| Escalation procedure | `dbo.sp_EscalateMaintenanceImpact` | Created with shared lock and affected-booking result | Pass | Step 12 lines 546-654 |
| Submission procedure | Protected insertion and Instant handoff | `dbo.sp_SubmitBooking` locks, validates, inserts, acknowledges, and invokes approval | Partial | It cannot evaluate required usage-policy satisfaction; see R12-1 |
| Direct workflow bypass | Normal application cannot directly insert BOOKING or update protected approval facts | `AppServiceRole` receives DENY/GRANT policy | Static pass | Effective permissions were not executed in this review |
| Step 13/15 scope | No production `WAITFOR`; no tuning index | Neither is present | Pass | Correctly deferred |

# 5. Issues Found

## Issue R12-1 — Instant approval omits required usage-policy evaluation

- **Severity:** Blocking
- **Issue:** `sp_SubmitBooking` assigns `resolution_path = 'Instant'` from Classroom type, requester role, current space status, capacity, conflict, and maintenance checks, but never evaluates whether the request satisfies `SPACE.usage_policy`. The procedure reads the value and then explicitly treats it as non-executable.
- **Evidence:** Phase 2 requires automatic approval only for selected space types whose requests satisfy usage policy (`req/business-requirement-phase2.md:20-22`). Approved Step 9 makes `SPACE.usage_policy` load-bearing for Instant eligibility (`outputs/09-updated-erd-and-logical-design-G02.md:56-62`). Step 12 reads `@UsagePolicy` at lines 114 and 134-139 but states that no executable grammar is approved and omits it at lines 227-235. The latest error-focused Step 9 review identifies the same missing machine-evaluable representation as Blocking (`docs/09-new-updated-erd-and-logical-design-review-G02.md:12-19`).
- **Why this is a problem:** A Lecturer or Teaching Assistant request for a Classroom can be automatically approved even when the stored usage policy would make it ineligible. Conversely, there is no authoritative way for Step 12 to evaluate the policy correctly without inventing semantics.
- **Downstream impact on Step 13:** Instant/Instant and Instant/Staff tests would prove concurrency for the implemented hard-coded subset, not for the approved automatic-approval contract. The tester must assume that policy text is informational, contradicting the approved Step 9 design. The prior Step 12 review states that such a clarification exists but cites no authoritative requirement or design artifact; it cannot resolve the conflict by itself.
- **Suggested correction:** Obtain an approved, machine-evaluable eligibility decision for selected space types and usage-policy conditions, align Step 9 if necessary, and implement that exact decision in `sp_SubmitBooking`. If the approved decision is that `usage_policy` is informational only, record that explicitly in the authoritative design rather than only in a review conclusion.

## Issue R12-2 — Staff decision-note requirement is unresolved and unenforced

- **Severity:** Major
- **Issue:** `sp_ApproveBooking` permits Staff approval with `@DecisionNote = NULL` and writes that NULL value, while the unchanged Phase 1 approval rule requires the decision actor, time, and decision note. Approved Step 9 instead labels the note optional, so the upstream artifacts conflict.
- **Evidence:** Phase 1 analysis states that approval decisions must record the staff/manager, decision time, and decision notes (`outputs/01-business-req-analysis-G02.md:243-244`). Step 9's state matrix marks Staff Approved `decision_note` optional (`outputs/09-updated-erd-and-logical-design-G02.md:318-329`). Step 12 checks only `@ApproverId` for the Staff path at lines 382-401 and assigns `decision_note = @DecisionNote` at line 525. The latest Step 9 review records this contradiction as part of Blocking issue R09-3 (`docs/09-new-updated-erd-and-logical-design-review-G02.md:21-28`).
- **Why this is a problem:** The procedure can commit an approval record that lacks a Phase 1-required audit fact. Step 12 cannot establish which behavior is correct while its approved inputs disagree.
- **Downstream impact on Step 13:** Existing tests can pass by supplying notes, but they do not establish that the production procedure rejects an invalid NULL-note Staff approval. The workflow contract remains unstable for test expectations and generated data.
- **Suggested correction:** Resolve the upstream matrix against the unchanged Phase 1 requirement. If notes remain required, reject NULL and any disallowed empty value in the Staff path and add a non-concurrent Step 13 validation case after Step 12 is corrected.

## Issue R12-3 — Upstream migration remains independently not ready

- **Severity:** Observation
- **Issue:** The current Step 10 review has a not-ready verdict for migration ownership, maintenance-side protection, history integrity, an unsafe procedure stub, and failure safety. Step 12 compensates for or overwrites some of those gaps but does not make Step 10 itself ready.
- **Evidence:** `docs/10-schema-migration-review-G02.md:3-15,37-117,211-215`. Step 12 creates the missing TVP at lines 88-95 and replaces the Step 10 submission stub at lines 97-279. Current Step 10 owns the booking backstop and submission-fact triggers that the latest Step 12 no longer recreates.
- **Why this is a problem:** This is not a defect in the core Step 12 lock implementation, but deployment must follow Step 5, Step 10, then Step 12 exactly. Rerunning Step 10 after Step 12 replaces the protected submission procedure with the unsafe stub.
- **Downstream impact on Step 13:** Tests against a clean current deployment require the exact order and must verify that the final procedure definitions are Step 12's versions. Historical Step 13 execution does not remove the upstream Step 10 verdict.
- **Suggested correction:** Resolve the Step 10 review separately. Until then, Step 13 setup must verify final procedure definitions and required triggers before testing; do not treat Step 12 as a substitute migration.

# 6. Transaction and Locking Walkthrough

## 1. Successful approval

1. `sp_ApproveBooking` performs a non-transactional booking lookup only to identify `space_code`.
2. It begins its own transaction, or creates a savepoint when called inside `sp_SubmitBooking`'s transaction.
3. It acquires `UPDLOCK, HOLDLOCK` on the single matching `dbo.SPACE` row.
4. It rereads the booking after the lock, verifies that the booking is still `Pending`, validates path-specific fields, and checks space status.
5. It freshly checks same-space `Approved`/`Checked In` overlaps with the correct half-open predicate and excludes `@BookingId`.
6. It freshly checks overlapping active `out-of-service` maintenance with the same half-open rule.
7. It updates approval facts. A standalone call commits immediately; an Instant call returns to `sp_SubmitBooking`, which commits the encompassing insertion/acknowledgement transaction.
8. The transaction-held `SPACE` lock is released only by the owning commit or rollback.

## 2. Rejected overlapping approval

1. The procedure acquires the same transaction-held `SPACE` lock before checking BOOKING.
2. A committed occupying overlap causes error 51012 at lines 421-433.
3. A standalone call rolls back its transaction. A nested call rolls back to its savepoint when committable and rethrows; `sp_SubmitBooking` then rolls back its owning transaction.
4. No approval update remains, and the `SPACE` lock is released by rollback.

## 3. Approval blocked by Out-of-Service maintenance

1. The procedure acquires the `SPACE` lock before reading active maintenance.
2. It checks `Reported`/`In Progress`, exact `out-of-service` impact, and half-open overlap, treating NULL completion as open-ended.
3. A match raises error 51013. The same ownership-aware rollback path applies, and no approval data commits.
4. Advisory maintenance does not trigger this rejection.

## 4. Maintenance escalation concurrent with approval

1. Escalation identifies its lock target, begins a transaction, then locks the same `SPACE` row with `UPDLOCK, HOLDLOCK`.
2. It rereads and validates the maintenance record only after acquiring that lock.
3. It atomically updates the impact, inserts history, and identifies overlapping `Approved`/`Checked In` bookings before commit.
4. If approval acquired the lock first, escalation waits and then includes the committed booking. If escalation acquired it first, approval waits and then rejects on the fresh Out-of-Service check.
5. Escalation commits immediately after returning the affected set; errors roll back the complete impact/history change and rethrow.

# 7. Step 13 Readiness Examination

1. **Can Session A and Session B both call a clearly defined protected operation?** Yes: `sp_SubmitBooking`, `sp_ApproveBooking`, and `sp_EscalateMaintenanceImpact` are explicit entry points.
2. **Is the transaction boundary visible and correct?** Yes for the locking invariant. Submission and escalation own transactions; approval correctly distinguishes standalone and caller-owned execution.
3. **Is the lock acquired before the protected checks?** Yes. Preliminary reads identify the resource only; all load-bearing validation and state changes are repeated after the transaction-held `SPACE` lock.
4. **Are approval and maintenance escalation serialized consistently?** Yes, on the same `dbo.SPACE(space_code)` row with the same lock hints.
5. **Can tests distinguish unsafe behavior from protected behavior?** Yes for concurrency. The protected errors and final states are observable.
6. **Are expected business-rule errors observable?** Yes: not-found, ineligible, overlap, Out-of-Service, invalid path, acknowledgement, and escalation errors use distinct `THROW` paths. R12-1 and R12-2 leave two eligibility expectations unresolved.
7. **Are object names stable enough for test scripts?** Yes. The physical maintenance table is consistently `MAINTENANCERECORD`, not `MAINTENANCE_RECORD`.
8. **Are there direct-update bypasses that would invalidate prevention tests?** No normal `AppServiceRole` bypass is visible statically. BOOKING insert and protected-column updates are denied, direct maintenance impact/history writes are denied, and protected procedure execution is granted. Effective permissions remain runtime-unverified.
9. **Are there unresolved blocking schema mismatches?** No physical-name/type mismatch blocks compilation against the exact Step 5 plus Step 10 schema. The unresolved Instant policy model in R12-1 is a blocking behavioral design mismatch.
10. **Would a tester need to modify production SQL before testing?** Yes, or accept an unsupported policy assumption. The authoritative Instant eligibility contract must be resolved and Step 12 aligned first.

**Ready elements:** Per-space locking, transaction order, fresh conflict and maintenance checks, complete half-open overlap logic, current-booking exclusion, occupancy statuses, consistent escalation serialization, rollback/rethrow behavior, protected entry points, and absence of Step 13 delays or Step 15 indexes.

**Blocking gaps:** Machine-evaluable Instant eligibility and usage-policy handling are unresolved and omitted.

**Non-blocking improvements:** Resolve Staff decision-note provenance and execute the complete current script plus effective-permission checks in a disposable database.

# 8. Scores

| Category | Score |
| --- | --- |
| Completeness | 8/10 |
| Schema Compatibility | 9/10 |
| Transaction Safety | 9/10 |
| Locking Correctness | 10/10 |
| Conflict Detection | 10/10 |
| Maintenance Interaction | 9/10 |
| Workflow Enforcement | 6/10 |
| Step 13 Readiness | 6/10 |

# 9. Required Revisions Before Step 13

1. Resolve the authoritative, machine-evaluable Instant eligibility contract, including selected space types and usage-policy conditions, then align `sp_SubmitBooking` with that decision.
2. Resolve whether Staff approval must record a non-NULL decision note; if the unchanged Phase 1 rule remains authoritative, enforce it in `sp_ApproveBooking`.
3. After correction, execute the complete current Step 12 script in a safe database and verify procedure compilation, one successful approval, overlap rejection, Out-of-Service rejection, rollback behavior, and effective `AppServiceRole` DENY/GRANT behavior.
4. Verify Step 13 setup applies Step 10 before Step 12 and confirms that final procedure definitions are the protected Step 12 versions.

# 10. Final Readiness Verdict

**NOT READY FOR STEP 13**

The core SQL Server locking protocol is correctly implemented, but Step 12 cannot be accepted as the approved Instant workflow while it omits a requirement and Step 9 condition that has no machine-evaluable representation. Staff decision-note semantics also require resolution. Runtime execution was not performed in this review.
