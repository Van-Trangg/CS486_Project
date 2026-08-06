# 1. Analysis Scope and Phase 1 Baseline

This is a delta-only analysis of the Phase 2 requirements in `req/business-requirement-phase2.md`. It extends the approved Phase 1 baseline without restating unchanged requirements.

Baseline evidence used: `outputs/01-business-req-analysis-G02.md` (the repository's latest approved Step 1 artifact; the filename named in the workflow does not exist), `outputs/02-erd-design-G02.md`, `outputs/03-logical-design-G02.md`, `outputs/04-design-validation-G02.md`, `outputs/05-db-definition-G02.sql`, and the related approved reviews in `docs/`.

Phase 1 has `MAINTENANCERECORD` with maintenance status and a timed relationship to `SPACE`, but no impact-level data. Its booking and maintenance triggers treat every active maintenance record as booking-blocking. `BOOKING` already records the requester, space, requested period, status, and optional approver/decision information. `SPACE`, `FACILITY`, and `SPACE_FACILITY` already provide the capacity and facility data needed by the room finder.

# 2. Requirement Change Summary

| Change ID | Phase 1 Baseline | Phase 2 Requirement | Change Type | Main Impact |
| --- | --- | --- | --- | --- |
| C08-01 | Every active maintenance record blocks an overlapping approved booking. | Distinguish `out-of-service`, which blocks overlapping booking, from `advisory`, which permits booking. | Replaced | Maintenance impact data and availability rule change. |
| C08-02 | No booking-time maintenance notice or acknowledgement is recorded. | Notify the requester of every active advisory affecting the requested space and store acknowledgement with the booking. | New | Booking-to-advisory audit information and booking workflow. |
| C08-03 | Maintenance has a status but no impact-level transition requirement. | An open maintenance record may be escalated or downgraded; escalation must identify already-approved overlapping bookings. | New | Impact change representation, escalation workflow, and affected-booking lookup. |
| C08-04 | Booking overlap trigger checks approved bookings, but Phase 1 has no concurrency design for simultaneous decisions. | Instant and staff approval must never produce overlapping approved bookings under concurrent operations. | Clarified | Atomic availability-and-approval decision for booking operations. |
| C08-05 | Booking, space, facility, and maintenance history support general operational viewing only. | Implement four named analytical reports and test index effects on a large dataset. | New | Semester interpretation, report inputs, query design, data generation, and index analysis. |
| C08-06 | Every booking requires staff review and approval. | Classroom booking requests submitted by a Lecturer or Teaching Assistant are approved automatically at submission time when availability, capacity, maintenance, and usage-policy conditions are satisfied; all other requests remain subject to staff approval. | Replaced | Resolution-path data, eligibility rules, approval workflow, concurrency handling, and test-data coverage. |

# 3. Affected Actors

No new actor is explicitly required.

| Actor | Existing Phase 1 Responsibility | Phase 2 Change | Required Update |
| --- | --- | --- | --- |
| Requester (Student, Lecturer, TA, Department Administrator, or other eligible user) | Submits booking requests and views availability. | Receives all active advisory notices at booking time and acknowledges being informed; may receive instant approval for selected space types. | Booking interaction must present all relevant advisories and capture acknowledgement before the result is recorded. |
| Facility Staff | Reviews standard requests and handles maintenance. | May approve requests concurrently with other staff or instant booking; must follow up with requesters whose approved bookings are identified after escalation. | Approval workflow requires atomic conflict protection; escalation output must identify contact targets. |
| Facility Manager | Configures policies, manages maintenance, and views reports. | Determines or administers maintenance impact changes and needs all four reports. | Maintenance workflow must support escalation/downgrade; reporting must expose required result sets. |

# 4. Affected Entities and Attributes

| Existing or Candidate Entity | Current Phase 1 Role | New or Changed Data Requirement | Reason | Status |
| --- | --- | --- | --- | --- |
| `MAINTENANCERECORD` | Timed maintenance for one space with status, but no impact level. | Record current impact level as `advisory` or `out-of-service`; retain enough information to support an escalation/downgrade while open and identify escalation-affected approved bookings. | Booking treatment now depends on impact, not only maintenance status. | Existing entity affected |
| `BOOKING` | Stores requester, space, requested period, status, and decision fields. | Persist evidence that the requester was informed of every active advisory affecting its space at booking time. | One acknowledgement flag cannot show which advisories were presented when several are active. | Existing entity affected |
| Booking-advisory acknowledgement | Not represented. | Associate one booking with each active advisory presented and record acknowledgement/audit information. | The requirement covers all active advisories and stored acknowledgement. The exact relation versus another representation is a Step 09 decision. | Candidate new entity |
| Maintenance impact-change history or event | Not represented. | Preserve or otherwise make available the escalation event needed to identify affected approved bookings; downgrade is also permitted while open. | Current maintenance state alone may not establish that an escalation occurred or when it occurred for historical reporting. | Requires confirmation |
| `SPACE` | Stores type, capacity, status, and policy. | No new explicit attribute; its existing type/policy participates in deciding whether a request is instant-approved. | Phase 2 says selected space types use instant booking but does not specify the selection or representation. | Requires confirmation |
| `SPACE_FACILITY` and `FACILITY` | Record facilities available in spaces. | No persistent required-facility list is stated; the room finder receives it as query input and must match all requested facilities. | Existing mappings can support the report. | No schema change required |

# 5. Affected Relationships and Cardinalities

| Relationship | Phase 1 Baseline | Phase 2 Impact | Cardinality or Participation Concern | Required Follow-up |
| --- | --- | --- | --- | --- |
| `SPACE` to `MAINTENANCERECORD` | One space has zero or many maintenance records; each record belongs to one space. | Multiple active records may overlap on the same space with different impacts. | Existing cardinality already permits this; no one-active-record constraint may be introduced. | Step 09 must keep concurrent maintenance records representable independently. |
| `BOOKING` to advisory maintenance acknowledgement | No relationship. | A booking must be tied to all active advisories of its space that were disclosed at booking time. | A booking may have zero acknowledgements or many; an advisory may be acknowledged by zero or many bookings. Acknowledgement participation is required for each advisory actually presented. | Step 09 must choose an auditable conceptual/logical representation without assuming a single booking flag is sufficient. |
| `MAINTENANCERECORD` to impact-change history/event | Only current maintenance status is represented. | Escalation and downgrade can occur while open. | One maintenance record can have zero or many impact changes if history is retained; each change belongs to one maintenance record. | Resolve whether retained history is required for the escalation report or whether a current-operation result is sufficient. |
| `BOOKING` approval to `USER` | A booking has zero or one staff approver. | Some qualifying requests are approved at submission; other requests are staff-approved. | Instant approval must not falsely require a staff approver. Phase 2 does not specify whether an approval path or system decision identity is persisted. | Step 09 must document the representation while preserving Phase 1 approval traceability for staff decisions. |

# 6. Changed and New Business Rules

| Rule ID | Rule Description | Change from Phase 1 | Requirement Evidence | Design Impact |
| --- | --- | --- | --- | --- |
| P2-BR-01 | An `out-of-service` maintenance record blocks a booking whose requested period overlaps its maintenance period. | Replaces the Phase 1 all-active-maintenance blocking treatment for this impact level only. | Phase 2, Maintenance impact levels, paragraphs 1-2. | Availability logic must filter by impact and use the established half-open overlap rule. |
| P2-BR-02 | An `advisory` maintenance record does not block booking. | Replaces Phase 1 blocking treatment for advisory work. | Phase 2, Maintenance impact levels, paragraph 2. | Availability logic must not treat advisory as unavailable. |
| P2-BR-03 | At booking time, the requester must be notified of all active advisories affecting the requested space and acknowledgement that the requester was informed must be stored with the booking. | New. | Phase 2, Maintenance impact levels, paragraph 2; additional rule on multiple active records. | The disclosure set and acknowledgement need auditable representation. |
| P2-BR-04 | A space may have several simultaneous active maintenance records with different impact levels. | Clarifies that maintenance impact cannot be reduced to one space-wide state. | Phase 2, Maintenance impact levels, additional rule 1. | Each record must retain independent timing, status, and impact. |
| P2-BR-05 | An open maintenance record may be escalated from advisory to out-of-service or downgraded. | New. | Phase 2, Maintenance impact levels, additional rule 2. | The maintenance workflow must support impact change without closing the record. |
| P2-BR-06 | When an advisory is escalated to out-of-service, already-approved bookings overlapping the maintenance period must be identifiable for staff follow-up. | New; unlike Phase 1, escalation must not simply be rejected because it overlaps an already-approved booking. | Phase 2, Maintenance impact levels, additional rule 3. | Preserve the ability to find affected approved bookings and their requesters; do not assume automatic cancellation. |
| P2-BR-07 | Two approved bookings must never overlap for the same space, regardless of instant or staff approval and concurrent activity. | Clarifies the existing Phase 1 no-double-booking rule as a concurrent transaction-level invariant. | Phase 2, Concurrent booking and approval, paragraphs 2-3. | Availability check and approval/insert transition must be protected as one atomic decision. |
| P2-BR-08 | The system must provide approved-hours-by-space, approved-bookings-by-weekday-and-hour, room-finder, and escalation-affected-bookings reports. | New named reporting scope. | Phase 2, New reporting needs, paragraphs 1-2. | Queries need semester scope, approved-status filtering, temporal data, capacity, facilities, maintenance impact, and escalation information. |
| P2-BR-09 | Index analysis must cover booking conflict checking, the room finder, and one selected additional listed report, using a sufficiently large generated dataset. | New performance-validation scope. | Phase 2, New reporting needs, paragraph 3. | Steps 14-16 must use consistent operations and data for tuning evidence. |
| P2-BR-10 | Classroom booking requests submitted by users with the Lecturer or Teaching Assistant role must be approved automatically at submission time, provided that all applicable availability, capacity, maintenance, and usage-policy constraints are satisfied. | New instant-approval rule. | Phase 2, Automatic booking approval requirement. | Steps 9–14 must model, implement, test, and generate valid data for the instant-approval workflow while preserving booking-conflict and maintenance checks. |
| P2-BR-11 | Once a booking’s resolution path has been assigned, it must not be changed or cleared. | New resolution-path immutability rule. | Phase 2, Booking resolution workflow. | Steps 9–12 must model and enforce resolution_path as a write-once attribute after its initial assignment. |

# 7. Concurrency Conflict Analysis

| Conflict ID | Concurrent Operations | Problematic Interleaving | Incorrect Outcome | Violated Rule | Required Protection |
| --- | --- | --- | --- | --- | --- |
| CC-01 | Two instant-booking submissions for the same space and overlapping periods. | Initial state has no approved overlap. Transaction A reads available; transaction B reads available before A commits; both record approval. | Two overlapping approved bookings exist. | P2-BR-07. | Atomically protect the approved-booking conflict predicate for the space and period together with both approval actions. |
| CC-02 | Two staff members approve different pending requests for the same space and overlapping periods. | Initial state has two pending requests and no approved overlap. Staff A checks availability; staff B checks availability before A commits; both update their request to approved. | Both pending requests become overlapping approved bookings. | P2-BR-07. | Treat the conflict check and pending-to-approved transition as one serialized/atomic decision. Pending requests themselves are not conflicts. |
| CC-03 | One instant booking and one staff approval for overlapping periods on the same space. | Initial state has one pending request and no approved overlap. Instant operation checks availability; staff operation checks availability before the instant operation commits; each records approval by its own path. | An approved instant booking and an approved staff booking overlap. | P2-BR-07. | Both paths must use the same concurrency-safe protection for the same approved-booking availability predicate; an application-side pre-check is insufficient. |

Candidate mechanisms such as transaction isolation, range/key locking, or a centralized transactional approval operation are implementation alternatives for Steps 11-13, not decisions made here.

# 8. Reporting Data Requirements

| Report | Required Data | Supported by Phase 1? | Phase 2 Update Needed | Notes |
| --- | --- | --- | --- | --- |
| Approved booking hours of each space for a semester | Space, approved booking status, requested start/end, and a defined semester boundary or identifier. | Partially. `BOOKING` and `SPACE` provide the booking and space data. | Define how a semester is supplied or derived. | Duration must be calculated only for approved bookings within the stated semester rule. |
| Approved booking counts by weekday and hour for a semester | Approved booking status, requested start, and a defined semester boundary or identifier. | Partially. | Define semester scope and the intended treatment of bookings spanning multiple hour buckets. | The requirement does not state whether a booking counts by start hour only or every occupied hour. |
| Room finder | Requested capacity, requested facility list, time period; space capacity; space-facility mapping; approved bookings; out-of-service maintenance; advisories for visibility. | Largely. Existing capacity, facility, booking, and maintenance timing data exist. | Add maintenance impact level; define query input representation for facility list. | Must require all requested facilities, exclude overlapping approved bookings and out-of-service maintenance, and allow advisory maintenance to remain discoverable. |
| Approved bookings affected by escalation | Escalated maintenance record/event, its space and period, approved overlapping bookings, and requester contact identity. | Partially. Existing maintenance, booking, space, requester, and time data exist. | Add impact level and resolve escalation-event/history information. | The report must identify, not automatically cancel, affected bookings. |

# 9. Downstream Design Update Map

| Change | Step 09 Design Update | Step 10 Migration | Steps 11-13 Concurrency | Steps 15-16 Query/Index Work |
| --- | --- | --- | --- | --- |
| C08-01 maintenance impacts | Represent impact level and its relationship to booking availability. | Backfill existing maintenance rows using an approved default/decision; replace all-active blocking behavior safely. | Include out-of-service availability decisions if booking and maintenance updates can overlap. | Room finder excludes only out-of-service overlaps; escalation report uses impact information. |
| C08-02 advisory acknowledgement | Model auditable booking-to-advisory disclosure/acknowledgement capable of several advisories. | Preserve bookings and add/backfill only as justified; do not invent acknowledgements for historical bookings. | Booking transaction must determine advisory set and store acknowledgement consistently. | Advisory visibility supports the room finder and audit/reporting needs. |
| C08-03 impact changes and escalation follow-up | Resolve current impact plus the required escalation identification/history representation. | Preserve maintenance history and make change order explicit. | Define safe interaction between escalation and booking approval. | Implement affected-approved-bookings report and select relevant indexes if chosen. |
| C08-04 concurrent approval | Retain design facts needed by both approval paths without implementing the mechanism. | Preserve existing bookings and approval data. | Design, implement, and test atomic protection for CC-01 through CC-03. | Tune the booking-conflict operation with fixed data and parameters. |
| C08-05 named reports and index scope | Confirm semester and report-input representation constraints. | Add only schema support selected by Step 09. | None beyond conflict-check operation. | Generate large data, implement all reports, and measure conflict check, room finder, and one selected report before/after indexing. |

# 10. Assumptions

| Assumption | Reason Needed | Risk if Incorrect | Must Be Confirmed In |
| --- | --- | --- | --- |
| The Phase 1 half-open overlap definition (`existing_start < requested_end AND existing_end > requested_start`) remains the temporal rule for Phase 2 booking and maintenance checks. | Phase 2 says overlap but does not redefine it. | Adjacent bookings or maintenance could be incorrectly treated as conflicting. | Step 09 |
| Existing maintenance records are not retroactively asserted to have advisory acknowledgement history. | Phase 1 did not collect advisory notices or acknowledgements. | A migration could manufacture audit evidence. | Step 10 |
| Instant approval is a booking workflow path, not a new user actor. | Phase 2 names selected space types but no system actor. | An unsupported actor/entity could be introduced. | Step 09 |
| Phase 2 does not require automatic cancellation, displacement, or notification after escalation; it requires identification for staff follow-up. | The requirement says staff can contact requesters. | Later work could overstate or implement an unsupported action. | Steps 09 and 16 |

# 11. Open Questions

| Question | Why It Matters | Working Assumption | Affected Later Step |
| --- | --- | --- | --- |
| What defines a semester: supplied start/end parameters, a maintained academic-calendar entity, or another authoritative source? | The first two reports require a consistent semester scope. | Treat semester boundaries as report parameters until requirements authorize stored academic-calendar data. | Steps 09 and 16 |
| For the weekday-and-hour report, does a booking count only in its requested start-hour bucket or in every hour bucket it occupies? | Different aggregation semantics yield different counts. | Do not select semantics in Step 08; obtain clarification before analytical SQL. | Step 16 |
| Which space types and policy conditions qualify for instant approval, and must the approval path be stored? | It determines how the two approval paths are recognized and audited. | Preserve existing optional staff approver for staff decisions; do not infer a new column until Step 09 justifies it. | Steps 09 and 11 |
| Must impact-level changes be retained as a complete history, or is a current escalation action plus immediate affected-booking result sufficient? | A historical escalation report may need who/when/old/new impact information; current state alone may be insufficient. | Step 09 must explicitly choose a representation that supports the required affected-booking use case and document any retention limit. | Steps 09, 10, and 16 |
| Does “active advisory at booking time” include maintenance in `Reported` and `In Progress` only, as Phase 1 treated active maintenance, or another status/time definition? | It determines which advisories are disclosed and acknowledged. | Use the existing Phase 1 active statuses (`Reported`, `In Progress`) pending confirmation. | Steps 09 and 11 |

# 12. Traceability Matrix

| Phase 2 Requirement | Affected Actor/Entity/Rule | Analysis Section | Downstream Deliverable |
| --- | --- | --- | --- |
| Out-of-service blocks overlapping bookings | `MAINTENANCERECORD`, `BOOKING`, P2-BR-01 | 2, 4, 6, 8 | Steps 09, 10, 11-13, 16 |
| Advisory permits booking but requires notification and stored acknowledgement | Requester, `BOOKING`, booking-advisory acknowledgement, P2-BR-02/03 | 2-6, 8 | Steps 09, 10, 14, 16 |
| Multiple active records with different impacts | `SPACE` to `MAINTENANCERECORD`, P2-BR-04 | 2, 4-6 | Steps 09, 10, 14, 16 |
| Escalate/downgrade open maintenance and find affected approved bookings | Facility Staff/Manager, maintenance impact-change information, P2-BR-05/06 | 2, 4-6, 8 | Steps 09, 10, 14, 16 |
| Concurrent instant and staff approvals cannot create overlap | Requester, Facility Staff, `BOOKING`, P2-BR-07, CC-01 to CC-03 | 2, 3, 6-7 | Steps 11-13, 15 |
| Approved hours by space and weekday/hour by semester | Facility Manager, `BOOKING`, `SPACE`, P2-BR-08 | 2, 8, 11 | Steps 14, 16 |
| Room finder by capacity, all facilities, and period | Requester/Facility Manager, `SPACE`, `SPACE_FACILITY`, `BOOKING`, maintenance impacts | 2, 4, 8 | Steps 14-16 |
| Index selected operations on large generated data | Facility Manager, P2-BR-09 | 2, 9 | Steps 14-16 |

# 13. Self-Review Checklist

- [x] The document analyzes updates only and does not repeat the full Phase 1 analysis.
- [x] Every Phase 2 requirement is included.
- [x] Every claimed change is compared with the Phase 1 baseline.
- [x] Affected entities, relationships, and business rules are identified.
- [x] Multiple simultaneous maintenance records are considered.
- [x] Advisory acknowledgement and auditability are considered.
- [x] Maintenance escalation and affected approved bookings are considered.
- [x] All three concurrency-conflict categories are analyzed.
- [x] Reporting needs are mapped to available or missing data.
- [x] Requirements, implications, assumptions, and open questions are clearly separated.
- [x] No final ERD, relational schema, migration SQL, concurrency implementation, index, or analytical query is produced in Step 08.
