# Step 14 Data Generator Review - G02

## 1. Review Summary

Reviewed the complete Step 14 package against the approved Phase 2 requirement, Steps 5, 9, 10, 11, and 12, the relevant reviews in `docs/`, and the Step 14 generator and review skills.

Runtime generation was performed in a disposable `University_Step14Review` database. Temporary copies of the approved scripts had only their hard-coded database name substituted; no approved artifact was modified. The clean sequence of Step 5, Step 10, Step 12, `01-generate-data.sql`, and `02-validate-data.sql` completed without SQL Server runtime errors.

- Observed booking count: 105,000.
- Observed booking date span: 2023-09-01 08:00 through 2026-03-25 14:00.
- Observed calendar years: 2023, 2024, 2025, and 2026, representing academic years 2023-2024 through 2025-2026.
- Most important strength: set-based generation produced the required scale, valid domains, and zero same-space overlaps among `Approved`, `Checked In`, and `Completed` bookings.
- Most important risk: advisory acknowledgement rows are generated for resolved advisories and omit many acknowledgements required by the approved active-advisory definition.

## 2. Files Reviewed

- `outputs/14-data-generator-G02/01-generate-data.sql`
- `outputs/14-data-generator-G02/02-validate-data.sql`

The package contains exactly both required non-empty files.

## 3. Requirement Coverage

| Requirement | Required | Generated or Checked | Evidence | Status |
| --- | --- | --- | --- | --- |
| Three academic years | Yes | Generated | Runtime span covers 2023-2026 and the three required academic-year windows | Pass |
| 100,000 bookings | Yes | Generated | 105,000 `BOOKING` rows after clean generation | Pass |
| Maintenance records and impact levels | Yes | Generated | 3,500 records: 2,450 `advisory`, 1,050 `out-of-service` | Pass |
| Cancelled and no-show bookings | Yes | Generated | 8,400 `Cancelled`; 5,250 `No-Show` | Pass |
| Instant and staff approval paths | Yes | Generated | 2,296 `Instant`; 102,704 `Staff` | Pass, but skew is far below the Step 14 skill's 30-40% target for instant approvals |
| Advisory acknowledgements | Yes | Generated and checked | 183,787 rows exist, but 145,458 reference maintenance not open under Step 9 and 8,953 qualifying pairs are absent | Fail |
| Different spaces, capacities, facilities | Yes | Generated | 60 spaces, 6 types, 12 facilities, 255 associations, capacities 5 through 300 | Pass |
| Reporting-data variation | Yes | Generated | Popular spaces have 5,010 bookings; least-popular populated spaces have 688-689 | Pass with major distribution gaps |
| No unintended approved overlaps | Yes | Checked | Validator reported 0 prohibited pairs | Pass |
| Escalation-affected bookings available for Report 4 | Required for nontrivial Phase 2 coverage | Checked | 0 escalations have an overlapping current `Approved` booking | Fail |

## 4. Schema and Integrity Check

| Area | Expected | Actual Runtime Finding | Status | Notes |
| --- | --- | --- | --- | --- |
| Tables and columns | Step 5 plus Step 10 schema | All referenced objects and columns compiled and ran | Pass | Includes both Phase 2 tables. |
| Booking status values | Seven Step 5 literals | All seven valid literals populated | Pass | Counts recorded below. |
| Approval-path values | `Instant`, `Staff` | Both valid literals populated | Pass | No instant booking has an approver. |
| Maintenance impact values | `advisory`, `out-of-service` | Both valid literals populated | Pass | Matches Step 10 constraint. |
| Foreign-key references | Valid parent rows | Inserts completed with constraints enabled | Pass | Validator does not independently report orphan checks. |
| Time and capacity integrity | Valid ordered intervals and capacity | Validator reported 0 invalid booking ranges and 0 over-capacity bookings | Pass | Maintenance and usage-session time ranges are not independently audited. |
| Approved overlap invariant | No same-space overlapping approved bookings | 0 prohibited overlap pairs | Pass | Validator includes `Approved`, `Checked In`, and `Completed`, which is stricter than the literal invariant. |
| Active out-of-service overlap | No overlap with open out-of-service maintenance | 0 pairs | Pass | Consistent with the generator's slot exclusion. |
| Advisory acknowledgement eligibility | Only active `advisory` records in `Reported` or `In Progress` at submission, with requested-period overlap | 145,458 acknowledgement rows reference a maintenance row that is not an open advisory | Fail | `01-generate-data.sql` includes `Resolved` in `#AdvMaint`. |
| Advisory acknowledgement completeness | Every qualifying active advisory is acknowledged | 8,953 qualifying booking-maintenance pairs have no acknowledgement | Fail | Rejected and cancelled bookings are excluded by the generator although they were submitted booking requests. |
| Semester representation | Date parameters, no calendar table | Date-based representation is compatible with Step 9 | Pass | Validator labels calendar years rather than academic years. |

