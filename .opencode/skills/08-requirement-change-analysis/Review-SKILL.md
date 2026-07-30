---
name: requirement-change-analysis-step08-review
description: Review the Step 08 requirement change analysis against the Phase 2 requirements and approved Phase 1 baseline, then determine whether it is ready for Step 09.
compatibility: opencode
---

# Step 08 — Requirement Change Analysis Review Skill

Use this skill after `outputs/08-requirement-change-analysis-G02.md` has been generated or updated.

The review must determine whether the Step 08 analysis is complete, accurate, traceable, appropriately scoped, and sufficiently clear to be used as the input for **Step 09 — Updated ERD and Logical Design**.

Do not approve the document only because all headings are present. Actively test whether a Step 09 designer could continue without inventing requirements or guessing which Phase 1 design elements must change.

---

## Review prompt

Examine `outputs/08-requirement-change-analysis-G02.md` critically and answer this question:

> Is this requirement-change analysis ready to guide Step 09 without causing the designer to miss a Phase 2 requirement, repeat unchanged Phase 1 material, introduce unsupported design decisions, or guess about affected entities, relationships, cardinalities, and business rules?

To answer, compare the Step 08 output with:

1. The complete Phase 2 requirement document.
2. The latest approved Phase 1 artifacts.
3. Relevant Phase 1 review documents.
4. The expected scope and structure defined in the Step 08 generation skill, if available.

If important information is missing, ambiguous, unsupported, or contradictory, mark the document as not ready or ready only after revisions.

---

## Input documents

### Required

Locate and read the Phase 2 requirement document fully.

Preferred locations include:

- `req/business-requirement-phase2.md`
- `req/phase2-requirement.md`
- Other Phase 2 requirement files under `req/` or `docs/`

Review target:

- `outputs/08-requirement-change-analysis-G02.md`

### Phase 1 baseline

Read the latest available approved versions of:

- `outputs/01-business-requirement-analysis-G02.md`
- `outputs/02-erd-design-G02.md`
- `outputs/03-logical-design-G02.md`
- `outputs/04-design-validation-G02.md`
- `outputs/05-db-definition-G02.sql`

Read relevant review files under `docs/` when available.

### Optional review standard

If present, read:

- `.opencode/skills/requirement-change-analysis-step08/SKILL.md`

Use it to verify the intended scope and required output structure, but treat the Phase 2 requirement document and approved Phase 1 artifacts as the primary evidence.

---

## Output file

Create or update:

`docs/08-requirement-change-analysis-review-G02.md`

Do not skip this file.

Do not directly modify `outputs/08-requirement-change-analysis-G02.md` unless the user explicitly requests automatic correction.

---

## Important review behavior

Before reviewing:

1. Run `ls -la` and locate all relevant files.
2. Verify that the Phase 2 requirement document and Step 08 output exist.
3. Read the relevant documents fully rather than relying on isolated excerpts.
4. Treat the approved Phase 1 artifacts as the baseline for comparison.
5. Base every issue on requirement evidence, baseline inconsistency, logical weakness, or downstream design risk.
6. Do not invent missing requirements.
7. Do not require Step 08 to contain final ERD changes, physical data types, migration SQL, concurrency code, indexes, or analytical SQL.
8. Distinguish between:
   - Blocking issue
   - Major issue
   - Minor issue
   - Observation
9. An open question is not automatically a defect. It becomes a readiness problem only when Step 09 cannot proceed safely without resolving it or clearly stating a working assumption.
10. Challenge the document instead of assuming it is correct because the expected sections are present.

---

# Review criteria

## 1. File and structure completeness

Verify that the Step 08 document contains the required sections:

1. Analysis Scope and Phase 1 Baseline
2. Requirement Change Summary
3. Affected Actors
4. Affected Entities and Attributes
5. Affected Relationships and Cardinalities
6. Changed and New Business Rules
7. Concurrency Conflict Analysis
8. Reporting Data Requirements
9. Downstream Design Update Map
10. Assumptions
11. Open Questions
12. Traceability Matrix
13. Self-Review Checklist

Report missing, empty, duplicated, or unusable sections.

Do not treat formatting completeness as sufficient evidence of substantive completeness.

---

## 2. Update-only scope

Verify that the analysis focuses on Phase 2 changes rather than repeating the complete Phase 1 business analysis.

Check whether:

- Unchanged Phase 1 actors, entities, attributes, and rules are omitted unless needed for context.
- Every included Phase 1 element is connected to a Phase 2 impact.
- The document clearly identifies the approved Phase 1 baseline.
- New, modified, clarified, and replaced requirements are distinguished.
- The Step 08 output does not prematurely perform Step 09 or later work.

Report unnecessary repetition, scope drift, or premature implementation decisions.

---

## 3. Phase 2 requirement coverage

Verify complete coverage of all Phase 2 changes.

### 3.1 Maintenance impact levels

Check that the analysis correctly captures:

- `Advisory` maintenance
- `Out-of-Service` maintenance
- The replacement of the Phase 1 rule that all active maintenance blocks booking
- Multiple simultaneously active maintenance records
- Different impact levels on the same space
- Escalation from advisory to out-of-service
- Downgrade while maintenance remains open
- Identification of already-approved overlapping bookings after escalation

