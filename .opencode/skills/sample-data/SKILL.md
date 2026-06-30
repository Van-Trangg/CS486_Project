---
name: sample-data-step6
description: Instructs the agent to produce a complete, realistic SQL INSERT script for any relational database project, dynamically derived from the approved DDL (Step 5), business requirement analysis (Step 1), and logical design (Step 3).
compatibility: opencode
---

## 1. Purpose
This skill instructs the agent to produce a comprehensive SQL `INSERT` script that populates every table defined in the Step 5 DDL with realistic, internally consistent sample data. The data must be large enough to support meaningful testing of normal operations, boundary conditions, and all important exceptional and edge cases — as established by the business rules in the BRA. The agent derives all schema details (table names, column names, allowed values, FK relationships) dynamically from the provided documents.

---

## 2. Required Inputs
Before beginning, the agent MUST locate and fully read the following documents from the project output directory:

| Input | Role |
|---|---|
| Step 5 DDL file (`05-db-definition-G02.sql`) | Authoritative schema: tables, columns, types, constraints, CHECK values, FK relationships, DEFAULT values |
| Step 1 BRA file (`01-business-req-analysis-G02.md`) | Business purpose, entities, attributes, business rules, actor roles, status enumerations |
| Step 3 Logical Design file (`03-logical-design-G02.md`) | Nullability rules, referential integrity actions, FK dependency order |

If any file is absent from the outputs directory, halt and request it. Do not proceed from memory or assumption.

---

## 3. Execution Pipeline
Execute the following stages in strict order. Do not skip or reorder steps.

### Stage 1 — Schema Extraction
Read the DDL file completely. For every table, dynamically extract and record:
- Table name (exact, with any quoting or bracketing used in the DDL)
- Every column name, data type, and length
- NOT NULL / NULL status of every column
- Every CHECK constraint and its full set of allowed values (enumerate all of them)
- Every DEFAULT constraint and its value
- Every PRIMARY KEY definition (simple or composite)
- Every FOREIGN KEY definition: child column → parent table and column
- Which columns are IDENTITY / auto-increment

This extracted information is the authoritative reference for all subsequent stages. Do not rely on memory for schema details.
**Do not add any tables, columns, or constraints that are not explicitly defined in the DDL.**

### Stage 2 — Insertion Order Resolution
From the FK relationships extracted in Stage 1, construct a valid topological insertion order so that every parent table is populated before any child table that references it. Record this order explicitly before proceeding.

If the schema contains circular FK references (rare), identify them and note that they require deferred constraint handling (e.g., inserting NULL first and updating later).

### Stage 3 — Coverage Planning
Before writing any INSERT, produce an explicit coverage plan covering two dimensions:

#### 3a. Enum Domain Coverage
For every column with a CHECK constraint that lists allowed values, the sample data MUST include at least one row using each allowed value. The agent must produce a coverage table before finalising the script. If any allowed value is missing, the generation is incomplete and must be corrected. The agent must maintain an explicit list of all allowed values for each enumerated column and check them off as rows are added. This list must be included in the verification report in Stage 5.1.

#### 3b. Scenario Coverage
Identify the full set of business scenarios the data must cover by reading BRA §7 (business rules) and §8 (assumptions). At minimum, plan for:

**Normal Operation Scenarios (every project should have these):**
- A record created in the initial/default state (e.g., a request just submitted)
- A record that has been fully processed through its lifecycle (approved, completed, resolved)
- A record that was declined or cancelled partway through
- At least one many-to-many relationship that has multiple associations on both sides

**Exceptional / Edge Case Scenarios (derive from BRA business rules):**
- Every status value that represents an unavailable, blocked, or inactive state must appear at least once
- A record with all optional (nullable) fields populated
- A record with all optional (nullable) fields left NULL
- At least one case where a business constraint *would* be violated if the system did not enforce it (e.g., a space that cannot be booked because it is unavailable — demonstrate this by having a space in that state with no conflicting approved bookings)
- At least one record that has been soft-deleted or retired (if the BRA describes soft-deletion)
- Any actor-specific restriction described in the BRA assumptions (e.g., only certain roles can approve) must be demonstrated correctly

**Lookup Domain Coverage:** For any lookup table whose domain is explicitly enumerated in the BRA (e.g., FACILITY.facility_name from BRA §4.3, BOOKING.purpose from BRA §4.4, MAINTENANCERECORD.problem_type from BRA §4.6), the sample data MUST contain every value listed in the BRA, and MUST NOT contain any value not listed. The agent must extract the exact set of required values from the BRA and verify that the INSERT statements include exactly those values – no substitutions, abbreviations, or extra items.

