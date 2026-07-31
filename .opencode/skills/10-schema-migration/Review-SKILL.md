---
name: 10-schema-migration-review
description: Instructs the agent to act as an independent reviewer and systematically validate the Step 10 Schema Migration SQL (10-schema-migration-G02.sql) against the Step 9 logical design baseline, Step 8 requirements, and SQL Server execution standards.
compatibility: opencode
---

## 1. Purpose
This skill instructs the agent to systematically validate `outputs/10-schema-migration-G02.sql` against `outputs/09-updated-erd-and-logical-design-G02.md`, `outputs/05-db-definition-G02.sql`, and `AGENTS.md`. The reviewer must check for completeness, SQL Server syntax compatibility, data preservation, idempotency, foreign key dependency order, transaction safety, and post-migration validation checks, producing `docs/10-schema-migration-review-G02.md`.

---

## 2. Required Inputs
- `outputs/10-schema-migration-G02.sql` (Subject under review)
- `outputs/09-updated-erd-and-logical-design-G02.md` (Target schema specification)
- `outputs/05-db-definition-G02.sql` (Phase 1 baseline schema)
- `outputs/08-requirement-change-analysis-G02.md` (Scope authority)
- `AGENTS.md` (SQL Server guidelines & workflow rules)

---

## 3. Review Pipeline (7 Mandatory Checks)

### Check 1 — Schema Delta Coverage
Verify every structural change from Step 9 is implemented in DDL:
- `MAINTENANCERECORD.impact_level` (`VARCHAR(20)` with default `'out-of-service'` and CHECK constraint).
- `BOOKING.approval_path` (`VARCHAR(20)` with default `'Staff'` and CHECK constraint).
- `BOOKING.row_version` (`ROWVERSION`).
- `BOOKING_ADVISORY_ACK` table creation with PK (`ack_id`), FKs, UQ constraint, and default timestamp.
- `MAINTENANCE_IMPACT_HISTORY` table creation with PK (`history_id`), FKs, CHECK constraints, and default timestamp.

### Check 2 — Baseline Preservation & Backfill Integrity
- Verify no pre-existing tables or columns are destroyed or dropped.
- Verify backfill/default logic for pre-existing records (`'out-of-service'` for maintenance impact, `'Staff'` for booking approval path).

### Check 3 — Dependency Ordering & FK Safety
- Verify table alterations and table creations follow safe dependency order so FKs reference already-existing PKs.

### Check 4 — Idempotency & Re-run Safety
- Verify `IF NOT EXISTS` / `OBJECT_ID` / `COL_LENGTH` guards prevent failure on re-execution.

### Check 5 — Transaction Safety & Exception Handling
- Verify `XACT_ABORT ON`, explicit `BEGIN TRANSACTION` / `COMMIT TRANSACTION`, and `TRY...CATCH` blocks are used properly.

### Check 6 — T-SQL Syntax & Data Type Precision
- Verify exact SQL Server types match Step 9 (`VARCHAR(20)`, `DATETIME`, `ROWVERSION`, `INT IDENTITY`).

### Check 7 — Post-Migration Validation Query Quality
- Verify validation queries exist to confirm schema state and row counts post-migration.

---

## 4. Review Report Format (`docs/10-schema-migration-review-G02.md`)

```markdown
# Step 10 Review Report — Schema Migration Validation

## Verdict
<APPROVED / APPROVED WITH MINOR ISSUES / REQUIRES REVISION>

## Check Results Table
| Check | Description | Result | Issues Found |
|---|---|---|---|
| 1 | Schema Delta Coverage | PASS/WARN/FAIL | 0 |
| 2 | Baseline Preservation & Backfill Integrity | PASS/WARN/FAIL | 0 |
| 3 | Dependency Ordering & FK Safety | PASS/WARN/FAIL | 0 |
| 4 | Idempotency & Re-run Safety | PASS/WARN/FAIL | 0 |
| 5 | Transaction Safety & Exception Handling | PASS/WARN/FAIL | 0 |
| 6 | T-SQL Syntax & Data Type Precision | PASS/WARN/FAIL | 0 |
| 7 | Post-Migration Validation Queries | PASS/WARN/FAIL | 0 |

## Detailed Findings
...

## Required Changes Before Step 11
...
```

Save output as: `docs/10-schema-migration-review-G02.md`
