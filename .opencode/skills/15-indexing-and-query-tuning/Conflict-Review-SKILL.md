---
name: booking-conflict-index-tuning-step15-review
description: Review booking-conflict index tuning for reproducibility, correctness preservation, and Step 15 report readiness.
compatibility: opencode
---

# Step 15 Review — Booking Conflict Check Tuning

Review:

- `outputs/15-booking-conflict-index-tuning-G02.sql`
- The Booking Conflict Check section of `outputs/15-index-tuning-report-G02.md`

## Review prompt

> Does the tuning provide credible, reproducible evidence that one suitable index improves the real Step 12 conflict check while preserving the per-space locking protocol and query correctness?

## Required inputs

Read:

- Phase 2 requirement
- Steps 9–12
- Step 14 generator and validator
- Both Step 15 files
- Existing index definitions
- Relevant reviews under `docs/`

## Output file

Create or update:

`docs/16-booking-conflict-index-tuning-review-G02.md`

Do not modify tuning files unless automatic correction is explicitly requested.

---

## Review criteria

### 1. Scope and integration

Verify:

- Only the booking-conflict section was updated.
- Room-finder and additional-query sections were preserved.
- Supporting SQL matches the report.
- No unrelated index was created or dropped.

### 2. Real-query fidelity

Verify that tested SQL matches `sp_ApproveBooking`:

- Same table
- Same status filter
- Same space filter
- Same interval predicate
- Same current-booking exclusion
- Same relevant parameter types

A simplified query with changed semantics is insufficient.

### 3. Dataset validity

Verify:

- At least 100,000 bookings
- At least three academic years
- Meaningful approved-booking volume
- Several spaces with varied density
- No unintended approved overlaps
- Counts are observed, not assumed

### 4. Existing-index analysis

Verify all relevant indexes were inventoried and the selected index is not redundant.

### 5. Index design quality

Check:

- Equality filters precede range filters where justified.
- Included columns are not described as seek keys.
- A filtered predicate matches the query when used.
- `requested_end` residual behavior is explained.
- One final index is recommended unless more are strongly justified.
- Write and storage costs are discussed.

### 6. Before-and-after fairness

Verify:

- Same query text
- Same parameters
- Same data
- Same database and server
- Comparable cache conditions
- Multiple runs where possible
- No global cache clearing on a shared system
- No unrelated index changes

### 7. Evidence quality

Verify observed:

- Logical reads
- CPU
- Elapsed time
- Actual and estimated rows
- Plan operators
- Index used
- Result count

Estimated cost percentage alone is insufficient.

Distinguish actual metrics from pending or predicted metrics.

### 8. Correctness preservation

Verify:

- Results are identical before and after.
- Correct overlap semantics remain.
- Adjacent bookings remain allowed.
- Per-space lock remains in Step 12.
- The report does not claim the index enforces correctness.

### 9. Reproducibility

An evaluator must be able to load data, run baseline, create the index, rerun, compare, and optionally drop the test index.

### 10. Runtime validation

When SQL Server is available, rerun representative cases. Otherwise label runtime evidence unverified.

---

## Output format

# 1. Review Summary
# 2. Documents and Environment Reviewed
# 3. Query Fidelity Check

| Step 12 Predicate Element | Tuning Script | Match? | Notes |
| --- | --- | --- | --- |

# 4. Index Design Assessment
# 5. Measurement Reproducibility
# 6. Before-and-After Evidence

| Metric | Reported Before | Reported After | Reproduced? | Assessment |
| --- | ---: | ---: | --- | --- |

# 7. Correctness and Concurrency Preservation
# 8. Issues Found

## Issue R15BC-X — Short title

- **Severity:** Blocking / Major / Minor / Observation
- **Issue:**
- **Evidence:**
- **Impact:**
- **Suggested correction:**

# 9. Scores

| Category | Score |
| --- | --- |
| Scope Safety | X/10 |
| Query Fidelity | X/10 |
| Dataset Validity | X/10 |
| Index Design | X/10 |
| Measurement Fairness | X/10 |
| Evidence Quality | X/10 |
| Correctness Preservation | X/10 |
| Reproducibility | X/10 |
| Report Readiness | X/10 |

# 10. Required Revisions
# 11. Final Verdict

Choose exactly one:

- **BOOKING CONFLICT TUNING READY FOR REPORT INTEGRATION**
- **BOOKING CONFLICT TUNING READY WITH MINOR REVISIONS**
- **BOOKING CONFLICT TUNING NOT READY**

State whether runtime validation occurred.

---

## Final response behavior

Report the review file, final verdict, runtime/static status, and blocking or major issues only.