## 5. Data Distribution Review

All following values were observed during the first clean generation unless noted otherwise.

| Distribution | Observed Result | Assessment |
| --- | --- | --- |
| Booking status | Completed 57,750; Approved 15,750; Rejected 10,500; Cancelled 8,400; No-Show 5,250; Checked In 4,200; Pending 3,150 | Meets required case coverage. |
| Approval path | Instant 2,296 (2.2%); Staff 102,704 (97.8%) | Both paths exist, but instant approval is too sparse for balanced path analysis. |
| Academic period | Fall 2023 has 44,029 bookings; subsequent periods range from 4,428 to 22,543 | Non-uniform, but the distribution is concentrated early. |
| Weekdays | 14,573 to 15,482 bookings per weekday | Includes all weekdays, including Saturday and Sunday. |
| Hours | Only 08:00, 10:00, 12:00, 14:00, and 16:00 starts; 18,758 to 24,097 each | Nontrivial but uniform slot-grid pattern. |
| Space concentration | Top spaces: 5,010 each; bottom populated spaces: 688-689 | Suitable skew for conflict checks. |
| Maintenance | Advisory 2,450; out-of-service 1,050 | Both levels and overlapping periods are present. |
| Acknowledgements | 183,787 total | Volume is nontrivial but semantically invalid as described in R14-1. |
| Capacity and facilities | 60 spaces, 12 facility types, 255 associations | Supports selective room-finder predicates. |

The approved-only report population is also not spread across the required academic years: all 15,750 rows with `booking_status = 'Approved'` run only from 2023-09-01 through 2024-05-08. This leaves the approved-booking reports empty for later semesters even though the overall booking table has later inactive-status rows.

## 6. Issues Found

### Issue R14-1 - Advisory acknowledgement eligibility and completeness are incorrect

- **Severity:** Blocking
- **Issue:** The generator treats `Resolved` advisories as active and excludes `Rejected` and `Cancelled` booking submissions from acknowledgement generation.
- **Evidence:** `01-generate-data.sql` lines 624-626 select advisories with `maintenance_status IN ('Reported', 'In Progress', 'Resolved')`; lines 642 exclude `Rejected` and `Cancelled`. Step 9 section 2, Decision 6 defines active advisories as `Reported` or `In Progress` at booking time. Runtime audit found 145,458 acknowledgement rows for a non-open advisory and 8,953 qualifying active-advisory booking pairs without acknowledgement.
- **Why this is a problem:** The generated data cannot substantiate the required audit that requesters were informed of all active advisories at booking time. It contains both false-positive and missing acknowledgement evidence.
- **Impact on Step 15:** Room-finder and booking-related performance results would be based on data that violates a core Phase 2 relationship. It also prevents a trustworthy index analysis of advisory acknowledgement access paths.
- **Suggested correction:** Restrict acknowledgement source maintenance to `impact_level = 'advisory'` and `maintenance_status IN ('Reported', 'In Progress')`; generate one row for every qualifying submitted booking-maintenance pair, including requests later rejected or cancelled when they qualified at submission; extend the validator to report invalid and missing pairs.

### Issue R14-2 - The validation script does not independently validate advisory acknowledgement correctness

- **Severity:** Major
- **Issue:** Check 5 only rejects acknowledgements whose maintenance starts after acknowledgement time. It does not test maintenance impact level, open status, acknowledgement-before-completion, requested-period overlap, duplicate pair detection, or missing acknowledgement pairs.
- **Evidence:** `02-validate-data.sql` lines 159-170 only compare `m.start_time` to `ack.acknowledged_at`. The runtime audit in R14-1 passes this check while exposing 145,458 invalid and 8,953 missing pairs.
- **Why this is a problem:** A passing validator result is misleading and cannot prove the Phase 2 advisory rule.
- **Impact on Step 15:** The package does not reliably validate the data intended for future query and index tests.
- **Suggested correction:** Add labeled pass/fail queries for invalid acknowledgement eligibility, missing qualifying pairs, duplicate `(booking_id, maintenance_id)` pairs, acknowledgement timestamps outside the maintenance interval, and acknowledgement booking-period overlap.

### Issue R14-3 - The generated data has no positive escalation-affected approved-booking scenario

- **Severity:** Major
- **Issue:** The generator creates escalation history but deliberately excludes all approved bookings from every out-of-service maintenance window. As a result, the required affected-bookings report has no positive dataset case.
- **Evidence:** Runtime audit found 0 `advisory` to `out-of-service` history rows with an overlapping current `Approved` booking. This matches `docs/16-query4-maintenance-affected-review-G02.md`, which records zero rows for generated maintenance ID 18.
- **Why this is a problem:** Step 14 is required to cover the Phase 2 maintenance escalation scenario. A query that only returns an empty result on generated data cannot be meaningfully analyzed or tuned.
- **Impact on Step 15:** The selected reporting query and maintenance-related indexes cannot be evaluated against a nontrivial positive result set without hidden inserts or manual repair.
- **Suggested correction:** Generate a controlled subset where bookings were approved while maintenance was advisory, then record the advisory-to-out-of-service escalation history and current out-of-service impact. Keep those rows separately identifiable as intentional escalation-affected cases.

