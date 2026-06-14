---
name: db-review-step5
description: Instructs the agent to act as an independent reviewer and systematically validate the generated SQL DDL script (Step 5) against the Logical Design (Step 3) and mandatory fixes from Step 4. Produces a structured review report with a readiness verdict.
compatibility: opencode
---

## 1. Purpose

This skill instructs the agent to act as an independent reviewer and systematically validate the SQL DDL script produced in Step 5 (`05-db-definition-G02.sql`) against:

- The Logical Database Design (`03-logical-design-G02.md`) as the ground truth.
- The mandatory, high-risk schema fixes identified in the Design Validation report (`04-design-validation-G02.md`).

The reviewer must identify every deviation — missing tables/columns/constraints, incorrectly applied fixes, extra database objects, syntax errors — and produce a structured review report with a clear readiness verdict.

This skill is executed **after** Step 5 DDL is produced and **before** proceeding to Step 6 (Sample Data). The goal is to catch implementation errors before data is inserted.

---

## 2. Required Inputs

All three documents must be loaded and fully read before any review begins:

| Input | File | Role |
|-------|------|------|
| Ground truth (schema) | `outputs/03-logical-design-G02.md` | What the DDL must implement |
| Mandatory fixes | `outputs/04-design-validation-G02.md` | Required deviations from Step 3 |
| Subject under review | `outputs/05-db-definition-G02.sql` | The actual DDL script |

If any file is absent, halt and request it.

---

## 3. Review Pipeline

Execute each check in order. For each check, produce a result of **PASS**, **WARN**, or **FAIL** with a specific justification. Cite exact line numbers, table names, column names, and constraint names where applicable. Do not produce vague summaries.

---

### Check 1 — Table Completeness

**Procedure:**
1. Extract the list of table names from Step 3 (§2 Table Schema Specifications).
2. Parse the DDL script and extract all `CREATE TABLE` table names.
3. Compare. Flag any table from Step 3 that is missing in the DDL (omission) or any table in the DDL that is not in Step 3 (invention).

**Pass condition:** DDL table set = Step 3 table set exactly. Count must match.

**Common failure modes:**
- Missing a table entirely.
- Extra table not defined in Step 3.
- Table name case mismatch (SQL Server is case-insensitive but traceability requires exact match).

---

### Check 2 — Column Completeness and Accuracy

**Procedure:**
For each table in Step 3, compare its columns against the DDL `CREATE TABLE` statement column by column.

| Sub-check | What to verify |
|-----------|----------------|
| 2a. No omissions | Every column from Step 3 appears in the DDL table. |
| 2b. No inventions | No column in the DDL is absent from Step 3. |
| 2c. Name fidelity | Column names match Step 3 exactly (same case and spelling). |
| 2d. Data type fidelity | Data type matches Step 3 exactly (e.g., `VARCHAR(50)` not `VARCHAR(50)` vs `VARCHAR(50)` — be careful with spaces, case of `INT` vs `int`). SQL Server is case-insensitive for types, but traceability requires match. |
| 2e. Nullability fidelity | `NOT NULL` / `NULL` matches Step 3. |
| 2f. Default value fidelity | If Step 3 specifies a default, the DDL must have an equivalent `DEFAULT` constraint. The expression must match exactly (e.g., `GETDATE()` not `CURRENT_TIMESTAMP` unless equivalent). |

**Pass condition:** All sub-checks pass for every column in every table.

---

### Check 3 — Primary Key Coverage

**Procedure:**
1. For each table in Step 3, extract the primary key column(s) and the primary key constraint name (if specified).
2. In the DDL, locate the primary key definition (inline or separate `CONSTRAINT PK_... PRIMARY KEY`).
3. Verify:
   - A primary key exists.
   - The key column(s) match Step 3.
   - The constraint name follows the naming convention (if Step 3 specifies a name, use it; otherwise, check that the generated name matches the pattern `PK_<Table>`).

**Pass condition:** Every table has exactly the primary key columns defined in Step 3.

---

### Check 4 — Foreign Key Coverage and Referential Actions

**Procedure:**
1. For each foreign key relationship described in Step 3 (from relationship mapping or explicit FK declarations), extract:
   - Child table and column(s)
   - Parent table and column(s)
   - `ON DELETE` action
   - `ON UPDATE` action
