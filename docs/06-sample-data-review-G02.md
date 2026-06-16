# Step 6 Review Report — Sample Data Validation

---

## Verdict

**APPROVED**

All 11 checks pass with zero issues. The sample data script (`06-sample-data-G02.sql`) provides comprehensive, realistic data that satisfies all schema constraints, covers every enumerated value, maintains referential integrity, and demonstrates all 18 business scenarios derived from the BRA. The self-verification report accurately reflects the data quality.

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

**Insertion order** follows the FK dependency graph correctly: `USER` → `SPACE` → `FACILITY` → `SPACE_FACILITY` → `BOOKING` → `USAGESESSION` → `MAINTENANCERECORD`. Every parent is populated before its children.

**IDENTITY tables** (FACILITY, BOOKING, MAINTENANCERECORD) are all wrapped with matching `SET IDENTITY_INSERT ... ON` / `OFF` pairs:
- FACILITY: lines 132/141
- BOOKING: lines 177/250
- MAINTENANCERECORD: lines 278/334

Tables without IDENTITY (USER, SPACE, SPACE_FACILITY, USAGESESSION) correctly have no identity insert wrappers.

### Check 2 — Schema Column Compliance
**Result:** PASS

Per-table compliance:

| Table | Columns in INSERT | DDL Columns | Column Names Match | Column Count Match | NOT NULL Coverage | No Invented Columns |
|---|---|---|---|---|---|---|
| `[USER]` | 7 | 7 | ✅ | 7/7 | ✅ (phone nullable) | ✅ |
| `SPACE` | 9 | 9 | ✅ | 9/9 | ✅ | ✅ |
| `FACILITY` | 3 | 3 | ✅ | 3/3 | ✅ | ✅ |
| `SPACE_FACILITY` | 5 | 5 | ✅ | 5/5 | ✅ | ✅ |
| `BOOKING` | 13 | 13 | ✅ | 13/13 | ✅ | ✅ |
| `USAGESESSION` | 8 | 8 | ✅ | 8/8 | ✅ | ✅ |
| `MAINTENANCERECORD` | 10 | 10 | ✅ | 10/10 | ✅ | ✅ |

Every column name, data type, and nullability matches the DDL. Every NOT NULL column appears in every INSERT column list (or has a DEFAULT). No invented columns exist.

### Check 3 — CHECK Constraint Compliance (Enum Values)
**Result:** PASS

| Table | Column | Allowed Values (from DDL CHECK) | Distinct Values Found in INSERTs | All Valid? |
|---|---|---|---|---|
| `[USER]` | `role` | 'Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager' | 'Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager' | Yes |
| `[USER]` | `account_status` | 'Active', 'Suspended', 'Inactive' | 'Active', 'Suspended', 'Inactive' | Yes |
| `SPACE` | `space_type` | 'Auditorium', 'Classroom', 'Computer Laboratory', 'Project Laboratory', 'Meeting Room', 'Student Workspace' | 'Auditorium', 'Classroom', 'Computer Laboratory', 'Project Laboratory', 'Meeting Room', 'Student Workspace' | Yes |
| `SPACE` | `current_status` | 'Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired' | 'Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired' | Yes |
| `SPACE_FACILITY` | `operation_status` | 'Operational', 'Partially Operational', 'Broken' | 'Operational', 'Partially Operational', 'Broken' | Yes |
| `BOOKING` | `purpose` | 'Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event' | 'Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event' | Yes |
| `BOOKING` | `booking_status` | 'Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-Show' | 'Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-Show' | Yes |
| `MAINTENANCERECORD` | `maintenance_status` | 'Reported', 'In Progress', 'Resolved', 'Cancelled' | 'Reported', 'In Progress', 'Resolved', 'Cancelled' | Yes |
| `MAINTENANCERECORD` | `problem_type` | 'Projector Failure', 'Air-Conditioning Issue', 'Cleaning Issue', 'Furniture Damage', 'Network Issue', 'Other' | 'Projector Failure', 'Air-Conditioning Issue', 'Cleaning Issue', 'Furniture Damage', 'Network Issue', 'Other' | Yes |

Every INSERT value is drawn from the allowed CHECK constraint lists. Zero invalid values found.

### Check 4 — Referential Integrity
**Result:** PASS

