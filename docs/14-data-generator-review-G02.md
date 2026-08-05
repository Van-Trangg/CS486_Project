# Step 14 Data Generator Review - G02

## Review Scope

Reviewed the current package against `outputs/05-db-definition-G02.sql`, `outputs/09-updated-erd-and-logical-design-G02.md`, `outputs/10-schema-migration-G02.sql`, `outputs/11-concurrency-design-G02.md`, `outputs/12-concurrency-implementation-G02.sql`, `req/business-requirement-phase2.md`, and relevant reviews under `docs/`.

The requested optional instruction file `.opencode/skills/step-14-review-SKILL.md` does not exist. The approved project artifacts and requested workflow were used instead.

Files present and read in full:

- `outputs/14-data-generator-G02/01-generate-data.sql`
- `outputs/14-data-generator-G02/02-validate-data.sql`

## Execution Status

Static review only. `sqlcmd` and a local SQL Server instance are available, but runtime generation was not performed: `01-generate-data.sql` hardcodes `USE University` and deletes all rows from the project tables. Running it against the shared `University` database would not be a safe disposable-database test. No actual booking count, academic-year span, status counts, overlap count, second-run result, or runtime errors are claimed by this review.

## Schema Compatibility

| Area | Static result | Evidence |
| --- | --- | --- |
| Tables and columns | Compatible | All referenced Phase 1 and Phase 2 table/column names exist in Steps 5 and 10. |
| Keys and references | Compatible | Inserts use generated identities and values sourced from parent tables. `BOOKING_ADVISORY_ACK` uses the migrated unique booking-maintenance pair. |
| Booking statuses | Compatible | Uses only `Pending`, `Approved`, `Rejected`, `Cancelled`, `Checked In`, `Completed`, and `No-Show`. |
| Approval paths | Compatible | Uses only `Instant` and `Staff`. |
| Maintenance impacts | Compatible | Uses only `advisory` and `out-of-service`. |
| Advisory acknowledgement structure | Structurally compatible, semantically incorrect | Uses `booking_id`, `maintenance_id`, and `acknowledged_at`, but includes resolved advisories. |
| Semester and academic year | Compatible with Step 9 date-range model | No semester table is required. Dates span the intended September 2023 through approximately May 2026 grid, subject to runtime confirmation. |

## Requirement and Distribution Coverage

| Requirement | Static assessment |
| --- | --- |
| At least 100,000 bookings | Pass by design: 105,000 planned bookings plus escalation-affected rows. |
| At least three academic years | Pass by design for the overall `BOOKING` date grid. |
| Cancelled and no-show cases | Pass by design: explicit 8% `Cancelled` and 5% `No-Show` allocations. |
| Maintenance impact levels | Pass by design: 3,500 records with both permitted levels. |
| Instant and staff paths | Pass by design, although instant cases are limited to qualifying workspace/meeting-room rows. |
| Capacity and facility combinations | Pass by design: 60 spaces across six types, varying capacities, 12 facilities, and type-specific facility sets. |
| Weekday, hour, and semester variation | Pass with limitations: all weekdays occur, but bookings use only five fixed two-hour start slots and include summer dates. |
| Popular and less-popular spaces | Pass by design: the first 10 spaces, next 25, and remaining spaces receive materially different booking volumes. |
| Conflict-check selectivity | Pass by design: large per-space approved subsets and intentional space skew support a conflict-check index comparison. |
| Room-finder selectivity | Pass by design: capacities and facilities vary by space type, although facility combinations within each type are uniform. |
| Nontrivial analytical results | Partial: reports can use populated early semesters, but the generator does not demonstrate approved bookings throughout the full third academic year. |

## Integrity and Safety Findings

### R14-1 - Unsafe destructive reset and no atomic recovery

- **Severity:** Blocking
- **Evidence:** `01-generate-data.sql` lines 33-56 disable every relevant trigger; lines 63-78 delete all rows from the core and Phase 2 tables and reseed identities. The surrounding `TRY...CATCH` has no `BEGIN TRANSACTION` or rollback of the data reset (lines 30 and 801-827).
- **Impact:** A runtime failure after any delete or partial insert leaves `University` partially populated. Re-running also removes unrelated project data rather than isolating a Step 14 benchmark dataset. Trigger re-enablement in `CATCH` does not restore deleted rows.
- **Required revision:** Make the generator target an explicit disposable benchmark database or a clearly owned data namespace, document the scope, and protect reset/load operations with a transaction that rolls back on failure. Avoid disabling integrity triggers where possible; if a controlled bulk-load exception is unavoidable, restore them transactionally and validate all bypassed rules before commit.

### R14-2 - Advisory acknowledgement generation violates the approved active-advisory definition

