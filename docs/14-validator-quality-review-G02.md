# Step 14 Validator Quality Review

## 1. Review Summary

This was a static, validator-quality and upstream-conformance review of `outputs/14-data-generator-G02/02-validate-data.sql`. No validator, generator, schema, procedure, or earlier output was modified. Runtime execution was not performed because this command did not explicitly provide a verified disposable review database.

Sources read in full include the actual repository artifacts `req/business-requirement.md`, `req/business-requirement-phase2.md`, `outputs/01-business-req-analysis-G02.md` (the actual Step 1 filename), Steps 2 through 12, the Step 14 Python generator package, relevant approved and current review files under `docs/`, and all relevant Step 14 generation/review skill files. The older Step 9 and Step 10 reviews contain stale `approval_path`/`row_version` descriptions; those descriptions were not allowed to override the current Step 9 `resolution_path` design, current Step 10 physical schema, or current Step 12 workflow.

The validator has a sound aggregate-control skeleton: all **53** distinct PASS/FAIL checks are inserted into `#Checks`; there are **0** standalone PASS/FAIL checks; all 53 can cause the final `THROW`; and no displayed FAIL can escape aggregate control. There are 9 informational result sets after the aggregate summary.

That control-flow strength does not make the validator complete or predicate-correct. The upstream traceability and gap-discovery passes identified **24 Missing/Partial persisted-data requirements** and **35 total validation gaps** when Weak, Redundant, and non-snapshot-testable limitations are included. Important false PASS cases include incomplete `Completed` usage sessions, approved/occupying bookings on retired or temporarily closed spaces, late acknowledgements, current-state-only acknowledgement completeness, and absent protected objects that are not counted as disabled. Important false FAIL cases include treating `Completed` and `No-Show` as current conflict-bearing statuses, treating resolved/cancelled out-of-service maintenance as blocking, rejecting valid post-start no-show decisions, and requiring historical actors to remain active today.

**Blocking/Major issues:** 2 Blocking, 7 Major.

**Final validator verdict:** **Validator not ready**.

## 2. Upstream Requirement Traceability Matrix

The matrix uses consolidated contract units: each row covers one independently testable rule or a tightly coupled group of attributes governed by one predicate. This avoids counting every mandatory column as a separate business rule while still tracing all data-relevant upstream requirements.