| Child Table | FK Column | Parent Table | Parent PK Column | All FK Values Resolvable? |
|---|---|---|---|---|
| `BOOKING` | `space_code` | `SPACE` | `space_code` | Yes (7/7 parent PKs match) |
| `BOOKING` | `requester_id` | `[USER]` | `user_id` | Yes (all 14 values resolve) |
| `BOOKING` | `approver_id` | `[USER]` | `user_id` | Yes (all non-NULL values: FST2020001, FMG2022001, FST2020002 resolve) |
| `USAGESESSION` | `booking_id` | `BOOKING` | `booking_id` | Yes (5, 6 both exist) |
| `USAGESESSION` | `check_in_staff_id` | `[USER]` | `user_id` | Yes (FST2020002, FST2020001 resolve) |
| `USAGESESSION` | `check_out_staff_id` | `[USER]` | `user_id` | Yes (FST2020001 resolves; NULL is valid) |
| `SPACE_FACILITY` | `space_code` | `SPACE` | `space_code` | Yes (all resolve) |
| `SPACE_FACILITY` | `facility_id` | `FACILITY` | `facility_id` | Yes (1-7 all exist) |
| `MAINTENANCERECORD` | `space_code` | `SPACE` | `space_code` | Yes (all resolve) |
| `MAINTENANCERECORD` | `reporter_id` | `[USER]` | `user_id` | Yes (all resolve) |
| `MAINTENANCERECORD` | `assigned_staff_id` | `[USER]` | `user_id` | Yes (FST2020001, FST2020002 resolve; NULL valid) |

All 11 FK relationships verified. Every non-NULL FK value resolves to an existing parent PK. NULL values in nullable FK columns (approver_id, check_out_staff_id, assigned_staff_id) are correctly allowed.

### Check 5 — Temporal Constraint Compliance
**Result:** PASS

**BOOKING — CK_BOOKING_TIME_ORDER (requested_end > requested_start):**
| Booking ID | requested_start | requested_end | Valid? |
|---|---|---|---|
| 1 | 2026-07-20 14:00 | 2026-07-20 17:00 | ✅ |
| 2 | 2026-07-10 09:00 | 2026-07-10 11:00 | ✅ |
| 3 | 2026-07-22 13:00 | 2026-07-22 17:00 | ✅ |
| 4 | 2026-07-25 10:00 | 2026-07-25 12:00 | ✅ |
| 5 | 2026-07-08 09:00 | 2026-07-08 12:00 | ✅ |
| 6 | 2026-07-12 10:00 | 2026-07-12 12:00 | ✅ |
| 7 | 2026-07-09 13:00 | 2026-07-09 15:00 | ✅ |
| 8 | 2026-07-11 09:00 | 2026-07-11 12:00 | ✅ |
| 9 | 2026-07-13 10:00 | 2026-07-13 11:00 | ✅ |
| 10 | 2026-07-14 09:00 | 2026-07-14 12:00 | ✅ |
| 11 | 2026-07-18 09:00 | 2026-07-18 11:00 | ✅ |
| 12 | 2026-07-19 14:00 | 2026-07-19 17:00 | ✅ |
| 13 | 2026-07-15 10:00 | 2026-07-15 12:00 | ✅ |
| 14 | 2026-07-16 14:00 | 2026-07-16 15:00 | ✅ |

All 14/14 valid.

**BOOKING — CK_BOOKING_FUTURE_START (requested_start >= created_at):**
All 14 bookings satisfy `requested_start >= created_at`. Equal only when requested_start = 14:00 and created_at = 14:00 on same day which is logically acceptable per the constraint semantics. ✅

**USAGESESSION — CK_USAGE_TIME_ORDER (actual_end > actual_start):**
| Booking ID | actual_start | actual_end | Valid? |
|---|---|---|---|
| 5 | 2026-07-08 09:05 | 2026-07-08 12:10 | ✅ |
| 6 | 2026-07-12 10:02 | NULL | ✅ (NULL end, not checked) |

