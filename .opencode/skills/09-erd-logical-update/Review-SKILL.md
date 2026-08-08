---
name: updated-erd-logical-design-step9-review
description: Review the Phase 2 updated ERD and logical design for completeness, consistency, implementability, and readiness for downstream steps.
compatibility: opencode
---

# Step 9 Review — Updated ERD and Logical Design

Use this skill after the Phase 2 updated ERD and logical design has been created or revised.

Primary file:

`outputs/09-updated-erd-and-logical-design-G02.md`

The review must determine whether Step 9 correctly extends the approved Phase 1 model and provides enough design detail for schema migration, concurrency implementation, testing, data generation, indexing, and analytical queries.

Do not approve the file only because all new entities or attributes are mentioned. Verify that the design is internally consistent and can be implemented without undocumented assumptions.

---

## Review prompt

Examine Step 9 critically and answer:

> Is the updated ERD and logical design complete, internally consistent, implementable in Microsoft SQL Server, and sufficient to support Steps 10–16?

Compare the design with the approved Phase 1 artifacts and the Phase 2 requirements.

---

## Required inputs

Read fully:

- `req/business-requirement-phase2.md`
- `outputs/01-business-requirement-analysis-G02.md`
- `outputs/02-conceptual-design-G02.md`
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- Relevant review files under `docs/`

When available, inspect downstream artifacts only to identify whether Step 9 caused ambiguity or mismatch:

- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `outputs/14-data-generator-G02/`
- `outputs/16-analytical-queries-G02.sql`

Downstream artifacts are supporting evidence, not the authority for redefining Step 9.

---

## Output file

Create or update:

`docs/09-updated-erd-and-logical-design-review-G02.md`

Do not modify Step 9 unless automatic correction is explicitly requested.

---

# Review criteria

## 1. Phase 1 preservation

Verify that Step 9:

- Preserves approved Phase 1 entities and keys.
- Does not silently remove required attributes or relationships.
- Clearly identifies added or changed Phase 2 elements.
- Avoids contradictions with approved Phase 1 business rules.
- Uses naming consistent with the approved logical design.

Report any Phase 2 change that breaks Phase 1 semantics without justification.

---

## 2. Requirement coverage

Verify that the updated design supports all Phase 2 requirements, including:

- Advisory maintenance.
- Out-of-Service maintenance.
- Multiple active maintenance records.
- Advisory acknowledgement.
- Maintenance escalation and downgrade.
- Identification of affected approved bookings.
- Instant approval where applicable.
- Staff approval.
- Booking conflict prevention support.
- Room finder.
- Required analytical reports.

For each requirement, identify the design element that supports it.

---

## 3. Maintenance modeling

Verify that the design clearly defines:

- Current impact level.
- Valid impact-level domain.
- Maintenance start and completion/end time.
- Open-ended maintenance.
- Relationship to space.
- Multiple maintenance records for the same space.
- Escalation and downgrade representation.
- Historical impact changes where required.

The design should support interval comparison between bookings and maintenance.

---

## 4. Advisory acknowledgement modeling

Verify that the model supports acknowledgement of relevant advisories for a booking.

Check:

- Booking-to-maintenance relationship.
- Cardinality.
- Primary or candidate key.
- Duplicate prevention.
- Acknowledgement timestamp.
- Requester or actor reference when required.
- Multiple advisories for one booking.
- Multiple bookings acknowledging one advisory.
- Same-space and active-period rules.

A single Boolean flag should not replace a relationship when several advisories may exist.

---

## 5. Approval modeling

Verify support for:

- Pending submission.
- Instant approval.
- Staff approval.
- Rejection.
- Cancellation.
- Completed lifecycle states where required.

Check:

- `approval_path`.
- `booking_status`.
- `approver_id`.
- `decision_time`.
- `decision_note`.
- Nullability rules.
- Consistency between status and approval path.
- Whether instant and staff approval are distinguishable.
- Whether the design contains enough information to evaluate automatic approval where required.

Do not assume unspecified policy details. Record gaps when the requirement is not translated into structured design.

---

## 6. Submission workflow support

Verify that the design provides the data needed for a later submission workflow, for example:

```text
Submit booking
→ evaluate applicable rules
→ record advisory acknowledgements
→ approve or keep pending
```

Step 9 does not need stored-procedure code, but it must define the data required by downstream implementation.

Identify decisions that Step 10 or Step 12 would otherwise have to invent.

---

## 7. Impact-history modeling

Verify whether the design supports:

