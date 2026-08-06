---
description: Run Phase 2 Step 9 updated ERD and logical design, review readiness, and revise before Step 10
---

Use the Step 9 design skill in:

`.opencode/skills/09-erd-logical-update/design/SKILL.md`

Use the Step 9 review skill in:

`.opencode/skills/09-erd-logical-update/review/SKILL.md`

Treat the latest approved Phase 1 baseline and Step 8 requirement change analysis as the design authority, especially:
- `outputs/02-erd-design-G02.md`
- `outputs/03-logical-design-G02.md`
- `outputs/04-design-validation-G02.md`
- `outputs/08-requirement-change-analysis-G02.md`
- `req/business-requirement-phase2.md`
- Relevant review files under `docs/`

Run the following workflow:

1. Inspect the project and verify that the required Phase 1 baseline, Step 8 analysis, and Phase 2 BRA files exist.

2. Read the relevant files fully and verify the exact Step 8 Change IDs, affected entities/relationships, and open questions assigned to Step 9, including:
   - `MAINTENANCERECORD` impact-level representation
   - Advisory acknowledgement entity/attributes
   - Resolution/approval path representation
   - Concurrency-support schema column(s)
   - Semester scope handling for reporting (parameter vs. stored entity)

3. Generate or update only:
   - `outputs/09-updated-erd-and-logical-design-G02.md`

4. Produce the approved Step 9 design. At minimum:
   - Build the Change Ledger from the actual Step 8 document (not from any illustrative example).
   - Resolve every Step 8 §11 open question assigned to Step 9 with an explicit, rationale-backed decision, traced to a Step 8 section.
   - Reproduce every unaffected Phase 1 entity, attribute, and relationship identically — no unexplained edits.
   - Introduce new structural elements only where traceable to a Change ID or a Stage 1 resolution.
   - Write new/changed attribute types as explicit SQL-style types, never generic aliases.
   - Scope the concurrency section to schema support only — no locking strategy or isolation level.
   - Run the Stage 8 self-consistency pre-check before finalizing.

5. Keep Step 9 within scope:
   - Do not produce migration SQL (Step 10).
   - Do not produce concurrency implementation (Steps 11–13).
   - Do not produce sample data generation (Step 14).
   - Do not produce analytical queries or indexing (Steps 15–16).
   - Do not modify approved earlier outputs unless a blocking inconsistency is found and clearly reported.

6. Run the Step 9 review skill and create or update:
   - `docs/09-updated-erd-and-logical-design-review-G02.md`

7. Do not automatically start Step 10.

At the end, report:

- Files created or updated
- Change IDs addressed and open questions resolved
- Final Step 10 readiness verdict
- Whether any Phase 1 baseline element was found modified without traceability
- Remaining ambiguities, assumptions, or unresolved blockers