| Source | Requirement / Invariant | Persisted-data testable? | Validator check | Aggregate-controlled? | Coverage |
| --- | --- | --- | --- | --- | --- |
| Steps 3, 5, 9, 10 | All nine final tables, current columns, data types, identities, nullability, keys, and Phase 2 columns exist. | Yes, metadata | Only `dbo.BOOKING` existence; other absence normally causes later SQL failure | Partial | Partial |
| Steps 3, 5, 9, 10 | Required PKs identify every entity and `USAGESESSION.booking_id` enforces at most one session per booking. | Yes | No PK metadata or duplicate-entity audit | No | Missing |
| Steps 3, 5 | `USER.email`, `SPACE(building,floor,room_number)`, and `FACILITY.facility_name` are candidate keys. | Yes | None | No | Missing |
| Steps 3, 5 | `SPACE_FACILITY(space_code,facility_id)` and Phase 2 acknowledgement pair are unique. | Yes | Duplicate acknowledgement pairs only | Yes for ACK only | Partial |
| Steps 3, 5, 9, 10 | Every required FK relationship resolves, including both Phase 2 tables. | Yes | `Foreign-key orphan rows` | Yes | Covered |
| Steps 3, 5, 9, 10 | Required columns are non-NULL and nullable columns retain their documented semantics. | Yes | Selected booking-state and usage checks only | Yes where present | Partial |
| Steps 3, 5, 9, 10 | Role, account, space type/status, facility status, purpose, booking status/path, maintenance status/problem/impact, and history impact values use exact allowed domains. | Yes | Eleven distinct-cardinality coverage checks | Yes | Partial |
| Steps 3, 5 | `SPACE.capacity > 0`, `SPACE_FACILITY.quantity > 0`, and booking participants are positive. | Yes | Booking participant/capacity join only | Yes | Partial |
| Step 1 BR-1/2 | Users retain required university identity and standard user information. | Yes | User minimum, domain coverage, orphan checks | Yes | Partial |
| Step 1 BR-4/5/6 | Spaces retain unique identity, complete location/policy/capacity information, and valid statuses. | Yes | Space minimum, type/status coverage, capacity diversity | Yes | Partial |
| Step 1 BR-7; Step 3 review | Facility catalog and space-facility mapping are correct, with quantity and operational condition. | Yes | Counts, status coverage, facility-set diversity, orphans | Yes | Partial |
| Step 1 BR-8/9/10 | Booking has requester, space, requested period, purpose, participants, and valid status/purpose. | Yes | Time, capacity, coverage, orphan checks | Yes | Partial |
| Step 1 BR-19 | `expected_participants > 0` and does not exceed selected space capacity. | Yes | `Invalid booking capacity` | Yes | Covered |
| Steps 1, 3, 5 | `created_at <= requested_start < requested_end`. | Yes | `Invalid booking time order` | Yes | Covered |
| Step 12 submission | Every accepted requester is an existing Active user. | Yes for current state; action-time status is historical | Active checked only for Instant rows | Yes | Missing |
| Step 8/9/12 project policy | Instant rows use Classroom and Lecturer/TA eligibility; free-text `usage_policy` is informational under accepted Step 12 clarification. | Partly | `Invalid Instant eligibility rows` | Yes | Partial |
| Step 12 | Instant approval has no approver/note, no rejection reason, and `decision_time = created_at`. | Yes | Status/path combinations plus `Invalid Instant decision time` | Yes | Covered |
| Step 1 BR-13/14; Step 12 | Staff approval/rejection retains approver, decision time, decision note, and rejection reason when rejected. | Yes | `Invalid status/path field combinations` | Yes | Covered with upstream matrix contradiction noted |
| Step 9/12 | Resolution path persists through later lifecycle states and is write-once. | Current value yes; prior mutation no | Current combinations only; no trigger/permission/mutation test | Partial | Partial |
| Step 12 | Staff approver is Active Facility Staff/Manager at decision time. | Current status only; action-time status needs history | `Invalid staff-role references` uses current state | Yes | Partial |
| Step 1 BR-11/23; Step 12 | Only `Approved` and `Checked In` currently reserve/occupy; same-space occupying rows cannot overlap. | Yes | Overlap self-join uses four statuses | Yes | Partial |
| Step 1 overlap assumption | Half-open predicate is `start < other_end AND end > other_start`; adjacency is valid. | Yes | Correct inequality in overlap queries | Yes | Covered predicate; scenario presence weak |
| Step 1 BR-12; Step 12 | Approved/Checked-In booking cannot use a Retired or Temporarily Closed space. | Yes | None | No | Missing |
| Phase 2 P2-BR-01; Step 12 | Active (`Reported`/`In Progress`) out-of-service maintenance blocks overlapping approval. | Yes, except historical event state | `Unexplained out-of-service overlaps` omits maintenance status and uses four booking statuses | Yes | Partial |
| Phase 2 P2-BR-02 | Advisory maintenance does not block booking. | Yes by positive scenario | ACK rows exist, but no explicit approved/occupying advisory-overlap success gate | No | Missing |
| Phase 2 P2-BR-04; Step 14 | Same space can have simultaneous active maintenance records, including different impacts; generated data must demonstrate overlaps. | Yes | Multiple ACKs for one booking is only an indirect proxy | Yes, indirect | Missing |
| Step 1 BR-15; Steps 3/5 | Usage session records check-in staff, actual start, and initial condition. | Yes | Session existence and staff-role query; no full NULL audit | Partial | Partial |
| Step 1 BR-16; Steps 3/5 | Completed usage records checkout staff, actual end, final condition, usage notes, and valid time order. | Yes | Session existence and time order only | Yes | Partial |
| Step 1 lifecycle; Step 14 | Every `Completed`/`Checked In` booking has exactly one session; unsupported statuses have none. | Yes | Missing/extra usage checks; duplicate protection assumed from PK | Yes | Partial |
| Step 1 lifecycle | `Checked In` represents an open session and `Completed` a closed session. | Yes | No status-specific checkout-field predicate | No | Missing |
| Step 1 Assumption 1 | Approver, check-in/out staff, and assigned maintenance staff have Facility Staff/Manager roles. | Current role yes; action-time role no | Combined staff-reference check | Yes | Partial |
| Step 1 BR-17 | Maintenance stores required space/reporter/problem/period/status/result information and has valid completion order. | Yes | Orphans, coverage, row minimum, time order | Yes | Partial |
| Step 14 skill | Open maintenance uses approved NULL completion representation and completed maintenance has coherent completion/result data. | Yes | Time ordering only | Yes | Partial |
| Phase 2 P2-BR-03; Step 9 | ACK references the correct booking and same-space overlapping maintenance advisory. | Partly; status-at-time lacks history | `Invalid advisory acknowledgement rows` | Yes | Partial |
| Phase 2 P2-BR-03; Step 12 | ACK is recorded atomically at submission; Step 12 stores `acknowledged_at = created_at`. | Yes | Validator allows any time through requested start | Yes | Partial |
| Phase 2 P2-BR-03; Step 9/12 | Exactly one ACK exists for every applicable advisory, with no unrelated/stale ACK. | Only partly after later maintenance changes | Missing, duplicate, invalid ACK checks use current-state status/impact for completeness | Yes | Partial |
| Step 9 | ACK requester provenance derives through immutable `BOOKING.requester_id`; ACK rows are insert-only. | Enforcement metadata yes; historical mutation no | Current FK only | Partial | Missing |
| Step 9 | Impact-history event has distinct old/new values and valid domains. | Yes | Invalid history plus schema-domain presence | Yes | Covered |
| Step 9 | History chain continuity uses `(changed_at,history_id)` ordering. | Yes | `Broken impact-history chains` | Yes | Covered |
| Step 9 | Current impact equals latest history `new_impact_level`. | Yes | `Impact history/current mismatches` | Yes | Covered |
| Step 9/12 | History event occurs while record is open and actor is eligible at event time. | Not fully; no status/actor history | Period-bound proxy plus current role/status | Yes | Partial |
| Step 9 | Current impact update and history insertion are atomic; complete history has no omitted direct changes. | No from final snapshot; permissions/procedure metadata partly testable | Current mismatch only | Partial | Not applicable for atomicity; Weak for completeness |
| Phase 2 P2-BR-05; Step 14 | Both escalation and downgrade events are populated. | Yes | Escalation and downgrade event checks | Yes | Covered |
| Phase 2 P2-BR-06 | Already-approved overlapping bookings are identifiable after escalation without being auto-cancelled. | Present reconstruction only; exact event-time set lacks histories/snapshot | `Escalation-affected bookings` | Yes | Partial |
| Step 11/12 | Instant/instant, staff/staff, and mixed approvals preserve final no-overlap invariant. | Final state yes; concurrent mechanism no | Overlap self-join | Yes | Partial; concurrency proven in Step 13, not this validator |
| Step 11/12 | Approval and escalation use same per-space lock; protected procedures are sole application path. | Metadata/runtime, not row snapshot | None | No | Not applicable to row state; metadata Missing |
| Step 12 | Required triggers/procedures/type/role and DENY/GRANT policy exist; protected triggers are enabled. | Yes, metadata | Counts disabled existing triggers only | Yes | Partial |
| Step 14 skill | Minimum rows: users 400, spaces 50, facilities 10, mappings 200, maintenance 3000, bookings 100000, usage 50000, ACK 5000, history 500. | Yes | Nine minimum checks | Yes | Covered |
| Step 14 skill | All schema enum values, both paths, both impacts, all statuses/purposes/categories appear. | Yes | Eleven cardinality checks | Yes | Partial because exact sets are not proved |
| Step 14/AGENTS | At least three September-based academic years, approximately Sep-2023 through May-2026. | Yes | Academic years and min/max boundary checks | Yes | Covered minimum; meaningful per-year volume weak |
| Step 14/AGENTS | Cancellations, no-shows, Instant/Staff paths, advisory ACKs, escalation history, and usage sessions are materially represented. | Yes | Presence/count checks | Yes | Partial because most category sizes have no lower bound |
| Step 14/AGENTS | Meaningful semester, weekday/hour, space, capacity, facility, and selectivity variation supports tuning. | Yes | Buildings/capacities/facility sets/weekdays/hours | Yes | Partial |
| Phase 2 report 1 | Approved booking hours by space has nontrivial data in each tested semester. | Yes | General status/space/year reports only | No | Partial |
| Phase 2 report 2 | Approved booking count by weekday/hour has meaningful approved-row variation. | Yes | Weekday/hour gate uses all bookings | Yes | Partial |
| Phase 2 room finder | Data supports capacity, all required usable facilities, time availability, OOS exclusion, and advisory discoverability with positive/negative cases. | Yes | Capacity/facility diversity and separate general integrity checks | Yes | Partial |
| Phase 2 report 4 | Escalation report returns meaningful affected bookings and requester provenance. | Partly | Nonzero reconstructed affected booking count and FK checks | Yes | Partial |
| Step 15 handoff | Conflict check, room finder, and one report have selective and non-selective parameter cases on the large dataset. | Yes | Broad diversity thresholds only | Yes | Partial |
| Step 1 BR-21 | Cancellation came only from Pending/Approved and cancelled history is preserved. | No from final row without status/deletion history | Current cancelled shape only | Partial | Not applicable for source transition/preservation proof |
| Step 1 BR-22; Step 12 | Requester, space, and requested period are immutable after submission. | No from final snapshot; trigger metadata testable | None | No | Not applicable for past mutation; metadata Missing |
| Step 9 | ACK and resolution-path immutability consequences remain historically trustworthy. | No without before-values/audit history; permission metadata testable | None | No | Not applicable historically; metadata Missing |

