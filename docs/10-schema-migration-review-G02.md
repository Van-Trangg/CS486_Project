# Step 10 Schema Migration Review

## 1. Executive Summary

- **Review status:** Static review completed. Runtime review completed on SQL Server 16.0.1000.6 using disposable databases and a disclosed stream wrapper that replaced only the hardcoded `University` token.
- **Blocking:** 0
- **Major:** 7
- **Minor:** 2
- **Missing migration changes:** 2
- **Incorrect migration changes:** 2
- **Redundant / out-of-scope objects:** 1
- **Upstream ambiguities:** 2
- **Final verdict:** **Step 10 not ready - correction required**

The wrapped clean `Step 5 -> Step 10` sequence and an immediate Step 10 rerun both exited `0`; no current clean-baseline batch-compilation blocker was found. Populated baseline rows were preserved and received the documented backfills. Step 10 is nevertheless not a complete target migration: it omits the downstream acknowledgement TVP, removes maintenance-side overlap protection too broadly, leaves approved impact-history invariants unenforced, and deploys an intentionally unsafe Step 12 procedure stub that fails against Step 10's own immutability trigger.

## 2. Baseline -> Target Migration Matrix

| ID | Upstream requirement | Step 5 baseline state | Required Step 10 target state | Step 10 implementation | Result | Action |
| --- | --- | --- | --- | --- | --- | --- |
| M10-01 | C08-01: current maintenance impact and Phase 1-compatible backfill | No impact column; all active maintenance is blocking | `impact_level VARCHAR(20) NOT NULL`, exact two-value domain, existing rows `out-of-service` | Column/default/CHECK at `outputs/10-schema-migration-G02.sql:54-66` | CORRECT | None |
| M10-02 | P2-BR-01/02: advisory allows booking; active out-of-service blocks approval | Phase 1 booking trigger blocks every active maintenance row | Impact-aware booking-side backstop | Trigger checks only active `out-of-service` rows at `outputs/10-schema-migration-G02.sql:224-266` | CORRECT | None |
| M10-03 | Phase 1 bidirectional protection retained except escalation must expose affected bookings | Maintenance INSERT/UPDATE rejects overlap with approved/checked-in bookings | Permit advisory escalation while retaining protection against a newly introduced overlapping out-of-service period | Drops the Phase 1 trigger entirely at `outputs/10-schema-migration-G02.sql:214-221`; no maintenance-side replacement exists | MISSING | R10-3 |
| M10-04 | Step 9: `resolution_path VARCHAR(20) NOT NULL`, exact domain, existing rows `Staff` | Column absent | Add column, default, CHECK, and backfill | Implemented at `outputs/10-schema-migration-G02.sql:73-85` | UPSTREAM AMBIGUITY | Resolve R10-6 before certifying the broader policy contract |
| M10-05 | Step 9: resolution path is assigned on INSERT and write-once | Column absent | Reject later value changes | Trigger at `outputs/10-schema-migration-G02.sql:185-209` | CORRECT | Retain subject to R10-6 |
| M10-06 | Step 9 booking path/status/decision provenance model | Only rejection reason has a conditional CHECK | Enforce the approved combinations | No Phase 2 state constraint is added | UPSTREAM AMBIGUITY | Resolve R10-6; do not invent the missing seven-status contract |
| M10-07 | C08-02: acknowledgement relation | Relation absent | Identity PK, mandatory FKs, timestamp default, unique booking/maintenance pair | Implemented at `outputs/10-schema-migration-G02.sql:112-130` | CORRECT | None |
| M10-08 | Step 9 acknowledgement applicability and insert-only audit semantics | No relation | Reject inapplicable rows and later UPDATE/DELETE | Set-based triggers at `outputs/10-schema-migration-G02.sql:298-354` | CORRECT | Completeness remains Step 12 submission-transaction responsibility |
| M10-09 | Acknowledgement requester provenance remains stable | `BOOKING.requester_id` is mutable; Phase 1 locks only space/time after non-Pending state | Approved immutable requester or requester snapshot | Makes requester and other submission facts immutable from submission at `outputs/10-schema-migration-G02.sql:267-292` | UPSTREAM AMBIGUITY | R10-7 |
| M10-10 | C08-03: impact history core relation and distinct transitions | Relation absent | Identity PK, mandatory FKs, domains/default, distinct old/new | Implemented at `outputs/10-schema-migration-G02.sql:136-160` | CORRECT | None |
| M10-11 | Step 9 history open-record, chain, latest/current, atomicity, and ordering invariants | No history relation or controls | Schema integrity backstops plus protected workflow | Only distinct transition and row immutability are enforced (`outputs/10-schema-migration-G02.sql:149-158,356-369`) | PARTIAL | R10-2 |
| M10-12 | Step 12 signature requires `dbo.BookingAdvisoryAckListType(maintenance_id INT NOT NULL PRIMARY KEY)` | Type absent | Rerun-safe table type created by Step 10 | Type absent; Step 12 compensates at `outputs/12-concurrency-implementation-G02.sql:88-95` | MISSING | R10-1 |
| M10-13 | Physical room candidate key `(building, floor, room_number)` | `UQ_SPACE_LOCATION` exists | Preserve candidate key | Preserved unchanged | CORRECT | None |
| M10-14 | Concurrency locking/protected procedures belong to Steps 11-13 | No Phase 2 workflow procedures | Step 10 supplies schema dependencies only | Adds an unsafe `sp_SubmitBooking` stub at `outputs/10-schema-migration-G02.sql:371-454` | REDUNDANT | R10-4 |
| M10-15 | Reports use existing facts plus new impact/history data; no semester entity required | Existing booking/space/facility facts | No additional reporting table | No unapproved reporting table added | CORRECT | None |

