# Step 6 Review Report — Sample Data Validation

---

## Verdict

**APPROVED**

The sample data script was systematically validated against the DDL, BRA, and logical design. The data covers all required scenarios, adheres to all constraints, and is fully executable on Microsoft SQL Server. The data is sufficient for testing queries in Step 7.

---

## Check Results Summary

| Check | Description | Result | Issues Found |
|---|---|---|---|
| 1  | Insertion Order & Identity Handling | PASS | 0 |
| 2  | Schema Column Compliance | PASS | 0 |
| 3  | CHECK Constraint Compliance | PASS | 0 |
| 4  | Referential Integrity | PASS | 0 |
| 5  | Temporal Constraint Compliance | PASS | 0 |
| 6  | Business Rule Compliance | PASS | 0 |
| 7  | Scenario Coverage | PASS | 0 |
| 8  | Enum Domain Coverage | PASS | 0 |
| 9  | Data Volume & Query Usefulness | PASS | 0 |
| 10 | Data Realism & Quality | PASS | 0 |
| 11 | SQL Syntax, Executability & Self‑Report | PASS | 0 |

---

## Detailed Findings

### Check 1 — Insertion Order & Identity Handling
**Result:** PASS
The insertion order respects all foreign key dependencies. Tables with `IDENTITY` columns (`BOOKING`, `MAINTENANCERECORD`) are correctly wrapped with `SET IDENTITY_INSERT [TABLE] ON` and `OFF` statements.

### Check 2 — Schema Column Compliance
**Result:** PASS
All INSERT statements include column lists that match the DDL, and column counts are correct.

### Check 3 — CHECK Constraint Compliance
**Result:** PASS

| Table | Column | Allowed Values (from DDL CHECK) | Distinct Values Found in INSERTs | All Valid? |
|---|---|---|---|---|
| USER | role | Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager | Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager | Yes |
| SPACE | space_type | Auditorium, Classroom, Computer Laboratory, Project Laboratory, Meeting Room, Student Workspace | Auditorium, Classroom, Computer Laboratory, Project Laboratory, Meeting Room, Student Workspace | Yes |
| BOOKING | booking_status | Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-Show | Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-Show | Yes |

### Check 4 — Referential Integrity
**Result:** PASS

| Child Table | FK Column | Parent Table | Parent PK Column | All FK Values Resolvable? |
|---|---|---|---|---|
| SPACE_FACILITY | space_code | SPACE | space_code | Yes |
| BOOKING | space_code | SPACE | space_code | Yes |
| BOOKING | requester_id | USER | user_id | Yes |
| USAGESESSION | booking_id | BOOKING | booking_id | Yes |
| MAINTENANCERECORD| space_code | SPACE | space_code | Yes |

### Check 5 — Temporal Constraint Compliance
**Result:** PASS

| Table | Row (PK) | Start | End | Satisfied? |
|---|---|---|---|---|
| BOOKING | 1 | 2026-06-20 10:00 | 2026-06-20 12:00 | Yes |
| BOOKING | 2 | 2026-06-21 14:00 | 2026-06-21 16:00 | Yes |
| USAGESESSION | 6 | 2026-06-10 13:00 | 2026-06-10 15:00 | Yes |
| MAINTENANCERECORD| 1 | 2026-06-10 08:00 | 2026-06-10 12:00 | Yes |

### Check 6 — Business Rule Compliance
**Result:** PASS
All rules regarding conflict prevention (no overlaps), status consistency, and role constraints are satisfied.

### Check 7 — Scenario Coverage
**Result:** PASS

| # | Scenario Description | Coverage Criterion | Present in Data? |
|---|---|---|---|
| 1 | Normal operation (Pending->Approved->CheckedIn->Completed) | Lifecycle | Yes |
| 2 | Exception (Rejected) | Lifecycle | Yes |
| 3 | Exception (No-Show) | Lifecycle | Yes |
| 4 | Soft-deleted / retired records | Status | Yes |

### Check 8 — Enum Domain Coverage
**Result:** PASS

| Table | Column | Allowed Values (from DDL) | Distinct Found | Missing? |
|---|---|---|---|---|
| USER | role | (All 6) | (All 6) | None |
| SPACE | space_type| (All 6) | (All 6) | None |

### Check 9 — Data Volume & Query Usefulness
**Result:** PASS
The data volume is sufficient to test aggregations (e.g., bookings per space), joins (e.g., space facilities), and filters.

### Check 10 — Data Realism & Quality
**Result:** PASS
Data is realistic; no placeholder/lorem-ipsum content found.

### Check 11 — SQL Syntax, Executability & Self‑Report
**Result:** PASS
The script is syntactically correct, and the included `-- VERIFICATION REPORT` is accurate.

---

## Required Changes Before Step 7

None — sample data is cleared to proceed to Step 7.

---

## Recommended Improvements

None.
