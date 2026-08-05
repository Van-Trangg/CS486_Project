# Step 14 Data Generator Review - G02

## 1. Review Summary

Reviewed `outputs/14-data-generator-G02/01-generate-data.sql` and `02-validate-data.sql` against the approved Phase 2 requirement, Steps 5 and 9-12, the relevant review reports, and `.opencode/skills/14-data-generator/SKILL.md`.

The generator and validation scripts were reviewed statically; generated row counts and runtime behavior remain unverified. `sqlcmd` can connect to the local SQL Server instance, but both reviewed scripts hard-code `USE University` and the existing `University` database was not established as a disposable database. Running the required clean sequence would delete its project data, so no destructive execution was performed.

- Most important strength: the scripts use mostly set-based generation, target the migrated object names and domains, and intend to create 105,000 bookings across September 2023 through May 2026.
- Most important risk: approved bookings are inserted with overlap prevention disabled and no substitute conflict-elimination logic. This will generate prohibited approved overlaps for the same space.
- Overall Step 15 readiness: not ready. The dataset cannot be relied upon for correctness-sensitive conflict checks, room finding, or index comparisons.

## 2. Files Reviewed

- `outputs/14-data-generator-G02/01-generate-data.sql`
- `outputs/14-data-generator-G02/02-validate-data.sql`

Both required files exist and are non-empty. Execution order and the `University` prerequisite are stated in the scripts.

## 3. Requirement Coverage

| Requirement | Required | Generated or Checked | Evidence | Status |
| --- | --- | --- | --- | --- |
| Three academic years | Yes | Intended, not runtime verified | Generator uses 1,004 days from `2023-09-01`; validator counts calendar years only | Partial |
| 100,000 bookings | Yes | Intended, not runtime verified | Target is 105,000; validator threshold is 100,000 | Partial |
| Maintenance records and impact levels | Yes | Intended | 3,500 rows; `advisory` and `out-of-service` values match migration | Static pass |
| Cancelled and no-show bookings | Yes | Intended | Modular status distribution includes both | Static pass |
| Instant and staff paths | Yes | Intended | `Instant` and `Staff` values match migration | Static pass |
| Advisory acknowledgements | Yes | Generated, but incomplete and temporally unreliable | Acknowledgements are limited with `booking_id % 3 = 0` and do not test whether advisory was active at submission | Fail |
| Different spaces, capacities, facilities | Yes | Intended | 60 spaces, six types, varied capacities, 12 facilities | Static pass |
| Useful semester, weekday, and hour distribution | Yes | Insufficiently modeled and unverified | Dates and hours are hash-uniform; no semester weighting; validator does not report weekday/hour or space distributions | Fail |
| No approved overlaps per space | Yes | Not generated or validated | Trigger disabled; independent booking generation; validator lacks the invariant query | Fail |

## 4. Schema and Integrity Check

| Area | Expected | Actual or Static Finding | Status | Notes |
| --- | --- | --- | --- | --- |
| Tables and columns | Step 5 plus Step 10 schema | Referenced table and column names match the migrated schema | Pass | Includes both Phase 2 junction/history tables. |
| Booking statuses | Seven Step 5 values | All seven valid literals are used | Pass | Status distribution is independent of time/space validity. |
| Approval paths | `Instant`, `Staff` | Both valid literals are used | Pass | Instant uses a NULL approver; staff uses facility staff/manager. |
| Maintenance impacts | `advisory`, `out-of-service` | Both valid literals are used | Pass | Values match `CK_MAINTENANCERECORD_IMPACT_LEVEL`. |
| Advisory acknowledgement structure | Unique booking/maintenance pair with valid disclosure | Correct columns and FK targets, but disclosure is not complete or provably active at submission | Fail | See R14-2. |
| Semester representation | Date-range parameters, no calendar table | Generator dates cover the intended broad period, but not weighted semesters | Partial | Validator counts `YEAR()`, not academic years/semesters. |
| Basic FK/domain values | Valid references and CHECK values | Static joins and literals appear compatible | Partial | Runtime validation is still required. |
| Approved booking invariant | No same-space approved overlaps | No construction safeguard while trigger is disabled | Fail | See R14-1. |
| Out-of-service relationship | No ordinary approved booking during active out-of-service maintenance; escalation cases identifiable | Independently generated approved bookings and maintenance can overlap; no escalation-only classification | Fail | See R14-1. |

## 5. Data Distribution Review

All values in this section are expected from static inspection, not observed.

- Statuses: Completed 55%, Approved 15%, Rejected 10%, Cancelled 8%, No-Show 5%, Checked In 4%, Pending 3%.
- Approval paths: `Instant` is only assigned to a modular subset of Meeting Room and Student Workspace rows; all other rows are `Staff`. This is meaningfully non-uniform.
- Academic period: dates are uniformly hash-distributed across 1,004 days, including summers. Fall and spring are not weighted more heavily as the Step 14 generation guidance requires.
- Weekday and hour: date assignment is uniform and hour assignment is uniform across 08:00 through 17:00, rather than weighted toward peak hours. No validator output proves these distributions.
- Space concentration: the 59 non-retired spaces are selected by uniform hash. It does not create deliberately popular and less-popular spaces.
- Maintenance: expected 70% advisory and 30% out-of-service; multiple records per space and overlapping periods are likely.
- Capacity and facilities: six space types and varied capacities/facility combinations are created. Facility combinations are type-wide templates rather than selectively varied within a type.