## 3. Blocking and Major Issues

### Issue R10-1 - Required acknowledgement TVP type is absent

- **Severity:** Major
- **Classification:** Missing
- **Upstream requirement:** Step 10 owns user-defined table types required by downstream procedures. Step 12 requires `dbo.BookingAdvisoryAckListType` with `maintenance_id INT NOT NULL PRIMARY KEY` (`outputs/12-concurrency-implementation-G02.sql:88-105`).
- **Step 5 baseline:** The type does not exist.
- **Step 10 evidence:** No `TYPE_ID` guard or `CREATE TYPE` exists in `outputs/10-schema-migration-G02.sql`.
- **Why this matters:** The migrated physical schema is incomplete until Step 12 performs an unowned schema migration.
- **Downstream impact:** Step 12 compensates before compiling its submission procedure; Step 13 declarations depend on that compensation.
- **Suggested correction:** Create the exact table type in Step 10 with a `TYPE_ID` guard and dynamic `CREATE TYPE` batch.

### Issue R10-2 - Impact-history integrity is only partially implemented

- **Severity:** Major
- **Classification:** Partial
- **Upstream requirement:** Step 9 requires open-record eligibility, chain continuity ordered by `(changed_at, history_id)`, latest-history/current-impact agreement, and atomic state/history change (`outputs/09-updated-erd-and-logical-design-G02.md:301-307`).
- **Step 5 baseline:** No impact-history relation or integrity mechanism exists.
- **Step 10 evidence:** The table enforces domains and `old_impact_level <> new_impact_level` only (`outputs/10-schema-migration-G02.sql:139-159`); the sole history trigger only rejects UPDATE/DELETE (`:356-369`).
- **Why this matters:** A history row can be inserted for a closed record, a chain can contradict prior history, and current `MAINTENANCERECORD.impact_level` can disagree with the latest event while every Step 10 constraint remains satisfied.
- **Downstream impact:** Step 12's escalation procedure protects its own path, but Step 10 does not provide the approved database-wide integrity backstop and provides no protected downgrade dependency.
- **Suggested correction:** Add only the approved, set-based schema backstops that can be supported by stored facts. Keep transactional escalation/downgrade workflow logic in Step 12.
- **Runtime evidence:** In the disposable migrated database, an `out-of-service -> advisory` history row was accepted for a currently `Resolved` maintenance row while the current impact remained `out-of-service`; `sqlcmd -b` exited `0`.

### Issue R10-3 - Maintenance-side overlap protection is removed too broadly

