# Step 14 Generator–Validator Coherence Review

## 1. Executive Summary

- **Generator reviewed:** `outputs/14-data-generator-G02/generate_data.py` with `generator_config.json` and `README.md`.
- **Validator reviewed:** current working-tree `outputs/14-data-generator-G02/02-validate-data.sql`.
- **Upstream reviewed:** actual Step 1 filename, Steps 3 and 8-12, Phase 2 requirements, and the latest relevant Step 9, Step 12, Step 14 generator, and validator reviews.
- **Review status:** Static only. No verified disposable database was explicitly supplied, so no database operation was performed. Existing runtime transcripts are historical context, not evidence for this review. They predate the current validator changes.
- **Counting method:** Counts below are counts of mandatory matrix rows by exact classification.
- **Generator Bug count:** 1
- **Validator Bug count:** 9
- **Both Bug count:** 3
- **Not Provable count:** 9
- **Not Step 14 Responsibility count:** 3
- **Upstream Ambiguity count:** 2
- **Blocking/Major actionable issue count:** 11 (1 Blocking, 10 Major)
- **Overall verdict:** **Not coherent — correction required**.

The immediate blocker is executable: `02-validate-data.sql:478` references undeclared `@UnexplainedOosOverlap`. The current script cannot reach its intended 53-row `#Checks` summary, final `THROW`, or a meaningful `sqlcmd -b` result. The nearby `@CurrentOosOverlap`, `@InvalidApprovalDuringOos`, `@OrphanMaintenanceHistory`, and `@InvalidImpactHistoryTransition` variables are declared but never aggregated.

## 2. Step 14 Responsibility Boundary

**Step 14 persisted-data responsibility**

- Generate and independently validate required volume, academic span, category representation, booking facts, capacity, time order, decision provenance, final protected occupancy, maintenance scenarios, impact history, ACK rows, UsageSession state, referential integrity, and useful Step 15 distributions.
- Validate current persisted facts directly. Use impact history only for state changes it can deterministically reconstruct.
- Preserve the distinction between current occupancy (`Approved`, `Checked In`) and historical post-approval states (`Completed`, `No-Show`).

**Steps 10-13 responsibility**

- Step 10 owns schema deployment and migration idempotency.
- Step 12 owns protected procedure implementation, lock acquisition, write-path permissions, and transaction semantics.
- Step 13 owns true two-session blocking/race evidence and effective access-path tests.
- Step 14 may require the resulting tables and constraints to interpret its data, but its validator must not claim static rows prove locking, permissions, or concurrent interleavings.

**Stored-data limits**

- No maintenance-status, maintenance-period, user-status, or booking-status history exists.
- No maintenance creation timestamp or escalation-affected-booking snapshot exists.
- Static rows therefore cannot prove every action-time state, the UI display event, cancellation origin, or historical immutability.

## 3. Requirement → Generator → Validator Matrix