These distributions are likely to make index comparisons less representative: there is little intentional selectivity by space, semester, weekday, or hour, and invalid approved conflicts distort the conflict check and room-finder results.

## 6. Issues Found

## Issue R14-1 - Generator creates invalid approved availability states

- **Severity:** Blocking
- **Issue:** The generator disables the booking overlap/unavailability trigger, then inserts independently distributed bookings with 15% `Approved` status. It does not perform a half-open conflict elimination check before assigning `Approved`. It also includes `Temporarily Closed` spaces in `#BookableSpaces`.
- **Evidence:** `01-generate-data.sql` lines 43-52 disable booking triggers; lines 420-424 exclude only `Retired`; lines 451-545 independently generate and insert all booking states; lines 699-708 only re-enable triggers after the invalid rows already exist. No post-load repair or conflict check exists.
- **Why this is a problem:** The approved-booking invariant in the Phase 2 requirement and Step 12 is violated by same-space overlap candidates. Approved bookings may also be created for temporarily closed spaces. Independently generated active out-of-service maintenance can overlap approved bookings without being a documented escalation-follow-up case.
- **Impact on Step 15:** The booking-conflict check cannot be tuned against a valid dataset, and room-finder/report results become semantically unreliable.
- **Suggested correction:** Generate approved intervals per space without overlap, excluding closed/retired spaces and active out-of-service windows. Deliberately create affected approved rows only through clearly identified advisory-to-out-of-service escalation scenarios. Add a post-load fail-fast invariant query before re-enabling triggers.

## Issue R14-2 - Advisory acknowledgement coverage does not represent disclosure at booking time

- **Severity:** Blocking
- **Issue:** The generator acknowledges only bookings where `booking_id % 3 = 0`, even when other qualifying bookings have active advisories. It tests requested-period overlap, but not whether the advisory began before `created_at` and remained active when the acknowledgement was recorded.
- **Evidence:** `01-generate-data.sql` lines 611-626 insert acknowledgements with `b.created_at` but use only requested-time overlap and the one-third sampling predicate.
- **Why this is a problem:** Step 9 requires an acknowledgement for every active advisory disclosed at submission. A sampled subset neither records all disclosures nor prevents acknowledgements that predate the advisory's start.
- **Impact on Step 15:** Room-finder/advisory and escalation analyses cannot trust acknowledgement coverage; cardinality/selectivity of the Phase 2 junction table is misleading.
- **Suggested correction:** Determine active advisory records as of submission, require `m.start_time <= b.created_at` and open-at-submission logic, retain the requested-period condition required by Step 9 Decision 6, and insert one acknowledgement for every qualifying booking/advisory pair.

## Issue R14-3 - Validation script omits required independent integrity and distribution checks

- **Severity:** Blocking
- **Issue:** `02-validate-data.sql` has no approved-overlap invariant, no active out-of-service overlap analysis, no null or orphan audit, no decision-time or maintenance-period validation, no weekday/hour report, no booking-count-by-space report, and no facility-coverage audit. It also counts calendar years with `YEAR(requested_start)`, not academic years or semesters.
- **Evidence:** The script ends at line 320 after created-at ordering. Its only overlap query (lines 264-279) lists up to five overlapping maintenance pairs, not prohibited approved booking pairs or maintenance/booking relationships.
- **Why this is a problem:** The validator cannot independently establish the required Phase 2 dataset properties and would not expose the invalid data in R14-1 or R14-2.
- **Impact on Step 15:** There is no trustworthy evidence that the generated data is fit for tuning; manual ad hoc checks would be required.
- **Suggested correction:** Add labeled pass/fail result sets for every required check, particularly the half-open approved-overlap invariant, out-of-service escalation/overlap classification, advisory acknowledgement validity/completeness, null/orphan checks, temporal checks, academic-semester counts, weekday/hour and space distributions, capacity ranges, facility combinations, and major-table row counts.

## Issue R14-4 - Rerun safety is destructive and failures can leave triggers disabled

- **Severity:** Major
- **Issue:** The generator deletes every row from core project tables without a dataset scope, and trigger disable/enable work is not protected by a transaction or `TRY...CATCH` cleanup path.
- **Evidence:** `01-generate-data.sql` lines 70-78 delete all rows from nine project tables. Lines 43-60 disable triggers, while re-enabling occurs only at lines 699-716.
- **Why this is a problem:** Re-running the generator destroys unrelated project data in `University`; an error during generation leaves production business-rule triggers disabled and a partially loaded database.
- **Impact on Step 15:** Repeatable baseline loads are unsafe and can invalidate subsequent test work.
- **Suggested correction:** Require an explicitly named disposable database or isolate generator rows with an approved dataset scope. Use `TRY...CATCH` to guarantee trigger restoration, and make cleanup/data load atomic where feasible.

