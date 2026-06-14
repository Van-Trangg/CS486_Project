cat > .opencode/skills/db-design-pipeline/SKILL.md <<'EOF'
---
name: db-design-pipeline
description: Analyze business requirements and produce conceptual ERD, logical database design, and DDL documents step by step.
compatibility: opencode
---

# Database Design Pipeline Skill

Use this skill when the user asks to transform business requirements into a database design.

## Important behavior

Before assuming anything, inspect the project:

1. Run `ls -la`.
2. Locate requirement files under `req/`, `docs/`, or files passed by the user.
3. Read the relevant requirement files fully before designing.
4. If the requirement is incomplete, continue with explicit assumptions, but also create an unresolved questions section.

## Required output files

Create or update the following files:

1. `outputs/01-business-requirement-analysis-G02.md`
2. `outputs/02-erd-design-G02.md`
Do not skip any Markdown file.

---


# Step 1: Business Requirement Analysis

Use template:
templates/business-analysis-template.md

Read review from:
docs\01-business-requirement-analysis-review-G02.md

Generate or update:
outputs/01-business-requirement-analysis-G02.md

Requirements:
- Fill every section of the template.
- Do not remove template headings.
- Base findings on the requirement document.
- Separate facts, assumptions, and open questions.

# Step 2: Conceptual Design / ERD
Create an ERD using Mermaid code to conceptualize the analysis obtained from the previous step.

To design the ERD, use:
.opencode/skills/erd-design/SKILL.md

Then, self-diagnose and cross-examine generated ERD by using:
.opencode/skills/erd-review/SKILL.md

Finally, using review from:
docs\02-erd-design-review-G02.md
If verdict is **NOT** "APPROVED", update or correct output at: outputs/01-business-requirement-analysis-G02.md

# Step 3: Logical Database Design

Translate the conceptual ERD design into a relational database schema.

To design the logical schema, strictly follow instructions at:
.opencode/skills/logical-design/SKILL.md

After producing the logical schema, self-diagnose and cross-examine with BRA & ERD by following:
.opencode/skills/logical-design-review/SKILL.md

Verify and correct output (if applicable) using review from:
docs\03-logical-design-review-G02.md

Generate or update:
outputs/03-logical-design-G02.md