**MAINTENANCERECORD — CK_MAINTENANCE_TIME_ORDER (completion_time > start_time):**
| Maintenance ID | start_time | completion_time | Valid? |
|---|---|---|---|
| 1 | 2026-07-02 14:00 | NULL | ✅ (NULL, not checked) |
| 2 | 2026-07-05 09:00 | NULL | ✅ |
| 3 | 2026-07-03 22:00 | 2026-07-04 07:00 | ✅ |
| 4 | 2026-07-06 10:00 | NULL | ✅ |
| 5 | 2026-07-07 15:00 | NULL | ✅ |
| 6 | 2026-07-01 08:00 | 2026-07-02 16:00 | ✅ |
| 7 | 2026-07-08 13:00 | NULL | ✅ |

All temporal constraints satisfied.

### Check 6 — Business Rule Compliance
**Result:** PASS

| BR # | Rule | Data Check | Satisfied? |
|---|---|---|---|
| BR-1 | Mandatory university account | All 9 users have non-NULL user_id | ✅ |
| BR-2 | Record user info | All columns present per BRA §4.1; phone is nullable (matches BRA) | ✅ |
| BR-3 | User roles constrained | All 6 roles used, all valid per CK_USER_ROLE | ✅ |
| BR-4 | Unique space code | 7 distinct space_codes | ✅ |
| BR-5 | Space attributes | All 9 columns populated per BRA §4.2 | ✅ |
| BR-6 | Space statuses constrained | All 5 statuses used, all valid per CK_SPACE_CURRENT_STATUS | ✅ |
| BR-7 | Facilities catalog & mapping | 7 facility types catalogued; 14 SPACE_FACILITY mappings | ✅ |
| BR-8 | Booking requires fields | All 14 bookings have space, start/end, purpose, participants | ✅ |
| BR-9 | Booking purposes constrained | All 7 purposes used, all valid per CK_BOOKING_PURPOSE | ✅ |
| BR-10 | Booking statuses constrained | All 7 statuses used, all valid per CK_BOOKING_STATUS | ✅ |
| BR-11 | Double booking prevention | **Enumerated pairs:** Approved bookings only: B2, B8, B13. No two share the same space with overlapping time ranges: B2 (CS-B2-F1-R102 Jul 10 09-11) is alone on that space; B8 (CS-B2-F1-R101 Jul 11 09-12) is alone on that space; B13 (CS-B1-F2-R201 Jul 15 10-12) is alone on that space | ✅ |
| BR-12 | Unavailable spaces blocked | No Approved booking references a space in 'Under Maintenance', 'Temporarily Closed', or 'Retired' status | ✅ |
| BR-13 | Approval tracking | All decided bookings (B2-B9, B13) have approver_id, decision_time, decision_note populated | ✅ |
| BR-14 | Rejection justification | B3 (Rejected) has rejection_reason populated | ✅ |
| BR-15 | Usage session check-in | Both US rows have check_in_staff_id, actual_start, initial_condition: NOT NULL values present | ✅ |
| BR-16 | Usage session completion | US2 has NULL actual_end/final_condition (ongoing); US1 has all completion fields populated | ✅ |
| BR-17 | Maintenance logging | All 7 MR rows have space, reporter, assigned, description, times, status, result_note | ✅ |
| BR-18 | Historical preservation | Inactive user (LEC2020005), Retired space (CS-B3-F2-R210), Cancelled bookings (B4, B9) present | ✅ |
| BR-19 | Capacity limit (expected ≤ capacity) | B1(50≤200), B2(30≤40), B3(15≤200), B4(25≤200), B5(35≤40), B6(60≤80), B7(10≤20), B8(100≤200), B9(8≤12), B10(40≤80), B11(20≤50), B12(15≤30), B13(70≤80), B14(10≤12) — all valid | ✅ |
| BR-20 | Future booking | All 14 bookings have requested_start ≥ created_at | ✅ |
| BR-21 | Cancellation rules | B4 cancelled (from Pending), B9 cancelled (from Approved) — correct source states | ✅ |
| A1 | Role-based permissions | Approvers: FST2020001 (Facility Staff), FMG2022001 (Facility Manager), FST2020002 (Facility Staff). Check-in staff: FST2020002, FST2020001 (Facility Staff). Assigned staff: FST2020001, FST2020002 (Facility Staff) | ✅ |
| A9 | USAGESESSION for Approved bookings | US1→B5 (Completed), US2→B6 (Checked In) — both started as approved bookings that reached check-in states | ✅ |

### Check 7 — Scenario Coverage
**Result:** PASS

