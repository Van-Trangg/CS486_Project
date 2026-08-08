# Step 9 Review Issues

## Issue R09-1 - Unconfirmed instant-approval policy is presented as a requirement

- **Severity:** Blocking
- **Issue:** Step 9 treats Classroom-only, Lecturer/Teaching Assistant-only instant approval and write-once `resolution_path` behavior as confirmed Phase 2 requirements.
- **Evidence:** The authoritative Phase 2 requirement states only that requests for "selected space types" may be approved automatically when they satisfy usage policy (`req/business-requirement-phase2.md`, line 22). It does not identify Classroom, restrict requester roles, require a stored path, or require path immutability. Step 8 now labels the detailed eligibility policy as a project assumption at line 8, but C08-06 and P2-BR-10/P2-BR-11 at lines 18 and 63-64 incorrectly cite it as a Phase 2 requirement. Step 9 repeats those claims at lines 16 and 56-62. The approved Step 8 review explicitly records automatic-approval eligibility as unresolved (`docs/08-requirement-change-analysis-review-G02.md`, lines 7 and 73).
- **Why this matters:** The design can automatically approve or reject the wrong users and spaces while claiming unsupported policy has stakeholder authority.
- **Downstream impact:** Step 10 would encode unapproved path constraints, and Steps 11-14 would implement and test an invented eligibility rule.
- **Required correction:** Reclassify the Classroom, requester-role, and path-immutability rules as explicit unconfirmed project assumptions, or remove them until an authoritative requirement amendment confirms them. Do not cite them as Phase 2 BRA requirements.

## Issue R09-2 - Automatic eligibility is not machine-evaluable from the model

- **Severity:** Blocking
- **Issue:** Step 9 says automatic approval evaluates selected space type and `SPACE.usage_policy`, but it provides no structured representation of selected types or executable policy conditions.
- **Evidence:** Step 9 lines 56-60 retain `SPACE.usage_policy` as unrestricted Phase 1 free text and hard-code Classroom eligibility in prose. The logical schema contains neither an instant-eligible type/configuration relation nor structured policy predicates. The review skill requires structured rules when later evaluation is required and asks whether automatic approval can be evaluated from the design.
- **Why this matters:** Free text cannot deterministically decide `resolution_path = 'Instant'`; Step 10 or Step 12 would have to invent policy syntax, configuration, and evaluation behavior.
- **Downstream impact:** Submission, concurrency, testing, and generated instant-approval cases cannot be validated against one implementable rule.
- **Required correction:** Define a machine-evaluable representation for selected space types and applicable usage-policy conditions, or explicitly define a bounded set of executable predicates and their configuration authority.

## Issue R09-3 - Booking resolution matrix remains incomplete and contradicts Phase 1

- **Severity:** Blocking
- **Issue:** The matrix claims to define every valid path/status combination but covers only `Pending`, `Approved`, and `Rejected`, then declares `Cancelled`, `Checked In`, `Completed`, and `No-Show` unconstrained. It also makes `decision_note` optional for staff approval and rejection.
- **Evidence:** Step 9 lines 318-329. Rows 326-327 mark staff `decision_note` optional, while the approved Phase 1 rule requires approval or rejection to record the decision actor, time, and note (`outputs/01-business-req-analysis-G02.md`, lines 243-246). Line 329 first says any other combination is invalid and then says later lifecycle statuses are unconstrained.
- **Why this matters:** Step 10 cannot derive valid cross-column constraints for all seven statuses, and the design permits staff decisions that violate the approved Phase 1 audit rule.
- **Downstream impact:** Approval procedures, cancellation/check-in transitions, validation data, conflict predicates, and reports can apply incompatible status/path semantics.
- **Required correction:** Define valid `resolution_path`, status, approver, decision-time, decision-note, and rejection-reason combinations for all seven statuses; require staff decision notes; and define how decision provenance persists through cancellation, check-in, completion, and no-show transitions.

## Issue R09-4 - Acknowledgement requester provenance relies on an unsupported assumption