## 3. Missing or Incomplete Validation Coverage

The mandatory independent gap-discovery pass found the following 35 gaps. Rows classified `Not persisted-data testable` are limitations the validator must disclose rather than claim to prove.

| ID | Source | Missing / Partial Requirement | Current Validator Coverage | Gap Type | Recommended Check | Severity |
| --- | --- | --- | --- | --- | --- | --- |
| GAP-01 | Steps 5/10 | Exact final schema metadata exists | Only `BOOKING` existence; later references fail indirectly | Partial | Validate all tables, columns, types, nullability, identities, and named keys | Major |
| GAP-02 | Steps 5/10/12 | Required constraints, triggers, procedures, type, role, and permissions exist and are enabled/trusted | Only disabled existing triggers counted | Missing | Query `sys.*` and `sys.database_permissions`; fail on absent, disabled, or untrusted objects | Major |
| GAP-03 | Steps 3/5/9 | Every PK/composite key is unique | No independent duplicate audit | Missing | Group every entity/composite key and require zero duplicates | Major |
| GAP-04 | Steps 3/5 | Email, location triple, and facility-name candidate keys are unique | None | Missing | Add duplicate queries for all alternate keys | Major |
| GAP-05 | Steps 3/5/9 | Complete required/nullable field semantics | Selected booking fields only | Partial | Audit every required column and lifecycle-dependent nullable group | Major |
| GAP-06 | Steps 5/10 | Exact allowed domain sets | `COUNT(DISTINCT)=N` proxies | Weak | Anti-join actual values to explicit allowed sets and separately test coverage | Major |
| GAP-07 | Steps 3/5 | Positive space capacity and facility quantity for all rows | Booking capacity catches booked spaces only | Missing | Directly count `SPACE.capacity<=0` and `SPACE_FACILITY.quantity<=0` | Major |
| GAP-08 | Step 12 | Every booking requester is Active under the generated submission contract | Only Instant requesters checked | Missing | Join every booking to requester and require current generated requester Active | Major |
| GAP-09 | Steps 9/12 | Complete seven-status resolution/provenance matrix | Validator invents a matrix beyond incomplete/contradictory Step 9 text | Partial | First obtain accepted operation-specific matrix, then encode it exactly | Major |
| GAP-10 | Step 1 no-show semantics | Decision chronology must not reject valid post-start no-show decisions | Global `decision_time<=requested_start` | Weak | Use status-specific chronology; do not impose unsupported upper bound | Major |
| GAP-11 | Step 12/historical actors | Action-time actor eligibility | Requires current Active status for every historical actor | Weak | Limit snapshot assertion to current role or add actor-status history; disclose limitation | Major |
| GAP-12 | Step 1 BR-12; Step 12 | No Approved/Checked-In booking on Retired/Temporarily Closed space | None | Missing | Booking-space join using authoritative occupying statuses | Major |
| GAP-13 | Step 1 BR-23; Step 12 | Same-space conflict uses only current occupying statuses | Includes Completed and No-Show | Partial | Use `Approved`,`Checked In`; report historical categories separately | Blocking |
| GAP-14 | Phase 2 OOS; Step 12 | Only active OOS blocks, with authoritative occupying statuses | Omits maintenance status and uses four booking statuses | Partial | Filter `Reported`/`In Progress` and `Approved`/`Checked In` | Blocking |
| GAP-15 | Phase 2 escalation | Only the relevant escalation explains an intentional OOS overlap | Any later escalation event suffices | Weak | Reconstruct latest event sequence/interval where possible; disclose period-history limitation | Major |
| GAP-16 | Phase 2 Advisory | Dataset proves advisory does not block approval | ACK existence does not require an approved overlap | Missing | Require at least one Approved/Checked-In advisory-overlap with valid ACK | Major |
| GAP-17 | Step 1/14 usage | Exactly one usage session per required booking | Existence relies on unverified PK for uniqueness | Partial | Verify PK and independently group `USAGESESSION.booking_id` | Major |
| GAP-18 | Step 1 BR-16 | Completed session has end, checkout staff, final condition, and notes | Only row existence/time order | Partial | Add Completed-to-session field completeness predicate | Major |
| GAP-19 | Step 1 lifecycle | Checked-In row is still open, Completed row is closed | None | Missing | Add status-specific checkout null/non-null consistency | Major |
| GAP-20 | Step 9/12 ACK | ACK occurs in booking submission transaction | Allows creation through requested start | Partial | Require `acknowledged_at=created_at` for Step 12-generated rows | Major |
| GAP-21 | Phase 2/Step 9 ACK | Exact booking-time advisory set is complete | Uses current maintenance status/impact | Partial | Reconstruct impact at `created_at`; disclose unprovable status/record-existence history | Major |
| GAP-22 | Step 9 ACK/history | Deterministic impact-at-ACK tie handling | Orders only by `changed_at` | Partial | Order all history windows by `changed_at,history_id` | Major |
| GAP-23 | Step 9/12 ACK | ACK insert-only and requester provenance protected | Current FK only | Missing | Verify DENY permissions and booking-fact immutability trigger; mutation test when safe | Major |
| GAP-24 | Step 9 history | History event occurred while maintenance was open | Uses start/completion bounds as proxy | Partial | Disclose non-testability without maintenance-status history; validate only supported chronology | Major |
| GAP-25 | Step 9 history | First/original state and every change are retained | Later chain/current state only | Weak | Store original impact or immutable full event stream; validator cannot infer omitted direct changes | Major |
| GAP-26 | Phase 2 report 4 | Exact affected set as of escalation | Uses current booking status and maintenance period | Weak | Persist affected set/status/period snapshots or label result current reconstruction only | Major |
| GAP-27 | Phase 2/Step 14 | Overlapping active same-space maintenance, including mixed impacts | Multiple-ACK proxy only | Missing | Self-join maintenance on same space with half-open overlap and required status/impact cases | Major |
| GAP-28 | Step 14 | Meaningful population in each academic year/semester | Endpoint outliers can satisfy checks | Weak | Require documented minimum per academic year and semester | Major |
| GAP-29 | Phase 2 report 2 | Weekday/hour variation among report-eligible approved rows | Uses every booking status | Partial | Restrict variation checks to the approved-report status definition | Major |
| GAP-30 | Phase 2 room finder | Positive/negative all-facility, capacity, availability, OOS, and advisory cases | Facility-ID sets and capacity counts only | Partial | Execute representative room-finder predicates and assert cardinality ranges | Major |
| GAP-31 | Step 14 distributions | Required categories are materially represented | Presence only for most categories | Weak | Add justified minimums/ratio bands for paths, statuses, impacts, spaces, and maintenance | Major |
| GAP-32 | Half-open boundary | Dataset demonstrates valid adjacency | Predicate allows adjacency but no scenario gate | Weak | Require at least one same-space adjacent occupying pair or retain Step 13 as explicit evidence | Minor |
| GAP-33 | Step 14 maintenance lifecycle | Open/completed status, completion time, and result fields are coherent | Time order only | Partial | Add status-specific completion/result predicates based on approved lifecycle | Major |
| GAP-34 | Existing checks | Repeated schema-backed role/domain predicates consume checks while exact contract is omitted | Staff role and Instant null checks overlap; domains repeat CHECK intent weakly | Duplicate/Redundant | Consolidate after exact-set and metadata checks exist | Minor |
| GAP-35 | Snapshot limitations | Cancellation origin, historical immutability, action-time user state, atomicity, and exact escalation history are presented near current-state proxies | No explicit limitation report | Not persisted-data testable | Label these as runtime/history-dependent and do not claim snapshot proof | Major |

