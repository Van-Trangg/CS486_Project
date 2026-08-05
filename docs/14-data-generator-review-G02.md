# Step 14 Data Generator Review - G02

## 1. Review Summary

Reviewed `outputs/14-data-generator-G02/01-generate-data.sql` and `02-validate-data.sql` against the approved Phase 2 requirement, Steps 5 and 9-12, and relevant files under `docs/`. The requested `.opencode/skills/step-14-review-SKILL.md` path was not present at review time; the requested workflow and approved project artifacts governed this review.

Runtime generation was performed in a disposable `University_Step14Review2` database. Temporary copies of the approved scripts used only a database-name substitution; no approved output was modified. Step 5, Step 10, Step 12, generator, and validator completed without runtime errors.

- Observed booking count: 105,000.
- Observed booking date span: 2023-09-01 08:00 through 2026-03-25 14:00.
- Observed academic-year coverage: 2023-2024, 2024-2025, and 2025-2026.
- Observed approved overlap count: 0.
- Second-run result: completed and retained 105,000 bookings without duplicate accumulation.
- Most important strength: the set-based generator produces required scale and a useful high/medium/low space-volume skew.
- Most important risk: advisory acknowledgement records do not match Step 9's active-advisory definition, while the validator incorrectly reports them as valid.

## 2. Files Reviewed

- `outputs/14-data-generator-G02/01-generate-data.sql`
- `outputs/14-data-generator-G02/02-validate-data.sql`

Both required files exist and were read in full.

## 3. Requirement Coverage

| Requirement | Required | Generated or Checked | Evidence | Status |
| --- | --- | --- | --- | --- |
| Three academic years | Yes | Generated | Overall date span includes all three required academic-year windows | Pass |
| 100,000 bookings | Yes | Generated | 105,000 `BOOKING` rows observed | Pass |
| Maintenance and impact levels | Yes | Generated | 3,500 records: 2,450 advisory and 1,050 out-of-service | Pass |
| Cancelled and no-show bookings | Yes | Generated | 8,400 cancelled and 5,250 no-show rows | Pass |
| Instant and staff paths | Yes | Generated | 2,296 instant and 102,704 staff rows | Pass, with low instant-path representation |
| Advisory acknowledgements | Yes | Generated and checked | 183,787 rows exist, but 145,458 are not tied to an open advisory and 8,953 qualifying pairs are absent | Fail |
| Spaces, capacities, and facilities | Yes | Generated | 60 spaces, 12 facilities, 255 space-facility rows | Pass |
| Semester, weekday, and hour variation | Yes | Generated | Multiple semesters, all weekdays, and five business-hour starts are populated | Pass with distribution limitations |
| No unintended approved overlaps | Yes | Checked | Validator reports zero prohibited pairs | Pass |
| Escalation-affected approved bookings | Required Phase 2 scenario coverage | Checked | Zero advisory-to-out-of-service escalation records have an overlapping `Approved` booking | Fail |

## 4. Schema and Integrity Check

| Area | Expected | Actual Runtime Finding | Status | Notes |
| --- | --- | --- | --- | --- |
| Tables, columns, and keys | Step 5 plus Step 10 schema | Generator and validator compiled and executed against the migrated schema | Pass | All references use existing objects. |
| Booking status values | Seven Step 5 values | All valid literals populated | Pass | No invalid values observed. |
| Approval path values | `Instant`, `Staff` | Both valid literals populated | Pass | Instant rows have NULL approvers. |
| Maintenance impact values | `advisory`, `out-of-service` | Both valid literals populated | Pass | Matches migration constraint. |
| Foreign keys and duplicate keys | Valid references and unique keys | Inserts succeeded with constraints enabled | Pass | Validator lacks independent major-table orphan and duplicate-key checks. |
| Booking time and capacity | Valid interval and capacity | Validator reported zero invalid booking ranges and zero over-capacity rows | Pass | Maintenance and usage-session time order are not independently audited. |
| Approved overlap invariant | No same-space approved overlap | Zero prohibited pairs | Pass | Uses the required half-open predicate. |
| Active out-of-service relationship | No active OOS overlap | Zero matching rows | Pass | The generator excludes all such slots. |
| Advisory acknowledgement eligibility | Open advisory at submission and requested-period overlap | 145,458 acknowledgement rows reference a non-open advisory | Fail | `Resolved` rows are included in `#AdvMaint`. |
| Advisory acknowledgement completeness | Every qualifying active advisory acknowledged | 8,953 qualifying booking-maintenance pairs lack an acknowledgement | Fail | Rejected and cancelled booking requests are excluded. |
| Semester representation | Date-range parameter model | Compatible with Step 9 | Pass | Validator counts calendar years rather than academic years. |

