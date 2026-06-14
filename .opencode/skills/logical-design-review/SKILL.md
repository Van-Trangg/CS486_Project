---
name: logical-design-review
description: Instructs the agent to act as an independent reviewer and systematically validate a Logical Database Design document against the BRA and ERD.
compatibility: opencode
---

## 1. Purpose
This skill instructs the agent to act as an independent reviewer and systematically validate the Step 3 deliverable: Logical Database Design (`outputs/03-logical-design-G02.md`) against the Conceptual Design ERD (`outputs/02-erd-design-G02.md`) and the Business Requirement Analysis (`outputs/01-business-requirement-analysis-G02.md`). The reviewer must identify every deviation — missing, incorrect, or mismatched elements — and produce a structured review report with a clear readiness verdict.

This review is performed **after** the Step 3 Logical Design is produced and **before** proceeding to Step 4 (Design Validation).

---
## 2. Required Inputs
Before beginning the review, the agent must load and read:
- **Business Requirement Analysis (BRA):** `outputs/01-business-requirement-analysis-G02.md`
- **Conceptual Design (ERD):** `outputs/02-erd-design-G02.md`
- **Logical Database Design:** `outputs/03-logical-design-G02.md`

If any of these files is missing, halt and request it.

---
## 3. Review Pipeline
Execute each check in order. For each check, produce a result of PASS, WARN, or FAIL with a specific justification. Cite exact table names, column names, constraints, and sections.

### Check 1 — Table Mapping Completeness
**Procedure:**
1. Extract all entity names from the ERD (`outputs/02-erd-design-G02.md`).
2. Verify that each entity has a corresponding relational table in the logical design (`outputs/03-logical-design-G02.md`).
3. Verify that the many-to-many relationship `Space_Equipped_With_Facility` is resolved using a junction table named `SPACE_FACILITY`.
4. Validate that the `SPACE_FACILITY` junction table includes the following columns to capture additional relational attributes:
   - `quantity` (Mandatory/NOT NULL `INT` to track equipment quantities)
   - `operation_status` (Mandatory/NOT NULL `VARCHAR(30)` to track status)
   - `description` (Optional/NULL `NVARCHAR(500)` to store Vietnamese accent/Unicode notes for equipment condition)

**Pass condition:** All ERD entities are mapped to tables, and the junction table includes all required relational columns.

---
### Check 2 — SQL Server Compatibility
**Procedure:**
Verify the relational schema naming and syntax compatibility with Microsoft SQL Server:
1. **Naming Conventions**:
   - Table names must be UPPERCASE singular (e.g., `USER`, `SPACE`, `BOOKING`, `USAGESESSION`, `MAINTENANCERECORD`, `SPACE_FACILITY`).
   - Column names must be lowercase `snake_case` (e.g., `user_id`, `space_code`, `facility_id`).
2. **SQL Server Syntax & Types**:
   - Ensure the data types specified are valid MS SQL Server types (e.g., `INT IDENTITY`, `NVARCHAR(n)`, `DATETIME`).
   - Ensure there are no generic or incompatible database types (e.g., `string`, `text`, or MySQL-specific type syntax).

**Pass condition:** Table and column names strictly adhere to naming conventions, and all types are valid MS SQL Server datatypes.

---
### Check 3 — Attribute Datatypes & Nullability
**Procedure:**
For each table, inspect the column specifications table in Section 2 of `outputs/03-logical-design-G02.md`:
1. Verify that the SQL Server data types correspond correctly to the ERD attributes and BRA.
2. Check that description/note columns capable of storing Unicode characters (such as room notes or user descriptions) utilize Unicode-compatible data types (`NVARCHAR` with a length or `NVARCHAR(MAX)`), rather than non-Unicode `VARCHAR`.
3. Check the nullability (NULL vs. NOT NULL) for each column. Primary keys and mandatory fields must be `NOT NULL`.

**Pass condition:** All columns have correct data types, appropriate Unicode storage where needed, and accurate nullability settings.

---
### Check 4 — Referential Integrity Constraints
**Procedure:**
Verify foreign key mappings and referential actions:
1. **1:1 Relationship Mapping**: For `BOOKING` to `USAGESESSION` (1:1), the primary key of `USAGESESSION` must be `booking_id`, referencing `BOOKING(booking_id)`.
2. **Junction Table Primary Key**: The primary key of `SPACE_FACILITY` must be a composite key `(space_code, facility_id)`.
3. **ON DELETE/UPDATE Actions**:
   - `USAGESESSION` referencing `BOOKING`: `ON DELETE CASCADE` and `ON UPDATE CASCADE`.
   - `SPACE_FACILITY` referencing `SPACE` and `FACILITY`: `ON DELETE CASCADE`.
   - Historical logging/transactional tables (`BOOKING`, `MAINTENANCERECORD`) referencing tables like `USER` or `SPACE`: Must use `ON DELETE NO ACTION` and `ON UPDATE NO ACTION` to ensure historical logs are preserved (preventing cascading deletions of audit logs).

**Pass condition:** Key mappings and ON DELETE/UPDATE actions are correctly specified according to referential integrity rules.

