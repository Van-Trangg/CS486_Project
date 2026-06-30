---
name: db-review-step4
description: Instructs the agent to act as an independent reviewer and systematically validate a database design validation report against the BRA, ERD, and Logical Design documents.
compatibility: opencode
---

## 1. Purpose

This skill instructs the agent to act as an independent reviewer of the Step 4 deliverable: `04-design-validation-G02.md`.

The objective is to verify whether the validation report:

* Correctly evaluates the Logical Database Design against the BRA and ERD.
* Identifies strengths, weaknesses, risks, missing coverage, and partial enforcement accurately.
* Uses evidence from the BRA, ERD, and Logical Design consistently.
* Follows the required output structure and verdict criteria.
* Does **not** invent requirements, redesign the schema, or overstate enforcement.

This review is performed **after** the Step 4 validation document is produced and **before** proceeding to Step 5 (Database Implementation).

---

## 2. Required Inputs

Before beginning, the agent MUST load and fully read:

* `outputs/01-business-requirement-analysis-G02.md`
* `outputs/02-erd-design-G02.md`
* `outputs/03-logical-design-G02.md`
* `outputs/04-design-validation-G02.md`

If any required file is unavailable, halt and request it.

Do not proceed from memory.

---

## 3. Review Pipeline

Execute the following checks in strict order. For each check, produce a result of PASS, WARN, or FAIL with precise justification. Do not write vague summaries. Cite exact sections, table names, entity names, attributes, constraints, and business rules.

---

### Check 1 — Required Section Completeness

Verify that the Step 4 document includes all required sections in the correct order:

1. Validation Scope
2. Entity Coverage Validation
3. Relationship Mapping Validation
4. Key Validation
5. Constraint Validation
6. Business Rule Coverage Analysis
7. Traceability Validation
8. Strengths
9. Issues and Risks
10. Recommendations
11. Conclusion

Validate that each section is present and meaningfully populated.

**Pass condition:** All required sections exist and are not empty placeholders.

---

### Check 2 — Evidence Coverage

Verify that the validation report cites evidence from all required sources:

* BRA
* ERD
* Logical Design

For every major finding, check that the report references the relevant source material and does not rely on unsupported claims.

Validate that the report distinguishes between:

* Fully Satisfied
* Partially Satisfied
* Unsatisfied

**Pass condition:** Every material conclusion is traceable to source documents.

---

### Check 3 — Entity Coverage Accuracy

Compare the validation report’s entity coverage analysis against the ERD and Logical Design.

For every ERD entity:

* Confirm the report identifies the corresponding table.
* Confirm the report does not omit any entity.
* Confirm the report does not incorrectly claim an extra table is missing or invented unless supported by evidence.

Record:

* Entity Name
* Corresponding Table
* Report Assessment
* Evidence Quality
* Notes

**Pass condition:** The report correctly covers all entities with no unsupported omissions or inventions.

---

### Check 4 — Relationship Mapping Accuracy

Verify that the report correctly assesses how ERD relationships are represented in the Logical Design.

Validate:

* 1:N relationships map to a foreign key on the N-side
* M:N relationships map to a junction table
* 1:1 relationships use shared primary key or UNIQUE foreign key where appropriate
* Optional participation is not silently upgraded to mandatory participation
* Multi-role relationships are not collapsed into one ambiguous mapping

For each relationship discussed in the report, confirm that the report’s conclusion matches the actual logical schema.

**Pass condition:** Relationship mapping evaluation is technically correct and evidence-based.

---

### Check 5 — Key Analysis Accuracy

Review the report’s evaluation of:

* Primary keys
* Foreign keys
* Composite keys
* Candidate keys
* Alternate keys

Validate that the report correctly states whether each table’s keys:

* Uniquely identify records
* Support relationships correctly
* Match the ERD design intent
* Are redundant, missing, or overly broad only when supported by evidence

**Pass condition:** Key validation findings are correct and do not mischaracterize schema design.

---

### Check 6 — Constraint Analysis Accuracy

Evaluate whether the report correctly classifies constraints such as:

* NOT NULL
* UNIQUE
* CHECK
* DEFAULT
* Referential integrity actions

The report must correctly distinguish between:

* Constraints enforced directly in the schema
* Constraints that require trigger/procedure/application logic
* Constraints that are only partially enforceable at the relational level

The report must not claim direct enforcement where only procedural enforcement exists.

**Pass condition:** Constraint analysis is accurate and does not overstate enforcement.

---

### Check 7 — Business Rule Coverage Accuracy

Review every business rule from the BRA that has structural or constraint implications.

For each rule, confirm the report correctly classifies it as:

* Fully Enforced
* Partially Enforced
* Not Enforced

The report must explicitly identify well-known relational limitations such as:

* Conflicting booking prevention
* Overlap detection
* Capacity validation
* Maintenance restrictions
* Role-based approval restrictions
* Temporal state transitions

**Pass condition:** All significant business rules are classified correctly with no unsupported enforcement claims.