2. In the DDL, find the corresponding `FOREIGN KEY` constraint.
3. Verify:
   - The FK exists.
   - The column mapping is correct.
   - The `ON DELETE` action matches Step 3 **unless** a mandatory Step 4 fix changes it (see Check 6).
   - The `ON UPDATE` action:
    - If Step 3 explicitly specifies an action, the DDL must match exactly.
    - If Step 3 is silent, the DDL may use either `ON UPDATE NO ACTION` (SQL Server default) or `ON UPDATE CASCADE` for foreign keys where the referenced column is a primary key and updates are rare or semantically safe (e.g., junction tables). This is a matter of implementation discretion and **must not** be flagged as an issue. Only flag if the action is clearly wrong (e.g., `SET NULL` on a non-nullable column).
   - The constraint name follows the pattern `FK_<Child>_<Parent>`.

**Pass condition:** All foreign keys from Step 3 are present with correct columns, references, and referential actions (after applying mandatory fixes).

---

### Check 5 — Other Constraints (UNIQUE, CHECK, DEFAULT)

**Procedure:**
- For each `UNIQUE` constraint in Step 3, verify it exists in the DDL with the correct column(s) and name pattern `UQ_<Table>_<Column>`.
- For each `CHECK` constraint in Step 3, verify it exists in the DDL with the exact same condition (string-compare after normalising whitespace) and name pattern `CK_<Table>_<Description>`.
- For each `DEFAULT` constraint in Step 3, verify it exists on the correct column with the same default expression and name pattern `DF_<Table>_<Column>`.

**Pass condition:** All constraints from Step 3 are present and correct.

---

### Check 6 — Mandatory Fixes from Step 4 (High Risk)

**Procedure:**
1. Parse the Step 4 validation report. Locate all issues that satisfy the mandatory fix criteria:
   - Classified as **High Risk**
   - Violates a business rule
   - Requires a database schema change
2. For each such fix, determine the expected change (e.g., change `ON DELETE CASCADE` to `ON DELETE NO ACTION` on `USAGESESSION.booking_id`).
3. Verify that the DDL implements the change exactly as recommended.
4. Also verify that the DDL includes a SQL comment documenting the fix (as required by the Step 5 skill).

**Pass condition:** Every mandatory fix is correctly applied and documented. If a fix is missing or incorrectly applied, mark as **FAIL** and specify the exact deviation.

**Common failure modes:**
- Forgetting to change a CASCADE to NO ACTION.
- Changing the wrong foreign key.
- Applying the fix but omitting the required comment.

---

### Check 7 — Purity (No Extra Database Objects)

**Procedure:**
Scan the DDL script for any database object not present in Step 3 and not required by a mandatory Step 4 fix. This includes:

- Extra tables
- Extra columns
- Extra foreign keys
- Extra unique constraints
- Extra check constraints
- Extra default constraints
- Indexes (`CREATE INDEX`, `CREATE CLUSTERED INDEX`, etc.)
- Views
- Triggers
- Stored procedures
- Functions

**Pass condition:** Zero extra objects. Any extra object is a FAIL.

**Note:** Comments, whitespace, and `GO` separators are not considered extra objects.

---

### Check 8 — SQL Server Syntax and Compatibility

**Procedure:**
Parse the DDL script for SQL Server correctness:

| Rule | What to check |
|------|---------------|
| Cleanup statements | `DROP TABLE IF EXISTS` used for every table, in reverse dependency order. |
| `GO` separators | Present after cleanup section and after each `CREATE TABLE`. |
| Reserved keyword handling | Any identifier that matches a SQL Server reserved keyword (e.g., `USER`, `ORDER`, `GROUP`) must be delimited with square brackets: `[USER]`. |
| Data type validity | All data types are valid for SQL Server (e.g., `NVARCHAR(MAX)`, `DATETIME`, `INT`, `VARCHAR(n)`). |
| Constraint syntax | Constraints are correctly attached to tables (inline or `ALTER TABLE`). |
| No sample data | No `INSERT`, `UPDATE`, `DELETE`, or `MERGE` statements. |
| Idempotence | Script can be executed multiple times without error (due to `DROP TABLE IF EXISTS`). |

**Pass condition:** No syntax errors, all SQL Server compatibility rules satisfied.

---

### Check 9 — Naming Convention Compliance

**Procedure:**
Check that every constraint name follows the pattern defined in the Step 5 skill:

| Constraint Type | Pattern | Example |
|----------------|---------|---------|
| Primary Key | `PK_<Table>` | `PK_USER` |
| Foreign Key | `FK_<Child>_<Parent>` | `FK_BOOKING_USER` |
| Unique | `UQ_<Table>_<Column>` | `UQ_USER_EMAIL` |
| Check | `CK_<Table>_<Description>` | `CK_BOOKING_STATUS` |
| Default | `DF_<Table>_<Column>` | `DF_BOOKING_CREATED_AT` |

