# Step 3 Review Report — Logical Design Validation

---

## Verdict

## APPROVED

The logical database design (`outputs/03-logical-design-G02.md`) has been reviewed and is now approved. All database schema specifications, SQL Server DDL constraints, and traceability links are correct, robust, and aligned with the business requirements.

---

## Check Results

| Check | Description | Result | Issues Found |
|---|---|---|---|
| 1 | Table Mapping Completeness | PASS | 0 (after correction) |
| 2 | SQL Server Compatibility | PASS | 0 |
| 3 | Attribute Datatypes & Nullability | PASS | 0 (after correction) |
| 4 | Referential Integrity Constraints | PASS | 0 |
| 5 | DDL Check Constraints & Defaults | PASS | 0 (after correction) |
| 6 | Traceability Matrix Accuracy | PASS | 0 (after correction) |
| 7 | Document Consistency & Formatting | PASS | 0 (after correction) |

---

## Detailed Findings & Evolution

### Check 1 — Table Mapping Completeness
* **Initial AI Output:** The AI correctly mapped all major entities. However, for the many-to-many relationship `Space_Equipped_With_Facility`, it modeled the associative table `SPACE_FACILITY` with only two primary/foreign keys (`space_code`, `facility_id`), completely omitting the ability to track quantities or equipment condition.
* **Correction Process:** I prompted the AI to evaluate adding `quantity` and `operation_status`. With feedback from my teammate, we refined this to include three additional columns on the junction table: `quantity`, `operation_status`, and `description`.

### Check 2 — SQL Server Compatibility
* **Result:** PASS
* The SQL DDL commands utilize valid Microsoft SQL Server syntax (e.g. `ALTER TABLE... ADD CONSTRAINT`, `INT IDENTITY`, `NVARCHAR(MAX)`).

### Check 3 — Attribute Datatypes & Nullability
* **Initial AI Output:** The AI did not specify how description text or unicode notes would be stored for facility statuses.
* **Correction Process:** I guided the AI to define `description` as `NVARCHAR(500)` to ensure compatibility with Unicode text (for Vietnamese accents in room notes) and set it to `NULL` (optional), while keeping `quantity` as a mandatory `INT` and `operation_status` as `VARCHAR(30)`.

### Check 4 — Referential Integrity Constraints
* **Result:** PASS
* Junction table uses `ON DELETE CASCADE` appropriately. Historical logging tables (`BOOKING`, `MAINTENANCERECORD`) correctly use `ON DELETE NO ACTION` to ensure data auditability.

### Check 5 — Traceability Matrix Accuracy
* **Initial AI Output:** The new junction table attributes were not documented in the Traceability Matrix in Section 4.
* **Correction Process:** The matrix was updated to trace `quantity`, `operation_status`, and `description` to document where these relational attributes map.

### Check 6 — Document Consistency & Formatting
* **Initial AI Output:** The insertion of `SPACE_FACILITY` constraints caused the numbering of subsequent constraint headers to become out of sync (retaining old section numbers).
* **Correction Process:** The DDL comment section headers were re-numbered sequentially (from 4 to 7) to ensure logical consistency.

---

## Required Changes Before Step 4 (Physical Design)

None — The logical schema is fully approved and ready to be translated into MS SQL Server physical DDL scripts.