| ID | Source | Upstream requirement | Step 14 scope | Generator behavior | Persisted evidence available? | Validator behavior | Classification | Action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D01 | AGENTS §9 Step 14 | At least 100,000 bookings. | Persisted data | Configures/generates 105,000. | `BOOKING` count. | `Booking row minimum >= 100000`. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D02 | Step 14 package contract | Required supporting-table minima. | Persisted data | Generates 600 users, 60 spaces, 12 facilities, 3,500 maintenance rows, and dependent rows. | Table counts. | Eleven supporting count gates are in `#Checks`. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D03 | AGENTS §9; config | At least three academic years, approximately Sep-2023 to May-2026. | Persisted data | Uses 2023-09-01 through 2026-05-31 and forces endpoint bookings. | Booking dates and academic-year keys. | Checks year count and both endpoints. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D04 | Steps 3, 5, 9, 10 | Persisted domain values are exact and every required category is represented. | Persisted data | Emits only approved values and all categories. | Actual distinct values. | Uses only `COUNT(DISTINCT)=N`; an illegal replacement value can false-PASS if a constraint is absent/untrusted. | `VALIDATOR BUG` | Use explicit allowed-value anti-joins plus separate coverage counts for load-bearing domains. |
| D05 | AGENTS §9 Step 14; config | Required statuses and paths must be materially represented for realistic data. | Persisted data | Deterministic configured status proportions produce substantial groups. | Counts/ratios by category. | Presence/cardinality only; one row can satisfy most category gates. | `VALIDATOR BUG` | Add documented, justified category minima or ratio tolerances. |
| D06 | Phase 1 BR-8/19; Steps 3/5/12 | Booking periods and participants are valid; creation is no later than start. | Persisted data | Generates positive, capacity-bounded participants and ordered times. | Booking and space columns. | Correct time/capacity predicates are aggregate-controlled. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D07 | Steps 3, 5, 9, 10 | Every generated load-bearing relationship resolves. | Persisted data | Inserts in FK-safe order with deterministic IDs. | Parent/child rows. | Aggregates orphan checks across all nine tables. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D08 | Step 12 submission/approval | Requesters and decision actors were active/eligible at action time. | Persisted-data limit | Chooses currently Active requesters/staff. | Current role/status only; no user-status history. | Checks current Active status incompletely and treats it as historical truth. | `NOT PROVABLE FROM STORED DATA` | Validate current referential role consistency only; disclose action-time status limitation. |
| D09 | Phase 2 line 22; Step 8 §§1/6; Step 9; Step 12 review | Exact Instant eligibility policy. | Upstream decision | Implements Classroom plus active Lecturer/TA; free-text policy is informational. | Current requester/space facts. | Enforces the same bounded policy. | `UPSTREAM AMBIGUITY` | Record authoritative approval of the detailed policy; do not label it verbatim Phase 2 BRA. |
| D10 | Step 9/12; generator config | Both resolution paths must be represented and configured overall Instant ratio must be achievable. | Persisted data/config | Silently caps impossible overall targets through `min(1.0, target/eligible_ratio)`. | Actual path counts and config. | Checks only two distinct paths, not target attainability or tolerance. | `BOTH BUG` | Reject impossible targets and validate actual ratio against the accepted target/tolerance. |
| D11 | Step 9 §5.4; Step 12 | Instant provenance has NULL approver/note and `decision_time = created_at`. | Persisted data | Generates those exact values, including later lifecycle states. | Booking columns. | Dedicated timestamp and state predicates are aggregate-controlled. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D12 | Phase 1 BR-13/14; Step 12 | Staff approval/rejection records actor, time, note, and rejection reason when rejected. | Persisted data | Populates staff actor/time/note; rejected rows have reason. | Booking columns and user role. | State predicate checks the required final fields. | `GENERATOR CORRECT + VALIDATOR CORRECT` | Keep separate from unsupported chronology limits. |
| D13 | Phase 1 no-show semantics | Do not impose one unsupported decision-time upper bound on every status. | Persisted data | Generated decisions happen before start, but this is only one valid pattern. | Decision and requested times. | `decision_time > requested_start` always fails, rejecting valid post-start no-show decisions. | `VALIDATOR BUG` | Require `decision_time >= created_at`; add only source-backed status-specific bounds. |
| D14 | Step 9 §5.4 and latest Step 9 review | Complete seven-status resolution/provenance matrix. | Upstream decision | Uses a coherent chosen matrix and preserves original decisions. | Final booking fields. | Enforces a stricter full matrix than current Step 9 explicitly approves. | `UPSTREAM AMBIGUITY` | Resolve all later-status combinations before treating them as universal validity rules. |
| D15 | Phase 1 BR-23; Step 12 | Only `Approved` and `Checked In` currently reserve/occupy and must not overlap. | Persisted data | `APPROVAL_LIFECYCLE_STATUSES` also serializes `Completed` and `No-Show`, suppressing valid historical overlap. | Final booking statuses/times. | Current self-join correctly uses only `Approved` and `Checked In`. | `GENERATOR BUG` | Maintain the conflict schedule only for `Approved`/`Checked In`; allow realistic historical overlap for other statuses. |
| D16 | Phase 1 overlap assumption; Step 12 | Half-open overlap; adjacency is allowed. | Persisted data | Uses the equivalent non-overlap condition. | Booking intervals. | Uses strict `<`/`>` half-open self-join. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D17 | Phase 1 BR-12; Step 12 | Current occupying bookings cannot be on Retired/Temporarily Closed spaces. | Persisted data | Excludes those spaces from all booking choices. | Booking-space join. | No aggregate-controlled check. | `VALIDATOR BUG` | Add zero-count check using `Approved`/`Checked In`. |
| D18 | Phase 2 concurrent approval; Steps 11-13 | Per-space locks prevent simultaneous conflicting approval. | Steps 11-13 | Historical bulk load does not execute concurrent paths. | Static rows show only final invariant, not blocking. | No true concurrency proof is appropriate here. | `NOT STEP 14 RESPONSIBILITY` | Keep two-session proof in Step 13. |
| D19 | Step 12 | `AppServiceRole` DENY/GRANT behavior prevents bypass. | Steps 12-13 | Not exercised by bulk load. | Effective permission behavior needs execution context. | Current trigger-state count does not prove permissions. | `NOT STEP 14 RESPONSIBILITY` | Test under `EXECUTE AS` in Step 12/13, not the data validator. |
| D20 | Phase 2 P2-BR-01; Step 12 | Approval while OOS was already effective is invalid; later escalation is valid. | Persisted-data limit | Generates OOS-open records outside booking range and intentional post-approval escalations. | Impact history can reconstruct impact, but not maintenance status/existence/period as of decision. | Declares an incomplete reconstruction but never aggregates it. | `NOT PROVABLE FROM STORED DATA` | Validate supported impact chronology and current facts; disclose missing status/existence/period history. |
| D21 | Phase 2 P2-BR-02; AGENTS §9 | Advisory maintenance does not block booking; generated data should contain a positive approved/occupying overlap case. | Persisted data | Broad active advisories overlap generated bookings and are acknowledged. | Booking-maintenance overlap and ACK rows. | No direct positive gate restricted to `Approved`/`Checked In`. | `VALIDATOR BUG` | Require at least one occupying advisory-overlap with a valid ACK. |
| D22 | Phase 2 additional rule 1; AGENTS §8.1/§9 | Same space supports simultaneous active maintenance with different impacts. | Persisted data | Broad overlapping rows are advisory; deterministic generic mapping does not guarantee an active same-space mixed-impact pair. | Maintenance self-join. | Multiple-ACK proxy proves multiple advisories, not mixed impacts. | `BOTH BUG` | Deliberately generate and directly validate an active overlapping advisory/OOS pair. |
| D23 | Phase 2 P2-BR-05; AGENTS §9 | Escalation and downgrade events are populated. | Persisted data | Generates 100 escalation-only histories and 300 two-event escalation/downgrade chains. | History rows. | Requires nonzero escalation/downgrade events and history minimum. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D24 | Step 9 §5.2.2 | History transitions are distinct, continuous, deterministic, and latest state matches current impact. | Persisted data | Generates coherent chains and reconciled current impact. | History IDs/times/old/new/current impact. | Aggregate checks use `(changed_at, history_id)` for chain and latest-state checks. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D25 | Step 9 §5.2.2 | Impact change occurred while maintenance status was open. | Persisted-data limit | Places changes within start/completion period, but stores final status only. | No maintenance-status history. | Uses time bounds as a proxy for open status. | `NOT PROVABLE FROM STORED DATA` | Validate event time against known period only; disclose open-status limitation. |
| D26 | Step 9 §5.2.2 | Complete history and atomic current-state/history updates. | Persisted-data limit | Emits matching snapshots, but final rows cannot prove no direct change was omitted. | No immutable initial event or transaction log. | Chain/current checks cannot prove completeness or atomicity. | `NOT PROVABLE FROM STORED DATA` | Do not claim snapshot proof; Step 12 tests the workflow. |
| D27 | Step 9 §5.2.2 | Equal history timestamps use `history_id` as authoritative order. | Persisted data | Generated changes use distinct times. | `history_id` is stored and sufficient. | Main chain uses the tie-breaker, but ACK reconstruction and two standalone history queries order only by `changed_at`. | `VALIDATOR BUG` | Use `(changed_at, history_id)` everywhere and remove duplicate standalone queries. |
| D28 | Phase 2 P2-BR-03; Step 9 | ACK pair is unique, references booking/maintenance, same space, and overlapping period. | Persisted data | Generates unique same-space overlapping pairs. | ACK, booking, maintenance rows and unique pair. | Invalid/duplicate/orphan predicates cover these properties. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D29 | Step 12 submission semantics | ACK is stored in the submission transaction with `acknowledged_at = created_at`. | Persisted data | Uses `created_at + 5 minutes`. | Both timestamps persist. | Allows any timestamp from creation through requested start. | `BOTH BUG` | Generate equality and validate exact equality. |
| D30 | Step 9 history model | ACK maintenance impact at submission is advisory where impact history permits reconstruction. | Persisted data | Benchmark ACK targets have advisory impact. | Impact history plus stable tie key. | Reconstructs impact, subject to D27 tie-order defect. | `GENERATOR CORRECT + VALIDATOR CORRECT` | Correct D27 without changing this supported scope. |
| D31 | Phase 2 P2-BR-03 | Exactly one ACK existed for every active advisory at submission. | Persisted-data limit | Intends completeness for broad benchmark advisories. | No maintenance-status history, creation time, or period history. | `@MissingAck` uses current status/impact and can false-PASS or false-FAIL history. | `NOT PROVABLE FROM STORED DATA` | Rename/check only current applicable set or remove; disclose full booking-time limitation. |
| D32 | Phase 2 P2-BR-03 | UI actually notified the human requester. | Persisted-data limit | Creates ACK audit rows only. | No UI/event evidence beyond ACK. | Cannot prove display. | `NOT PROVABLE FROM STORED DATA` | Validate only persisted acknowledgement evidence. |
| D33 | Phase 1 BR-15/16; Assumption 9 | `Checked In` and `Completed` have one UsageSession; other statuses have none. | Persisted data | Generates one session for each required status and none otherwise. | Booking/session rows; PK limits to one. | Missing/extra predicates check the status relationship. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D34 | Phase 1 BR-15/16 | Checked-In session is open; Completed session has checkout staff/end/final condition/notes. | Persisted data | Generates correct open/closed field sets. | UsageSession columns. | Checks only existence and time order; contradictory field sets can pass. | `VALIDATOR BUG` | Add status-specific open/closed field predicates. |
| D35 | Phase 1 no-show meaning | No-Show has no successful check-in/session. | Persisted data | Generates no session for No-Show. | Booking/session relationship. | Unsupported-status session check covers No-Show. | `GENERATOR CORRECT + VALIDATOR CORRECT` | None. |
| D36 | Phase 2 P2-BR-06; latest Step 9 review | Exact bookings approved and affected at escalation time. | Persisted-data limit | Creates plausible positive scenarios with decision before escalation. | No booking-status or maintenance-period history/snapshot. | Counts a current reconstruction as affected evidence. | `NOT PROVABLE FROM STORED DATA` | Label as current reconstruction; persist snapshots/history upstream for exact proof. |
| D37 | Phase 2 reports; AGENTS §9/Step 15 | Dataset has report-eligible semester/hour and room-finder selectivity. | Persisted data | Creates broad time, capacity, facility, building, and popularity skew. | Report-specific row cardinalities can be queried. | Uses all-status weekday/hour and shallow distinct counts; no functional facility or representative room-finder gates. | `VALIDATOR BUG` | Add compact report-eligible and representative room-finder cardinality checks. |
| D38 | Generator safety contract | Protected triggers are restored after load. | Step 14 operational/current metadata | Captures enabled triggers, restores in `finally`, and verifies restoration. | Current disabled state; full before/after proof requires run log. | Checks zero disabled protected-table triggers. | `GENERATOR CORRECT + VALIDATOR CORRECT` | Keep current-state gate; do not expand into Step 12 certification. |
| D39 | Steps 10/12 | Migration idempotency, procedure bodies, role permissions, and transactional locking are correct. | Steps 10-13 | Generator only inspects load prerequisites. | Not proven by generated rows. | Generic certification would duplicate prior steps. | `NOT STEP 14 RESPONSIBILITY` | Keep deployment/workflow validation in Steps 10-13. |
| D40 | Phase 1 BR-21 | Cancelled row originated only from Pending/Approved. | Persisted-data limit | Generates both pending-cancel and decided-cancel shapes, but no transition history. | Final row lacks prior status. | Current field shape cannot prove source transition. | `NOT PROVABLE FROM STORED DATA` | Do not add a misleading snapshot check. |
| D41 | Phase 1 BR-22; Step 9/12 | Submission facts, ACK rows, and resolution path were never mutated historically. | Persisted-data limit | Bulk load writes final rows directly. | No before-image/audit history. | Current rows cannot prove past immutability. | `NOT PROVABLE FROM STORED DATA` | Leave mutation enforcement/testing to Steps 10-13. |
| D42 | Review contract §6 | Every correctness check reaches summary, final `THROW`, and `sqlcmd -b`. | Validator control | Not applicable to generation. | Script text is sufficient. | Intended 53 `#Checks` rows exist, but undeclared `@UnexplainedOosOverlap` prevents execution; four replacement variables are unused. | `VALIDATOR BUG` | Define one correct supported OOS predicate, aggregate it, remove unused/standalone fragments, then verify `sqlcmd -b`. |