**Missing/Partial count:** 24 rows (`GAP-01` to `GAP-05`, `GAP-07` to `GAP-09`, `GAP-12` to `GAP-14`, `GAP-16` to `GAP-24`, `GAP-27`, `GAP-29`, `GAP-30`, and `GAP-33`).

**Additional gap-discovery count:** 35 total gaps, including 24 Missing/Partial, 9 Weak, 1 Duplicate/Redundant, and 1 explicit non-persisted-data-testable group.

## 3. Check Count Audit

Counting method: one check is one distinct persisted predicate represented by one named `#Checks` row. Multi-row `INSERT #Checks VALUES` statements are counted by tuples. Headings, variable declarations, repeated scalar subqueries, detailed check display, aggregate summary, and informational distribution queries are not additional checks.

| Category | Count | Notes |
| --- | ---: | --- |
| Distinct validation checks | 53 | 53 unique `check_name` literals |
| Aggregate-controlled checks | 53 | Every named check is inserted into `#Checks` |
| Standalone PASS/FAIL checks | 0 | No PASS/FAIL result exists outside `#Checks` |
| Informational result sets | 9 | Lines 578-586: booking summary, status, path, year, weekday/hour, space, maintenance, ACK, trigger inventory |
| Checks capable of failing the script | 53 | Any `result='FAIL'` reaches final `THROW 51402` |
| Checks that can display FAIL while script succeeds | 0 | Assuming normal SQL Server `THROW`/`sqlcmd -b` behavior |