- **Severity:** Blocking
- **Evidence:** Step 9 Decision 6 defines an active advisory as `impact_level = 'advisory'` and `maintenance_status IN ('Reported', 'In Progress')`. `01-generate-data.sql` lines 626-632 also includes `Resolved` advisory records in `#AdvMaint`, then creates acknowledgements from them at lines 635-646.
- **Impact:** Acknowledgement rows can claim that a resolved advisory was disclosed at booking time. This does not satisfy the Phase 2 requirement to inform requesters of all active advisories and corrupts acknowledgement-dependent test and tuning data.
- **Required revision:** Restrict acknowledgement generation and validation to open advisories (`Reported` and `In Progress`) that are active at the submission/acknowledgement time and overlap the requested period. Independently verify every qualifying booking-advisory pair has exactly one acknowledgement.

### R14-3 - Validator does not independently prove acknowledgement correctness or required integrity properties

- **Severity:** Major
- **Evidence:** `02-validate-data.sql` lines 159-200 checks current `impact_level`, timestamps, and period overlap for existing acknowledgement rows but does not test open maintenance status, missing qualifying acknowledgements, duplicate acknowledgement pairs, or generic Phase 2 orphan/null audits. Lines 275-296 check selected booking and session rules only. It also lacks maintenance time-order, usage-session time-order, explicit orphan checks for the major and Phase 2 tables, duplicate-key checks, and labelled capacity/facility coverage checks.
- **Impact:** The script can report a successful validation while data violates the acknowledgement rule or while required integrity evidence is absent. It validates generator assumptions rather than independently auditing the generated result.
- **Required revision:** Add labelled pass/fail queries for invalid and missing acknowledgement pairs, duplicate pairs, null/orphan rows for all major tables, maintenance and usage-session ranges, key duplicates, and explicit capacity/facility coverage. Include academic-year counts using the documented September-to-May academic-year windows rather than only `YEAR(requested_start)`.

### R14-4 - Approved-booking coverage is not demonstrably representative across all three academic years

- **Severity:** Major
- **Evidence:** Active booking slot sequences for the ten popular spaces stop at 3,500 two-hour slots (lines 512-517), approximately 700 days after 2023-09-01. Later dates are allocated to non-active statuses only. The validator's only approved-date-span check (lines 344-352) counts calendar years, not academic-year reporting semesters.
- **Impact:** The required approved-booking reports and a selected reporting-query index comparison may yield no representative approved result set for the 2025-2026 academic year, despite the overall table covering three years.
- **Required revision:** Distribute `Approved` rows across Fall and Spring semesters in each of the three academic years, and add an academic-year/semester status breakdown with a pass/fail threshold appropriate to the report workload.

## Positive Escalation Scenario

The package now intentionally adds escalation-affected approved bookings at lines 698-745. The source rows have advisory-to-out-of-service history and the final current maintenance impact is `out-of-service`. This is the appropriate type of positive scenario for Report 4, assuming the generated history, booking, and maintenance timing validate at runtime. The validator includes a positive check at lines 325-342, but runtime execution is still needed to verify a nonzero result.

## Validator Coverage Summary

Present checks include table counts, overall date range, calendar-year and semester labels, booking status/path values, weekday/hour counts, populated-space volume, impact-level counts, acknowledgement totals, booking time order, capacity, approver role, approved overlaps, active out-of-service overlaps, usage-session alignment, trigger state, and escalation-affected bookings.

Missing or inadequate required validation evidence includes:

- Open-advisory eligibility and completeness of advisory acknowledgements.
- Duplicate acknowledgement, key, and Phase 2-table relationship checks.
- Null and orphan audits for all major and Phase 2 tables.
- Maintenance and usage-session time-range checks.
- Academic-year counting based on the Step 14 three-year requirement.
- Explicit capacity and facility-combination coverage checks.
- Second-run safety evidence and post-failure recovery evidence.

## Step 15 Readiness

The package has useful scale, set-based generation patterns, space-volume skew, facility/capacity variation, valid literal domains, and a planned escalation scenario. Those strengths do not overcome the active-advisory acknowledgement violation, incomplete independent validation, and unsafe reset behavior. Benchmark measurements performed before these are corrected would not rest on a trustworthy and reproducible Step 14 dataset.

## Required Revisions Before Step 15

1. Isolate generator ownership and make reset/load failure-atomic without deleting unrelated `University` data.
2. Generate acknowledgements only for qualifying open advisory records and verify both invalid and missing pairs.
3. Expand `02-validate-data.sql` with independent null, orphan, duplicate, time-range, acknowledgement, academic-year, and capacity/facility coverage audits.
4. Ensure approved bookings occur in reportable Fall/Spring semesters across all three academic years and validate that distribution.
5. Execute the clean schema-to-generator-to-validator sequence in a disposable database and record actual counts, spans, status/path counts, approved overlap count, escalation scenario count, errors, and second-run outcome.

## Final Readiness Verdict

**NOT READY FOR STEP 15**
