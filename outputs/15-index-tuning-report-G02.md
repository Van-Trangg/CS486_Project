# Booking Conflict Check

## Business and Concurrency Context

Phase 2 requires that concurrent instant and staff approvals never create overlapping approved bookings for the same space. `dbo.sp_ApproveBooking` preserves this invariant by first acquiring `dbo.SPACE` with `UPDLOCK, HOLDLOCK`, then rechecking `dbo.BOOKING` inside the same short transaction. The selected index reduces the cost of that recheck and may shorten lock duration; it is not a concurrency-control mechanism and does not replace the lock, transaction, or fresh check.

## Baseline Query

The measured predicate is the approved-booking conflict check from `dbo.sp_ApproveBooking`:

```sql
WHERE b.space_code = @LockedSpaceCode
  AND b.booking_id <> @BookingId
  AND b.booking_status = 'Approved'
  AND b.requested_start < @RequestedEnd
  AND b.requested_end > @RequestedStart
```

It uses the approved half-open overlap rule. `requested_end` remains a residual predicate because a B-tree cannot simultaneously seek efficiently on both range endpoints.

## Dataset and Test Environment

- Server/database: local SQL Server `localhost`, `University`.
- Dataset: the loaded Step 14 generator output.
- Observed `BOOKING` rows: 105,000.
- Observed approved rows: 15,750 (15.0%).
- Observed booking span: 2023-09-01 through 2026-03-25, covering four calendar years.
- Observed spaces with bookings: 58.
- Observed prohibited approved-overlap pairs before and after tuning: 0.
- Representative conflict case: `space_code = 'CLS-BD-F1-011'`, `booking_id = -1`, requested interval `[2023-09-01 08:00, 2023-09-01 10:00)`. It represents a new pending booking and returned one conflict in every run.
- Cache conditions: warm-cache runs only. No `DBCC FREEPROCCACHE` or `DBCC DROPCLEANBUFFERS` command was issued. Each phase used one `STATISTICS PROFILE` execution and two additional identical steady-state executions.

## Existing Indexes

Before tuning, `dbo.BOOKING` had one index:

| Index | Keys | Includes | Filter | Conflict-query fit | Redundant with selected index? |
| --- | --- | --- | --- | --- | --- |
| `PK_BOOKING` | `booking_id` | None | None | No useful leading key for `space_code`, status, or time predicates | No |

`PK_BOOKING` was the clustered unique primary key. The conflict predicate's `booking_id <> @BookingId` was transformed into two primary-key ranges, but `space_code`, `booking_status`, and both time predicates were residual filters. No existing index covered the proposed access path.

## Baseline Plan and Measurements

Actual plan evidence was captured with `SET STATISTICS PROFILE ON`; I/O and timing evidence used `SET STATISTICS IO ON` and `SET STATISTICS TIME ON`.

- Main access: `Clustered Index Seek` on `PK_BOOKING`, but effectively scan-like because the two ranges derived from `booking_id <> -1` span the clustered key.
- Actual versus estimated rows at the conflict-producing access: 1 versus 1.
- Logical reads: 2,520 in each of three runs.
- Key lookup: none; the clustered index itself supplied all columns.
- Residual predicates: `space_code`, `booking_status`, `requested_start`, and `requested_end`.

Observed baseline CPU times were 47 ms, 63 ms, and 46 ms. Observed elapsed times were 50 ms, 51 ms, and 49 ms. Median values are used in the comparison.

## Candidate Indexes Considered

| Candidate | Decision | Rationale |
| --- | --- | --- |
| `(space_code, booking_status, requested_start) INCLUDE (requested_end)` | Not selected | It can support the predicate, but stores all 105,000 status values and duplicates the constant `Approved` condition as a key. |
| `(space_code, requested_start) INCLUDE (requested_end) WHERE booking_status = 'Approved'` | Selected | The filter exactly matches the procedure predicate and targets the observed 15% approved subset. Equality on `space_code` precedes the `requested_start` range. |