Check-group reconciliation:

| Group | Checks |
| --- | ---: |
| Volume/date minima | 12 |
| Domain/category coverage | 11 |
| Booking chronology/state/provenance | 7 |
| Booking overlap | 1 |
| Usage sessions | 3 |
| Advisory acknowledgements | 4 |
| Maintenance/history | 6 |
| OOS/escalation | 2 |
| FK orphan aggregate | 1 |
| Step 15 diversity/trigger state | 6 |
| **Total** | **53** |

## 4. Aggregate Control-Flow Review

The actual control path is:

```text
database COUNT/EXISTS/self-join predicate
-> scalar BIGINT or direct scalar subquery
-> named PASS/FAIL row inserted into #Checks
-> detail SELECT from #Checks
-> overall_result and pass/fail totals derived from #Checks
-> IF EXISTS (#Checks result='FAIL')
-> THROW 51402
-> sqlcmd -b returns nonzero
```

Strengths:

- All 53 current checks enter `#Checks`.
- The summary uses `EXISTS` and `SUM` over current rows, not a hardcoded expected check total.
- A newly inserted `#Checks` row automatically participates in the summary and final failure gate.
- The nine later informational queries execute before the final throw but do not overwrite `#Checks`, clear the failure state, or catch the error.
- No `TRY...CATCH` masks `THROW 51402`.
- No standalone PASS/FAIL check can disagree with aggregate PASS because none exists.

Limitations:

- `check_name` is not unique, so a future duplicate name is possible, although current names are distinct.
- Several variables combine multiple relationships or conditions into one total, reducing diagnostics.
- Aggregate correctness cannot compensate for a missing or incorrect persisted predicate. The present aggregate can reliably fail on the checks it has while still returning PASS for states outside those predicates.