## 4. Generator Findings

### Booking Lifecycle

- R14COH-2: ACK creation is five minutes late relative to the Step 12 persisted contract.
- R14COH-3: conflict scheduling incorrectly includes `Completed` and `No-Show`.
- Generated status fields, required decision provenance, capacity, and times are otherwise internally coherent for the chosen matrix.

### Resolution Paths

- R14COH-5: impossible overall Instant targets are accepted and silently capped.
- Detailed Instant eligibility remains upstream-ambiguous (OQ-1), although generator and Step 12 currently agree.

### Decision Provenance

- Instant rows preserve `decision_time = created_at`; Staff rows preserve actor/time/note after later lifecycle states.
- The generator does not create the validator's false-fail post-start no-show case; that does not make the unsupported predicate valid.

### Occupancy

- Half-open interval logic is correct.
- The scheduled status set is overbroad; this reduces realistic historical overlap and misrepresents current occupancy semantics.

### Maintenance

- Both impacts, open/completed rows, overlapping advisories, and escalation/downgrade cases are generated.
- R14COH-4: no deliberate active mixed-impact overlap is guaranteed.

### Maintenance History

- Generated chains are continuous and current-state reconciled.
- Open-at-change status and complete event retention remain unprovable from the final schema.

### ACK

- Pairs are deterministic, unique, same-space, and period-overlapping.
- Timestamp equality is wrong. Full historical active-set completeness is not reconstructable.

