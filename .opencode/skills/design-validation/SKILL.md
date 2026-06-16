---
name: design-validation
description: Instructs the agent to evaluate whether the Logical Database Design correctly represents the ERD, satisfies the Business Requirement Analysis (BRA), and uses appropriate keys, relationships, and constraints.
compatibility: opencode
---

## 1. Purpose

This skill instructs the agent to perform a formal validation of the database design.

The objective is to determine whether the Logical Database Design:
- Correctly represents the ERD.
- Preserves the requirements defined in the BRA.
- Satisfies the business rules defined in the BRA.
- Uses appropriate keys and relationships.
- Implements appropriate constraints.
- Maintains traceability from requirements to schema elements.

The validation process must identify strengths, weaknesses, risks, missing requirement coverage, and any business rules that are only partially enforced or require procedural/application-level implementation.
---

## 2. Required Inputs

Before beginning, the agent MUST load and fully read:

* `outputs/01-business-requirement-analysis-G02.md`
* `outputs/02-erd-design-G02.md`
* `outputs/03-logical-design-G02.md`

If any required file is unavailable, halt and request it.

Do not proceed from memory.

---

## 3. Execution Pipeline

Execute the following stages in strict order.

### Stage 1.1 — Entity Coverage Validation

Compare the ERD against the Logical Database Design.

For every ERD entity:

* Verify a corresponding relational table exists.
* Verify no ERD entity is omitted.
* Verify no additional table exists without justification.

Record:

* Entity Name
* Corresponding Table
* Validation Status
* Notes

### Stage 1.2 — Internal Consistency of Referential Actions

Compare foreign key rules across related tables:

- If a child table has `ON DELETE CASCADE` but the parent table’s business rule requires historical preservation, flag as **High Risk**.
- If two related tables have conflicting referential actions (e.g., `BOOKING` has `ON DELETE NO ACTION`, but `USAGESESSION` has `ON DELETE CASCADE` on `booking_id`), flag as **High Risk** and recommend alignment.
- Document any inconsistency with exact excerpts from the logical design.

---

### Stage 2 — Relationship Mapping Validation

For every ERD relationship:

Validate:

* Cardinality preservation
* Foreign key placement
* Junction table implementation
* Shared primary key implementation (where applicable)

Expected mapping rules:

| ERD Relationship | Expected Relational Mapping |
| ---------------- | --------------------------- |
| 1:N              | FK on N-side                |
| M:N              | Junction Table              |
| 1:1              | Shared PK or UNIQUE FK      |

Identify any incorrect mappings.

---

### Stage 3 — Key Validation

For every table:

Validate:

* Primary Keys
* Foreign Keys
* Composite Keys
* Candidate Keys
* Alternate Keys

Determine whether the selected keys:

* Uniquely identify records
* Correctly support relationships
* Match the ERD design

---

### Stage 4.1 — Constraint Validation

Evaluate all constraints.

Validate:

* NOT NULL
* UNIQUE
* CHECK
* DEFAULT
* Referential Integrity Actions

Determine whether each constraint correctly supports the intended requirement.

### Stage 4.2 — Referential Integrity & History Preservation

If a table stores transactional history (e.g., `BOOKING`, `USAGESESSION`, `MAINTENANCERECORD`):

- Check whether any foreign key referencing it uses `ON DELETE CASCADE`.
- If yes, and the business requirement explicitly states "historical records must be preserved", then mark this as a **High Risk**.
- Recommend removing `ON DELETE CASCADE` or using soft deletion (status flags) instead.

### Stage 4.3 — Future-Time Constraints (No Past-Dated Events)

For any column that represents a scheduled or anticipated future timestamp (e.g., a start time of a booking, a deadline, an event time):

- Check whether the logical design includes a mechanism (trigger, application rule, or, where DBMS-allowed, a CHECK constraint) that prevents the timestamp from being set to a value earlier than the current database time (`GETDATE()` or `CURRENT_TIMESTAMP`) for new records.
- If no such constraint exists, and the column is used for future scheduling, mark this as a **Medium Risk**.
- **Recommendation**: Enforce this rule with an `AFTER INSERT, UPDATE` trigger that compares the future‑time column against `GETDATE()` and rolls back if the value is in the past, **or** enforce it entirely at the application layer.
- **Important note**: In Microsoft SQL Server, non‑deterministic functions like `GETDATE()` cannot be used in `CHECK` constraints. Therefore, do not recommend a `CHECK` constraint for this rule unless the project explicitly targets a DBMS that supports it (e.g., PostgreSQL allows `CURRENT_TIMESTAMP` in `CHECK` constraints). The trigger approach is safe and portable.
- Note: This is separate from ordering constraints (e.g., end > start), which are already validated elsewhere.

---

### Stage 5 — Business Rule Coverage Analysis

Review every business rule identified in the BRA.

For each business rule:

Determine whether it is:

* Fully Enforced
* Partially Enforced
* Not Enforced

Possible enforcement mechanisms:

* PK
* FK
* UNIQUE
* CHECK
* DEFAULT
* Trigger
* Stored Procedure
* Application Logic

If a business rule cannot be enforced through relational constraints alone, explicitly identify the limitation.

Examples include:

* Double-booking prevention
* Capacity validation
* Maintenance restrictions
* Role-based approval restrictions

All business rules need a justification with the final conclusion

---

### Stage 6 — Traceability Validation

Verify traceability:

BRA Requirement
→ ERD Element
→ Relational Schema Element
→ Constraint

Identify any missing traceability links.

---

### Stage 7 — Overall Assessment

Provide:

* Strengths
* Issues
* Risks
* Recommendations

Conclude whether the design is:

* Fully Valid
* Conditionally Valid
* Invalid

---

## 4. Output Format

Produce the output as:

# Step 4: Database Design Validation

---

## 1. Validation Scope

---

## 2. Entity Coverage Validation

---

## 3. Relationship Mapping Validation

---

## 4. Key Validation

---

## 5. Constraint Validation

---

## 6. Business Rule Coverage Analysis

---

## 7. Traceability Validation

---

## 8. Strengths

---

## 9. Issues and Risks

---

## 10. Recommendations

---

## 11. Conclusion

Save output as:

`outputs/04-design-validation-G02.md`

---

## 5. Critical Constraints

1. Do not redesign the schema.

2. Do not invent requirements that are not present in the BRA.

3. Every finding must reference evidence from:

   * BRA
   * ERD
   * Logical Design

4. Clearly distinguish:

   * Fully Satisfied Requirements
   * Partially Satisfied Requirements
   * Unsatisfied Requirements

5. Missing business-rule enforcement must be explicitly documented.

6. Validation findings must be evidence-based and traceable.

7. Recommendations may suggest improvements but must not modify the original design automatically.

8. Do not claim a business rule is enforced unless the enforcement mechanism can be identified.