- **Severity:** Major
- **Classification:** Incorrect
- **Upstream requirement:** Out-of-service maintenance retains Phase 1 blocking meaning (`req/business-requirement-phase2.md:7-10`). The explicit Phase 2 exception is escalation of an advisory, where existing approved overlaps must be identified rather than blocking escalation (`:14-16`).
- **Step 5 baseline:** `TR_MAINTENANCE_PREVENT_BOOKING_OVERLAP` rejects active maintenance INSERT/UPDATE that overlaps approved or checked-in bookings (`outputs/05-db-definition-G02.sql:368-395`).
- **Step 10 evidence:** The trigger is dropped wholesale at `outputs/10-schema-migration-G02.sql:214-221`, with no INSERT-side or non-escalation replacement.
- **Why this matters:** A brand-new active out-of-service maintenance row can be introduced over an approved booking, although the approved exception concerns advisory escalation.
- **Downstream impact:** Step 12 serializes its escalation procedure but does not restore a schema backstop for direct maintenance creation.
- **Suggested correction:** Replace the Phase 1 trigger with Phase 2-aware maintenance-side integrity that permits the approved escalation workflow without permitting unrelated new out-of-service conflicts. Do not duplicate Step 12 locking logic.
- **Runtime evidence:** A new active out-of-service row overlapping an approved booking was accepted in a rolled-back disposable test; the overlap count was `1` and `sqlcmd -b` exited `0`.

### Issue R10-4 - Step 10 deploys an out-of-scope procedure that contradicts its schema

- **Severity:** Major
- **Classification:** Redundant
- **Upstream requirement:** Resolution path is assigned in the booking INSERT transaction and never changed later (`outputs/09-updated-erd-and-logical-design-G02.md:41,312-329`). Protected submission logic belongs to Step 12.
- **Step 5 baseline:** No Phase 2 submission procedure exists.
- **Step 10 evidence:** The script deploys an explicitly non-concurrency-safe `dbo.sp_SubmitBooking` at `outputs/10-schema-migration-G02.sql:371-454`. Its Instant branch updates `resolution_path` from the default `Staff` to `Instant` (`:432-439`), while `TR_BOOKING_RESOLUTION_PATH_IMMUTABLE` rejects that change (`:189-208`).
- **Why this matters:** Step 10 publishes a callable workflow object that cannot perform its advertised Instant branch and is unsafe by its own comments.
- **Downstream impact:** Step 12 later replaces the procedure with a different signature, but Step 10 remains an invalid intermediate deployment and rerunning Step 10 after Step 12 would overwrite the protected procedure with the stub.
- **Suggested correction:** Remove the procedure stub from Step 10; leave procedure creation and replacement to Step 12.
- **Runtime evidence:** Executing the stub for a valid Pending Lecturer/Classroom booking returned trigger error `50000`, batch-abort error `3609`, and `sqlcmd -b` exit `1`.

### Issue R10-5 - Baseline guards do not fail safely across batches

- **Severity:** Major
- **Classification:** Incorrect
- **Upstream requirement:** Migration preconditions must prevent execution in the wrong database and failures must not be presented as successful deployment.
- **Step 5 baseline:** The intended database is created as `University`.
- **Step 10 evidence:** `USE University` occurs before the `DB_ID` check (`outputs/10-schema-migration-G02.sql:10,27-31`). Both precondition failures use `RETURN` in batches terminated by `GO` (`:27-40`), so they do not stop later batches. Schema stages commit independently and trigger/procedure batches are outside TRY/CATCH (`:46-454`); the completion message is unconditional (`:524-526`).
- **Why this matters:** If `USE` fails, execution can remain in the caller's prior context; batch-local `RETURN` does not prevent later migration batches from running. A client that does not abort on severity 16 can continue and print success after partial failure.
- **Downstream impact:** Deployment state can be partial or applied to an unintended database despite the apparent preflight checks.
- **Suggested correction:** Make database-context validation occur before any target DDL and use a cross-batch fail-fast mechanism. Do not require one giant transaction, but do not print success unless every stage completed.

### Issue R10-6 - Resolution policy and full state matrix remain inconsistent upstream

- **Severity:** Major
- **Classification:** Upstream Ambiguity
- **Upstream requirement:** The Phase 2 requirement names only selected space types satisfying usage policy (`req/business-requirement-phase2.md:22`). Step 8 labels the detailed policy a project assumption (`outputs/08-requirement-change-analysis-G02.md:9`) but later presents Classroom/Lecturer/TA and write-once behavior as P2-BR-10/11 (`:64-65`). Step 9 adopts that policy while retaining free-text usage policy and defines only core decision states (`outputs/09-updated-erd-and-logical-design-G02.md:56-62,318-329`). The latest error-focused Step 9 review records this contract as unresolved (`docs/09-new-updated-erd-and-logical-design-review-G02.md:3-29`).
- **Step 5 baseline:** Staff-only workflow; no resolution path.
- **Step 10 evidence:** Adds the path domain/default/immutability and hardcodes Classroom plus Lecturer/TA in the redundant stub (`outputs/10-schema-migration-G02.sql:73-85,185-209,419-430`) but adds no state-matrix constraint.
- **Why this matters:** Enforcing more would require Step 10 to choose among inconsistent upstream statements; enforcing less leaves Step 9's stated core matrix physically permissive.
- **Downstream impact:** Steps 12-14 implement one project interpretation, but downstream consistency cannot turn it into authoritative upstream approval.
- **Suggested correction:** Obtain an accepted decision for eligibility, usage-policy treatment, path storage/immutability, and all seven status/provenance combinations; then align Step 8/9 and Step 10.