## 5. Predicate Quality Review

### Booking Overlap

The interval inequalities are correct and half-open:

```sql
b1.requested_start < b2.requested_end
AND b1.requested_end > b2.requested_start
```

They allow adjacency. The status set is wrong for the latest protected availability contract. Phase 1 BR-23 and Step 12 use `Approved` and `Checked In`; the validator also includes `Completed` and `No-Show`. This can reject valid historical data and conflates “previously approved lifecycle” with “currently reserving or occupying.”

### Instant Provenance

The dedicated predicate correctly rejects every Instant row where `decision_time IS NULL OR decision_time <> created_at`, and it is aggregate-controlled. The status/path predicate also enforces NULL approver, NULL note, no Pending/Rejected Instant row, and valid Classroom/Lecturer/TA/current-Active data under the Step 12 project policy.

The limitation is upstream authority: the original Phase 2 requirement did not define Classroom/Lecturer/TA eligibility, and current review history records that policy as a project decision rather than a confirmed requirement. The validator should label it accordingly.

### Staff Provenance

The staff state predicate generally preserves actor/time/note data through approved lifecycle statuses and rejection. Its global decision chronology is incorrect: `decision_time > requested_start` is treated as invalid even though a `No-Show` decision is naturally recorded after start and the approved Phase 1 sample demonstrates that. The combined role predicate also substitutes current account status for action-time status and applies “Active” to check-in/out and assigned-maintenance references without a clear preserved action-time contract.

### Advisory Acknowledgement

Same-space and half-open maintenance-period linkage are checked. Impact is reconstructed through history, but the CTE omits the required `history_id` tie-breaker. The timestamp range permits acknowledgement any time between creation and requested start, whereas Step 12 writes ACKs in the submission transaction with `acknowledged_at = created_at`.

The missing-ACK predicate is materially wrong for historical completeness because it uses current maintenance status and current impact. It can miss an advisory that was applicable at submission and later resolved/escalated, or demand an ACK for a record that became applicable only later. Maintenance-status history, maintenance-record creation time, and period snapshots do not exist, so exact historical completeness cannot be reconstructed after arbitrary changes. The review must not describe the current query as proof of the full booking-time ACK contract.

### Maintenance History

Distinct transitions, later chain continuity, tie ordering for the chain, current-state reconciliation, role reference, and escalation/downgrade presence are useful. The “open record” predicate is only a period-bound proxy; it cannot prove event-time `Reported`/`In Progress` status. It also rejects an open scheduled record escalated before physical `start_time`, which the requirement does not prohibit. Original impact and omitted direct changes cannot be proven because no immutable initial-impact event is stored.

### Out-of-Service and Escalation

`@UnexplainedOosOverlap` omits `maintenance_status IN ('Reported','In Progress')` and uses the stale four-status booking set. It can reject valid overlaps with resolved/cancelled maintenance and historical Completed/No-Show rows. Conversely, any advisory-to-OOS event after `decision_time` explains the overlap even if later downgrade/re-escalation or period edits make that event irrelevant.

`@EscalationAffected` proves only a nonempty current reconstruction. It cannot prove “approved at event time” or the exact affected set because booking-status history, maintenance-period history, and an affected-booking snapshot are absent.

### Null Semantics

The explicit Instant predicate safely handles NULL. Several other checks rely on inner joins, current state, or schema non-nullability rather than independently finding NULL defects. The validator lacks a complete required-column audit. It also does not use null-safe comparisons for every provenance matrix transition because it validates only final values, not old-to-new changes.

## 6. False-PASS / False-FAIL Risks

### False PASS

| Risk | Concrete invalid state that can still yield aggregate PASS |
| --- | --- |
| Incomplete completion | `Completed` booking has a `USAGESESSION`, but `actual_end`, checkout staff, final condition, and notes are all NULL. |
| Unavailable space | `Approved` booking references a Retired space and has no overlap/OOS defect. |
| Late ACK | ACK is inserted a week after `created_at` but before `requested_start`. |
| Missing historical ACK | Advisory applicable at submission is later Resolved or escalated; omitted ACK is invisible to current-state `@MissingAck`. |
| Trigger absence | Required protected trigger is dropped; disabled-trigger count remains zero. |
| Invalid domain replacement | CHECK is absent and one expected status is replaced by an illegal value while distinct count remains seven. |
| No maintenance overlap scenario | Maintenance periods never overlap; multiple ACKs can still arise from disjoint advisories within one long booking. |
| Weak path distribution | One Instant row and 99,999+ Staff rows satisfy path coverage. |
| Broken room-finder workload | Eight facility-ID combinations exist but all requested facilities are Broken; diversity still passes. |
| Incomplete history | A direct impact change omitted from history still leaves a syntactically valid later chain/current state. |

### False FAIL

