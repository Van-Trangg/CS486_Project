---
name: booking-conflict-index-tuning-step15
description: Tune the booking-conflict check used by the protected approval workflow and document evidence before and after one suitable index.
compatibility: opencode
---

# Step 15 — Booking Conflict Check Indexing and Query Tuning

Use this skill for the required Phase 2 tuning target:

> Booking conflict check

This work tunes the overlap check used by the approved Step 12 booking-approval workflow. It must not replace or weaken the per-space concurrency lock.

## Required outputs

Create or update:

1. `outputs/15-index-tuning-report-G02.md`
2. `outputs/15-booking-conflict-index-tuning-G02.sql`

In the shared report, update only the clearly marked **Booking Conflict Check** section. Preserve room-finder and additional-report sections owned by other members.

---

## 1. Inspect the project

Read fully:

- `req/business-requirement.md`
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `outputs/14-data-generator-G02/01-generate-data.sql`
- `outputs/14-data-generator-G02/02-validate-data.sql`
- Existing `outputs/15-index-tuning-report-G02.md`
- Existing indexes from Step 5, Step 10, and the live database
- Relevant reviews under `docs/`

Identify the exact booking-conflict query inside `sp_ApproveBooking`.

Do not design an unrelated or simplified conflict query merely because it is easier to index.

---

## 2. Correctness boundary

The approved concurrency invariant is enforced by:

1. Acquiring the per-space lock.
2. Rechecking approved-booking overlap.
3. Approving only when no conflict exists.

The index improves lookup speed and may shorten transaction and lock duration. It is not the source of correctness.

Do not remove:

- The per-space lock
- The fresh recheck
- The transaction boundary
- The exact overlap semantics

Do not claim that an index alone prevents concurrent conflicting approvals.

---

## 3. Baseline conflict predicate

Use the actual Step 12 predicate, semantically equivalent to:

```sql
WHERE b.space_code = @space_code
  AND b.booking_status = 'Approved'
  AND b.booking_id <> @booking_id
  AND b.requested_start < @requested_end
  AND b.requested_end > @requested_start
```

Use actual schema names and status values.

Preserve the half-open interval rule. Do not replace it with `BETWEEN`.

---

## 4. Dataset readiness

Before tuning, verify from Step 14 or the live database:

- At least 100,000 bookings
- At least three academic years
- Several spaces
- A meaningful number of approved bookings
- Popular and less-popular spaces
- No unintended approved-overlap invariant violations

If the dataset is unsuitable, report the limitation rather than fabricating a performance comparison.

---

## 5. Existing-index inventory

Document all indexes on `BOOKING`, including:

- Index name
- Key columns and order
- Included columns
- Filter predicate
- Uniqueness
- Whether the conflict query can use it
- Whether the proposed index would duplicate it

Do not create a redundant index.

---

## 6. Candidate index analysis

Evaluate evidence-based candidates such as:

### Composite candidate

```sql
(space_code, booking_status, requested_start)
INCLUDE (requested_end, booking_id)
```

### Filtered candidate

```sql
(space_code, requested_start)
INCLUDE (requested_end, booking_id)
WHERE booking_status = 'Approved'
```

Use actual column names.

Do not create both by default. Select one final index based on:

- Approved-row proportion
- Existing indexes
- Execution plan
- Logical reads
- Estimated and actual row counts
- Write cost
- Filtered-index compatibility with the exact query predicate

Explain that interval overlap normally cannot seek efficiently on both interval endpoints at once. `requested_end` may remain a residual predicate.

---

## 7. Reproducible tuning script

Create `outputs/15-booking-conflict-index-tuning-G02.sql` with:

```sql
/* 1. Environment and dataset validation */
/* 2. Existing index inventory */
/* 3. Representative parameter selection */
/* 4. Baseline conflict-check execution */
/* 5. Proposed index creation */
/* 6. After-index conflict-check execution */
/* 7. Correctness and invariant checks */
/* 8. Optional rollback/drop statement */
```

Requirements:

- Use identical query text and representative parameters before and after.
- Use `SET STATISTICS IO ON`.
- Use `SET STATISTICS TIME ON`.
- Request or document the actual execution plan.
- Run multiple measured executions when possible.
- Separate compile effects from steady-state comparison.
- Do not use `DBCC FREEPROCCACHE` or `DBCC DROPCLEANBUFFERS` on a shared server.
- If cold-cache testing is used, do it only in a disposable environment and document it.
- Do not fabricate metrics.
- Do not drop unrelated indexes.
- Make the script rerunnable.
- Give the index a clear project-specific name.

---

## 8. Measurement requirements

Record before and after:

- Index used
- Main plan operator
- Seek versus scan
- Estimated rows
- Actual rows
- Logical reads
- CPU time
- Elapsed time
- Returned conflict-row count
- Key lookup, if any
- Residual predicate, if any
- Lock-duration implication only as a clearly labeled inference

Prefer several runs and report median elapsed time when actual execution is available.

Use the same database state and parameter set.

---

## 9. Representative parameter sets

Test more than one selectivity case where possible:

1. Popular space and busy interval
2. Less-popular space
3. Interval with no conflict
4. Interval with an existing conflict
5. Broad or worst practical interval if representative of the procedure

Do not tune only for one artificially favorable parameter.

If parameter sniffing materially affects plans, document it. Do not add `OPTION (RECOMPILE)` without evidence.

---

## 10. Correctness validation after tuning

Confirm that:

- Results are identical before and after.
- Approved-overlap invariant remains unchanged.
- Adjacent bookings remain allowed.
- Step 12 still acquires the per-space lock first.
- The index does not alter business semantics.
- No Step 12 workflow or error-handling rule was removed.

---

## 11. Report section

Update only this section in `outputs/15-index-tuning-report-G02.md`:

```markdown
# Booking Conflict Check

## Business and Concurrency Context
## Baseline Query
## Dataset and Test Environment
## Existing Indexes
## Baseline Plan and Measurements
## Candidate Indexes Considered
## Selected Index
## After-Index Plan and Measurements
## Before-and-After Comparison
## Correctness Verification
## Write and Maintenance Cost
## Limitations
## Conclusion
```

Include:

| Metric | Before | After | Change | Interpretation |
| --- | ---: | ---: | ---: | --- |

Clearly label metrics as observed. Do not place predicted values in the observed table.

---

## 12. Quality rules

- Use SQL Server terminology accurately.
- Do not say included columns are seek keys.
- Do not claim `requested_end` is fully seekable unless the plan proves it.
- Do not infer improvement only from estimated cost percentage.
- Prioritize actual logical reads and elapsed time.
- Do not compare different query text or parameters without disclosure.
- Do not tune on fewer rows while claiming a 100,000-row result.
- Preserve other members’ report sections.
- Do not tune Query 4 or the room finder here.

---

## 13. Self-review checklist

Confirm:

- The real Step 12 query was tuned.
- Dataset scale was verified.
- Existing indexes were inventoried.
- One nonredundant index was selected.
- Before/after query text and parameters match.
- Metrics are actual or explicitly pending.
- Correctness does not depend on the index.
- Results remain identical.
- Per-space locking remains unchanged.
- Write cost is discussed.
- Shared report sections are preserved.
- No result is fabricated.

---

## 14. Final response behavior

After generation:

1. State which files were created or updated.
2. State the selected index definition.
3. State whether measurements were executed or only prepared.
4. Summarize observed improvement only when evidence exists.
5. State any dataset or runtime limitation.
6. Do not proceed to other tuning targets.