## 5. Data Distribution Review

Observed during the first clean generation:

| Distribution | Observed Result | Assessment |
| --- | --- | --- |
| Statuses | Completed 57,750; Approved 15,750; Rejected 10,500; Cancelled 8,400; No-Show 5,250; Checked In 4,200; Pending 3,150 | All required cases represented. |
| Approval paths | Instant 2,296 (2.2%); Staff 102,704 (97.8%) | Both exist, but instant bookings are sparse. |
| Weekdays | 14,573 to 15,482 bookings per weekday | Nontrivial but nearly uniform. |
| Hours | 08:00, 10:00, 12:00, 14:00, and 16:00 only | Supports hourly reporting but has a fixed slot pattern. |
| Space volume | Top spaces: 5,010 each; least-popular populated spaces: 688-689 | Useful selectivity for conflict checks. |
| Capacity and facilities | 60 spaces, 12 facility types, 255 associations | Sufficient room-finder variation. |
| Maintenance | 2,450 advisory; 1,050 out-of-service | Both levels present. |
| Acknowledgements | 183,787 total | High volume, but relationship correctness fails. |

`Approved` bookings are also confined to 2023-09-01 through 2024-05-08. Consequently, the approved-booking reports have no results for later academic-year semesters, despite later rows in other booking statuses.

## 6. Issues Found

### Issue R14-1 - Advisory acknowledgement eligibility and completeness are incorrect

- **Severity:** Blocking
- **Issue:** The generator includes `Resolved` advisories in acknowledgement generation and excludes `Rejected` and `Cancelled` booking submissions.
- **Evidence:** `01-generate-data.sql` lines 624-626 use `maintenance_status IN ('Reported', 'In Progress', 'Resolved')`; line 642 excludes `Rejected` and `Cancelled`. Step 9 Decision 6 defines active advisories as only `Reported` or `In Progress`. Runtime audit found 145,458 acknowledgement rows tied to non-open advisories and 8,953 qualifying pairs with no acknowledgement.
- **Why this is a problem:** The data does not prove that every active advisory was disclosed at booking time, which is a core Phase 2 requirement.
- **Impact on Step 15:** Future query and index results involving acknowledgement data would be based on invalid relationships.
- **Suggested correction:** Source acknowledgements only from advisory records in `Reported` or `In Progress`, and insert every qualifying booking-maintenance pair, including requests later rejected or cancelled when they were submitted.

### Issue R14-2 - Validation does not independently test acknowledgement correctness

- **Severity:** Major
- **Issue:** The validator only tests whether maintenance began no later than the acknowledgement. It does not check active status, impact level, maintenance completion, requested-period overlap, missing acknowledgements, or duplicate pairs.
- **Evidence:** `02-validate-data.sql` lines 159-170 only compare `m.start_time` with `ack.acknowledged_at`. This check returns PASS despite the runtime findings in R14-1.
- **Why this is a problem:** The validation result is misleading and does not prove the Phase 2 acknowledgement rule.
- **Impact on Step 15:** The package cannot independently establish its own data quality before performance tests.
- **Suggested correction:** Add labeled pass/fail audits for invalid acknowledgement eligibility, missing qualifying pairs, duplicate pairs, acknowledgement time within the advisory period, and booking-period overlap.

### Issue R14-3 - No positive escalation-affected booking scenario exists

