---
description: Generate the Step 14 Python data package, review it safely, and revise only Step 14 files
---

Use the generation skill:

`.opencode/skills/14-data-generator/new-SKILL.md`
Use the review skill:

`.opencode/skills/14-data-generator/new-review-SKILL.md`

Treat these as the approved baseline:

- `req/business-requirement-phase2.md`
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- Relevant reviews under `docs/`

Use `$ARGUMENTS` only as optional additional instructions.

Run this workflow:

1. Inspect the repository and read all baseline files fully.
2. Generate or update only:
   - `outputs/14-new-data-generator-G02/generate_data.py`
   - `outputs/14-new-data-generator-G02/generator_config.json`
   - `outputs/14-new-data-generator-G02/requirements.txt`
   - `outputs/14-new-data-generator-G02/README.md`
   - `outputs/14-new-data-generator-G02/02-validate-data.sql`
   - Necessary Step 14 helper files
3. Do not modify earlier approved outputs.
4. Ensure:
   - No hardcoded `University` database
   - Disposable-database guard
   - Safe reset policy
   - `--dry-run`
   - Configurable random seed
   - At least 105,000 bookings
   - At least three academic years
   - Required statuses and both approval paths
   - Advisory and Out-of-Service maintenance
   - Valid advisory acknowledgements
   - No overlapping approved bookings on the same space
   - `pyodbc.fast_executemany`
   - Configurable batch insertion
   - Independent validation SQL
5. Run Python syntax checks.
6. Run CLI help and configuration validation.
7. Run `--dry-run` when dependencies are available.
8. Perform full runtime generation only when:
   - SQL Server is reachable
   - A disposable database can be created
   - Step 5 and Step 10 can be applied cleanly
   - No script redirects to `University`
   - No destructive operation can affect a valuable database
9. Never run full generation against `University` automatically.
10. Run the review skill and create:
    - `docs/14-python-data-generator-review-G02.md`
11. Do not proceed to Step 15 automatically.

At the end, report:

- Step 14 files created or updated
- Review file created or updated
- Final verdict
- Static or runtime-verified status
- Observed booking count and date span when executed
- Remaining blocker or limitation
