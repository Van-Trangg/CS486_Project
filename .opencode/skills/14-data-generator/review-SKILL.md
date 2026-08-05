---
name: data-generator-step14-review
description: Review the Step 14 SQL Server data generator and validation scripts, then determine whether the generated dataset is ready for Step 15 indexing and query-tuning work.
compatibility: opencode
---

# Step 14 — Data Generator Review Skill

Use this skill after the Step 14 data-generation package has been created or updated.

Expected package:

`outputs/14-data-generator-G02/`

Expected files:

- `01-generate-data.sql`
- `02-validate-data.sql`

The review must determine whether the generator can reproducibly create a sufficiently large, realistic, and internally consistent Phase 2 dataset, and whether the validation script proves that the dataset is suitable for analytical-query and index-tuning work.

Do not approve the package merely because the scripts run or because the booking count reaches 100,000. Actively test whether the generated data covers the required business cases and whether the validation evidence is reliable.

---

## Review prompt

Examine the complete Step 14 data-generation package critically and answer:

> Is this data generator ready to support Step 15 indexing and query tuning without requiring manual repair, hidden assumptions, missing edge cases, unrealistic distributions, or unverified claims about data volume and quality?

Compare the package with:

1. The complete Phase 2 requirements.
2. The approved Phase 1 schema.
3. The Step 9 updated ERD and logical design.
4. The Step 10 schema migration.
5. The Step 11–13 concurrency design and implementation where relevant.
6. The Step 14 generation skill, if available.
7. The actual generated dataset, when a SQL Server runtime is available.

If the generator cannot create a clean dataset from the approved schema, does not include the required business cases, or cannot prove its own output through `02-validate-data.sql`, mark it as not ready.

---

## Input documents

### Required

Data-generation package:

- `outputs/14-data-generator-G02/01-generate-data.sql`
- `outputs/14-data-generator-G02/02-validate-data.sql`

Schema and design baseline:

- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`

Phase 2 requirement:

- `req/business-requirement-phase2.md`
- Or the actual Phase 2 requirement file under `req/` or `docs/`

### Relevant supporting artifacts

Read when available:

- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `outputs/13-concurrency-tests-G02/`
- Relevant review files under `docs/`
- `.opencode/skills/14-data-generator/SKILL.md`

---

## Output file

Create or update:

`docs/14-data-generator-review-G02.md`

Do not directly modify the generator or validation scripts unless the user explicitly requests automatic correction.

---

## Important review behavior

Before reviewing:

1. Run `ls -la`.
2. List every file under `outputs/14-data-generator-G02/`.
3. Verify that both required SQL files exist.
4. Read both files fully.
5. Verify object and column names against the migrated schema.
6. Distinguish:
   - Blocking issue
   - Major issue
   - Minor issue
   - Observation
7. Do not infer successful generation from comments or expected-result text.
8. If SQL Server execution is available, run the generator only in a safe disposable database.
9. If execution is unavailable, perform a static review and mark runtime-dependent findings as unverified.
10. Do not require exact distributions unless the requirement, design, or testing purpose justifies them.
11. Do not reject reasonable synthetic data merely because it is not identical to real university data.
12. Challenge unrealistic patterns when they would make index results misleading.

---

# Review criteria

## 1. Package completeness

Verify that the package contains:

- `01-generate-data.sql`
- `02-validate-data.sql`

Check whether:

- Files are non-empty.
- Sections are clearly organized.
- Execution order is documented.
- Required prerequisites are stated.
- The generator and validator use the same data assumptions.
- There are no unresolved placeholders.

Report missing files, broken references, or undocumented dependencies.

---

## 2. Schema compatibility

Verify every referenced:

- Table
- Column
- Primary key
- Foreign key
- Check constraint
- Status value
- Approval-path value
- Maintenance impact-level value
- Advisory-acknowledgement structure

against Steps 9 and 10 and the actual schema.

Check especially:

- `BOOKING`
- `SPACE`
- `FACILITY`
- Space-facility relationship table
- `MAINTENANCE_RECORD`
- Advisory acknowledgement table or columns
- User and staff references
- Requested start and end times
- Approval fields
- Semester or academic-year representation

A script that references nonexistent objects or invalid values is not ready.

---

## 3. Required data volume

Verify that the generator produces at least:

- Three academic years of data
- 100,000 booking records

Check whether:

- Booking volume is measured after generation.
- The count includes actual booking rows rather than staging rows.
- Re-running the script does not accidentally double the dataset unless documented.
- The validation script checks the exact required minimum.

If runtime is available, record the observed booking count.

---

## 4. Required business-case coverage

Verify that the generated data includes meaningful examples of:

- Approved bookings
- Pending bookings, when supported
- Rejected bookings, when supported
- Cancelled bookings
- Completed bookings
- No-show bookings
- Instant approvals
- Staff approvals
- Maintenance records
- Advisory maintenance
- Out-of-service maintenance
- Multiple active maintenance records for one space
- Maintenance escalation or data supporting escalation testing
- Advisory acknowledgements
- Spaces with different capacities
- Spaces with different facility combinations
- Spaces with no matching facility combinations
- Bookings distributed across multiple weekdays and hours
- Bookings across multiple semesters and academic years

Coverage must be large enough that analytical queries do not return trivial or empty results.

---

## 5. Temporal correctness

Verify that:

- `requested_start < requested_end`
- Approval or decision time is not earlier than creation time, when both are present
- Actual check-in and check-out times are logically ordered
- Maintenance start is earlier than completion when completion exists
- Open maintenance uses the approved null or open-ended representation
- Semester and academic-year dates are internally consistent
- Booking times fall within the intended academic period
- No impossible dates are generated
- Boundary cases exist where useful

Report temporal combinations that violate constraints or make reports unreliable.

---

## 6. Referential integrity and domain validity

Verify that:

- Every booking references an existing requester and space.
- Every approval staff reference exists and has a suitable role when required.
- Every maintenance reporter and assigned staff reference exists where required.
- Every space-facility row references existing records.
- Every advisory acknowledgement references valid booking and maintenance records.
- Status and impact values satisfy check constraints.
- Unique keys are not duplicated.
- Required fields are not null.
- Generated values fit declared data types and lengths.

The generator must not depend on disabling foreign keys or check constraints.

---

## 7. Booking-conflict validity

Verify that:

- Two `Approved` bookings do not overlap for the same space.
- Overlapping pending, rejected, or cancelled requests may exist when useful and allowed.
- Non-overlapping bookings for the same space are present.
- Overlapping bookings for different spaces are present.
- Adjacent intervals are present where useful.

The validation script should contain a conflict-detection query using:

```sql
b1.requested_start < b2.requested_end
AND b1.requested_end > b2.requested_start
```

Expected result for approved conflicts:

`0 rows`

Do not accept a validator that checks only duplicate start times.

---

## 8. Maintenance and acknowledgement consistency

Verify that:

- Advisory maintenance does not automatically make the space unbookable.
- Out-of-service maintenance is represented correctly.
- Approved bookings overlapping out-of-service maintenance are either intentional escalation-affected cases or clearly separated from invalid generated states.
- Advisory acknowledgements correspond to advisories active at booking time according to the approved design.
- A booking can acknowledge multiple advisories when required.
- Acknowledgement rows are not duplicated without justification.
- Maintenance escalation cases can be found by the required analytical query.

The validator should separately report:

- Advisory count
- Out-of-service count
- Acknowledgement count
- Bookings linked to multiple advisories
- Escalation-affected approved bookings

---

## 9. Distribution realism for index testing

Evaluate whether the generated distributions are sufficiently realistic to make before-and-after index comparisons meaningful.

Check for:

- Several spaces rather than nearly all bookings assigned to one space
- Popular and less-popular spaces
- Different booking densities by semester
- Different booking densities by weekday and hour
- Meaningful variation in capacity
- Meaningful facility combinations
- Selective room-finder results
- A nontrivial proportion of approved bookings
- Some maintenance and acknowledgement rows without overwhelming the booking table
- Enough repeated values for indexes to matter
- Enough selectivity for indexed predicates to produce different plans

Report distributions that would make tuning results misleading.

---

## 10. Generator quality and efficiency

Verify that `01-generate-data.sql`:

- Is rerunnable or clearly documents one-time execution.
- Avoids accidental duplicate generation.
- Uses a scalable set-based approach where practical.
- Avoids unnecessary row-by-row loops for 100,000+ bookings.
- Does not rely on undocumented temporary objects.
- Does not leave temporary tables or transactions behind.
- Uses deterministic or documented randomization.
- Avoids unbounded loops.
- Handles identity values safely.
- Preserves existing data or clearly documents reset behavior.
- Does not delete unrelated project data.

A slower generator is not automatically incorrect, but severe scalability problems may block performance testing.

---

## 11. Validation-script quality

Verify that `02-validate-data.sql` independently checks the generated result.

It should report at least:

1. Total booking count
2. Minimum and maximum booking dates
3. Number of distinct academic years or semesters
4. Counts by booking status
5. Counts by approval path
6. Counts by weekday and hour
7. Counts by space
8. Maintenance count by impact level
9. Advisory acknowledgement count
10. Null and orphan checks
11. Invalid time-range checks
12. Approved overlap invariant
13. Out-of-service overlap analysis
14. Facility and capacity coverage
15. Row counts for major Phase 2 tables

Each check should have:

- A clear label
- Actual observed result
- Expected threshold or condition
- Pass/fail interpretation where practical

Do not accept a validator that only displays total row counts.

---

## 12. Clean execution validation

When a SQL Server runtime is available, use a disposable database and run:

1. Step 5 schema
2. Step 10 migration
3. Step 12 implementation if required
4. `01-generate-data.sql`
5. `02-validate-data.sql`

Record:

- Whether each script completed
- Runtime errors
- Actual booking count
- Date range
- Major status counts
- Approved-conflict count
- Invalid foreign-key or null count
- Whether a second generator run is safe
- Approximate generation time only when actually measured

Do not manually repair the schema between steps.

When runtime is unavailable, state:

`The generator and validation scripts were reviewed statically; generated row counts and runtime behavior remain unverified.`

---

## 13. Step 15 readiness examination

Answer explicitly:

1. Does the package create at least 100,000 bookings?
2. Does it cover at least three academic years?
3. Are required booking statuses represented?
4. Are both approval paths represented?
5. Are maintenance impact levels represented?
6. Are advisory acknowledgements represented?
7. Are approved-booking conflicts absent except for documented escalation cases?
8. Does the room-finder query have meaningful capacity and facility variation?
9. Do the analytical queries return nontrivial result sets?
10. Are distributions suitable for before-and-after index comparison?
11. Can the package be rerun safely?
12. Does the validation script prove the required properties?
13. Would Step 15 need manual data repair or hidden inserts?
14. Are any blocking issues unresolved?

Then provide:

- **Ready elements**
- **Blocking gaps**
- **Non-blocking improvements**

---

## 14. Quality assessment

Assign a score from 0 to 10:

| Category | Evaluation focus |
| --- | --- |
| Completeness | Both scripts and required sections exist |
| Schema Compatibility | Scripts match the migrated schema |
| Data Volume | Required row count and time span are met |
| Business Coverage | Required statuses, maintenance, and acknowledgements exist |
| Integrity | Keys, constraints, domains, and temporal rules are valid |
| Distribution Quality | Data supports meaningful query tuning |
| Generator Quality | Script is safe, scalable, and reproducible |
| Validation Quality | Validator independently proves dataset properties |
| Step 15 Readiness | Dataset can support index and performance analysis |

Do not inflate scores because the SQL is long or generates many rows.

---

# Output format

# 1. Review Summary

State:

- What was reviewed
- Whether runtime generation was performed
- Observed booking count, if executed
- Most important strength
- Most important risk
- Overall Step 15 readiness

# 2. Files Reviewed

List every file in `outputs/14-data-generator-G02/`.

# 3. Requirement Coverage

| Requirement | Required | Generated or Checked | Evidence | Status |
| --- | --- | --- | --- | --- |

Include at least:

- Three academic years
- 100,000 bookings
- Maintenance
- Cancellations
- No-shows
- Advisory acknowledgements
- Approval paths
- Reporting-data variation

# 4. Schema and Integrity Check

| Area | Expected | Actual or Static Finding | Status | Notes |
| --- | --- | --- | --- | --- |

# 5. Data Distribution Review

Report:

- Counts by status
- Counts by approval path
- Counts by academic year or semester
- Counts by weekday and hour
- Booking concentration by space
- Maintenance distribution
- Acknowledgement distribution
- Capacity and facility variation

Clearly label values as observed or expected.

# 6. Issues Found

For each issue:

## Issue R14-X — Short title

- **Severity:** Blocking / Major / Minor / Observation
- **Issue:**
- **Evidence:**
- **Why this is a problem:**
- **Impact on Step 15:**
- **Suggested correction:**

# 7. Validation Script Assessment

State which required checks are present, missing, correct, or unreliable.

# 8. Step 15 Readiness Examination

Answer all readiness questions explicitly.

# 9. Scores

| Category | Score |
| --- | --- |
| Completeness | X/10 |
| Schema Compatibility | X/10 |
| Data Volume | X/10 |
| Business Coverage | X/10 |
| Integrity | X/10 |
| Distribution Quality | X/10 |
| Generator Quality | X/10 |
| Validation Quality | X/10 |
| Step 15 Readiness | X/10 |

# 10. Required Revisions Before Step 15

List only revisions required before index tuning begins.

If none:

`No blocking revisions are required before Step 15.`

# 11. Final Readiness Verdict

Choose exactly one:

- **READY FOR STEP 15**
- **READY FOR STEP 15 WITH MINOR REVISIONS**
- **NOT READY FOR STEP 15**

Provide a brief justification.

---

## Final response behavior

After creating the review:

1. State that `docs/14-data-generator-review-G02.md` was created or updated.
2. State the final readiness verdict.
3. State whether the generator was executed or reviewed statically.
4. Report the observed booking count and academic-year span when available.
5. Summarize only blocking and major issues.
6. Do not modify the data generator automatically.
7. Do not proceed to Step 15 automatically.
