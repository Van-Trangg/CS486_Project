## Issue R09-2 - Booking resolution state model is contradictory and incomplete

- **Severity:** Blocking
- **Issue:** `resolution_path NOT NULL DEFAULT 'Staff'` assigns a value at insert, while Step 9 also says staff rows may first receive it at decision time and that it is immutable. Conditional relationships among path, status, approver, decision time, decision note, and rejection reason are not specified.
- **Evidence:** Step 9 lines 38-40, 64-66, 243-248, and 311-313. Phase 1 requires staff approval/rejection to record actor, time, and note (`outputs/01-business-req-analysis-G02.md`, lines 243-246), but the updated schema keeps these columns nullable without a conditional state matrix.
- **Why this matters:** Valid staff decisions can be missing audit data, invalid instant decisions can carry staff approvers, and pending/default/write-once behavior has two incompatible interpretations.
- **Downstream impact:** Step 10 cannot define constraints or backfill semantics without guessing; Step 12 and the generator have already invented their own combinations.
- **Suggested correction:** Define path assignment timing and a complete status/path/decision-field matrix. Preserve Phase 1 staff decision audit requirements and distinguish confirmed rules from assumptions where Phase 2 is silent.

## Issue R09-3 - Advisory acknowledgement integrity contract is incomplete

- **Severity:** Major
- **Issue:** The acknowledgement table guarantees only references, timestamp presence, and pair uniqueness; it does not define enforcement of applicability, completeness, or audit immutability.
- **Evidence:** Step 9 lines 271-284. Decision 6 at lines 55-59 defines active advisory selection but does not state that every stored row and every booking transaction must satisfy the same-space, overlap, active-status, impact-at-time, and exactly-once rules.
- **Why this matters:** A database can contain an acknowledgement for an out-of-service, resolved, non-overlapping, or different-space record, or omit one of several applicable advisories while satisfying all listed table constraints.
- **Downstream impact:** Step 10/12 must invent cross-table validation and submission-transaction behavior; generated audit evidence cannot be trusted from schema validity alone.
- **Suggested correction:** Add explicit acknowledgement invariants and assign them to one atomic booking-submission workflow. State whether acknowledgement rows are immutable/non-deletable audit records and that requester identity is derived from the immutable booking requester or stored separately if requester changes are allowed.

## Issue R09-4 - Impact history lacks transition and current-state integrity

- **Severity:** Major
- **Issue:** The selected complete-history model lacks the rules that make its events a valid chronological state history.
- **Evidence:** Step 9 lines 286-301 define only PK, FKs, and old/new value-domain checks. No rule requires an open maintenance status, different old/new values, chain continuity, latest-event/current-state agreement, or atomic update plus history insertion.
- **Why this matters:** The history can claim impossible transitions or disagree with current maintenance impact, undermining escalation reporting and auditability.
- **Downstream impact:** Step 12 implements only escalation and invents actor/open-state checks; Step 14's validator independently invents broken-chain and current-state reconciliation rules.
- **Suggested correction:** Define transition validity, ordering/tie handling, actor eligibility if required, open-record eligibility, atomic current-state/history update, current-state reconciliation, and both escalation and downgrade workflows.

## Issue R09-5 - `row_version` is an unsupported and misleading concurrency addition

- **Severity:** Major
- **Issue:** Step 9 adds an implementation-specific `ROWVERSION` to the conceptual ERD and says it enables atomic conflict detection, although the required conflict is a phantom across different rows.
- **Evidence:** Step 9 lines 14, 43-47, 107-124, 248, 305-307, and 325. Step 8 lines 70-74 and 87-93 require atomic protection but defer mechanism choice. Step 11 lines 17 and 30 explicitly state that row versioning does not solve this race.
- **Why this matters:** It misstates concurrency readiness and introduces physical implementation detail into the conceptual ERD without a separate lost-update requirement.
- **Downstream impact:** Step 10 adds an unnecessary column, while correctness still depends entirely on another shared-resource transaction strategy.
- **Suggested correction:** Remove `row_version` and its atomic-conflict claim unless a separate, traced lost-update use case is documented. Describe concurrency readiness through the stable `SPACE.space_code` resource and defer the actual mechanism to Steps 11-13.