| # | Scenario Description | Coverage Criterion | Present in Data? |
|---|---|---|---|
| N1 | Booking in initial Pending state | At least one booking with status 'Pending', no approver, no decision | ✅ B1 (B10, B11, B12, B14 also) |
| N2 | Full lifecycle (Approved→CheckedIn→Completed) | Separate bookings for each lifecycle stage with correct state transitions | ✅ B2 (Approved), B5 (Completed), B6 (Checked In) |
| N3 | Booking that was Rejected | Booking with status 'Rejected' and rejection_reason populated | ✅ B3 |
| N4a | Booking Cancelled from Pending | Cancelled booking that originated as Pending | ✅ B4 |
| N4b | Booking Cancelled from Approved | Cancelled booking that originated as Approved | ✅ B9 |
| N5 | M:N space↔facility mapping | Space with multiple facilities; facility in multiple spaces | ✅ Auditorium A has 4 facilities; Projector in 3 spaces |
| E1 | Soft-deleted user (Inactive) | User with account_status = 'Inactive' | ✅ LEC2020005 |
| E2 | Retired space (Retired) | Space with current_status = 'Retired' | ✅ CS-B3-F2-R210 |
| E3 | Under Maintenance space | Space with current_status = 'Under Maintenance' + active maintenance records | ✅ CS-B3-F1-R015 + MR1 |
| E4 | Temporarily closed space | Space with current_status = 'Temporarily Closed' | ✅ CS-B2-F2-R205 |
| E5 | No-show booking | Booking with status 'No-Show' | ✅ B7 |
| E6 | Completed session with all fields | USAGESESSION row with all nullable fields populated | ✅ US1 (check_out_staff, actual_end, final_condition, usage_notes all non-NULL) |
| E7 | Ongoing session with nullable NULL | USAGESESSION row with checkout fields NULL | ✅ US2 (check_out_staff_id, actual_end, final_condition, usage_notes all NULL) |
| E8 | Non-overlapping on same space | Multiple bookings on same space on different days | ✅ B1 (Jul 20) and B8 (Jul 11) both on CS-B2-F1-R101 |
| E9 | Multiple users booking same space | Bookings from different requesters for same space | ✅ B6 (LEC2021001), B10 (TA2023002), B13 (LEC2021001) on CS-B1-F2-R201 |
| E10 | Suspended user | User with account_status = 'Suspended' | ✅ STU2021004 |
| E11 | Rejected booking with reason | Rejected booking with non-NULL rejection_reason | ✅ B3 |
| E12 | Maintenance assigned to staff | Maintenance record with non-NULL assigned_staff_id | ✅ MR2 (FST2020001), MR3 (FST2020002), MR6 (FST2020002), MR7 (FST2020001) |
| E13 | Maintenance with no assignment | Maintenance record with NULL assigned_staff_id | ✅ MR1, MR4, MR5 |

All 18 scenarios covered.

### Check 8 — Enum Domain Coverage (Every Allowed Value Appears)
**Result:** PASS

| Table | Column | Allowed Values (from DDL CHECK) | Values Found | Missing Values |
|---|---|---|---|---|
| `[USER]` | `role` | Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager | Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager | None |
| `[USER]` | `account_status` | Active, Suspended, Inactive | Active, Suspended, Inactive | None |
| `SPACE` | `space_type` | Auditorium, Classroom, Computer Laboratory, Project Laboratory, Meeting Room, Student Workspace | Auditorium, Classroom, Computer Laboratory, Project Laboratory, Meeting Room, Student Workspace | None |
| `SPACE` | `current_status` | Available, In Use, Under Maintenance, Temporarily Closed, Retired | Available, In Use, Under Maintenance, Temporarily Closed, Retired | None |
| `SPACE_FACILITY` | `operation_status` | Operational, Partially Operational, Broken | Operational, Partially Operational, Broken | None |
| `BOOKING` | `purpose` | Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Administrative Event | Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Administrative Event | None |
| `BOOKING` | `booking_status` | Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-Show | Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-Show | None |
| `MAINTENANCERECORD` | `maintenance_status` | Reported, In Progress, Resolved, Cancelled | Reported, In Progress, Resolved, Cancelled | None |
| `MAINTENANCERECORD` | `problem_type` | Projector Failure, Air-Conditioning Issue, Cleaning Issue, Furniture Damage, Network Issue, Other | Projector Failure, Air-Conditioning Issue, Cleaning Issue, Furniture Damage, Network Issue, Other | None |

