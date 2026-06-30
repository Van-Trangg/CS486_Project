---
name: logical-design-review
description: Instructs the agent to act as an independent reviewer and validate the Logical Database Design document.
compatibility: opencode
---

# Logical Design Review Guidelines

This skill guides the review of the Logical Database Design (`outputs/03-logical-design-G02.md`) against the Conceptual Design ERD (`outputs/02-erd-design-G02.md`) and the Business Requirements (`outputs/01-business-requirement-analysis-G02.md`).

## Review Steps

1. **Table Mapping Completeness**:
   - Check that all ERD entities are mapped to relational tables.
   - Verify that Many-to-Many relationships are correctly resolved using junction tables.
   - Verify that One-to-One relationships are set up correctly.

2. **Naming and SQL Server Compatibility**:
   - Verify that table names are UPPERCASE singular and column names are lowercase `snake_case`.
   - Ensure all data types are valid Microsoft SQL Server types (e.g. `INT`, `NVARCHAR`, `DATETIME`).

3. **Data Types and Nullability**:
   - Ensure columns capable of storing Unicode text use `NVARCHAR`.
   - Check nullability constraints to make sure mandatory columns are `NOT NULL`.

4. **Referential Integrity**:
   - Check foreign key definitions and associated `ON DELETE`/`ON UPDATE` rules.
   - Ensure `ON DELETE CASCADE` is used for junction tables and `ON DELETE NO ACTION` is used for historical transaction logs to preserve data auditability.

5. **Constraints and Defaults**:
   - Verify check constraints restricting roles/statuses to valid enums.
   - Ensure range and logic checks are present (e.g., capacities/quantities > 0, end times > start times).
   - Verify default constraints (e.g., creation timestamps using `GETDATE()`).

6. **Traceability Matrix**:
   - Check that every column maps back to a valid ERD attribute and business requirement reference.

## Report Output

Save the review report to `docs/03-logical-design-review-G02.md` using the following format:

- **1. Verdict**: One of `APPROVED`, `APPROVED WITH MINOR ISSUES`, or `REQUIRES REVISION`.
- **2. Check Results**: A summary table of PASS, WARN, or FAIL for each of the steps above.
- **3. Detailed Findings**: Bullet points listing issues, severity (BLOCKING or ADVISORY), and details.
- **4. Required Changes**: List of blocking changes needed before approval.
