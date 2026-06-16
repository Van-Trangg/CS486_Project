---
name: db-review-step6
description: Instructs the agent to act as an independent reviewer and systematically validate a generated sample data SQL script against the DDL, BRA, and logical design for any relational database project.
compatibility: opencode
---

## 1. Purpose

This skill instructs the agent to act as an independent reviewer and validate the sample data script produced in Step 6 against three authoritative sources:

- The approved DDL (Step 5) — schema and constraint compliance
- The approved BRA (Step 1) — business rule and scenario coverage
- The logical design (Step 3) — referential integrity and nullability rules

The reviewer must identify every deviation — invalid values, missing scenarios, FK violations, constraint breaches, data quality issues — and produce a structured report with a clear readiness verdict.

This review is executed **after** Step 6 is produced and **before** Step 7 (Query Design). Its purpose is to guarantee that all queries in Step 7 execute against valid, meaningful, and sufficiently varied data.

---

## 2. Required Inputs

All documents must be located and fully read before any review begins:

| Input | Role |
|---|---|
| Step 5 DDL (`05-db-definition-G02.sql`) | Authoritative column names, types, CHECK values, FK relationships, IDENTITY columns |
| Step 1 BRA (`01-business-req-analysis-G02.md`) | Business rules (§7), assumptions (§8), actor roles, status enumerations |
| Step 3 Logical Design (`03-logical-design-G02.md`) | Nullability rules, referential integrity actions, FK dependency order |
| Step 6 Sample Data (`06-sample-data-G02.sql`) | The INSERT script under review |

If any file is absent, halt and request it. Do not proceed from memory.

---

## 3. Pre-Review: Schema and Rule Extraction

Before any check, the reviewer must build two reference structures **from the source documents only**:

**3a. Schema Reference** (from DDL):  
For every table: column names, types, NOT NULL/NULL status, every CHECK constraint with its full list of allowed values (preserve case, spacing, punctuation), DEFAULT values, PK definition, FK definitions, IDENTITY columns.

**3b. Business Rule Reference** (from BRA §7 and §8):  
List every business rule that has a structural or data implication. For each, note:
- What data condition it requires or forbids
- Which table(s) and column(s) it involves
- Whether it is a hard constraint (FAIL if violated) or a soft guideline (WARN if violated)

The reviewer must **not** rely on memory or the verification comments inside the SQL file. The SQL file's `-- VERIFICATION REPORT` block is **not authoritative**; it is part of the submission and must be verified like any other data.

---

## 4. Review Checks

Execute each check in order. For each check, produce a result of **PASS**, **WARN**, or **FAIL** with specific justification. Cite exact table names, column names, row values, and source document references. Do not produce vague summaries.

---

### Check 1 — Insertion Order and Identity Handling

**Procedure:**
1. From the DDL FK graph, derive the valid topological insertion order.
2. Verify that the INSERT script follows this order (every parent table is populated before its child tables).
3. Identify every table with an IDENTITY (auto-increment) PK column.
4. Verify that every such table's INSERT block is wrapped with the appropriate DBMS override syntax (e.g., `SET IDENTITY_INSERT [TABLE] ON/OFF` for SQL Server).
5. Verify that every `ON` has a matching `OFF`.

**Pass condition:** Topological order respected. All IDENTITY tables wrapped correctly with matching ON/OFF pairs.

---

### Check 2 — Schema Column Compliance

**Procedure:**
For every INSERT statement in the script, verify:

| Sub-check | What to verify |
|---|---|
| 2a. Column names | Every column name in the INSERT matches the DDL exactly (case, spelling, bracketing) |
| 2b. Column count | The number of values in each VALUES row matches the number of columns declared in the INSERT column list |
| 2c. NOT NULL coverage | Every column declared NOT NULL in the DDL either appears in the INSERT column list or has a DEFAULT value in the DDL |
| 2d. No invented columns | No column name in any INSERT is absent from the DDL table definition |

**The reviewer must produce a per-table compliance checklist** – a global "looks correct" statement is not acceptable.

**Pass condition:** All sub-checks pass for all tables.

---

### Check 3 — CHECK Constraint Compliance (Enum Values)

**Procedure:**
From the DDL, extract every CHECK constraint that restricts a column to an enumerated set of values.

**Important:** The reviewer must **parse the INSERT statements** to collect the actual values used. Do **not** trust the `-- VERIFICATION REPORT` comments inside the SQL file. If the submitted SQL file claims `PASS` but the data is missing values, that is a **FAIL** for Check 11 (accuracy of self‑reporting).