### Issue R10-7 - Acknowledgement requester provenance uses an unapproved design choice

- **Severity:** Major
- **Classification:** Upstream Ambiguity
- **Upstream requirement:** Step 9 derives requester provenance through `BOOKING.requester_id`, explicitly assumes requester immutability, and says the acknowledgement design must be revisited if that assumption is false (`outputs/09-updated-erd-and-logical-design-G02.md:282`).
- **Step 5 baseline:** Requester is not write-once; the Phase 1 trigger locks only space and period after the row is no longer Pending (`outputs/05-db-definition-G02.sql:536-562`).
- **Step 10 evidence:** `TR_BOOKING_LOCK_SUBMISSION_FACTS` makes requester, space, and period immutable from submission (`outputs/10-schema-migration-G02.sql:267-292`).
- **Why this matters:** Step 10 selects one material physical solution where Step 9 leaves a conditional choice.
- **Downstream impact:** The choice is compatible with current Step 12, but compatibility does not resolve upstream authority.
- **Suggested correction:** Approve either immutable booking requester provenance or a requester snapshot on the acknowledgement relation, then retain only the selected implementation.

## 4. Minor Issues

### Issue R10-8 - Existence guards accept malformed partial objects

- **Severity:** Minor
- **Classification:** Partial
- **Upstream requirement:** Exact reruns should be safe without silently accepting an incomplete prior deployment.
- **Step 5 baseline:** Phase 2 objects are absent.
- **Step 10 evidence:** Column guards check only `COL_LENGTH` (`outputs/10-schema-migration-G02.sql:54,73`), constraint guards check only globally named `OBJECT_ID` (`:62,81`), and table guards check only table existence (`:112,136`).
- **Why this matters:** A wrong-type/nullable column or incomplete table can be skipped and treated as migrated.
- **Downstream impact:** Step 12 can compile or run against a schema different from its expected contract.
- **Suggested correction:** Add focused metadata assertions that reject shape mismatches; full schema-diff reconciliation is unnecessary.

### Issue R10-9 - Post-migration validation does not establish final schema convergence

- **Severity:** Minor
- **Classification:** Partial
- **Upstream requirement:** Validation must support a reliable migration success decision.
- **Step 5 baseline:** Not applicable.
- **Step 10 evidence:** Validation checks the two columns, two table names, five CHECK names, and backfill distributions only (`outputs/10-schema-migration-G02.sql:465-522`). It omits PK/UQ/FK/default definitions and trust, trigger existence, the required TVP, table shape, and invalid state counts.
- **Why this matters:** The script can print `Completed Successfully` while required objects are missing or malformed; runtime metadata confirmed the TVP was absent despite the success message.
- **Downstream impact:** Operators need separate inspection before Step 12 can rely on the schema.
- **Suggested correction:** Add concise target-shape and trust assertions and gate the final success message on them.

## 5. Missing Migration Changes

| Issue | Missing change | Ownership boundary |
| --- | --- | --- |
| R10-1 | `dbo.BookingAdvisoryAckListType` | Step 10 creates the schema dependency; Step 12 consumes it |
| R10-3 | Phase 2-aware maintenance-side out-of-service overlap backstop | Step 10 preserves schema integrity; Step 12 owns protected escalation locking/workflow |

R10-2 is partial rather than wholly absent. R10-6 and R10-7 require upstream decisions and are not counted as missing migrations.

## 6. Redundant / Out-of-Scope Migration Logic

| Issue | Object | Assessment |
| --- | --- | --- |
| R10-4 | `dbo.sp_SubmitBooking` stub | OUT-OF-SCOPE / REDUNDANT. It belongs to Step 12, has an incompatible later signature, is intentionally unsafe, and fails against Step 10's own path-immutability trigger. |

