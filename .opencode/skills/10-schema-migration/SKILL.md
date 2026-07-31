---
name: 10-schema-migration
description: Instructs the agent to produce a safe, transactional, idempotent SQL Server migration script (Step 10) extending the Phase 1 schema baseline (05-db-definition-G02.sql) to match the Step 9 updated logical design (09-updated-erd-and-logical-design-G02.md).
compatibility: opencode
---

## 1. Purpose
This skill instructs the agent to create `outputs/10-schema-migration-G02.sql`, the SQL Server DDL migration script for Step 10 of Phase 2. The script must safely alter the Phase 1 baseline schema (`outputs/05-db-definition-G02.sql`) to implement all structural changes specified in the Step 9 logical design (`outputs/09-updated-erd-and-logical-design-G02.md`), while preserving existing data, establishing explicit backfills/defaults, maintaining strict FK creation order, and providing validation queries.

---

## 2. Required Inputs
Before execution, the agent MUST inspect and load all of the following:

| Input | File | Role |
|---|---|---|
| Phase 1 Schema Baseline | `outputs/05-db-definition-G02.sql` | Existing DDL baseline being migrated |
| Phase 2 Logical Design Baseline | `outputs/09-updated-erd-and-logical-design-G02.md` | Target schema specification |
| Phase 2 Requirement Change Analysis | `outputs/08-requirement-change-analysis-G02.md` | Change source citations & rules |
| Ground Truth Requirements | `req/business-requirement-phase2.md` | Business rules and value constraints |

---

## 3. Mandatory Migration Rules & Constraints

1. **SQL Server Syntax & Quality Standards**:
   - Must use valid T-SQL syntax targeting Microsoft SQL Server.
   - Must use explicit column names and schemas (`dbo`).
   - Must wrap structural changes in `TRY...CATCH` blocks with `XACT_ABORT ON` and explicit transactions (`BEGIN TRANSACTION` / `COMMIT TRANSACTION`).

2. **Data Preservation & Backfill Treatment**:
   - Pre-existing rows in `MAINTENANCERECORD` must default `impact_level` to `'out-of-service'` (matching Phase 1 baseline semantics).
   - Pre-existing rows in `BOOKING` must default `approval_path` to `'Staff'` (matching Phase 1 staff workflow semantics).
   - Non-destructive alterations: Use `ALTER TABLE` to add columns and constraints. Do NOT drop existing baseline tables or overwrite existing data.

3. **Explicit Migration Order**:
   - Stage 1: Add new columns and defaults to existing tables (`MAINTENANCERECORD`, `BOOKING`).
   - Stage 2: Add CHECK constraints to modified tables.
   - Stage 3: Create new tables (`BOOKING_ADVISORY_ACK`, `MAINTENANCE_IMPACT_HISTORY`) with PKs, FKs, Unique constraints, and Defaults.
   - Stage 4: Post-migration validation queries.

4. **Idempotency & Re-run Safety**:
   - Use `COL_LENGTH('table_name', 'column_name') IS NULL` before adding columns.
   - Use `OBJECT_ID('table_name', 'U') IS NULL` before creating tables.
   - Use `OBJECT_ID('constraint_name') IS NULL` before adding constraints.

5. **Post-Migration Validation Queries**:
   - Provide verification `SELECT` queries checking column existence, backfilled values, constraint statuses, and row counts.

---

## 4. Output Structure (`outputs/10-schema-migration-G02.sql`)

```sql
-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 10: Schema Migration DDL
-- Target Schema: Step 09 Logical Design (09-updated-erd-and-logical-design-G02.md)
-- Baseline Schema: Step 05 DDL (05-db-definition-G02.sql)
-- ============================================================

USE University;
GO

SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;
GO

-- Section 1: Pre-Migration Validation / Context Setup
...

-- Section 2: Transactional Schema Alterations (Modified Tables)
-- Alter MAINTENANCERECORD (add impact_level + default + check)
-- Alter BOOKING (add approval_path + row_version + default + check)
...

-- Section 3: Transactional Schema Creations (New Tables)
-- Create BOOKING_ADVISORY_ACK
-- Create MAINTENANCE_IMPACT_HISTORY
...

-- Section 4: Post-Migration Validation & Data Verification Queries
...
```

Save output as: `outputs/10-schema-migration-G02.sql`