### Issue R14-4 - Approved-report data is limited to the first academic year

- **Severity:** Major
- **Issue:** Although all bookings span three academic years, `Approved` bookings end on 2024-05-08.
- **Evidence:** Runtime query returned 15,750 `Approved` rows from 2023-09-01 through 2024-05-08. The required Reports 1 and 2 filter approved bookings by a supplied semester.
- **Why this is a problem:** Later-semester approved booking-hours and weekday/hour reports return no data, despite the claimed three-year reporting dataset.
- **Impact on Step 15:** Index comparisons for approved-booking reports will be misleading or impossible for later academic years.
- **Suggested correction:** Distribute the final approved booking status across every Fall and Spring semester in all three academic years.

## 7. Validation Script Assessment

Present and useful checks:

- Total and major-table row counts with thresholds.
- Minimum and maximum booking dates and calendar-year count.
- Counts by booking status, approval path, weekday, hour, and populated space.
- Maintenance impact counts and acknowledgement count.
- Booking time order, capacity, rejection reason, approver role, instant-path consistency, usage-session alignment, approved overlap, out-of-service overlap, and trigger status.

Missing or unreliable checks:

- No explicit null audit for required Phase 2 or major-table fields.
- No independent orphan audit for bookings, maintenance, facilities, acknowledgements, or impact history.
- No maintenance time-order audit, usage-session time-order audit, duplicate-key audit, or impact-history domain and direction audit.
- No count of academic years using the project-defined academic-year windows; only calendar years are counted.
- No pass/fail assessment of facility and capacity coverage.
- No acknowledgement eligibility, completeness, duplicate, impact-level, active-status, period-overlap, or acknowledgement-time-within-maintenance audit.
- No report of bookings linked to multiple advisories.
- No escalation-affected approved-booking count tied to advisory-to-out-of-service history.

## 8. Step 15 Readiness Examination

| Question | Answer |
| --- | --- |
| Does the package create at least 100,000 bookings? | Yes, 105,000 observed. |
| Does it cover at least three academic years? | Yes for all bookings. |
| Are required booking statuses represented? | Yes. |
| Are both approval paths represented? | Yes, but the instant path is only 2.2%. |
| Are maintenance impact levels represented? | Yes. |
| Are advisory acknowledgements represented correctly? | No. |
| Are approved-booking conflicts absent except documented escalation cases? | Yes; 0 observed prohibited pairs. |
| Does room finding have meaningful capacity and facility variation? | Yes. |
| Do approved-booking analytical queries return nontrivial results for all academic years? | No. |
| Are distributions suitable for before-and-after index comparison? | Partly; space skew is useful, but later approved-report semesters and positive escalation cases are absent. |
| Can the package be rerun safely? | Yes for the dedicated benchmark database. The second run completed with 105,000 bookings and no duplicate accumulation. |
| Does the validation script prove the required properties? | No. |
| Would Step 15 need manual data repair or hidden inserts? | Yes, for acknowledgement correctness and a positive escalation-affected scenario. |
| Are blocking issues unresolved? | Yes, R14-1. |

## 9. Scores

| Category | Score |
| --- | --- |
| Completeness | 9/10 |
| Schema Compatibility | 10/10 |
| Data Volume | 10/10 |
| Business Coverage | 5/10 |
| Integrity | 5/10 |
| Distribution Quality | 6/10 |
| Generator Quality | 8/10 |
| Validation Quality | 4/10 |
| Step 15 Readiness | 4/10 |

## 10. Required Revisions Before Step 15

1. Correct advisory acknowledgement generation to match Step 9's active-advisory definition and create every required acknowledgement pair.
2. Add independent acknowledgement eligibility, completeness, duplicate, and temporal checks to `02-validate-data.sql`.
3. Generate intentional advisory-to-out-of-service escalation cases with overlapping approved bookings, and validate the affected-booking count.
4. Distribute `Approved` bookings across all three academic years so the approved-booking reports have nontrivial results for each semester.
5. Add the missing null, orphan, maintenance/usage temporal, academic-year, and facility/capacity coverage audits.

## 11. Final Readiness Verdict

**NOT READY FOR STEP 15**

The scripts run at the required scale and preserve the approved booking-overlap invariant, but the generated advisory acknowledgement data violates the approved Phase 2 definition and the validator fails to detect it. Positive escalation-affected and later-year approved-report data must also be generated before index-tuning work can proceed without manual repair.