### UsageSession

- Generated `Checked In` sessions are open and `Completed` sessions are closed with all completion fields.
- `No-Show` receives no session.

### Distribution/Step 15 Readiness

- The generator creates useful broad skew, but the validator does not independently prove operation-specific selectivity.

## 5. Validator Findings

### Predicate Correctness

- Current protected booking overlap uses the correct `Approved`/`Checked In` set and half-open predicate.
- ACK timing, decision chronology, action-time actor state, and current-state missing-ACK predicates do not match what stored data can prove.
- OOS work is unfinished: corrected variables were added but not connected to `#Checks`.

### Aggregate Failure Control

The intended path is sound in structure:

```text
predicate -> #Checks -> summary -> final THROW -> sqlcmd -b
```

All 53 named rows would participate if the batch compiled. It currently does not: `@UnexplainedOosOverlap` is undeclared. Therefore actual current aggregate count, PASS count, and FAIL count are **not available**.

### False-PASS

- Completed sessions with missing checkout/final fields.
- Occupying bookings on Retired/Temporarily Closed spaces.
- Late ACKs before requested start.
- Illegal domain replacement with unchanged distinct cardinality.
- Trivial required-category populations and shallow Step 15 workload.

### False-FAIL

- Valid post-start no-show decision.
- Historical actor whose account later became inactive.
- Missing ACK demanded from a current advisory that was not applicable at submission.
- Equal-timestamp impact history interpreted without `history_id` in ACK reconstruction.