---

### Check 8 — Traceability Accuracy

Verify that the report correctly maps:

BRA Requirement → ERD Element → Logical Schema Element → Constraint or Enforcement Mechanism

Check that:

* Every important requirement has traceability coverage.
* Missing links are identified only when truly absent.
* The report does not invent traceability that is not present.

**Pass condition:** Traceability analysis is complete and faithful to the source documents.

---

### Check 9 — Overall Assessment Quality

Validate the report’s final judgment:

* Fully Valid
* Conditionally Valid
* Invalid

Check whether the conclusion matches the evidence in the report.

The reviewer must assess whether the report:

* Correctly distinguishes strengths from risks
* Avoids overstating certainty
* Clearly states unresolved implementation limitations
* Gives appropriate recommendations without changing the original design

**Pass condition:** Final conclusion is justified by the report’s own findings.

---

### Check 10 — Output Discipline and Rule Compliance

Check the report for compliance with the required review discipline:

* Does not redesign the schema
* Does not invent new business requirements
* Does not claim a business rule is enforced unless the enforcement mechanism is identified
* Clearly separates blocking issues from advisory issues
* Uses the required output structure
* Saves to the correct output path

**Pass condition:** The report stays within the boundaries of Step 4 validation.

---

## 4. Review Report Format

> **OUTPUT PATH — MANDATORY**
> Save the review report to: `docs/04-design-validation-review-G02.md`
> Do NOT write to `outputs/` or any other directory.

Produce the review report as a Markdown file with this structure:

```md
# Step 4 Review Report — Database Design Validation Review

---

## Verdict

<One of: APPROVED / APPROVED WITH MINOR ISSUES / REQUIRES REVISION>

<Two to four sentences summarising the overall finding.>

---

## Check Results

| Check | Description | Result | Issues Found |
|---|---|---|---|
| 1 | Required Section Completeness | PASS/WARN/FAIL | <count> issues |
| 2 | Evidence Coverage | PASS/WARN/FAIL | <count> issues |
| 3 | Entity Coverage Accuracy | PASS/WARN/FAIL | <count> issues |
| 4 | Relationship Mapping Accuracy | PASS/WARN/FAIL | <count> issues |
| 5 | Key Analysis Accuracy | PASS/WARN/FAIL | <count> issues |
| 6 | Constraint Analysis Accuracy | PASS/WARN/FAIL | <count> issues |
| 7 | Business Rule Coverage Accuracy | PASS/WARN/FAIL | <count> issues |
| 8 | Traceability Accuracy | PASS/WARN/FAIL | <count> issues |
| 9 | Overall Assessment Quality | PASS/WARN/FAIL | <count> issues |
| 10 | Output Discipline and Rule Compliance | PASS/WARN/FAIL | <count> issues |

---
## Detailed Findings

### Check N — <Name>
**Result:** PASS / WARN / FAIL

<For PASS: one sentence confirming what was verified.>
<For WARN or FAIL: itemised list of specific issues. Each issue must cite:>
- The exact element (section name, entity name, table name, attribute name, constraint, or business rule)
- What was written in the Step 4 report
- What the source documents support
- Severity: BLOCKING (must fix before Step 5) or ADVISORY (should fix, non-blocking)

---

## Required Changes Before Step 5

<Numbered list of all BLOCKING issues only, each with a specific correction instruction.>
<If no blocking issues: state "None — Step 4 report is cleared to proceed to Step 5.">

---

## Recommended Improvements

<Numbered list of ADVISORY issues only. These do not block Step 5 but should be addressed.>
<If none: state "None.">
```

Save output to:

`docs/04-design-validation-review-G02.md`

---

## 5. Verdict Criteria

| Verdict                        | Condition                                                                                                                                             |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **APPROVED**                   | All checks PASS. No issues of any severity.                                                                                                           |
| **APPROVED WITH MINOR ISSUES** | All checks PASS or WARN. Zero FAIL results. Zero BLOCKING issues. Advisory issues documented.                                                         |
| **REQUIRES REVISION**          | Any check returns FAIL, or any BLOCKING issue is found regardless of check result. The Step 4 report must be corrected and re-reviewed before Step 5. |

If the verdict is REQUIRES REVISION, the agent must:

1. List every blocking issue clearly.
2. Explain the exact correction needed in the Step 4 report.
3. Re-run the relevant checks on the corrected report and confirm the blocking issues are resolved.

---

## 6. Reviewer Stance

The reviewer must treat the BRA, ERD, and Logical Design as the authoritative sources.

The reviewer must not:

* Accept claims without evidence.
* Treat procedural enforcement as if it were schema enforcement.
* Ignore missing traceability links.
* Overlook partially enforced rules.
* Approve a report that uses the wrong output path.
* Rewrite the schema or change design decisions inside the review.

The reviewer must be constructive: every FAIL or WARN finding includes a specific, actionable correction instruction, not just a description of what is wrong.
