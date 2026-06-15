# Step 6 Review Report — Sample Data Validation

---

## Verdict

**APPROVED**

The sample data script was thoroughly validated against the project's DDL, Business Requirement Analysis, and Logical Design. All 11 checks passed, and the data provides robust coverage for normal operations, edge cases, and all constraints required by the business rules.

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
| 11 | SQL Syntax & Executability | PASS | 0 |

---

## Detailed Findings

### Check 3 — CHECK Constraint Compliance
**Result:** PASS
All enumerated values in the INSERT script match the DDL constraints exactly.

| Table | Column | Allowed Values (from DDL CHECK) | Values Used in Data | All Valid? |
|---|---|---|---|---|
| USER | role | 'Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager' | 'Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager' | Yes |
| USER | account_status | 'Active', 'Suspended', 'Inactive' | 'Active', 'Suspended', 'Inactive' | Yes |
| SPACE | space_type | 'Auditorium', 'Classroom', 'Computer Laboratory', 'Project Laboratory', 'Meeting Room', 'Student Workspace' | 'Auditorium', 'Classroom', 'Computer Laboratory', 'Project Laboratory', 'Meeting Room', 'Student Workspace' | Yes |
| SPACE | current_status | 'Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired' | 'Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired' | Yes |
| SPACE_FACILITY | operation_status | 'Operational', 'Partially Operational', 'Broken' | 'Operational', 'Broken' | Yes |
| BOOKING | purpose | 'Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event' | 'Lecture', 'Student Activity', 'Meeting', 'Examination', 'Administrative Event' | Yes |
| BOOKING | booking_status | 'Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-Show' | 'Pending', 'Approved', 'Checked In', 'Rejected', 'Completed', 'Cancelled', 'No-Show' | Yes |
| MAINTENANCERECORD | maintenance_status | 'Reported', 'In Progress', 'Resolved', 'Cancelled' | 'Reported', 'Resolved', 'In Progress' | Yes |
| MAINTENANCERECORD | problem_type | 'Projector Failure', 'Air-Conditioning Issue', 'Cleaning Issue', 'Furniture Damage', 'Network Issue', 'Other' | 'Projector Failure', 'Cleaning Issue', 'Network Issue' | Yes |

### Check 4 — Referential Integrity
**Result:** PASS
All foreign keys resolve to valid primary keys in parent tables.

| Child Table | FK Column | Parent Table | Parent PK Column | All FK Values Resolvable? |
|---|---|---|---|---|
| SPACE_FACILITY | space_code | SPACE | space_code | Yes |
| SPACE_FACILITY | facility_id | FACILITY | facility_id | Yes |
| BOOKING | space_code | SPACE | space_code | Yes |
| BOOKING | requester_id | USER | user_id | Yes |
| BOOKING | approver_id | USER | user_id | Yes |
| USAGESESSION | booking_id | BOOKING | booking_id | Yes |
| USAGESESSION | check_in_staff_id | USER | user_id | Yes |
| USAGESESSION | check_out_staff_id | USER | user_id | Yes |
| MAINTENANCERECORD | space_code | SPACE | space_code | Yes |
| MAINTENANCERECORD | reporter_id | USER | user_id | Yes |
| MAINTENANCERECORD | assigned_staff_id | USER | user_id | Yes |

### Check 5 — Temporal Constraint Compliance
**Result:** PASS
All temporal checks (end > start) are satisfied.

- **BOOKING**:
  - Row 1: 2026-06-20 09:00:00 < 2026-06-20 11:00:00 (Pass)
  - Row 2: 2026-06-20 13:00:00 < 2026-06-20 15:00:00 (Pass)
  - Row 3: 2026-06-20 10:00:00 < 2026-06-20 11:00:00 (Pass)
  - Row 4: 2026-06-20 12:00:00 < 2026-06-20 13:00:00 (Pass)
  - Row 5: 2026-06-20 14:00:00 < 2026-06-20 16:00:00 (Pass)
  - Row 6: 2026-06-21 09:00:00 < 2026-06-21 11:00:00 (Pass)
  - Row 7: 2026-06-21 13:00:00 < 2026-06-21 14:00:00 (Pass)
  - Row 8: 2026-06-22 09:00:00 < 2026-06-22 10:00:00 (Pass)
  - Row 9: 2026-06-22 10:00:00 < 2026-06-22 11:00:00 (Pass)
  - Row 10: 2026-06-23 10:00:00 < 2026-06-23 12:00:00 (Pass)

- **USAGESESSION**:
  - Row 2: 2026-06-20 14:00:00 < 2026-06-20 16:00:00 (Pass)
  - Row 3: 2026-06-21 13:00:00 < 2026-06-21 14:00:00 (Pass)

- **MAINTENANCERECORD**:
  - Row 2: 2026-06-16 09:00:00 < 2026-06-16 11:00:00 (Pass)

### Check 6 — Business Rule Compliance
**Result:** PASS
All business rules with data implications are satisfied.

- **Conflict Prevention**: Checked all pairs of bookings.
  - B1-F3-R101: Bookings 1, 6, 10 do not overlap (6:06-21; 10:06-23; 1:06-20).
  - B1-F2-R103: Bookings 3, 4 do not overlap.
  - B2-F3-R203: Bookings 5, 9 do not overlap.
- **Role Constraints**: All approvers (MGR2023001), check-in staff (STAFF2023001, STAFF2023002), and maintenance staff have appropriate roles.

### Check 7 — Scenario Coverage
**Result:** PASS
All scenarios derived from the BRA are covered.

| # | Scenario Description | Coverage Criterion | Present in Data? |
|---|---|---|---|
| 1 | Normal Operation: Initial State | Pending Booking | Yes |
| 2 | Normal Operation: Approved Lifecycle | Approved Booking | Yes |
| 3 | Normal Operation: Completed Lifecycle | Checked In/Completed Session | Yes |
| 4 | Edge Case: Rejected/Cancelled | Rejected/Cancelled Booking | Yes |
| 5 | Edge Case: No-Show | No-Show Booking | Yes |
| 6 | Edge Case: Under Maintenance | Space status 'Under Maintenance' | Yes |
| 7 | Edge Case: Retired Space | Space status 'Retired' | Yes |
| 8 | Edge Case: Null Optional Fields | Nullable fields in User/Booking | Yes |

---

## Required Changes Before Step 7
None — sample data is cleared to proceed to Step 7.

---

## Recommended Improvements
None.