- Maintenance reference.
- Previous impact level.
- New impact level.
- Change timestamp.
- Changed-by user.
- Chronological order.
- Current-state reconciliation.
- Historical identification of escalation to Out-of-Service.

If only the current impact is stored, report the limitation for historical reporting.

---

## 8. Concurrency readiness

Verify that the design supports later concurrency implementation.

Check:

- Stable key for `SPACE`.
- Every booking references one space.
- Every maintenance record references one space.
- Approval and maintenance workflows can derive the same space key.
- The model supports consistent transaction and lock ordering.
- The design does not require undocumented cross-space locking behavior.

Step 9 should support concurrency implementation without prescribing SQL syntax.

---

## 9. Query and reporting support

Verify that the design supports:

- Approved booking hours by space and semester.
- Approved booking counts by weekday and hour.
- Room finder by capacity, facilities, and requested period.
- Approved bookings affected by maintenance escalation.

Check whether required dates, statuses, capacities, facilities, requester details, and history are available.

---

## 10. Keys and constraints

For each new or changed relation, verify:

- Primary key.
- Candidate keys.
- Foreign keys.
- Nullability.
- Domain constraints.
- Cardinality.
- Participation.
- Duplicate prevention.
- Important update/delete behavior.

Pay attention to relationship tables and history tables.

---

## 11. Logical-to-physical implementability

Verify that Step 10 can implement the design without guessing.

Check:

- Attributes are clearly defined.
- Multi-valued concepts are represented as relations.
- Structured rules are not represented only as free text when later evaluation is required.
- Historical data is not overwritten when history is required.
- Derived values are identified.
- Naming is consistent.
- Suggested data types are compatible with SQL Server where provided.

---

## 12. Downstream readiness

Assess readiness for:

### Step 10

Can the migration implement all required tables, columns, keys, and checks?

### Step 11

Can the concurrency design identify shared resources and protected workflows?

### Step 12

Can procedures and permissions be implemented from the design?

### Step 13

Can functional and concurrency tests be derived from the design?

### Step 14

Can the generator create valid and representative data from the model?

### Step 15

Can the required queries be indexed and tuned?

### Step 16

Can all analytical queries be written without undocumented assumptions?

---

## 13. Issue severity

Use:

- **Blocking** — the design cannot be implemented or contradicts a required rule.
- **Major** — a required concept or workflow is missing or ambiguous.
- **Minor** — implementable but documentation, naming, or constraints need improvement.
- **Observation** — useful note without required revision.

---

# Output format

# 1. Review Summary

State:

- What was reviewed.
- Main strengths.
- Main gaps.
- Overall readiness for Step 10.

# 2. Files Reviewed

# 3. Requirement Coverage

| Requirement | Design Element | Evidence | Status | Notes |
| --- | --- | --- | --- | --- |

# 4. Entity and Relationship Review

| Entity/Relationship | Purpose | Keys | Cardinality | Constraint Support | Status |
| --- | --- | --- | --- | --- | --- |

# 5. Keys and Constraints Review

# 6. Workflow Support Review

Cover submission, approval, maintenance changes, acknowledgements, and reporting.

# 7. Concurrency Readiness

# 8. Query and Reporting Readiness

# 9. Downstream Impact

| Step | Ready? | Missing Design Decision | Impact |
| --- | --- | --- | --- |

Cover Steps 10–16.

# 10. Issues Found

For each issue:

## Issue R09-X — Short title

- **Severity:** Blocking / Major / Minor / Observation
- **Issue:**
- **Evidence:**
- **Why this matters:**
- **Downstream impact:**
- **Suggested correction:**

# 11. Scores

| Category | Score |
| --- | --- |
| Phase 1 Preservation | X/10 |
| Requirement Coverage | X/10 |
| Maintenance Modeling | X/10 |
| Advisory Acknowledgement | X/10 |
| Approval Modeling | X/10 |
| Impact History | X/10 |
| Concurrency Readiness | X/10 |
| Query Readiness | X/10 |
| Implementability | X/10 |
| Step 10 Readiness | X/10 |

# 12. Required Revisions Before Step 10

List only required changes.

# 13. Final Verdict

Choose exactly one:

- **READY FOR STEP 10**
- **READY FOR STEP 10 WITH MINOR REVISIONS**
- **NOT READY FOR STEP 10**

Provide a concise justification.

---

## Final response behavior

After review:

1. State that `docs/09-updated-erd-and-logical-design-review-G02.md` was created or updated.
2. State the final verdict.
3. Summarize blocking and major issues only.
4. Do not modify Step 9 automatically.
5. Do not proceed to Step 10 automatically.