For each such column, the reviewer must:
1. List all allowed values exactly as written in the CHECK constraint (preserve case, spacing, punctuation).
2. **Scan every INSERT statement** for that table and column to collect the distinct values that actually appear.
3. Confirm every used value matches one of the allowed values (case‑sensitive, spacing‑sensitive, hyphen‑sensitive).
4. Report any value in the data that is **not** in the allowed list – this is a **FAIL** (runtime error).

**The reviewer must produce this table:**

| Table | Column | Allowed Values (from DDL CHECK) | Distinct Values Found in INSERTs | All Valid? |
|---|---|---|---|---|
| ... | ... | ... | ... | Yes / No (if No, list invalid values) |

**Pass condition:** Every inserted enum value exactly matches one of the DDL CHECK constraint allowed values for that column.

---

### Check 4 — Referential Integrity

**Procedure:**
From the DDL, extract every FK relationship. For every FK column in every child table, collect all PK values inserted into the parent table and verify that every non‑NULL FK value in the child table matches an existing parent PK.

**The reviewer must produce this table:**

| Child Table | FK Column | Parent Table | Parent PK Column | All FK Values Resolvable? |
|---|---|---|---|---|
| ... | ... | ... | ... | Yes / No |

For nullable FK columns: `NULL` is always valid. Only non‑NULL values must be verified.

**Pass condition:** Every non‑NULL FK value resolves to an existing PK in the parent table. Any unresolvable FK is a FAIL (runtime constraint error).

---

### Check 5 — Temporal Constraint Compliance

**Procedure:**
From the DDL, identify every CHECK constraint of the form `end_column > start_column` (or equivalent). For every table containing such a constraint, list every row with its start and end timestamp values and confirm the ordering is satisfied where both values are non‑NULL.

**The reviewer must enumerate every row individually** – a blanket "all timestamps look fine" is not acceptable.

**Pass condition:** All temporal ordering constraints satisfied in all rows where both columns are non‑NULL.

---

### Check 6 — Business Rule Compliance

**Procedure:**
Using the business rule reference built in §3b, check each rule against the data. For every rule with a data implication:

1. State the rule (cite BRA section).
2. Describe the check performed.
3. List the rows evaluated.
4. State whether the rule is satisfied.

**The following rule categories apply to most booking/reservation-style systems — adapt to the actual BRA rules:**

| Rule Category | What to Check |
|---|---|
| **Conflict prevention** | No two active/approved records for the same resource overlap in time or conflict by any other dimension specified in the BRA |
| **Conditional field population** | Fields described as "populated only when status is X" are non‑NULL when status = X and NULL otherwise |
| **Approver/actor role constraints** | Any field that must reference a user of a specific role references a user with the correct role |
| **Unavailability enforcement** | No active/approved records reference a resource that is in an unavailable/blocked/retired state, unless explicitly allowed for historical data |
| **Lifecycle state consistency** | Records in terminal states (completed, resolved, cancelled) have the appropriate final fields populated; records in initial states do not |
| **Numeric limit constraints** | Any field that is bounded by another field (e.g., participant count ≤ capacity) is within bounds |
| **Child record existence rules** | Any BRA rule stating "a record in status X must have a child record Y" or "must not have child record Y" is satisfied |

For **conflict prevention**: the reviewer must enumerate every pair of records sharing the same resource and confirm no overlap. A blanket statement is not acceptable.

**Pass condition:** All business rules from BRA §7 and §8 that have data implications are satisfied in the sample data.

---

### Check 7 — Scenario Coverage

**Procedure:**
From the BRA, derive the complete set of business scenarios that the sample data should cover. These include:
- All normal operation scenarios (lifecycle states from initial to completed)
- All exceptional/edge case scenarios (unavailable states, null optional fields, constraint-boundary cases, soft‑deleted or retired records)
- All status/enum values that represent inactive, blocked, or error conditions

For each scenario, verify it is demonstrably present in the data. The reviewer must produce a scenario coverage matrix:

| # | Scenario Description | Coverage Criterion | Present in Data? |
|---|---|---|---|
| ... | ... | ... | Yes / No |

The scenario list must be derived dynamically from the BRA. It must **not** be a generic list copied from this skill file. The reviewer reads the BRA and enumerates the scenarios specific to this project.

**Pass condition:** Every scenario is present and identifiable in the data. Missing scenarios are a FAIL if they represent required business rule coverage, or a WARN if they are supplementary.

---

### Check 8 — Enum Domain Coverage (Every Allowed Value Appears)

