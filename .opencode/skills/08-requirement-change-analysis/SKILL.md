---
name: requirement-change-analysis-step08
description: Analyze Phase 2 requirement changes against the approved Phase 1 database design and produce a focused delta analysis for Step 08.
compatibility: opencode
---

# Step 08 — Requirement Change Analysis Skill

Use this skill when Phase 1 has already been completed and the user asks to analyze the Phase 2 requirements.

The purpose of this step is to identify **what must change from Phase 1**. Do not repeat the full Phase 1 business requirement analysis and do not redesign the database in this step.

## Required output

Create or update:

`outputs/08-requirement-change-analysis-G02.md`

Do not modify the approved Phase 1 output files unless the user explicitly requests it.

---

## 1. Inspect the project before analysis

1. Run `ls -la` and inspect the project structure.
2. Locate and read the Phase 2 requirement document fully.
3. Locate and read the latest approved Phase 1 artifacts, especially:
   - `outputs/01-business-requirement-analysis-G02.md`
   - `outputs/02-erd-design-G02.md`
   - `outputs/03-logical-design-G02.md`
   - `outputs/04-design-validation-G02.md`
   - `outputs/05-db-definition-G02.sql`
4. Read relevant review files under `docs/` when available.
5. Treat the latest approved Phase 1 artifacts as the baseline.
6. If a required file cannot be found, report the missing file and continue only where evidence is sufficient.

---

## 2. Delta-only analysis behavior

Analyze only requirements that are new, changed, removed, or clarified in Phase 2.

For each item, compare:

- **Phase 1 baseline:** what the current system already supports.
- **Phase 2 change:** what the new requirement adds or changes.
- **Required impact:** which existing design elements are affected.

Do not reproduce unchanged Phase 1 actors, entities, attributes, relationships, or business rules.

Include an unchanged Phase 1 element only when it is necessary to explain the effect of a Phase 2 change.

Do not silently treat a new design proposal as a confirmed requirement. Clearly separate:

- Explicit requirement
- Design implication
- Assumption
- Open question

---

## 3. Required analysis scope

The analysis must cover all Phase 2 changes, including the following areas.

### 3.1 Maintenance impact levels

Analyze the change from the Phase 1 rule that all active maintenance blocks booking to the Phase 2 distinction between:

- `Advisory`
- `Out-of-Service`

Determine the impact on:

- Maintenance-related entities and attributes
- Space availability rules
- Booking validation rules
- Multiple simultaneous maintenance records
- Maintenance escalation and downgrade
- Identification of already-approved bookings affected by escalation

### 3.2 Advisory acknowledgement

Analyze the requirement to:

- Notify the requester of every active advisory at booking time
- Record that the requester was informed

Identify the affected entities, relationships, business rules, and audit requirements.

Do not decide prematurely whether acknowledgement must be implemented as an attribute or a separate relation. Present alternatives as design implications unless Phase 1 evidence makes one option clearly necessary.

### 3.3 Concurrent booking and approval

Identify possible concurrency conflicts involving:

- Two instant-booking requests for overlapping periods
- Two staff approvals for overlapping requests
- An instant booking and a staff approval occurring concurrently
- Multiple operations reading availability before either operation commits

For each conflict, describe:

- Initial database state
- Concurrent operations
- The interleaving that causes the problem
- Incorrect possible outcome
- Business rule violated
- Data that must be protected atomically

Do not implement the concurrency solution in Step 08. State only the required protection and candidate approaches at a high level. Detailed design belongs to Steps 11–13.

### 3.4 New reporting needs

Identify data and relationships required to support:

- Total approved booking hours by space for a semester
- Approved booking counts by weekday and hour for a semester
- Available-space room finder using capacity, required facilities, and requested time period
- Approved bookings affected by maintenance escalation

For each report, state whether the Phase 1 schema already contains the required data or whether a Phase 2 change is needed.

Do not write the final analytical SQL in Step 08.

---

## 4. Required output structure

The generated document must use the following headings.

# 1. Analysis Scope and Phase 1 Baseline

Briefly identify the Phase 1 artifacts used as the baseline and explain that this document contains only Phase 2 changes.

# 2. Requirement Change Summary

Use a table with these columns:

| Change ID | Phase 1 Baseline | Phase 2 Requirement | Change Type | Main Impact |
| --- | --- | --- | --- | --- |