### Redundancy

- Lines 428-464 repeat chain/current-state queries already represented by `Broken impact-history chains` and `Impact history/current mismatches`; they are standalone unlabeled result sets and add no gate coverage.
- `@OrphanMaintenanceHistory` duplicates part of the aggregate orphan check.
- `@InvalidImpactHistoryTransition` duplicates existing history predicates and is unused.

### Over-Validation

- Current Active account status is used as a historical actor-state assertion.
- `decision_time <= requested_start` is imposed globally without upstream support.
- Full current-state missing-ACK approximation is presented as booking-time completeness.
- Broad Step 10/12 procedure, role, permission, and migration certification should not be added to this validator.

### Missing Validation

- R14COH-6 through R14COH-13 identify exact domain, material category, unavailable-space, positive advisory, UsageSession, history-order, and Step 15 workload gaps.

## 6. Not Provable From Stored Data

| Requirement | Missing historical information | Strongest provable property | Schema change needed for full proof? |
| --- | --- | --- | --- |
| Active requester/actor at action time | User role/status history | Current referenced user and current role/status | Yes, user-state history or event snapshot. |
| Approval occurred while maintenance was OOS and active | Maintenance status, creation, and period history | Impact-at-time where history is deterministic; current status/period | Yes. |
| Impact changed while record status was open | Maintenance-status history | Event lies within current start/completion bounds | Yes. |
| Complete/atomic impact history | Immutable initial event and transaction evidence | Chain continuity and latest/current agreement | Yes for complete historical proof; workflow tests cover transaction behavior. |
| Exact booking-time ACK set | Maintenance status, creation, and period history | ACK pair validity, impact-at-time where reconstructable, current applicable-set comparison | Yes. |
| Requester actually saw UI notice | Presentation/event telemetry | Persisted ACK evidence | Yes, if UI display proof is required. |
| Exact affected set at escalation | Booking-status and maintenance-period history or snapshot | Current reconstruction with decision-before-event evidence | Yes. |
| Cancellation origin | Booking-status transition history | Current Cancelled row shape | Yes. |
| Historical immutability | Before-images/audit log | Current values and current enforcement metadata | Yes for historical proof; mutation tests can prove current enforcement. |