**Procedure:**
For every column with an enumerated CHECK constraint, verify that the sample data includes **at least one row** using **each allowed value**. This is a stronger requirement than Check 3 (which only checks that used values are valid). Here we require **complete coverage**.

**The reviewer must produce this table:**

| Table | Column | Allowed Values (from DDL CHECK) | Distinct Values Found in INSERTs | Missing Values (if any) |
|---|---|---|---|---|
| ... | ... | ... | ... | ... |

If any allowed value is missing, mark that row as **FAIL** (unless the BRA explicitly states that value is optional for sample data – but by default, all allowed values should appear to test queries).

**Pass condition:** Every allowed value appears at least once in the data. Missing values are a FAIL.

---

### Check 9 — Data Volume and Query Usefulness

**Procedure:**
Assess whether the data volume is sufficient for meaningful query testing in Step 7:

| Sub‑check | What to verify |
|---|---|
| 9a. Non‑trivial aggregations | Aggregation queries (COUNT, AVG, GROUP BY) would return multiple groups with multiple rows each, not a single‑row result |
| 9b. Relationship breadth | At least one parent entity has multiple child records; relationships are not all 1‑to‑1 in practice |
| 9c. Filtering usefulness | Filter queries (WHERE status = X, WHERE role = Y) would return a non‑empty subset, not the entire table or an empty set |
| 9d. Join coverage | Join queries across multiple tables would return meaningful result sets, not empty or trivially small ones |
| 9e. Historical depth | Data spans enough time periods that time‑based queries (recent vs. past, upcoming vs. past) would return non‑empty results on both sides |

**Pass condition:** All sub‑checks pass. Insufficient data volume is a WARN if queries would still function but return trivial results; it is a FAIL if key query types would return empty result sets.

---

### Check 10 — Data Realism and Quality

**Procedure:**

| Sub‑check | What to verify |
|---|---|
| 10a. No placeholder data | No values like `'User1'`, `'test@test.com'`, `'Room A'`, `'note'`, `'description here'`, or any obvious placeholder |
| 10b. Realistic identifiers | IDs follow a structured pattern consistent with the system's domain |
| 10c. Realistic names and emails | Human names and email addresses are plausible; emails follow a consistent domain pattern |
| 10d. Realistic numeric values | Numeric fields (capacities, counts, quantities) are plausible for the domain |
| 10e. Realistic dates and times | Timestamps are in plausible date ranges for the domain; business‑appropriate hours used |
| 10f. Domain‑consistent combinations | Record combinations make sense in context (e.g., the purpose of a booking matches the type of space and role of the requester) |

**Pass condition:** All sub‑checks pass. Placeholder data is a WARN. Logically inconsistent combinations are a WARN.

---

### Check 11 — SQL Syntax, Executability, and Self‑Report Accuracy

**Procedure:**

| Sub‑check | What to verify |
|---|---|
| 11a. Single‑quote escaping | Strings containing a literal single quote use `''` (two single quotes), not `\'` |
| 11b. DateTime literal format | All datetime literals use a format accepted by the target DBMS (ISO 8601 recommended) |
| 11c. NULL syntax | `NULL` used (not `'NULL'`, `''`, or `0`) for nullable columns with no value |
| 11d. GO / batch separators | Batch separators (`GO` for SQL Server, or equivalent) present between DDL sections and INSERT sections |
| 11e. IDENTITY_INSERT pairing | Every `SET IDENTITY_INSERT [TABLE] ON` has a corresponding `SET IDENTITY_INSERT [TABLE] OFF` |
| 11f. No duplicate PKs | No two rows in the same table share the same PK value |
| 11g. No duplicate composite PKs | No two rows in a junction/associative table share the same composite PK combination |
| 11h. Column list present | Every INSERT has an explicit column list (not bare `VALUES` without column names) |
| 11i. Self‑report accuracy | The `-- VERIFICATION REPORT` comments (if present) must match the actual data. If the report claims `PASS` for enum coverage but values are missing, this is a FAIL. |

**Pass condition:** No syntax issues that would cause runtime errors. Any issue causing a runtime failure is a FAIL. Self‑report inaccuracies are a FAIL.

---

## 5. Review Report Format

> **OUTPUT PATH — MANDATORY**
> Save the review report to:
>
> `docs/06-sample-data-review-G02.md`
>
> Do NOT write to `outputs/` or any other directory.

Produce the report with this structure:

