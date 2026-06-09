# Step 2 Review Report — ERD Validation

---

## Verdict

REQUIRES REVISION

The ERD contains multiple omissions in attributes, and relationship cardinalities and definitions must be corrected to align with the Business Requirement Analysis.

---

## Check Results

| Check | Description | Result | Issues Found |
|---|---|---|---|
| 1 | Entity Completeness | PASS | 0 |
| 2 | Attribute Completeness & Accuracy | FAIL | 6 |
| 3 | Relationship Completeness | FAIL | 3 |
| 4 | Cardinality Fidelity | FAIL | 10 |
| 5 | Relationship Label Quality | PASS | 0 |
| 6 | Mermaid Syntax & Formatting | FAIL | 2 |
| 7 | Business Rule Traceability | FAIL | 3 |
| 8 | Design Decisions Prose Accuracy | PASS | 0 |

---

## Detailed Findings

### Check 2 — Attribute Completeness & Accuracy
**Result:** FAIL

- Omissions: `Booking` is missing `space_code`, `requester_id`, `approver_id`. `UsageSession` is missing `check_in_staff_id`, `check_out_staff_id`. `MaintenanceRecord` is missing `space_code`, `reporter_id`, `assigned_staff_id`.
- Severity: BLOCKING

### Check 3 — Relationship Completeness
**Result:** FAIL

- The ERD does not explicitly represent the Foreign Key relationships described in §5 (e.g., Space–Booking). While they are implicit in some cases, the ERD should ideally show the connecting lines.
- Severity: BLOCKING

### Check 4 — Cardinality Fidelity
**Result:** FAIL

| # | Relationship | ERD left token | ERD Entity A decoded | BRA Entity A | Match? | ERD right token | ERD Entity B decoded | BRA Entity B | Match? |
|---|---|---|---|---|---|---|---|---|---|
| 5.1 | USER→BOOKING (requests) | o| | (0,1) | (0,N) | NO | o{ | (0,N) | (1,1) | NO |
| 5.2 | USER→BOOKING (approves) | o| | (0,1) | (0,N) | o{ | (0,N) | (0,1) | NO |
| 5.3 | SPACE→BOOKING (hosts) | || | (1,1) | (0,N) | NO | o{ | (0,N) | (1,1) | NO |
| 5.4 | SPACE→FACILITY (equipped) | o{ | (0,N) | (0,N) | YES | o{ | (0,N) | (0,N) | YES |
| 5.5 | BOOKING→USAGESESSION | || | (1,1) | (0,1) | NO | || | (1,1) | (1,1) | YES |
| 5.6 | USER→USAGESESSION (checks in) | || | (1,1) | (0,N) | NO | o{ | (0,N) | (1,1) | NO |
| 5.7 | USER→USAGESESSION (checks out) | o| | (0,1) | (0,N) | NO | o{ | (0,N) | (0,1) | NO |
| 5.8 | SPACE→MAINTENANCERECORD | || | (1,1) | (0,N) | NO | o{ | (0,N) | (1,1) | NO |
| 5.9 | USER→MAINTENANCERECORD (reports) | || | (1,1) | (0,N) | NO | o{ | (0,N) | (1,1) | NO |
| 5.10 | USER→MAINTENANCERECORD (assigned) | o| | (0,1) | (0,N) | NO | o{ | (0,N) | (0,1) | NO |

- Severity: BLOCKING

### Check 6 — Mermaid Syntax & Formatting
**Result:** FAIL

- Attributes like `INT(Identity)` were not found, but many foreign keys are missing.
- Inline comments appear in the relationship section (e.g., `%% BRA §5.1`).
- Severity: BLOCKING

### Check 7 — Business Rule Traceability
**Result:** FAIL

- Rules 13, 15, 16, 17 cannot be fully implemented without the missing FK attributes in `Booking`, `UsageSession`, and `MaintenanceRecord`.
- Severity: BLOCKING

---

## Required Changes Before Step 3

1. **Add missing attributes:** Populate `Booking`, `UsageSession`, and `MaintenanceRecord` with all FKs listed in BRA §4.
2. **Correct Cardinalities:** Fix all relationship tokens in the Mermaid diagram to match the decoded table in Check 4 precisely.
3. **Format Comments:** Ensure all `%%` comments are on dedicated lines and remove any inline comments on attributes or relationships.

---

## Recommended Improvements

1. None.