## 7. Not Step 14 Responsibility

- Per-space `UPDLOCK/HOLDLOCK` blocking and true concurrent interleavings: Steps 11-13.
- Effective `AppServiceRole` DENY/GRANT behavior and protected-path bypass tests: Steps 12-13.
- Migration idempotency, full schema deployment certification, procedure correctness, and transaction rollback behavior: Steps 10-13.

## 8. Redundant / Excessive Validator Checks

- Remove the two standalone history `SELECT COUNT_BIG` result sets at lines 428-464 after retaining the aggregate-controlled chain/current checks with stable ordering.
- Remove unused `@OrphanMaintenanceHistory` and `@InvalidImpactHistoryTransition`; their coverage already exists in the orphan/history gates.
- Replace the unused OOS variables and undeclared reference with one explicitly scoped supported predicate. Do not present it as exact historical approval validity without status/existence history.
- Keep concise distributions needed to diagnose Step 15 readiness; remove the full trigger inventory if the aggregate current-disabled-state row is retained and no diagnosis requires it.
- Do not add a generic inventory of every Step 10/12 procedure, role, permission, trigger body, or migration constraint.

## 9. Assumptions

| ID | Assumption | Why needed | Evidence supporting it | Risk if wrong |
| --- | --- | --- | --- | --- |
| None | No material assumption was used to resolve a requirement. | Ambiguities and historical limits are classified explicitly. | Source precedence and inspected artifacts. | None. |

## 10. Open Questions

| ID | Open question | Why it matters | Required source/decision |
| --- | --- | --- | --- |
| OQ-1 | Is Classroom plus active Lecturer/TA the formally approved Instant policy, with free-text `usage_policy` informational? | Generator and validator enforce it, but the Phase 2 BRA says only selected space types and Step 8 describes conflicting authority. | Accepted requirement amendment or explicit project decision artifact. |
| OQ-2 | What is the authoritative seven-status resolution/provenance and report-eligibility matrix? | Step 9 defines core decision states but leaves later states orthogonal; the latest Step 9 review records unresolved operation-specific status semantics. | Approved Step 9 correction/decision. |

## 11. Issues Found

### Issue R14COH-1 — Validator references an undeclared OOS variable

- **Classification:** VALIDATOR BUG
- **Severity:** Blocking
- **Source requirement:** Review contract §6 aggregate failure control.
- **Generator behavior:** Not applicable.
- **Validator behavior:** Declares four new OOS/history variables, leaves them unused, then references removed `@UnexplainedOosOverlap` at line 478.
- **Why this matters:** The batch cannot reach its summary or final `THROW`; current PASS/FAIL evidence is impossible.
- **Impact on Step 15:** No trustworthy current validator gate exists.
- **Suggested correction:** Replace the fragment with one supported, declared, aggregate-controlled OOS predicate and run with `sqlcmd -b` on an explicitly verified disposable database.

### Issue R14COH-2 — ACK timestamp contract is wrong on both sides

- **Classification:** BOTH BUG
- **Severity:** Major
- **Source requirement:** Step 12 `sp_SubmitBooking` inserts `acknowledged_at = @CreatedAt`.
- **Generator behavior:** Writes `booking.created_at + 5 minutes` (`generate_data.py:398`).
- **Validator behavior:** Accepts any timestamp through `requested_start` (`02-validate-data.sql:285-287`).
- **Why this matters:** Data that could not be produced by the approved submission transaction is accepted.
- **Impact on Step 15:** Advisory workload is based on nonconforming audit rows.
- **Suggested correction:** Generate and require exact equality.

### Issue R14COH-3 — Generator uses historical states as occupancy blockers

- **Classification:** GENERATOR BUG
- **Severity:** Major
- **Source requirement:** Phase 1 BR-23 and Step 12 use only `Approved` and `Checked In` for current occupancy.
- **Generator behavior:** `APPROVAL_LIFECYCLE_STATUSES` includes `Completed` and `No-Show` and drives schedule allocation.
- **Validator behavior:** Current overlap self-join is corrected to the authoritative two statuses.
- **Why this matters:** Generated history is unnecessarily serialized and does not model the approved availability semantics.
- **Impact on Step 15:** Conflict/report selectivity is distorted.
- **Suggested correction:** Separate current occupying statuses from historical approved-lifecycle statuses.

