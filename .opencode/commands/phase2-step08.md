---
description: Run Phase 2 Step 08 requirement-change analysis, review readiness, and revise the output before Step 09
---

Use the Step 08 requirement-change analysis skill in:

`.opencode/skills/08-requirement-change-analysis/SKILL.md`

Use the Step 08 review skill in:

`.opencode/skills/08-requirement-change-analysis/Review-SKILL.md`

Read the Phase 2 business requirement from:

`$ARGUMENTS`

Treat the latest approved Phase 1 artifacts as the baseline, especially:

- `outputs/01-business-requirement-analysis-G02.md`
- `outputs/02-erd-design-G02.md`
- `outputs/03-logical-design-G02.md`
- `outputs/04-design-validation-G02.md`
- `outputs/05-db-definition-G02.sql`
- Relevant review files under `docs/`

Run the following workflow:

1. Inspect the project and verify that the Phase 2 requirement file and relevant Phase 1 baseline files exist.
2. Generate or update only:
   - `outputs/08-requirement-change-analysis-G02.md`
3. Keep Step 08 update-only:
   - Analyze only new, modified, replaced, or clarified Phase 2 requirements.
   - Do not repeat the full Phase 1 analysis.
   - Do not modify approved Phase 1 output files.
   - Do not perform Step 09 design work or later implementation work.
4. Run the Step 08 review skill and create or update:
   - `docs/08-requirement-change-analysis-review-G02.md`
5. Do not automatically start Step 09.

At the end, report:

- Files created or updated
- Final readiness verdict
- Remaining assumptions or open questions