Every allowed enumerated value appears at least once. Zero missing values.

### Check 9 — Data Volume & Query Usefulness
**Result:** PASS

| Sub-check | Assessment | Status |
|---|---|---|
| 9a. Aggregations | COUNT/GROUP BY on role returns 6 groups, on space_type 6 groups, on booking_status 7 groups, on purpose 7 groups. All non-trivial. | ✅ |
| 9b. Relationship breadth | Auditorium A has 4 facilities; Projector appears in 3 spaces. CS-B1-F2-R201 has 3 bookings from 2 users. FST2020001 is assigned to 2 maintenance records. | ✅ |
| 9c. Filtering usefulness | WHERE role='Student' returns 2/9 rows; WHERE booking_status='Approved' returns 3/14; WHERE current_status='Available' returns 3/7. | ✅ |
| 9d. Join coverage | SPACE↔BOOKING returns 14 rows; SPACE_FACILITY↔SPACE returns 14 rows; USER↔BOOKING (requester) returns 14 rows. | ✅ |
| 9e. Historical depth | Date range spans 2026-07-01 to 2026-07-25 across 25 days; time-based filtering produces different result sets for past vs. upcoming relative to any point. | ✅ |

### Check 10 — Data Realism & Quality
**Result:** PASS

| Sub-check | Assessment | Status |
|---|---|---|
| 10a. No placeholder data | No 'test@test.com', 'User1', 'Room A', or generic placeholder values. All names, emails, descriptions are specific and detailed. | ✅ |
| 10b. Realistic identifiers | user_ids follow structured pattern: role abbreviation + year + serial (e.g., STU2023001). Space codes follow building-floor-room pattern (CS-B1-F0-R001). | ✅ |
| 10c. Realistic names & emails | Names like 'Sarah Chen', 'Dr. James Mitchell', 'Elena Park'. Emails follow firstname.lastname@university.edu convention. | ✅ |
| 10d. Realistic numeric values | Capacities: 12 (meeting room) to 200 (auditorium). Participants: 10 (consultation) to 100 (town hall). 25 workstations in computer lab. All plausible. | ✅ |
| 10e. Realistic dates & times | All bookings within business hours (08:00–17:00). Durations 1–4 hours typical. Maintenance at 22:00 for after-hours cleaning. | ✅ |
| 10f. Domain-consistent combinations | Lectures in Computer Laboratory, Examination in Computer Laboratory, Student Activity in Auditorium, Meeting in Meeting Room. Maintenance types match spaces (Projector Failure in lab, Air-Conditioning in lecture hall). | ✅ |

### Check 11 — SQL Syntax, Executability & Self‑Report Accuracy
**Result:** PASS

| Sub-check | Assessment | Status |
|---|---|---|
| 11a. Single-quote escaping | No unescaped single quotes in string literals | ✅ |
| 11b. DateTime literal format | All use `YYYY-MM-DD HH:MM:SS` format (unambiguous for SQL Server) | ✅ |
| 11c. NULL syntax | NULL used correctly for nullable columns; never 'NULL' string or empty string | ✅ |
| 11d. GO separators | GO present after every INSERT block (lines 98, 124, 142, 170, 251, 271, 335) | ✅ |
| 11e. IDENTITY_INSERT pairing | FACILITY (ON:132/OFF:141), BOOKING (ON:177/OFF:250), MAINTENANCERECORD (ON:278/OFF:334) — all correctly paired | ✅ |
| 11f. No duplicate PKs | USER: 9/9 distinct, SPACE: 7/7, FACILITY: 7/7, BOOKING: 14/14, USAGESESSION: 2/2, MAINTENANCERECORD: 7/7 | ✅ |
| 11g. No duplicate composite PKs | SPACE_FACILITY: 14/14 distinct (space_code, facility_id) combinations | ✅ |
| 11h. Column list present | Every INSERT has explicit column list | ✅ |
| 11i. Self-report accuracy | VERIFICATION REPORT (lines 8–56) claims PASS for all checks. Verified against actual INSERT data — all claims are accurate. | ✅ |

---

## Required Changes Before Step 7

None — sample data is cleared to proceed to Step 7.

---

## Recommended Improvements

None.