## Selected Index

```sql
CREATE NONCLUSTERED INDEX IX_BOOKING_Approved_Space_Start
ON dbo.BOOKING (space_code, requested_start)
INCLUDE (requested_end)
WHERE booking_status = 'Approved';
```

`booking_id` is available implicitly as the clustered key in this nonclustered index, so explicitly including it would be redundant. `requested_end` is included to evaluate the residual overlap predicate without a key lookup.

## After-Index Plan and Measurements

- Main access: `Index Seek` on `IX_BOOKING_Approved_Space_Start`.
- Seek predicates: `space_code = @LockedSpaceCode` and `requested_start < @RequestedEnd`.
- Residual predicates: `requested_end > @RequestedStart` and `booking_id <> @BookingId`.
- Actual versus estimated rows at the seek: 1 versus 1.
- Key lookup: none.
- Conflict result: 1 in every run, matching baseline.

Observed after-index CPU and elapsed time were each reported as 0 ms in all three runs, below the server's one-millisecond reporting resolution. Logical reads were 2 in every run.

## Before-and-After Comparison

| Metric | Before | After | Change | Interpretation |
| --- | ---: | ---: | ---: | --- |
| Main access | `PK_BOOKING` scan-like clustered seek | Filtered index seek | Improved | The filtered index supplies useful leading seek keys. |
| Logical reads, median | 2,520 | 2 | -2,518 (99.92%) | Observed substantial reduction. |
| CPU time, median | 47 ms | <1 ms | At least 46 ms lower | The after value is limited by reporting resolution. |
| Elapsed time, median | 50 ms | <1 ms | At least 49 ms lower | The after value is limited by reporting resolution. |
| Estimated / actual rows | 1 / 1 | 1 / 1 | Unchanged | Both plans estimated this conflict case accurately. |
| Returned conflict result | 1 | 1 | Identical | Both forms detect the same overlap. |
| Key lookup | None | None | Unchanged | `requested_end` is covered by the selected index. |

## Correctness Verification

- The before and after predicates and parameters were identical.
- Both phases returned `conflict_exists = 1` for the selected conflicting interval.
- The post-index approved-overlap invariant check returned 0 prohibited pairs.
- The half-open predicates were unchanged, so adjacent intervals remain non-conflicting.
- `outputs/12-concurrency-implementation-G02.sql` was not modified. `dbo.sp_ApproveBooking` still acquires the per-space `UPDLOCK, HOLDLOCK` before its overlap recheck.
- The index changes only lookup cost. It does not enforce the no-overlap invariant or provide correctness without the Step 12 locking protocol.

## Write and Maintenance Cost

The filtered index adds storage and maintenance for rows currently in `Approved` status, rather than all booking rows. Inserts or status transitions into/out of `Approved`, and changes to `space_code`, `requested_start`, or `requested_end`, incur index maintenance. This is an acceptable trade-off for the observed 15% filtered subset and substantial read reduction, but index size and update overhead should be monitored after production workload characteristics are known.

## Limitations

- Measurements are from one representative conflicting two-hour interval on a local generated dataset. Additional popular, low-volume, no-conflict, and broad-interval cases should be measured before extrapolating latency to every approval workload.
- The dataset's generated approved bookings are non-overlapping by design; conflict testing uses a candidate interval against an existing approved row rather than an actual conflicting approved pair.
- The elapsed and CPU after-index values are below one-millisecond resolution, so exact percentage time improvement is not claimed.
- Warm-cache results are intentionally reported; cold-cache behavior was not measured.

## Conclusion

Retain `IX_BOOKING_Approved_Space_Start`. It is nonredundant, matches the exact `Approved` conflict predicate, preserved results and concurrency semantics, and reduced observed logical reads from 2,520 to 2. The accompanying script reproduces the baseline, filtered-index creation, after measurement, correctness checks, and optional rollback without changing any other tuning target.
