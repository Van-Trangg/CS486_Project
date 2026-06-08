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

Do not skip any Markdown file.

---


# Step 1: Business Requirement Analysis

Use template:
templates/business-analysis-template.md

Generate:
outputs/01-business-requirement-analysis-G02.md

Requirements:
- Fill every section of the template.
- Do not remove template headings.
- Base findings on the requirement document.
- Separate facts, assumptions, and open questions.