```markdown
# Step 6 Review Report — Sample Data Validation

---

## Verdict

<One of: APPROVED / APPROVED WITH MINOR ISSUES / REQUIRES REVISION>

<Two to four sentences summarising the overall finding.>

---

## Check Results Summary

| Check | Description | Result | Issues Found |
|---|---|---|---|
| 1  | Insertion Order & Identity Handling | PASS/WARN/FAIL | <n> issues |
| 2  | Schema Column Compliance | PASS/WARN/FAIL | <n> issues |
| 3  | CHECK Constraint Compliance | PASS/WARN/FAIL | <n> issues |
| 4  | Referential Integrity | PASS/WARN/FAIL | <n> issues |
| 5  | Temporal Constraint Compliance | PASS/WARN/FAIL | <n> issues |
| 6  | Business Rule Compliance | PASS/WARN/FAIL | <n> issues |
| 7  | Scenario Coverage | PASS/WARN/FAIL | <n> issues |
| 8  | Enum Domain Coverage | PASS/WARN/FAIL | <n> issues |
| 9  | Data Volume & Query Usefulness | PASS/WARN/FAIL | <n> issues |
| 10 | Data Realism & Quality | PASS/WARN/FAIL | <n> issues |
| 11 | SQL Syntax, Executability & Self‑Report | PASS/WARN/FAIL | <n> issues |

---

## Detailed Findings

### Check N — <Name>
**Result:** PASS / WARN / FAIL

<For PASS: one sentence confirming what was verified and how.>
<For WARN or FAIL: itemised list of specific issues. Each issue must include:>
- The exact row, column, or value affected
- What was found in the data
- What was expected (cite DDL, BRA section, or logical design section)
- Severity: BLOCKING (must fix before Step 7) or ADVISORY (non‑blocking)

[Include the mandatory output tables for Check 3, Check 4, Check 5, Check 6 conflict pairs, Check 7 scenario matrix, and Check 8 missing values list.]

---

## Required Changes Before Step 7

<Numbered list of all BLOCKING issues with specific correction instructions.>
<If none: "None — sample data is cleared to proceed to Step 7.">

---

## Recommended Improvements

<Numbered list of ADVISORY issues.>
<If none: "None.">
```
## 6. Verdict Criteria

| Verdict | Condition |
|---|---|
| **APPROVED** | All 11 checks PASS. No issues of any severity. |
| **APPROVED WITH MINOR ISSUES** | All checks PASS or WARN. Zero FAIL results. Zero BLOCKING issues. |
| **REQUIRES REVISION** | Any check returns FAIL, or any BLOCKING issue found regardless of check result. |

If the verdict is REQUIRES REVISION, the reviewer must:

1. List every blocking issue with row‑level correction instructions.
2. Produce corrected INSERT statements for every affected table (or reference the line numbers).
3. Re‑run all 11 checks on the corrected data and confirm resolution.

---

## 7. Anti‑Rubber‑Stamp Rules

The following mandatory exhibits must appear in the report. A verdict issued without them is **invalid**:

1. **Check 3:** The full CHECK constraint compliance table must list all allowed values and all distinct values found in the INSERTs for every constrained column.
2. **Check 4:** The full FK resolution table must be present for every FK relationship.
3. **Check 5:** Every row containing temporal columns must be individually listed and evaluated.
4. **Check 6:** For any conflict‑prevention rule, every relevant record pair must be enumerated and evaluated – not summarised.
5. **Check 7:** The full scenario coverage matrix must be present with a Yes/No for every scenario derived from the BRA.
6. **Check 8:** The full enum domain coverage table must list every allowed value and mark which are missing (if any).
7. **Check 11i:** If the submitted SQL file contains a `-- VERIFICATION REPORT`, the reviewer must explicitly note whether it is accurate. If inaccurate, that is a FAIL.

A blanket "everything looks fine" or "no issues found" statement without the supporting exhibits is a review failure, not a review result.

---

## 8. Reviewer Stance

The reviewer treats the DDL, BRA, and logical design as the joint authoritative sources. The reviewer must **not**:

- Accept enum values that are "close" to the allowed values (e.g., `'in progress'` when the DDL requires `'In Progress'`).
- Overlook a business rule violation because the intent is clear.
- Approve data that would fail at runtime, regardless of how minor the error appears.
- Skip any of the 11 checks.
- Omit any of the seven mandatory exhibits.
- Trust the `-- VERIFICATION REPORT` comments inside the SQL file without verifying them against the actual `INSERT` statements.

Every FAIL or WARN finding must include a specific, actionable correction instruction – not just a description of the problem.