**Pass condition:** All constraints follow the naming convention exactly. Any deviation is a FAIL.

---

## 4. Review Report Format

> **OUTPUT PATH — MANDATORY**
> Save the review report to: `docs/05-db-definition-review-G02.md`
> Do NOT write to `outputs/` or any other directory.

Produce the review report as a Markdown file with this structure:

```markdown
# Step 5 DDL Review Report

---

## Verdict

<One of: APPROVED / APPROVED WITH MINOR ISSUES / REQUIRES REVISION>

<Two to four sentences summarising the overall finding.>

---

## Check Results

| Check | Description | Result | Issues Found |
|-------|-------------|--------|---------------|
| 1 | Table Completeness | PASS/WARN/FAIL | count |
| 2 | Column Completeness & Accuracy | PASS/WARN/FAIL | count |
| 3 | Primary Key Coverage | PASS/WARN/FAIL | count |
| 4 | Foreign Key Coverage & Referential Actions | PASS/WARN/FAIL | count |
| 5 | Other Constraints (UNIQUE, CHECK, DEFAULT) | PASS/WARN/FAIL | count |
| 6 | Mandatory Fixes from Step 4 | PASS/WARN/FAIL | count |
| 7 | Purity (No Extra Objects) | PASS/WARN/FAIL | count |
| 8 | SQL Server Syntax & Compatibility | PASS/WARN/FAIL | count |
| 9 | Naming Convention Compliance | PASS/WARN/FAIL | count |

---

## Detailed Findings

### Check N — <Name>
**Result:** PASS / WARN / FAIL

<For PASS: one sentence confirming what was verified.>
<For WARN or FAIL: itemised list of specific issues. Each issue must cite:>
- The exact element (table name, column name, constraint name)
- What was found in the DDL (line number or excerpt)
- What was expected per Step 3 or Step 4 (cite section)
- Severity: BLOCKING (must fix before Step 6) or ADVISORY (should fix, non-blocking)

---

## Required Changes Before Step 6

<Numbered list of all BLOCKING issues only, each with a specific correction instruction.>
<If no blocking issues: state "None — DDL is cleared to proceed to Step 6.">

---

## Recommended Improvements

<Numbered list of ADVISORY issues only. These do not block Step 6 but should be addressed.>
<If none: state "None.">
```
## 5. Verdict Criteria

| Verdict | Condition |
|---------|-----------|
| **APPROVED** | All 9 checks PASS. No issues of any severity. |
| **APPROVED WITH MINOR ISSUES** | All checks PASS or WARN. Zero FAIL results. Zero BLOCKING issues. Advisory issues documented. |
| **REQUIRES REVISION** | Any check returns FAIL, OR any BLOCKING issue is found regardless of check result. DDL must be corrected and re‑reviewed before Step 6. |

If the verdict is REQUIRES REVISION, the agent must:

1. List every blocking issue clearly.
2. Provide a corrected DDL snippet or full script (if requested) that resolves all blocking issues.
3. Re‑run checks 1–9 on the corrected DDL and confirm all blocking issues are resolved.

**Anti‑rubber‑stamp rule:** An APPROVED verdict is only valid if the reviewer has explicitly shown its work for Check 4 (foreign key actions) and Check 6 (mandatory fixes). A verdict issued without verifying every foreign key action against Step 3/Step 4 is invalid.

---

## 6. Reviewer Stance

The reviewer must treat Step 3 (Logical Design) as the primary source of truth, with Step 4 mandatory fixes as the only permitted deviations. It is not the reviewer's role to suggest design improvements or add missing constraints not required by the business rules — only to verify that the DDL faithfully implements what was approved.

The reviewer must not:

- Accept missing foreign keys because "they are implied by the relationship mapping."
- Overlook incorrect referential actions (e.g., `ON DELETE CASCADE` when Step 4 requires `NO ACTION`).
- Skip checking default values or check constraints because "they look right."
- Approve a DDL that has any BLOCKING issue, regardless of how minor it appears.

The reviewer must be constructive: every FAIL or WARN finding includes a specific, actionable correction instruction, not just a description of what is wrong.

---
## 7. Example: Verifying a Mandatory Foreign Key Fix

If Step 3 defines a foreign key with a certain referential action (e.g., `ON DELETE CASCADE`), and Step 4 mandates changing it (e.g., to `ON DELETE NO ACTION` to preserve history), then the reviewer expects the DDL to use the corrected action. Any deviation is a **BLOCKING** issue.

The reviewer must not simply check that a foreign key exists; they must verify that its `ON DELETE` and `ON UPDATE` actions match Step 3, unless overridden by a mandatory Step 4 fix.