### Issue R14COH-4 — Mixed-impact active maintenance is neither guaranteed nor proved

- **Classification:** BOTH BUG
- **Severity:** Major
- **Source requirement:** Phase 2 additional rule 1 and AGENTS §8.1.
- **Generator behavior:** Deliberate broad overlaps are advisory-only; no explicit mixed-impact active pair is constructed.
- **Validator behavior:** Multiple ACKs prove multiple advisories, not a same-space active advisory/OOS overlap.
- **Why this matters:** A required maintenance scenario can be absent while validation passes.
- **Impact on Step 15:** Room-finder maintenance selectivity may omit a central Phase 2 case.
- **Suggested correction:** Construct one deterministic mixed-impact active overlap and validate it with a maintenance self-join.

### Issue R14COH-5 — Impossible Instant ratios are silently accepted

- **Classification:** BOTH BUG
- **Severity:** Minor
- **Source requirement:** Generator configuration must be semantically achievable and deterministic.
- **Generator behavior:** Caps impossible target probability rather than rejecting it.
- **Validator behavior:** Proves only both-path presence.
- **Why this matters:** Accepted future config can silently miss its target.
- **Impact on Step 15:** None for current 0.35; future workload skew can be wrong.
- **Suggested correction:** Validate target feasibility and actual tolerance.

### Issue R14COH-6 — Domain gates are cardinality proxies

- **Classification:** VALIDATOR BUG
- **Severity:** Minor
- **Source requirement:** Steps 3, 5, 9, and 10 exact domains.
- **Generator behavior:** Emits exact values after schema inspection.
- **Validator behavior:** Uses only distinct counts.
- **Why this matters:** Illegal replacement values can false-PASS independently of generator behavior.
- **Impact on Step 15:** Filters may benchmark unapproved categories.
- **Suggested correction:** Use compact explicit-set anti-joins and separate representation checks.

### Issue R14COH-7 — Material category representation is not validated

- **Classification:** VALIDATOR BUG
- **Severity:** Major
- **Source requirement:** AGENTS §9 Step 14 and Step 15 observable-selectivity requirement.
- **Generator behavior:** Produces substantial deterministic status/path groups.
- **Validator behavior:** Most categories need only one row.
- **Why this matters:** A severely skewed or partial dataset can pass.
- **Impact on Step 15:** Index comparisons may be unrepresentative.
- **Suggested correction:** Add justified minimum counts or tolerances, not arbitrary generic ratios.

### Issue R14COH-8 — Decision and actor predicates overclaim history

- **Classification:** VALIDATOR BUG
- **Severity:** Major
- **Source requirement:** Phase 1 no-show semantics and action-time actor eligibility.
- **Generator behavior:** Uses currently Active actors and pre-start decisions.
- **Validator behavior:** Rejects every post-start decision and requires historical actors to remain Active now.
- **Why this matters:** Valid history can false-FAIL; action-time state is not reconstructable.
- **Impact on Step 15:** Valid historical rows may be distorted or removed.
- **Suggested correction:** Keep source-backed chronology and current role consistency; disclose action-time status limits.

### Issue R14COH-9 — Unavailable-space invariant is not independently checked

- **Classification:** VALIDATOR BUG
- **Severity:** Major
- **Source requirement:** Phase 1 BR-12 and Step 12.
- **Generator behavior:** Excludes Retired/Temporarily Closed spaces.
- **Validator behavior:** Has no occupying-booking/space-status predicate.
- **Why this matters:** Invalid current reservations can pass.
- **Impact on Step 15:** Availability and room-finder baselines can be incorrect.
- **Suggested correction:** Add a zero-count join using only `Approved`/`Checked In`.

### Issue R14COH-10 — Advisory nonblocking coverage is indirect

- **Classification:** VALIDATOR BUG
- **Severity:** Major
- **Source requirement:** Phase 2 P2-BR-02.
- **Generator behavior:** Creates broad advisory overlaps and ACKs.
- **Validator behavior:** Does not require an `Approved`/`Checked In` advisory-overlap success case.
- **Why this matters:** Advisory data can exist without proving the generator modeled a usable booked space.
- **Impact on Step 15:** Room-finder advisory behavior may be untested.
- **Suggested correction:** Add one direct positive scenario gate.

### Issue R14COH-11 — Impact ordering and ACK completeness checks are misleading