### 3.2 Advisory acknowledgement

Check that the analysis captures:

- Notification of all active advisories at booking time
- Recording that the requester was informed
- Auditability of the acknowledgement
- The possibility that one booking is associated with several active advisories
- The distinction between a requirement and a proposed implementation

### 3.3 Concurrent booking and approval

Check that the analysis covers at least:

1. Instant booking versus instant booking
2. Staff approval versus staff approval
3. Instant booking versus staff approval

For each conflict, verify that it identifies:

- Initial state
- Concurrent operations
- Problematic interleaving
- Incorrect outcome
- Violated business rule
- Data or decision that must be protected atomically

The analysis may mention candidate approaches at a high level, but it must not substitute implementation details for requirement analysis.

### 3.4 Reporting needs

Check that the analysis addresses the data needed for:

- Total approved booking hours of each space for a semester
- Approved booking counts by weekday and hour for a semester
- Room finder by capacity, required facilities, and time period
- Approved bookings affected by maintenance escalation

For each report, verify that the document states whether Phase 1 already supports it or whether a Phase 2 update is needed.

For every missing requirement:

- Cite or reference the source requirement.
- Explain the omission.
- Explain the downstream impact.
- Suggest a focused correction.

---

## 4. Baseline accuracy

Compare every claimed Phase 2 change with the approved Phase 1 artifacts.

Verify that:

- The Phase 1 maintenance rule is described accurately.
- Existing Phase 1 entities, relationships, attributes, and statuses are not misrepresented.
- The document does not claim an element is new when Phase 1 already supports it.
- The document does not overlook existing Phase 1 data that can support a new report.
- Proposed changes do not contradict approved Phase 1 decisions without identifying the replacement explicitly.

Report false deltas, missing deltas, and inaccurate baseline descriptions.

---

## 5. Affected actors, entities, attributes, and relationships

Verify that every identified design impact is justified by the requirements.

Check for:

- Missing affected actors
- Unsupported new actors
- Missing affected entities
- Unsupported candidate entities
- Missing data requirements
- Premature physical data types
- Incorrect or missing relationships
- Incorrect cardinality or participation concerns
- Failure to consider the relationship between a booking and multiple advisory maintenance records
- Failure to distinguish an existing entity update from a candidate new entity

The review should not force one physical solution when multiple valid solutions remain. It should require the Step 08 document to identify the design problem and the constraints Step 09 must satisfy.

---

## 6. Business-rule quality

Verify that changed and new business rules are:

- Correct
- Complete
- Non-contradictory
- Traceable to Phase 2
- Clearly distinguished from assumptions and design implications

Pay particular attention to:

- Overlap logic for approved bookings
- Advisory versus out-of-service effects
- Escalation effects on existing approved bookings
- Acknowledgement requirements
- Automatic approval versus staff approval
- Concurrency-independent enforcement of the no-conflicting-approved-bookings rule

Report rules that are missing, duplicated, vague, unsupported, or inconsistent.

---

## 7. Concurrency analysis quality

Actively test whether the concurrency analysis explains a real race condition rather than merely stating that concurrency is possible.

Verify that:

- At least one concrete interleaving demonstrates how both operations can observe availability before either commits.
- The analysis distinguishes pending requests from approved-booking conflicts.
- The protected unit includes the availability check and approval or insertion as one atomic decision.
- The rule applies consistently to instant booking and staff approval.
- The document does not rely only on an application-level pre-check.
- The required protection is clear enough to guide Steps 11–13.

Report concurrency descriptions that are too vague to support later design and testing.

---

## 8. Reporting-data feasibility

For each required report, determine whether the listed data is sufficient to design the query later.

Check for:

- Semester identification or derivation
- Booking status and approved-booking filtering
- Requested start and end times
- Space capacity
- Space-facility relationships
- Required-facility matching of all requested facilities, not merely any one facility
- Booking overlap conditions
- Out-of-service maintenance overlap conditions
- Maintenance escalation identification
- Advisory visibility where relevant

Do not require final SQL, indexes, or execution plans in Step 08.

---

## 9. Traceability

Verify that:

- Every major Phase 2 requirement appears in the traceability matrix.
- Every affected actor, entity, relationship, and rule is tied to requirement evidence.
- Every claimed downstream update maps to an appropriate Phase 2 deliverable.
- No unsupported design claim is presented as a requirement.
- Assumptions and open questions are clearly labeled.

Identify missing or circular traceability.

---

## 10. Downstream design readiness

Examine whether the document is ready for Step 09.

Attempt to use the Step 08 output as if you were responsible for updating the ERD and relational schema. Determine whether Step 09 can identify, without unsupported guessing:

- Which existing entities are affected
- Which new data must be represented
- Which candidate relationship may be required
- Which cardinality and participation questions must be resolved
- Which business rules the updated design must support
- How multiple advisories per booking affect the conceptual design
- What maintenance escalation history or state must support
- Which decisions remain open and whether a safe working assumption is provided

