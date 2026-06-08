---
name: db-review-step1
description: Review the Business Requirement Analysis document against the original business requirements.
compatibility: opencode
-----------------------

# Step 1 Review Skill

Use this skill after Step 1 Business Requirement Analysis has been completed.

## Important Behavior

Before reviewing:

1. Run `ls -la`.
2. Read the original requirement document.
3. Read the generated business requirement analysis document.
4. Compare the generated analysis against the original requirements.
5. Base findings only on evidence from the requirements.

Do not invent missing requirements.

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

Verify that all important information from the requirement document has been captured.

Check for:

* Missing actors
* Missing entities
* Missing attributes
* Missing relationships
* Missing business rules

For every missing item:

* Quote or reference the requirement statement.
* Explain why it should appear in the analysis.

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

## 5. Quality Assessment

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
* Evidence
* Impact
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