- **Severity:** Major
- **Issue:** The generator deliberately prevents all approved bookings from overlapping every out-of-service maintenance period, including records with advisory-to-out-of-service history.
- **Evidence:** The runtime audit found 0 escalation records with an overlapping `Approved` booking. This matches the prior Query 4 review's observed empty result for generated data.
- **Why this is a problem:** The required affected-booking report and related tuning cannot be evaluated against a nontrivial positive result set.
- **Impact on Step 15:** Staff would need hidden test inserts or manual repair to analyze the escalation scenario.
- **Suggested correction:** Generate controlled cases that were approved while maintenance was advisory, then represent the escalation to current out-of-service state and history. Keep them identifiable as intentional escalation-affected records.

### Issue R14-4 - Approved-report data is absent after the first academic year

- **Severity:** Major
- **Issue:** All 15,750 rows with status `Approved` end by 2024-05-08.
- **Evidence:** Runtime query returned an approved-booking range of 2023-09-01 through 2024-05-08. Phase 2 Reports 1 and 2 require approved booking data for a supplied semester.
- **Why this is a problem:** Later-semester approved booking-hours and weekday/hour reports are empty despite the claimed multi-year reporting dataset.
- **Impact on Step 15:** Approved-booking report tuning is not representative across the stated three academic years.
- **Suggested correction:** Distribute `Approved` status rows across Fall and Spring semesters for all three academic years.

## 7. Validation Script Assessment

Present checks include total row counts, booking date range, status and path distributions, weekday and hour counts, populated-space counts, impact-level counts, acknowledgement count, booking interval order, capacity, approver role, approved overlaps, active out-of-service overlaps, usage-session alignment, and trigger enablement.

The validator is missing or incomplete for the following required evidence:

- Explicit null and orphan audits for major tables and Phase 2 tables.
- Maintenance and usage-session time-order checks.
- Duplicate-key and impact-history validity checks.
- Academic-year counting using the project academic-year windows.
- Facility and capacity coverage pass/fail checks.
- Advisory acknowledgement eligibility, completeness, duplicate, and temporal checks.
- Count of bookings linked to multiple advisories.
- Advisory-to-out-of-service escalation-affected approved-booking analysis.

## 8. Step 15 Readiness Examination

| Question | Answer |
| --- | --- |
| Does the package create at least 100,000 bookings? | Yes, 105,000 observed. |
| Does it cover at least three academic years? | Yes for the overall booking table. |
| Are all required booking statuses represented? | Yes. |
| Are both approval paths represented? | Yes, but the instant path is only 2.2%. |
| Are both maintenance impact levels represented? | Yes. |
| Are advisory acknowledgements correctly represented? | No. |
| Are prohibited approved-booking conflicts absent? | Yes, zero observed. |
| Does room finding have meaningful capacity and facility variation? | Yes. |
| Do approved-booking reports have nontrivial results for every academic year? | No. |
| Are distributions suitable for all required tuning work? | Partly; space skew is useful, but escalation and later approved-report data are not. |
| Can the generator be rerun safely? | Yes in a dedicated benchmark database; the second run did not duplicate rows. |
| Does the validator prove the required properties? | No. |
| Would Step 15 need manual repair or hidden inserts? | Yes. |
| Are blocking issues unresolved? | Yes. |

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

1. Correct advisory acknowledgement generation to use only qualifying open advisory records and include every qualifying booking-maintenance pair.
2. Add independent acknowledgement eligibility, completeness, duplicate, and temporal validation checks.
3. Add intentional advisory-to-out-of-service escalation cases with affected approved bookings and validate their count.
4. Spread approved bookings over every required academic year and reporting semester.
5. Add the missing null, orphan, maintenance/usage temporal, academic-year, facility, and capacity validation evidence.

## 11. Final Readiness Verdict

**NOT READY FOR STEP 15**

The package meets scale, schema-compatibility, rerun, and approved-overlap requirements, but its acknowledgement data violates the approved active-advisory definition and its validator fails to detect that violation. Positive escalation cases and later-year approved reporting data are also required before meaningful Step 15 tuning can begin.