For each scenario, write a one-line description before writing data. The data must make every scenario unambiguously identifiable.

### Stage 4 — Data Volume Determination
Do not hardcode row counts. Instead, derive the minimum row count for each table as follows:

1. **Enum coverage floor:** The minimum is at least the number of distinct allowed values in the most constrained column of that table — so that every value appears at least once.
2. **Scenario coverage floor:** Add enough rows so that every scenario from Stage 3b is represented, including cases requiring multiple rows in combination (e.g., two bookings for the same space to demonstrate conflict prevention).
3. **Relationship coverage floor:** For any many-to-many or one-to-many relationship, ensure at least one parent has multiple children (not every parent has exactly one child).
4. **Query usefulness floor:** The data must be large enough that aggregation queries (counts, averages, groupings) return non-trivial results — at minimum 3–5 rows per logical grouping. Avoid data where every query returns a single row.

The resulting minimum is the **maximum** of these four floors per table. If the schema is complex (7+ tables, many enum columns), expect a minimum of 10–15 rows per central table and 5–10 rows per peripheral table.

### Stage 5 — Data Consistency Enforcement
Before writing any INSERT, define and record the consistency rules that apply to this schema, derived from the DDL constraints and BRA business rules. At minimum:

- **FK integrity:** Every FK value in a child table has a matching PK in the parent table.
- **CHECK compliance:** Every inserted enum value exactly matches one of the allowed values (case-sensitive, spacing-sensitive).
- **NOT NULL compliance:** No NOT NULL column receives a NULL value.
- **Time ordering:** All pairs of start/end timestamps must satisfy end > start (when both are non-NULL).
- **Uniqueness:** No two rows in the same table share the same primary key. No two rows in a junction table share the same composite PK.
- **Conditional field rules:** Any field that is described as "populated only when status is X" in the BRA must be NULL when the status is not X, and non-NULL when it is X.
- **Conflict prevention rules:** Any business rule in the BRA that prevents two records from overlapping or conflicting (e.g., double-booking prevention) must be honoured in the data.
- **Capacity or limit rules:** Any numeric constraint described in the BRA (e.g., participant count ≤ room capacity) must be satisfied.
- **Lifecycle Consistency:** If a parent table has a status column where a specific value logically implies that no further action can occur (e.g., 'Cancelled', 'No-Show', 'Rejected', 'Closed'), then any child table that records subsequent steps MUST NOT contain a row referencing that parent. The agent must derive such implications from the business rules in the BRA.

Apply all of these when writing data. Do not insert any row that violates them.

### Stage 6 — SQL Script Generation
Write the complete SQL INSERT script following these standards:

**File Header:**
```sql
-- ============================================================
-- Database: <Project Name>
-- Platform: <Target DBMS, e.g., Microsoft SQL Server>
-- Group: G02
-- Step 6: Sample Data Preparation
-- ============================================================
```

**Per-Table Sections:**
Precede each table's inserts with a section comment block:
```sql
-- ============================================================
-- Table: <TABLENAME>
-- Rows: <count>
-- Scenarios covered: <comma-separated list>
-- ============================================================
```

**IDENTITY / Auto-Increment Handling:**
For any table where the PK is an auto-incrementing identity column, use explicit ID values so child tables can reference them reliably. Wrap those INSERT blocks with the DBMS-appropriate override syntax. For Microsoft SQL Server:
```sql
SET IDENTITY_INSERT [TABLENAME] ON;
-- INSERT statements
SET IDENTITY_INSERT [TABLENAME] OFF;
GO
```
For other DBMS platforms, use the equivalent mechanism.

**INSERT Format:**
Use explicit column lists in every INSERT statement (never `INSERT INTO table VALUES (...)` without column names). After each table's INSERT block, include a `GO` statement on its own line.

Example:
```sql
INSERT INTO [TABLENAME] (col1, col2, col3) VALUES
    (val1a, val2a, val3a),
    (val1b, val2b, val3b),
    (val1c, val2c, val3c);
GO
```

**NULL Handling:**
- Use `NULL` (not `''`, `'NULL'`, or `0`) for nullable columns with no value.
- Do not insert DEFAULT-valued columns unless the test scenario requires a non-default value.

**String Values:**
- Enclose all string literals in single quotes.
- Escape any literal single quote inside a string with `''` (two single quotes).
- Enum values must match DDL CHECK constraint strings exactly, including capitalisation, spacing, and hyphens.

