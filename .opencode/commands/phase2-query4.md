---
description: Generate Query 4 for maintenance-escalation affected bookings, review it, and revise only its Step 16 section
---

Use the Query 4 generation skill in:

`.opencode/skills/16-query4-maintenance-affected/SKILL.md`

Use the Query 4 review skill in:

`.opencode/skills/16-query4-maintenance-affected/Review-SKILL.md`

Treat the latest Phase 2 schema and generated data as the baseline, especially:

- `req/business-requirement.md`
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `outputs/14-data-generator-G02/01-generate-data.sql`
- `outputs/14-data-generator-G02/02-validate-data.sql`
- Existing `outputs/16-analytical-queries-G02.sql`
- Relevant reviews under `docs/`

Use `$ARGUMENTS` only as optional additional instructions.

Run this workflow:

1. Inspect and read all relevant files fully.
2. Verify exact table, column, status, impact-level, and maintenance-period names.
3. Generate or update only the Query 4 section in:
   - `outputs/16-analytical-queries-G02.sql`
4. Preserve Query 1–3 and other members’ work.
5. Implement the query for approved bookings affected by a selected maintenance record escalated to `Out-of-Service`.
6. Include business question, target users, business value, requirement, parameters, assumptions, SQL, expected behavior, and tests.
7. Do not create indexes or modify Step 12 procedures.
8. Run the Query 4 review and create:
   - `docs/16-query4-maintenance-affected-review-G02.md`
9.  Do not modify other query sections.

At the end, report:

- Files updated
- Final verdict
- Tables and columns used
- Runtime or static test status
- Remaining schema limitation or blocker