| Risk | Concrete valid state rejected by current predicate |
| --- | --- |
| Historical overlap | Two `Completed` rows overlap, although Completed does not block current availability. |
| No-show timing | No-show is recorded 30 minutes after requested start; global decision chronology fails. |
| Resolved OOS | A booking overlaps old Resolved out-of-service maintenance; maintenance-status omission fails it. |
| Actor lifecycle | Historical approver later becomes Inactive; current-state staff reference check fails. |
| Scheduled escalation | Open Reported maintenance is escalated before physical `start_time`; history predicate fails it. |
| Later advisory | Advisory is created after booking submission but overlaps its future period; current missing-ACK query requires impossible prior acknowledgement. |
| History timestamp tie | Equal-time impact changes use valid `history_id` order, but ACK reconstruction orders only by time and may classify nondeterministically. |
| Non-rejected reason | An informational residual reason remains on a non-Rejected row; Phase 1 requires reasons on rejection but does not explicitly prohibit all residual values. |

## 7. Step 15 Readiness Coverage

The validator establishes useful broad evidence: at least 100,000 bookings; three academic-year keys and configured endpoints; table minima; every category represented; multiple buildings, capacities, facility-ID combinations, weekdays, and hours; both impacts/paths; ACK/history volume; and zero conflicts under its current overbroad four-status predicate.

It does not sufficiently establish Step 15 readiness:

- Academic-year and endpoint checks can pass with only outlier rows outside one dominant year.
- Weekday/hour variation is measured across all statuses, not report-eligible approved rows.
- Facility-set diversity ignores operation status and does not prove all-required-facility positive/negative room-finder cases.
- No representative room-finder cardinality is asserted.
- No report-specific semester workload is asserted.
- No mixed-impact overlapping active-maintenance scenario is directly proved.
- Presence checks permit trivial Instant, advisory, or category populations.
- Zero “approved-lifecycle” overlap uses a stale status set and therefore is not a trustworthy protected-invariant result.

The dataset may in fact be useful, but this validator does not prove enough operation-specific selectivity or complete correctness to authorize Step 15 tuning without relying on generator behavior and prior runtime claims.

## 8. Runtime Evidence

Runtime execution was not performed. No verified disposable review database name was explicitly supplied with this command. The protected `University` database was not accessed or mutated.

Existing repository transcripts and earlier Step 14 reviews were read as historical review context only. They were not represented as runtime evidence produced by this review. The current static count is 53 checks; stale references to 49 checks do not describe the current validator.

## 9. Issues Found

### Issue R14VAL-1 — Broad persisted-data contract is not independently validated

- **Severity:** Blocking
- **Issue:** Exact domains, most keys/candidate keys, complete required/null semantics, all numeric constraints, and final schema/enforcement metadata are missing or only indirectly checked.
- **Evidence:** Domain gates use cardinalities at validator lines 44-59; only ACK duplicate pairs are checked; `BOOKING` is the only explicit prerequisite object; no trusted constraint inventory exists.
- **Why this matters:** A database with dropped constraints, illegal replacement domain values, duplicate candidate keys, invalid unbooked-space capacity, or missing protected objects can produce aggregate PASS.
- **Impact on Step 15:** Query plans and result correctness cannot be trusted against a dataset whose complete relational contract has not been proved.
- **Suggested correction:** Add exact-set, duplicate, complete NULL/numeric, and metadata trust/existence checks, all routed through `#Checks`.

### Issue R14VAL-2 — Conflict and Out-of-Service predicates use stale status semantics

- **Severity:** Blocking
- **Issue:** The validator treats `Completed` and `No-Show` as currently blocking and treats all OOS maintenance statuses as blocking.
- **Evidence:** Validator lines 146-149 and 365-367 versus Phase 1 BR-23 and Step 12 predicates using `Approved`/`Checked In` and open maintenance only.
- **Why this matters:** Valid historical data can fail, while the check no longer proves the exact invariant enforced by Step 12.
- **Impact on Step 15:** Conflict-query and room-finder baselines can be validated against the wrong result set.
- **Suggested correction:** Use operation-specific authoritative status sets and active maintenance statuses; separate historical lifecycle reporting from current occupancy.

### Issue R14VAL-3 — Booking-time acknowledgement contract is only current-state approximated

- **Severity:** Major
- **Issue:** ACK timing is too permissive, impact tie ordering is incomplete, and missing ACKs are derived from current status/impact instead of submission-time facts.
- **Evidence:** Validator lines 183-193, 285-287, and 298-307; Step 12 inserts ACKs at `created_at` in the submission transaction.
- **Why this matters:** Late, stale, or omitted booking-time disclosure evidence can pass; later valid maintenance changes can also cause false failure.
- **Impact on Step 15:** Advisory and room-finder workloads may rest on untrustworthy audit relationships.
- **Suggested correction:** Require Step 12 timestamp equality, fix tie ordering, reconstruct only what stored history supports, and explicitly disclose the unprovable status/period-history remainder.

### Issue R14VAL-4 — Usage and booking lifecycle validation is incomplete