The impact-aware booking trigger, acknowledgement integrity triggers, submission-fact trigger, and history immutability trigger are schema-integrity objects and are not redundant solely because Step 12 consumes the schema.

## 7. Clean-Baseline / Batch-Compilation Review

**Result:** The current wrapped `Step 5 -> Step 10` sequence compiles and completes from a clean baseline.

- Added-column CHECK constraints use dynamic SQL after the ALTER operations (`outputs/10-schema-migration-G02.sql:54-85`), avoiding same-batch new-column binding defects.
- New tables are committed before trigger batches reference them (`:105-174,298-369`).
- Trigger and procedure definitions begin in valid later batches.
- Wrapped clean execution returned `STEP5_EXIT_CODE=0` and `STEP10_FIRST_EXIT_CODE=0`.
- Immediate wrapped rerun returned `STEP10_RERUN_EXIT_CODE=0`.
- A populated baseline test with one valid BOOKING and one valid MAINTENANCERECORD preserved both rows and backfilled `Staff` and `out-of-service`; migration exit was `0`.

The runtime wrapper streamed the exact current files through a token replacement from `University` to disposable names. No source file was changed. This is not an unchanged-source execution: the hardcoded database context requires the disclosed wrapper for safe disposable review.

## 8. Idempotency and Failure-Safety

- An immediate exact migration rerun on the disposable clean-baseline database succeeded with exit `0`.
- Trigger definitions are rerun-safe through drop/create or `CREATE OR ALTER`; table/column operations are existence-guarded.
- R10-8 limits convergence from malformed partial states.
- R10-5 means preflight and partial-failure behavior are unsafe outside fail-fast `sqlcmd -b` execution.
- Rerunning Step 10 after Step 12 is not safe because it replaces Step 12's protected `sp_SubmitBooking` with the Step 10 stub.

## 9. Downstream Compatibility

- Core table names, column names, types, PK/FK targets, impact values, path values, acknowledgement columns, and history columns match Steps 12-14.
- R10-1 forces Step 12 to create a Step 10-owned type before its signature can compile.
- R10-4 is replaced by Step 12, but Step 10 alone exposes a failing and incompatible procedure contract.
- R10-2 leaves Step 14 data validity dependent on loader discipline and validator checks rather than the approved physical backstop.
- R10-3 leaves direct maintenance creation outside the protected escalation path capable of introducing an out-of-service overlap.
- Step 12 locking, permissions, and two-session correctness were not re-reviewed as Step 10 responsibilities.

## 10. Assumptions

No material assumptions were used to make Step 10 pass or fail.

## 11. Open Questions

| ID | Open question | Why it matters | Required decision/source |
| --- | --- | --- | --- |
| OQ10-1 | What is the authoritative Instant eligibility, usage-policy treatment, path immutability, and complete seven-status provenance contract? | Determines which BOOKING cross-column constraints Step 10 may validly enforce | Accepted requirement/change decision and aligned Step 8/9 |
| OQ10-2 | Is acknowledgement requester provenance protected by immutable BOOKING submission facts or by an immutable requester snapshot? | Step 10 currently selects the first option without a final Step 9 choice | Approved Step 9 design decision |

## 12. Recommended Corrections

1. **Major:** Add the Step 10-owned `dbo.BookingAdvisoryAckListType` with exact downstream key/type semantics.
2. **Major:** Add supported impact-history integrity backstops for the approved open/chain/current-state contract while leaving protected workflow logic to Step 12.
3. **Major:** Replace the dropped Phase 1 maintenance trigger with Phase 2-aware maintenance-side protection that permits escalation but rejects unrelated new out-of-service conflicts.
4. **Major:** Remove the Step 10 `sp_SubmitBooking` stub.
5. **Major:** Make database preconditions and cross-batch failure reporting fail-safe.
6. **Major:** Resolve OQ10-1 and OQ10-2 upstream before adding or certifying the affected BOOKING constraints.
7. **Safe Minor:** Add focused shape/trust validation for guarded objects and gate the final success message.

## 13. Final Verdict

**Step 10 not ready - correction required**

Step 11 can remain a design artifact, but Step 12 and Step 14 cannot safely rely on Step 10 as the complete owner of the migrated physical schema. The clean migration and immediate rerun compile successfully, but the missing TVP, missing maintenance-side protection, partial history integrity, unsafe redundant procedure, and failure-safety defects require correction first.