Mark an issue as **blocking** when its absence or ambiguity would likely cause Step 09 to:

- Omit a required design element
- Choose an unsupported cardinality
- Lose required acknowledgement or escalation information
- Contradict the Phase 1 baseline
- Make concurrency enforcement impossible later
- Make a required analytical query impossible or unreliable

Do not mark the document not ready merely because Step 09 still needs to choose between multiple valid implementation alternatives. Step 08 is ready when the design constraints and unresolved choices are stated clearly enough for Step 09 to make and justify that choice.

---

## 11. Design-quality challenge

Actively search for:

- Missing requirement changes
- False assumptions
- Unsupported entities or attributes
- Over-engineering
- Under-specification
- Misplaced implementation details
- Data-integrity risks
- Auditability gaps
- Temporal-data ambiguities
- Inadequate handling of several simultaneous advisories
- Failure to preserve the distinction between maintenance state and space status
- Failure to map a change to a later deliverable

For every issue, provide:

- Severity
- Issue
- Evidence
- Why it is a problem
- Downstream impact
- Suggested correction

---

## 12. Quality assessment

Assign a score from 0 to 10 for each category:

| Category | Evaluation focus |
| --- | --- |
| Completeness | All required sections and Phase 2 changes are covered |
| Accuracy | Requirements and Phase 1 baseline are represented correctly |
| Delta Scope | The document analyzes updates only and avoids scope drift |
| Consistency | Actors, entities, relationships, rules, assumptions, and mappings agree |
| Traceability | Claims are linked to requirements and downstream deliverables |
| Concurrency Analysis | Race conditions and required atomic protection are clearly analyzed |
| Step 09 Readiness | The document can guide the updated ERD and logical design without unsupported guessing |

Do not inflate scores because the document is lengthy or well formatted.

---

# Output format

The review document must contain the following sections.

# 1. Review Summary

State:

- What was reviewed
- Overall quality
- The most important strength
- The most important risk
- Whether the analysis is ready for Step 09

# 2. Documents Reviewed

List the Phase 2 requirement, Phase 1 baseline artifacts, review files, and Step 08 output used.

# 3. Strengths

List specific strengths supported by evidence.

# 4. Requirement Coverage Check

Use this table:

| Requirement Area | Covered? | Accurate? | Evidence in Step 08 | Missing or Incorrect Detail |
| --- | --- | --- | --- | --- |

Include at least:

- Maintenance impact levels
- Multiple active maintenance records
- Escalation and downgrade
- Advisory acknowledgement
- Instant versus instant conflict
- Staff versus staff conflict
- Instant versus staff conflict
- Approved-hours report
- Weekday-and-hour report
- Room finder
- Escalation-affected bookings

# 5. Issues Found

For each issue, use:

## Issue R08-X — Short title

- **Severity:** Blocking / Major / Minor / Observation
- **Issue:**
- **Evidence:**
- **Why this is a problem:**
- **Downstream impact:**
- **Suggested correction:**

Do not create an issue when there is no evidence of a real problem.

# 6. Step 09 Readiness Examination

Answer each question explicitly:

1. Are all affected entities and data requirements identifiable?
2. Are all affected relationships and cardinality concerns identifiable?
3. Are changed and new business rules complete and traceable?
4. Is advisory acknowledgement specified clearly enough for conceptual design?
5. Is maintenance escalation specified clearly enough for conceptual design?
6. Are unresolved questions separated from confirmed requirements?
7. Do unresolved questions have safe working assumptions where necessary?
8. Would Step 09 need to invent any material requirement or constraint?
9. Are any blocking issues still unresolved?

Then provide:

- **Ready elements:** What Step 09 can safely use now
- **Blocking gaps:** What must be corrected first
- **Non-blocking improvements:** What can be improved without delaying Step 09

# 7. Scores

| Category | Score |
| --- | --- |
| Completeness | X/10 |
| Accuracy | X/10 |
| Delta Scope | X/10 |
| Consistency | X/10 |
| Traceability | X/10 |
| Concurrency Analysis | X/10 |
| Step 09 Readiness | X/10 |

# 8. Required Revisions Before Step 09

List only corrections that are necessary before Step 09 begins.

If none are required, state:

`No blocking revisions are required before Step 09.`

# 9. Final Readiness Verdict

Choose exactly one:

- **READY FOR STEP 09**  
  Use only when there are no blocking or major issues and the document can guide the updated ERD and logical design without unsupported guessing.

- **READY FOR STEP 09 WITH MINOR REVISIONS**  
  Use when remaining issues are non-blocking and can be corrected without changing the core requirement analysis.

- **NOT READY FOR STEP 09**  
  Use when one or more blocking or major issues could cause an incomplete, incorrect, or unsupported updated design.

Provide a brief justification for the verdict.

---

## Final response behavior

After creating the review file:

1. State that `docs/08-requirement-change-analysis-review-G02.md` was created or updated.
2. State the final readiness verdict.
3. Summarize only the blocking and major issues.
4. Do not proceed to Step 09 automatically.
5. If the verdict is not ready, tell the user to revise Step 08 before continuing.