Use change types such as:

- New
- Modified
- Clarified
- Replaced

# 3. Affected Actors

List only actors whose responsibilities or interactions change.

Use this table:

| Actor | Existing Phase 1 Responsibility | Phase 2 Change | Required Update |
| --- | --- | --- | --- |

If no new actor is required, state this explicitly.

# 4. Affected Entities and Attributes

Use this table:

| Existing or Candidate Entity | Current Phase 1 Role | New or Changed Data Requirement | Reason | Status |
| --- | --- | --- | --- | --- |

For `Status`, use:

- Existing entity affected
- Candidate new entity
- No schema change required
- Requires confirmation

Do not finalize physical data types in this step.

# 5. Affected Relationships and Cardinalities

Use this table:

| Relationship | Phase 1 Baseline | Phase 2 Impact | Cardinality or Participation Concern | Required Follow-up |
| --- | --- | --- | --- | --- |

Pay particular attention to whether one booking may need to acknowledge multiple active advisory maintenance records.

# 6. Changed and New Business Rules

Use this table:

| Rule ID | Rule Description | Change from Phase 1 | Requirement Evidence | Design Impact |
| --- | --- | --- | --- | --- |

Each rule must be traceable to the Phase 2 requirement. Do not invent operational rules.

# 7. Concurrency Conflict Analysis

Document at least the three required conflict categories:

1. Instant booking versus instant booking
2. Staff approval versus staff approval
3. Instant booking versus staff approval

Use this table:

| Conflict ID | Concurrent Operations | Problematic Interleaving | Incorrect Outcome | Violated Rule | Required Protection |
| --- | --- | --- | --- | --- | --- |

# 8. Reporting Data Requirements

Use this table:

| Report | Required Data | Supported by Phase 1? | Phase 2 Update Needed | Notes |
| --- | --- | --- | --- | --- |

# 9. Downstream Design Update Map

Map each identified change to later Phase 2 deliverables.

| Change | Step 09 Design Update | Step 10 Migration | Steps 11–13 Concurrency | Steps 15–16 Query/Index Work |
| --- | --- | --- | --- | --- |

This section should identify required future work, not perform it.

# 10. Assumptions

List only assumptions necessary to continue the analysis.

| Assumption | Reason Needed | Risk if Incorrect | Must Be Confirmed In |
| --- | --- | --- | --- |

# 11. Open Questions

| Question | Why It Matters | Working Assumption | Affected Later Step |
| --- | --- | --- | --- |

# 12. Traceability Matrix

| Phase 2 Requirement | Affected Actor/Entity/Rule | Analysis Section | Downstream Deliverable |
| --- | --- | --- | --- |

# 13. Self-Review Checklist

Confirm that:

- The document analyzes updates only and does not repeat the full Phase 1 analysis.
- Every Phase 2 requirement is included.
- Every claimed change is compared with the Phase 1 baseline.
- Affected entities, relationships, and business rules are identified.
- Multiple simultaneous maintenance records are considered.
- Advisory acknowledgement and auditability are considered.
- Maintenance escalation and affected approved bookings are considered.
- All three concurrency-conflict categories are analyzed.
- Reporting needs are mapped to available or missing data.
- Requirements, implications, assumptions, and open questions are clearly separated.
- No final ERD, relational schema, migration SQL, concurrency implementation, index, or analytical query is produced in Step 08.

---

## 5. Quality rules

- Base every factual statement on the Phase 2 requirement or the approved Phase 1 artifacts.
- Cite the relevant requirement section or source artifact for each major change.
- Prefer concise delta descriptions over repeating old material.
- Do not introduce new actors or entities without justification.
- Do not assume that `space.status` alone is sufficient to represent maintenance impact.
- Do not assume that one acknowledgement flag is sufficient when several advisories may be active.
- Do not confuse a pending booking request with an approved booking conflict.
- Treat conflict prevention as a transaction-level integrity requirement, not only as an application check.
- When evidence is ambiguous, record an open question instead of inventing a rule.

---

## 6. Final response behavior

After generating the file:

1. State that `outputs/08-requirement-change-analysis-G02.md` was created or updated.
2. Summarize the major identified changes in no more than five bullets.
3. List any unresolved questions that block Step 09.
4. Do not proceed to Step 09 unless the user requests it.