## Issue R14-5 - Distribution is too uniform for the stated performance purpose

- **Severity:** Major
- **Issue:** Hash assignment makes booking dates, hours, and spaces broadly uniform. The generator does not implement popular versus less-popular spaces or fall/spring concentration, and the validator does not report whether selectivity is achieved.
- **Evidence:** `01-generate-data.sql` lines 454-466 use uniform modulo hashes for day, hour, and space. The validator has no weekday/hour or per-space booking query.
- **Why this is a problem:** Uniform data can conceal realistic selectivity changes and make before/after index comparisons misleading.
- **Impact on Step 15:** The selected booking-conflict, room-finder, and reporting tuning cases may not demonstrate meaningful, repeatable index effects.
- **Suggested correction:** Define deterministic weighted distributions for popular spaces, peak weekday/hour slots, and fall/spring semesters, then validate the resulting concentration and selectivity explicitly.

## 7. Validation Script Assessment

Present checks include major-table row counts, calendar-year span, enum distributions, usage-session alignment, rejection reason, requested time order, capacity limit, approver role, instant-path approver nullability, acknowledgement/history presence, overlapping maintenance examples, trigger status, and `created_at` ordering.

Missing or unreliable required checks are approved booking overlaps, out-of-service overlap analysis, acknowledgement temporal validity and completeness, null/orphan checks, decision-time ordering, maintenance time order, exact academic-semester coverage, weekday/hour counts, counts by space, facility and capacity coverage, and clear pass/fail results for every reportable property. The script validates assumptions selectively; it does not prove the generated result is suitable for Step 15.

## 8. Step 15 Readiness Examination

| Question | Answer |
| --- | --- |
| Does the package create at least 100,000 bookings? | Intended but unverified at runtime. |
| Does it cover at least three academic years? | Intended but validator only proves calendar-year count. |
| Are required booking statuses represented? | Yes, statically. |
| Are both approval paths represented? | Yes, statically. |
| Are maintenance impact levels represented? | Yes, statically. |
| Are advisory acknowledgements represented? | Rows are intended, but required disclosure coverage is not met. |
| Are approved-booking conflicts absent except documented escalation cases? | No. |
| Does room finding have meaningful capacity/facility variation? | Partial; base variation exists, but availability data is invalid. |
| Do analytical queries return nontrivial results? | Intended but unverified; semantics are compromised by invalid availability data. |
| Are distributions suitable for index comparison? | No. |
| Can the package be rerun safely? | No. |
| Does the validation script prove required properties? | No. |
| Would Step 15 need manual data repair or hidden inserts? | Yes. |
| Are blocking issues unresolved? | Yes: R14-1 through R14-3. |

**Ready elements:** migrated object names and domain literals, broad row-volume target, all status literals, both approval paths, both maintenance impacts, set-based booking batches, and temp-table cleanup on the normal success path.

**Blocking gaps:** approved availability correctness, advisory acknowledgement correctness, and independent validation evidence.

**Non-blocking improvements:** isolate reruns and make distributions deliberately non-uniform for performance testing.

## 9. Scores

| Category | Score |
| --- | --- |
| Completeness | 7/10 |
| Schema Compatibility | 8/10 |
| Data Volume | 5/10 |
| Business Coverage | 5/10 |
| Integrity | 2/10 |
| Distribution Quality | 3/10 |
| Generator Quality | 4/10 |
| Validation Quality | 2/10 |
| Step 15 Readiness | 1/10 |

## 10. Required Revisions Before Step 15

1. Generate a valid approved-booking timeline per space, respecting half-open overlap logic, closed/retired spaces, and active out-of-service maintenance. Represent approved overlaps only when they are documented escalation-affected cases.
2. Generate every required advisory acknowledgement using active-at-submission and requested-period rules; remove the arbitrary one-third sampling condition.
3. Expand the validator to independently report all required integrity, temporal, overlap, acknowledgement, facility/capacity, academic-semester, weekday/hour, and per-space distribution checks with pass/fail conditions.
4. Make execution safe for an explicitly disposable database and guarantee trigger restoration after any failure.
5. Add deterministic skew by semester, space popularity, weekday, and hour, then validate that skew for Step 15 selectivity.
6. Execute the clean Step 5, Step 10, Step 12, generator, validator, and second-generator-run sequence in a confirmed disposable database; record observed counts, academic-year span, status counts, invariant results, and errors.

## 11. Final Readiness Verdict

**NOT READY FOR STEP 15**

The package targets the required schema and volume but does not construct or validate a dataset that preserves the approved-booking and advisory-disclosure rules. Runtime generation was not performed because a safe disposable target database was not available without overwriting the existing hard-coded `University` database.