- **Severity:** Major
- **Issue:** Completed checkout fields and Checked-In open-session semantics are not checked; exact one-to-one relies on an unverified PK; the full resolution matrix remains upstream-inconsistent.
- **Evidence:** Validator lines 153-168 only require a row and valid non-NULL end ordering.
- **Why this matters:** Contradictory lifecycle states can pass while valid states may be rejected by invented matrix details.
- **Impact on Step 15:** Approved-hours and usage analyses can return incorrect or misleading results.
- **Suggested correction:** Add status-specific session predicates and align the booking matrix with an explicitly accepted upstream decision.

### Issue R14VAL-5 — Maintenance history and escalation evidence overclaim historical proof

- **Severity:** Major
- **Issue:** Open-at-event, original impact, complete event retention, and exact affected-booking state cannot be reconstructed from current rows.
- **Evidence:** Validator lines 317-390; schema lacks maintenance-status/period history, booking-status history, and affected-booking snapshots.
- **Why this matters:** A syntactically coherent history can still be incomplete or historically false.
- **Impact on Step 15:** Escalation-report tuning may benchmark a current reconstruction rather than the required event-time result.
- **Suggested correction:** Label non-testable semantics, validate only supported facts, or extend future design with immutable snapshots/history before claiming historical proof.

### Issue R14VAL-6 — Active requester and unavailable-space rules are omitted

- **Severity:** Major
- **Issue:** Staff-path requesters are not checked as Active and occupying bookings are not checked against Retired/Temporarily Closed spaces.
- **Evidence:** Active requester appears only in Instant eligibility at lines 78-86; no booking-space status predicate exists.
- **Why this matters:** Meaningful invalid persisted bookings can pass aggregate validation.
- **Impact on Step 15:** Room finder and availability tuning may use invalid reservations.
- **Suggested correction:** Add aggregate-controlled requester and unavailable-space checks using the approved status set.

### Issue R14VAL-7 — Step 15 workload readiness is inferred from shallow diversity

- **Severity:** Major
- **Issue:** Broad distinct counts do not prove report-eligible semester/weekday/hour populations, functional facility combinations, mixed-impact overlaps, or selective room-finder cases.
- **Evidence:** Validator lines 548-570 and informational queries 578-586.
- **Why this matters:** All integrity checks can pass while required analytical operations are empty, trivial, or non-selective.
- **Impact on Step 15:** Before/after index comparisons may be meaningless.
- **Suggested correction:** Add report-specific cardinality checks and representative room-finder positive/negative cases with documented thresholds.

### Issue R14VAL-8 — Protected workflow and immutability metadata are not verified

- **Severity:** Major
- **Issue:** The validator passes when required triggers are absent and does not inspect procedures, TVP type, role, permissions, or immutable-field protection.
- **Evidence:** `@DisabledTriggers` counts only rows that exist with `is_disabled=1`.
- **Why this matters:** Generator trigger restoration and Step 12 protected-path assumptions are not actually proved.
- **Impact on Step 15:** Later test/tuning operations may run against a database no longer matching the approved implementation.
- **Suggested correction:** Validate exact object inventory, definitions or signatures where practical, enabled state, and effective DENY/GRANT metadata.

### Issue R14VAL-9 — Chronology and current-user predicates can reject valid history

- **Severity:** Major
- **Issue:** All decision times must precede requested start, and all historical actors must still be Active today.
- **Evidence:** Validator lines 61-63 and 99-118; Phase 1 no-show semantics allow a post-start decision.
- **Why this matters:** The validator confuses action-time facts with current master-data state and imposes an unsupported global upper bound.
- **Impact on Step 15:** A valid historical dataset may be rejected or distorted to satisfy the validator.
- **Suggested correction:** Use status-specific chronology and avoid action-time assertions that cannot be reconstructed without user history.

## 10. Quality Score

| Category | Score / 10 | Reason |
| --- | ---: | --- |
| Upstream requirement coverage | 4 | 24 Missing/Partial contract units remain |
| Predicate correctness | 4 | Critical overlap, OOS, ACK, chronology, and history predicates are incomplete or wrong |
| Aggregate failure control | 10 | All 53 checks control the final throw |
| Validator independence | 5 | Many database predicates are direct, but several rely on schema/generator assumptions or current-state proxies |
| False-PASS resistance | 4 | Multiple meaningful invalid states can still yield PASS |
| False-FAIL resistance | 3 | Stale status sets and unsupported chronology/current-user assertions reject valid history |
| Maintainability | 7 | Clear labels and one aggregate table, but large repeated scalar SQL and combined totals reduce diagnostics |
| Step 15 readiness evidence | 5 | Volume and broad diversity are shown; operation-specific workload quality is not |

**Overall score: 5.3 / 10**

## 11. Final Verdict

**Validator not ready**

The current script can detect many useful defects and will reliably return a nonzero `sqlcmd -b` exit when any of its 53 aggregate-controlled checks fails. It does not cover the complete persisted-data contract, however, and several load-bearing predicates can produce both false PASS and false FAIL outcomes. The validator therefore cannot be trusted as the independent authorization gate for Step 15 in its current form.
