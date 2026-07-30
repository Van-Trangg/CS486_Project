---
name: db-review-step1
description: Review the Business Requirement Analysis document against the original business requirements.
compatibility: opencode
-----------------------

# Step 1 Review Skill

Use this skill after Step 1 Business Requirement Analysis has been completed.

---

## Input Documents

Requirement Document:

`req/business-requirement.md`

Business Requirement Analysis:

`outputs/01-business-requirement-analysis-G02.md`

---

## Output File

Create or update:

`docs/01-business-requirement-analysis-review-G02.md`

Do not skip this file.

---

## Important Behavior

Before reviewing:

1. Verify that both input files exist before starting the review.
2. Compare the generated analysis against the original requirements.
3. Base findings only on evidence from the requirements.
4. Do not recommend changes unless there is clear evidence from the requirements, logical inconsistency, or a significant design improvement.
Do not invent missing requirements.

---

# Review Criteria

## 1. Completeness

Verify that the analysis includes:

* Business Purpose
* Actors
* Entities
* Attributes
* Relationships
* Cardinalities
* Business Rules
* Assumptions
* Open Questions

Report any missing sections.

---

## 2. Requirement Coverage

Verify that all important information from the requirement document has been correctly captured in the analysis.

Check for:

* Missing actors
* Missing entities
* Missing attributes
* Missing relationships
* Missing cardinalities
* Missing business rules

For every issue:

* Quote or reference the requirement statement.
* Explain why it should appear in the analysis.
* Explain the impact of the omission.
* Suggest a correction.

---

## 3. Consistency

Verify:

* Every actor participates in at least one relationship.
* Every entity has at least one attribute.
* Every relationship has a cardinality.
* Business rules do not contradict each other.

Report inconsistencies.

---

## 4. Traceability

Verify that:

* Every entity can be traced back to a requirement.
* Every business rule can be traced back to a requirement.

Identify unsupported assumptions.

---
## 5. Design Quality Review

Actively challenge the analysis and search for design weaknesses, not only missing information.

Check for:

* Incorrect actors
* Incorrect entities
* Incorrect attributes
* Incorrect relationships
* Incorrect cardinalities
* Incorrect business rules
* Incorrect assumptions
* Misplaced information
* Unsupported assumptions
* Over-engineered design decisions
* Under-specified design decisions
* Data integrity concerns
* Auditability concerns

For every suspected issue:

* Describe the issue.
* Explain why it may be incorrect.
* Reference the relevant requirement text or design element.
* Explain the potential impact.
* Suggest a correction.

Do not assume the analysis is correct simply because information is present.
Challenge the design and look for weaknesses.

---


## 6. Quality Assessment

Evaluate:

* Clarity
* Completeness
* Accuracy
* Traceability

Assign scores from 0-10 for each category.

---

# Output Format

The review document must contain:

# Review Summary

# Strengths

# Issues Found
For each issue:

* Issue
* Evidence (Missing Items/Incorrect Items)
* Impact (Design Concerns)
* Suggested Fix

# Scores

| Category     | Score |
| ------------ | ----- |
| Completeness | X/10  |
| Accuracy     | X/10  |
| Consistency  | X/10  |
| Traceability | X/10  |

# Final Recommendation

One of:

* Approved
* Approved with Minor Revisions
* Requires Revision Before Step 2