**DateTime Values:**
- Use ISO 8601 string literals: `'YYYY-MM-DD HH:MM:SS'`.
- Use realistic dates appropriate to the system's domain context (e.g., academic calendar dates for a university system, business hours for a booking system).
- Ensure all temporal ordering constraints are satisfied.

**Scenario Traceability:**
After each INSERT block or group of related rows, add a brief comment identifying which scenario(s) are covered:
```sql
-- [N2] Approved booking - room confirmed by staff
-- [E3] Space under maintenance - no approved bookings should overlap
```
The `.sql` file must **not** contain any markdown, HTML, or non‑SQL text outside of SQL comments (`--`). The verification report from Stage 5.1 must be included as SQL comments at the top of the file.
---

## 4. Data Realism Standards
Sample data must be realistic and recognisable, not placeholder text:
- **Names:** Use plausible human names appropriate to the institution's likely demographic context.
- **Identifiers:** Use structured identifiers consistent with how real systems assign them (e.g., `STU2023001` for student IDs, `CS-B2-F1-R101` for room codes).
- **Emails:** Use a consistent and plausible domain pattern.
- **Descriptions and notes:** Write brief but coherent prose, not `'test note'` or `'description here'`.
- **Dates and times:** Use realistic scheduling — business hours, semester periods, appropriate durations.
- **Numeric values:** Use values that reflect reality (e.g., room capacity of 30–200, not 1 or 9999).
- **Bookings**: All seeded Bookings with status "Completed" must still have `requested_start` and `requested_end` columns filled to simulate an "Approved" booking that had been approved, taken place and marked for completion.

Avoid: `'User1'`, `'test@test.com'`, `'Room A'`, `'note'`, `'description'`, or any other placeholder.

---

## 5. Self-Consistency Pre-Check
### 5.1 Mandatory Verification Output (as SQL Comments)

Before generating the final SQL script, the agent MUST produce a verification report as **SQL comments** at the top of the `.sql` file. This report must be included **inside the output file** (not in a separate chat message or markdown file).

The report must include:

- **Enum Coverage Report** – For each table and column with a CHECK constraint, list all allowed values and mark which are present using SQL comments (`--`).
- **Lookup Domain Coverage Report** – For each lookup table that has a defined set of values in the BRA, list all required values and mark which are present.
- **Verification Checklist** – A checklist of all items from Section 5.2, each marked `[x]` or `[ ]` as applicable.

The report must be placed immediately after the file header and before the `-- Cleanup` section. Example format:

```sql
-- ============================================================
-- Database: <Project Name>
-- Platform: <DBMS>
-- Group: G02
-- Step 6: Sample Data Preparation
-- ============================================================
--
-- VERIFICATION REPORT
-- ============================================================
-- Enum Coverage Report:
--   USER.role: Student[x], Lecturer[x], Teaching Assistant[x],
--              Facility Staff[x], Department Administrator[x], Facility Manager[x] -> PASS
--   ...
--
-- Lookup Domain Coverage Report:
--   FACILITY (BRA §4.3): Projector[x], Whiteboard[x], Microphone[x],
--                        Computer[x], Livestreaming Equipment[x], Air Conditioner[x] -> PASS
--   ...
--
-- Verification Checklist:
--   [x] Insertion order follows topological FK dependency order
--   [x] Every enum column has all allowed values
--   ...
-- ============================================================
-- Cleanup
-- ============================================================
```
Only after the verification report shows all checks PASS may the agent write the INSERT statements below.
---
### 5.2 Verification Checklist

**Mandatory Enforcement – Before Saving Output**

1. For every column with a CHECK constraint, the agent MUST **count the distinct values** that actually appear in the generated `INSERT` statements.
2. Compare the distinct set against the full list of allowed values extracted from the DDL.
3. If any allowed value is missing, the agent MUST **automatically add** the missing rows (or update existing ones) to include every missing value.
4. After adding missing data, **re-run all verification checks** (foreign keys, uniqueness, time ordering, conditional rules, etc.).
5. Only when **all checklist items pass** and **no enum value remains missing** may the agent save the final `.sql` file.