- **Classification:** VALIDATOR BUG
- **Severity:** Major
- **Source requirement:** Step 9 tie ordering and Phase 2 booking-time ACK contract.
- **Generator behavior:** Uses distinct history times and complete broad-advisory ACK sets.
- **Validator behavior:** ACK history windows omit `history_id`; `@MissingAck` substitutes current state for booking-time state; duplicate standalone history queries are not gated.
- **Why this matters:** Equal-time history is nondeterministic and historical ACK completeness can false-PASS/false-FAIL.
- **Impact on Step 15:** Advisory/escalation data cannot be trusted at the claimed scope.
- **Suggested correction:** Use stable ordering, retain only supported checks, and state the historical limitation.

### Issue R14COH-12 — UsageSession lifecycle fields can contradict booking state

- **Classification:** VALIDATOR BUG
- **Severity:** Major
- **Source requirement:** Phase 1 BR-15/16.
- **Generator behavior:** Correctly generates open Checked-In and fully closed Completed sessions.
- **Validator behavior:** A Completed session with all checkout fields NULL can pass; a Checked-In session may be closed.
- **Why this matters:** Persisted usage history can contradict lifecycle meaning.
- **Impact on Step 15:** Usage/utilization reporting can be wrong.
- **Suggested correction:** Add compact status-specific open/closed field checks.

### Issue R14COH-13 — Step 15 readiness checks are too shallow

- **Classification:** VALIDATOR BUG
- **Severity:** Major
- **Source requirement:** Phase 2 reporting and AGENTS §9 Step 15 handoff.
- **Generator behavior:** Produces useful broad skew and facility variation.
- **Validator behavior:** Weekday/hour checks include all statuses; facility-set counts ignore operation state and no representative room-finder cardinality is checked.
- **Why this matters:** Integrity may pass while tuned operations are trivial or empty.
- **Impact on Step 15:** Before/after measurements may not be meaningful.
- **Suggested correction:** Add a small set of report-eligible and room-finder positive/negative cardinality checks.

## 12. Recommended Final Validator Scope

1. **Dataset volume/span:** nine table minima, three academic years, boundary coverage, and nontrivial per-year population.
2. **Domains/status representation:** explicit allowed-value anti-joins plus required category representation and justified minima.
3. **Booking row/lifecycle consistency:** required facts, time order, capacity, rejection fields, source-backed provenance; no unsupported universal chronology.
4. **Resolution-path provenance:** both paths, Instant timestamp/null fields, Staff decision fields, and accepted eligibility policy only after OQ-1 is resolved.
5. **Protected occupancy invariant:** only `Approved`/`Checked In`, same space, half-open overlap, and unavailable-space check.
6. **Maintenance/history consistency:** impact/status coverage, general/mixed overlap scenarios, distinct transitions, `(changed_at, history_id)` chain, latest/current match, escalation/downgrade presence.
7. **ACK persisted-data checks:** FKs, unique pair, same space, period overlap, `acknowledged_at = created_at`, reconstructable impact-at-time, multiple-advisory coverage; explicitly label current-set completeness as weaker than booking-time completeness.
8. **UsageSession consistency:** required/unsupported statuses, one-to-zero-or-one, time order, Checked-In open fields, Completed closed fields, No-Show absence.
9. **FK/orphan/load-bearing relationship checks:** retain the current direct orphan aggregate and ACK/session duplicate checks; only minimal metadata needed to trust these relationships.
10. **Step 15 distribution/readiness checks:** report-eligible year/weekday/hour populations, popular/selective space cases, usable all-facility positive/negative cases, advisory discoverability, OOS exclusion, and escalation workload.

**Checks that should not be in the final validator**

- True two-session blocking, race rejection, or lock acquisition.
- Effective role permission tests under `EXECUTE AS`.
- Full stored-procedure implementation certification.
- Migration idempotency or wholesale Step 10 metadata review.
- Claims of action-time maintenance status, exact historical ACK set, exact escalation affected set, UI display, cancellation origin, or historical immutability without the missing histories/snapshots.
- Duplicate standalone informational history queries that do not enter `#Checks`.

## 13. Final Verdict

**Not coherent — correction required**

Step 15 cannot safely proceed using the current validator as its authorization gate. The validator first needs the blocking undeclared-variable repair, and the generator/validator must align ACK timestamps, current occupancy semantics, and mixed-impact maintenance coverage. Unprovable historical requirements should be documented at their strongest supported scope rather than approximated as current-state correctness checks.