- **Severity:** Major
- **Issue:** Step 9 derives the acknowledged requester through `BOOKING.requester_id` while merely assuming that column is immutable.
- **Evidence:** Step 9 line 282 explicitly states the assumption and says the design must be revisited if it is false. Phase 1 only prevents changing an approved booking's space and requested period (`outputs/01-business-req-analysis-G02.md`, line 258; `outputs/05-db-definition-G02.sql`, lines 498-524); it does not make `requester_id` write-once.
- **Why this matters:** A later requester change would attribute an immutable acknowledgement to a user who did not receive the advisory.
- **Downstream impact:** Step 10/12 must invent either requester immutability or an acknowledgement actor snapshot before the audit record is trustworthy.
- **Required correction:** Make `BOOKING.requester_id` explicitly immutable from insertion, or add an immutable acknowledged-requester FK to `BOOKING_ADVISORY_ACK`.

## Issue R09-5 - Historical escalation-report semantics are unresolved

- **Severity:** Major
- **Issue:** The impact-history model records the change event but does not establish whether affected bookings are identified immediately at escalation or reconstructed historically later.
- **Evidence:** Step 9 lines 24-28 claim complete impact history directly supports Report 4, while lines 284-308 store only impact transitions. No booking-status history, affected-booking snapshot, or maintenance-period snapshot is retained. Supporting Query 4 uses current booking status and the current maintenance period (`outputs/16-analytical-queries-G02.sql`, lines 228-238 and 264-320).
- **Why this matters:** Later cancellation, completion, no-show transition, or maintenance-period edits can change the reported affected set and prevent reconstruction of which bookings were approved when escalation occurred.
- **Downstream impact:** Steps 10, 12, 14, and 16 can implement different meanings of the required escalation report.
- **Required correction:** Choose and document immediate-at-escalation versus historical-as-of-event semantics. If historical reconstruction is required, preserve the affected booking set or sufficient booking-status and maintenance-period history.

## Issue R09-6 - Analytical status and semester semantics remain undefined

- **Severity:** Major
- **Issue:** Step 9 does not define which lifecycle statuses count as "approved bookings" for conflict checks and each report, or how bookings crossing semester boundaries contribute hours. The weekday/hour interpretation also remains unresolved rather than visibly handed off in Step 9.
- **Evidence:** Step 9 Decision 4 defines only semester start/end parameters (lines 44-48). Supporting artifacts already diverge: Query 1 uses `Approved`, `Checked In`, and `Completed`; room finder and Query 4 use only `Approved`; the generator validator additionally treats `No-Show` as approved lifecycle (`outputs/16-analytical-queries-G02.sql`, lines 45, 78, 186, and 319; `outputs/14-data-generator-G02/02-validate-data.sql`, lines 74-84).
- **Why this matters:** The same booking can be included in one required operation and excluded from another without an approved design rule.
- **Downstream impact:** Steps 14-16 cannot generate, query, validate, or tune one stable reporting contract.
- **Required correction:** Define authoritative operation-specific status sets, semester inclusion/clipping behavior, and the explicit Step 16 handoff for start-hour versus occupied-hour counting.

## Issue R09-7 - Current downstream artifacts are incompatible with the revised schema contract

- **Severity:** Major
- **Issue:** Step 9 now specifies `resolution_path` and no `row_version`, but existing downstream artifacts target a different schema.
- **Evidence:** Step 9 lines 14 and 38-42. Step 10 uses `resolution_path` but still adds `row_version` (lines 68-93). Steps 11, 12, 13, 14, and Query 4 still reference `approval_path`; the generator also requires `row_version`. These files are supporting evidence of contract mismatch, not authority for redefining Step 9.
- **Why this matters:** The procedures, tests, generator, and analytical query cannot all compile against the current Step 9 design.
- **Downstream impact:** Steps 10-16 are not currently ready as an integrated sequence.
- **Required correction:** Finalize the Step 9 column contract, describe `resolution_path` as a Phase 2 addition rather than a rename from a nonexistent Phase 1 column, then align all downstream artifacts after Step 9 is approved.

# Final Verdict

**NOT READY FOR STEP 10**

Step 9 preserves the approved Phase 1 entities, keys, relationships, cardinalities, stable `SPACE.space_code` resource, maintenance impact domain, and the core acknowledgement/history structures. However, the three blocking and four major issues above require Step 10 to invent or encode unsupported policy and leave Steps 10-16 without a consistent implementable contract.
