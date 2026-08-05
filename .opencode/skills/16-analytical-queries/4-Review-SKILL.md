---
name: analytical-query4-maintenance-affected-review
description: Review Query 4 for correctness, schema compatibility, and readiness for Step 16 integration.
compatibility: opencode
---

# Query 4 Review — Maintenance Escalation Affected Bookings

Review the Query 4 section in:

`outputs/16-analytical-queries-G02.sql`

## Review prompt

> Is Query 4 ready for Step 16 integration without missing affected bookings, returning unaffected bookings, duplicating results, inventing escalation history, or overwriting other members’ work?

## Required inputs

Read fully:

- `req/business-requirement.md`
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- Step 14 generator and validation files
- `outputs/16-analytical-queries-G02.sql`
- Relevant reviews under `docs/`

Optional standard:

`.opencode/skills/16-query4-maintenance-affected/SKILL.md`

## Output file

Create or update:

`docs/16-query4-maintenance-affected-review-G02.md`

Do not modify the SQL unless automatic correction is explicitly requested.

---

## Review criteria

### 1. Integration safety

Verify that Query 4 has clear markers, Query 1–3 remain unchanged, no duplicate Query 4 exists, and the section is independently executable.

### 2. Schema compatibility

Verify every table, column, key, status, impact value, and data type against Steps 9 and 10.

Check especially:

- Maintenance ID
- Space foreign key
- Booking ID
- Booking start/end
- Approved status value
- Impact-level value
- Maintenance end/completion representation
- Requester/contact joins
- Escalation history or its absence

### 3. Requirement correctness

The result must include only bookings that are:

- Approved
- On the same space
- Overlapping the selected maintenance period
- Associated with a maintenance record confirmed as Out-of-Service

If historical escalation cannot be proven, the limitation must be explicit.

### 4. Interval correctness

Verify:

```sql
booking_start < maintenance_end
AND booking_end > maintenance_start
```

Test equal, containing, contained, partial, adjacent, and open-ended cases.

Use of `BETWEEN` or one-sided overlap logic is a major issue.

### 5. Result usefulness

The output should identify maintenance, space, affected booking, requester/contact details when available, and both time periods.

### 6. Duplicate control

Check that joins to users, facilities, acknowledgements, or history do not duplicate booking rows.

### 7. Functional testing

Verify coverage of multiple affected rows, no affected rows, advisory-only maintenance, another space, boundaries, full/partial overlap, and open-ended maintenance.

Distinguish prepared tests from executed tests.

### 8. SQL quality

Verify schema qualification, no `SELECT *`, clear aliases, correct parameter use, no index creation, no Step 12 changes, and no fabricated results.

---

## Runtime validation

When SQL Server is available:

1. Use a safe database with migrated schema and generated data.
2. Run Query 4 for at least three maintenance cases.
3. Independently calculate expected booking IDs.
4. Compare expected and actual results.
5. Record duplicates and boundary behavior.

Otherwise, state that runtime results remain unverified.

---

## Output format

# 1. Review Summary
# 2. Documents Reviewed
# 3. Requirement and Schema Mapping

| Requirement Element | Expected Schema Support | Query Evidence | Status | Notes |
| --- | --- | --- | --- | --- |

# 4. Result-Correctness Walkthrough
# 5. Functional Test Coverage

| Test Case | Prepared? | Executed? | Expected | Actual | Status |
| --- | --- | --- | --- | --- | --- |

# 6. Issues Found

## Issue R16Q4-X — Short title

- **Severity:** Blocking / Major / Minor / Observation
- **Issue:**
- **Evidence:**
- **Why this matters:**
- **Suggested correction:**

# 7. Scores

| Category | Score |
| --- | --- |
| Integration Safety | X/10 |
| Schema Compatibility | X/10 |
| Requirement Correctness | X/10 |
| Interval Correctness | X/10 |
| Result Usefulness | X/10 |
| Duplicate Control | X/10 |
| Test Coverage | X/10 |
| Step 16 Readiness | X/10 |

# 8. Required Revisions
# 9. Final Verdict

Choose exactly one:

- **QUERY 4 READY FOR INTEGRATION**
- **QUERY 4 READY WITH MINOR REVISIONS**
- **QUERY 4 NOT READY FOR INTEGRATION**

State whether runtime execution occurred.

---

## Final response behavior

Report the review file, final verdict, runtime/static status, and blocking or major issues only.