**Strict Prohibition:** The agent must NEVER mark a check as `PASS` when the actual data does not satisfy the requirement. Any discrepancy between the verification report and the actual data is a critical error.
```
[ ] Insertion order follows topological FK dependency order
[ ] Every enum column has all its allowed values represented at least once
[ ] Every lookup table that has a defined domain in the BRA (e.g., facility types, problem categories, purpose lists) contains **all** values listed in the BRA, not just a subset. For each such table, the agent must produce a list of required values from the BRA and compare against the inserted rows. If any required value is missing, the script is incomplete.
[ ] Every nullable column has at least one NULL and one non-NULL row
[ ] Every business scenario from Stage 3b is present and identifiable
[ ] No two rows violate any uniqueness constraint (PK, composite PK, UNIQUE)
[ ] All FK values resolve to existing PK values in parent tables
[ ] All time orderings valid (end > start for all non-NULL pairs)
[ ] All conflict-prevention rules honoured (no overlapping approved records, etc.)
[ ] All conditional field rules honoured (fields NULL/non-NULL per their conditions)
[ ] All capacity or limit constraints satisfied
[ ] IDENTITY_INSERT ON/OFF wraps all identity table inserts
[ ] Aggregation queries on this data would return non-trivial, varied results
[ ] No placeholder or lorem-ipsum data present
```

If any check fails, correct before writing the final output.

---

## 6. Common Pitfalls and Mitigations

The following issues were identified during real execution of this skill on the Campus Space Management System. They are documented here as general guidance for future runs.

### 6.1. AFTER INSERT Triggers That Block Sample Data

**Problem:** A trigger defined in the DDL may enforce a business rule using `RAISERROR ... ROLLBACK` on INSERT, making it impossible to insert sample rows that represent a later lifecycle stage.

*Example from CS486:* `TR_USAGESESSION_CHECK_BOOKING_STATUS` rejects USAGESESSION inserts unless the referenced booking has `booking_status = 'Approved'`. This blocks USAGESESSION rows for bookings at the `'Checked In'` or `'Completed'` stage.

**Mitigation — General approach:**

1. **Before writing INSERT statements, audit every AFTER INSERT trigger in the DDL.** For each trigger, determine which column values would cause it to roll back.
2. **If a child table has a trigger that checks a parent's column value**, the parent row must have the expected value when the child is inserted. This may require:
   - Setting the parent's status to the trigger-approved value (e.g., `'Approved'`) rather than the final lifecycle value.
   - Covering the skipped enum values (e.g., `'Completed'`, `'Checked In'`) on **separate parent rows that have no child rows**, so enum coverage is not lost.
3. **Document the constraint** in the verification report and in SQL comments adjacent to the affected INSERT block so future maintainers understand why certain status values were chosen.

### 6.2. Future-Time Triggers and Date Sensitivity

**Problem:** A trigger may reject inserts where a timestamp column is earlier than `GETDATE()` for certain actor types, making sample data with static dates execution-time-sensitive.

*Example from CS486:* `TR_BOOKING_FUTURE_START_ENFORCEMENT` rejects booking inserts where `requested_start < GETDATE()` for users whose role is not `'Facility Staff'` or `'Facility Manager'`.

**Mitigation — General approach:**

1. **Identify all triggers that compare a column to `GETDATE()`** during Stage 1 schema extraction. These are execution-time-sensitive.
2. **Choose sample dates sufficiently far in the future** from the expected script execution date. A general rule: use dates at least 6–12 months ahead of the project's current date to maximise the execution window.
3. **Document the date window** as a comment in the file header: `-- This script executes correctly if run before YYYY-MM-DD.`
4. **Accept the inherent limitation.** Sample data with static dates can never be future-proof against an arbitrary execution date. This is a property of the problem, not a defect in the data.

### 6.3. Conditional Field Rules vs. Lifecycle State

**Problem:** A column may be required (non-NULL) only when a related status column has a specific value, but the lifecycle state needed for a different constraint contradicts that requirement.

*Example from CS486:* `approver_id` should be non-NULL for any non-Pending booking, but a booking at the `'Pending'` stage must have `approver_id = NULL`. If enum coverage requires a `'Pending'` row, that row must have all conditional-NULL fields set to NULL, even if other scenarios would populate them.

**Mitigation — General approach:**

1. **Identify all conditional field rules** from the BRA and DDL during Stage 5.
2. **Ensure at least one row per status value satisfies the NULL/NOT NULL condition** for that status. If a status value requires NULL (e.g., `'Pending'` → `approver_id IS NULL`), the sample data for that row must have NULL.
3. **If a single row cannot simultaneously satisfy two conflicting requirements**, split across multiple rows.

---

## 7. Output
Save the output as: `outputs/06-sample-data-G02.sql`