---
### Check 5 — DDL Check Constraints & Defaults
**Procedure:**
Verify that all CHECK and DEFAULT constraints in Section 3 of `outputs/03-logical-design-G02.md` match the required rules:
1. **Check Constraints (Value Enums)**:
   - `USER(role)`: IN ('Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager')
   - `USER(account_status)`: IN ('Active', 'Suspended', 'Inactive')
   - `SPACE(space_type)`: IN ('Auditorium', 'Classroom', 'Computer Laboratory', 'Project Laboratory', 'Meeting Room', 'Student Workspace')
   - `SPACE(current_status)`: IN ('Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired')
   - `BOOKING(purpose)`: IN ('Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event')
   - `BOOKING(booking_status)`: IN ('Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-Show')
   - `MAINTENANCERECORD(problem_type)`: IN ('Projector Failure', 'Air-Conditioning Issue', 'Cleaning Issue', 'Furniture Damage', 'Network Issue', 'Other')
   - `MAINTENANCERECORD(maintenance_status)`: IN ('Reported', 'In Progress', 'Resolved', 'Cancelled')
2. **Check Constraints (Range/Logic Rules)**:
   - `SPACE(capacity)`: > 0
   - `BOOKING(expected_participants)`: > 0
   - `BOOKING(requested_end)`: > `requested_start`
   - `USAGESESSION(actual_end)`: > `actual_start` (if not NULL)
   - `MAINTENANCERECORD(completion_time)`: > `start_time` (if not NULL)
3. **Default Constraints**:
   - `BOOKING(created_at)`: Defaults to `GETDATE()`.

**Pass condition:** All value enums, ranges, date comparisons, and defaults match these lists verbatim.

---
### Check 6 — Traceability Matrix Accuracy
**Procedure:**
Verify the Traceability Matrix in Section 4 of `outputs/03-logical-design-G02.md`:
1. Check that every column in every table is documented in the matrix.
2. Verify that junction table columns (including `quantity`, `operation_status`, and `description` in `SPACE_FACILITY`) are mapped to their respective attributes and requirements.
3. Cross-reference the mappings to ensure they accurately trace columns to ERD attributes and BRA requirements.

**Pass condition:** Every schema column has an accurate traceability mapping.

---
### Check 7 — Document Consistency & Formatting
**Procedure:**
1. Check the general layout against the template in `outputs/03-logical-design-G02.md`.
2. Ensure sections are numbered sequentially and no headings are skipped or out of order.
3. Confirm that no redundant conceptual diagrams (such as Mermaid ERDs) are included, as they belong strictly to Step 2.

**Pass condition:** Formatting is clean, headers are sequential, and there are no redundant diagrams.

---
## 4. Review Report Format

> **OUTPUT PATH — MANDATORY**
> Save the review report to: `docs/03-logical-design-review-G02.md`
> Do NOT write to `outputs/` or any other directory.

Produce the review report as a Markdown file with this structure:

```markdown
# Step 3 Review Report — Logical Design Validation

---

## Verdict

<One of: APPROVED / APPROVED WITH MINOR ISSUES / REQUIRES REVISION>

<Two to four sentences summarising the overall finding.>

---

## Check Results

| Check | Description | Result | Issues Found |
|---|---|---|---|
| 1 | Table Mapping Completeness | PASS/WARN/FAIL | <count> issues |
| 2 | SQL Server Compatibility | PASS/WARN/FAIL | <count> issues |
| 3 | Attribute Datatypes & Nullability | PASS/WARN/FAIL | <count> issues |
| 4 | Referential Integrity Constraints | PASS/WARN/FAIL | <count> issues |
| 5 | DDL Check Constraints & Defaults | PASS/WARN/FAIL | <count> issues |
| 6 | Traceability Matrix Accuracy | PASS/WARN/FAIL | <count> issues |
| 7 | Document Consistency & Formatting | PASS/WARN/FAIL | <count> issues |

---
## Detailed Findings

### Check N — <Name>
**Result:** PASS / WARN / FAIL

<For PASS: one sentence confirming what was verified.>
<For WARN or FAIL: itemised list of specific issues. Each issue must cite:>
- The exact element (table name, column name, constraint, or section)
- What was found in the logical design
- What was expected (refer to requirements or erd)
- Severity: BLOCKING (must fix before Step 4) or ADVISORY (should fix, non-blocking)

---

## Required Changes Before Step 4

<Numbered list of all BLOCKING issues only, each with a specific correction instruction.>
<If no blocking issues: state "None — Logical schema is cleared to proceed to Step 4.">

---

## Recommended Improvements

<Numbered list of ADVISORY issues only. These do not block Step 4 but should be addressed.>
<If none: state "None.">
```

---
## 5. Verdict Criteria

| Verdict | Condition |
|---|---|
| **APPROVED** | All 7 checks PASS. No issues of any severity. |
| **APPROVED WITH MINOR ISSUES** | All checks PASS or WARN. Zero FAIL results. Zero BLOCKING issues. Advisory issues documented. |
| **REQUIRES REVISION** | Any check returns FAIL, OR any BLOCKING issue is found regardless of check result. Logical design must be corrected and re-reviewed before Step 4. |

---
## 6. Reviewer Stance
The reviewer must treat the BRA and ERD as the authoritative source. It is not the reviewer's role to second-guess design decisions but to ensure the logical schema faithfully and cleanly implements them using MS SQL Server rules.
Every FAIL or WARN must include specific, actionable correction instructions.
