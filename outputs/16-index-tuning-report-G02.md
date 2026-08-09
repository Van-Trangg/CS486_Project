# Booking Conflict Check

## Context

`dbo.sp_ApproveBooking` prevents overlapping occupying bookings by locking the target `SPACE` row with `UPDLOCK, HOLDLOCK`, then rechecking `BOOKING`. The index below only improves that lookup; it does not replace the locking or transaction logic.

## Conflict Predicate

```sql
WHERE b.space_code = @LockedSpaceCode
  AND b.booking_id <> @BookingId
  AND b.booking_status IN ('Approved', 'Checked In')
  AND b.requested_start < @RequestedEnd
  AND b.requested_end > @RequestedStart
```

The half-open interval rule allows adjacent bookings.

## Benchmark Setup

- Database: `University`
- `BOOKING` rows: 105,000
- Same real conflicting Pending booking used for BEFORE and AFTER
- `SET STATISTICS IO ON`
- `SET STATISTICS TIME ON`
- Actual Execution Plan enabled
- Candidate index removed before baseline
- No global cache clearing

## Candidate Index

```sql
CREATE NONCLUSTERED INDEX IX_BOOKING_ConflictLookup
ON dbo.BOOKING
(
    space_code,
    booking_status,
    requested_start
)
INCLUDE (requested_end);
```

`space_code` and `booking_status` support equality filtering, while `requested_start` supports the range seek. `requested_end` remains a residual predicate, which is expected for interval-overlap queries.

## Before vs After

| Metric | Before | After | Change |
|---|---:|---:|---:|
| Main access | Clustered Index Seek on `PK_BOOKING` | Nonclustered Index Seek on `IX_BOOKING_ConflictLookup` | Improved |
| Logical reads | 913 | 13 | -98.6% |
| Actual rows read | 47,755 | 698 | -98.5% |
| Estimated rows read | 43,505.5 | 770.002 | Reduced |
| Actual rows returned | 1 | 1 | Same |
| Warm elapsed run 1 | 129 ms | 76 ms | Improved |
| Warm elapsed run 2 | 114 ms | 83 ms | Improved |
| CPU time | 31 ms | 0 ms reported | Improved* |
| Conflict result | 1 | 1 | Same |

\* `0 ms` means below SQL Server's timing resolution, not zero CPU usage.

The strongest evidence is the reduction in logical reads and rows read. BEFORE used `PK_BOOKING` and read 47,755 rows to return one result. AFTER used `IX_BOOKING_ConflictLookup` and read only 698 rows.

## Correctness

```text
before_conflict_result = 1
after_conflict_result  = 1
result_equality_check  = PASS
prohibited_occupying_overlap_pairs_after_index = 0
```

The query semantics and `Approved`/`Checked In` occupancy rule were preserved.

## Index Cost

```text
Index rows: 105,000
Used pages: 655
Used size: 5.12 MB
```

The index is unfiltered because the production query must cover both occupying statuses. This increases write-maintenance cost for relevant `BOOKING` inserts/updates, but the observed 5.12 MB footprint is small relative to the measured read reduction.

## Conclusion

Retain `IX_BOOKING_ConflictLookup`.

For the representative production conflict lookup, it reduced:

- logical reads from **913 to 13**;
- rows read from **47,755 to 698**;

while preserving the conflict result and the zero-overlap invariant. The index improves lookup efficiency only; concurrency correctness still depends on the Step 12 locking protocol and fresh conflict recheck.

# Number of Approved Bookings by Weekday and Hour (Additional Reporting Query)

## Business and Reporting Context

Phase 2 requires a report showing the number of approved bookings by weekday and hour for a given semester (`req/business-requirement-phase2.md`, "New reporting needs"; P2-BR-08). This is the group's selected **additional reporting query** — the "other" reporting operation beyond the booking-conflict check and the room-finder query that the Phase 2 handout requires to be indexed (AGENTS.md §8.3). The query uses the same approved-lifecycle status definition as analytical Query 1 and the same semester-boundary convention as the group's documented semester design decision (Step 9, Decision 4): semester start and end are supplied as report parameters.

## Baseline Query

The measured operation is the approved-bookings-by-weekday-and-hour report for a single semester:

```sql
SELECT
    DATEPART(WEEKDAY, requested_start) AS weekday_num,
    DATENAME(WEEKDAY, requested_start) AS weekday_name,
    DATEPART(HOUR, requested_start) AS start_hour,
    COUNT(*) AS approved_booking_count
FROM dbo.BOOKING
WHERE booking_status IN ('Approved', 'Checked In', 'Completed')
  AND requested_start >= @SemesterStart
  AND requested_start <= @SemesterEnd
GROUP BY
    DATEPART(WEEKDAY, requested_start),
    DATENAME(WEEKDAY, requested_start),
    DATEPART(HOUR, requested_start)
ORDER BY weekday_num, start_hour;
```

The status filter matches the approved-lifecycle statuses used by analytical Query 1 (`Approved`, `Checked In`, `Completed`). A booking is counted once, in the weekday and hour bucket of its `requested_start`; the semester boundary is applied to `requested_start` inclusive on both ends, consistent with the other semester reports.

## Dataset and Test Environment

- Server/database: local SQL Server `localhost`, `University`.
- Dataset: the loaded Step 14 generator output, identical to the booking-conflict benchmark.
- Observed `BOOKING` rows: 105,000.
- Observed approved-lifecycle rows (`Approved`, `Checked In`, `Completed`): 77,700 (74.0%).
- Benchmark semester: Fall 2024, `[2024-09-01 00:00, 2024-12-31 23:59]`, matching analytical Query 1's default semester parameters.
- Rows counted by the benchmark: 10,107 approved-lifecycle bookings; result set: 63 rows (7 weekdays × 9 hour buckets).
- Cache conditions: warm-cache runs only. No `DBCC FREEPROCCACHE` or `DBCC DROPCLEANBUFFERS` command was issued. Each phase used one `STATISTICS PROFILE` execution and two additional identical steady-state executions.

## Existing Indexes

Before tuning, `dbo.BOOKING` had one index:

| Index | Keys | Includes | Filter | Weekday-and-hour-query fit | Redundant with selected index? |
| --- | --- | --- | --- | --- | --- |
| `PK_BOOKING` | `booking_id` | None | None | Leading key is `booking_id`, which does not serve the status or `requested_start` predicates | No |

`PK_BOOKING` was the clustered unique primary key. The report predicate had to filter all 105,000 rows by `booking_status` and `requested_start` as residual predicates.

## Baseline Plan and Measurements

Actual plan evidence was captured with `SET STATISTICS PROFILE ON`; I/O and timing evidence used `SET STATISTICS IO ON` and `SET STATISTICS TIME ON`.

- Main access: `Clustered Index Scan` on `PK_BOOKING`, reading every row and applying `requested_start` and `booking_status` as residual predicates.
- Actual versus estimated rows at the scan: 10,107 versus 16,000.7.
- Logical reads: 1,988 in each of three runs.
- Key lookup: none; the clustered index itself supplied all columns.
- Grouping and ordering were computed by the optimizer above the scan.

Observed baseline elapsed times were 34 ms, 24 ms, and 26 ms (the first value includes the profiling run). Median elapsed time is used in the comparison.

## Candidate Indexes Considered

| Candidate | Decision | Rationale |
| --- | --- | --- |
| `(requested_start) INCLUDE (booking_status)` without filter | Not selected | Stores all 105,000 rows including rejected, cancelled, pending, and no-show rows that the report never reads. |
| `(requested_start) WHERE booking_status IN ('Approved', 'Checked In', 'Completed')` | Selected | The filter matches the report's exact status set and narrows the index to the observed 74% approved-lifecycle subset; `requested_start` is the range seek key. |

## Selected Index

```sql
CREATE NONCLUSTERED INDEX IX_BOOKING_WeekdayHour
ON dbo.BOOKING (requested_start)
WHERE booking_status IN ('Approved', 'Checked In', 'Completed');
```

The filtered index stores only the 77,700 approved-lifecycle rows. `requested_start` is the leading and only key, which lets the optimizer seek directly on the semester range without reading rejected, cancelled, pending, or no-show rows. `booking_id` is available implicitly as the clustered key in this nonclustered index, so explicitly including it would be redundant. The filter's status set is exactly the report's `IN` predicate, so no residual status filter is needed inside the index.

## After-Index Plan and Measurements

- Main access: `Index Seek` on `IX_BOOKING_WeekdayHour`.
- Seek predicates: `requested_start >= @SemesterStart` and `requested_start <= @SemesterEnd`.
- Residual predicates: none.
- Actual versus estimated rows at the seek: 10,107 versus 17,253.3.
- Key lookup: none.
- Index footprint: 77,700 rows, 188 used pages, 1.47 MB.
- Report result: 63 rows, unchanged from baseline.

Observed after-index elapsed times were 7 ms, 6 ms, and 6 ms. Median elapsed time is used in the comparison.

## Before-and-After Comparison

| Metric | Before | After | Change | Interpretation |
| --- | ---: | ---: | ---: | --- |
| Main access | `PK_BOOKING` clustered scan | Filtered index seek | Improved | The filtered index restricts the scan to the 74% approved-lifecycle subset and adds a `requested_start` range seek. |
| Logical reads, median | 1,988 | 26 | -1,962 (98.69%) | Observed substantial reduction. |
| Elapsed time, median | 26 ms | 6 ms | 20 ms lower (~77%) | Steady-state elapsed time reduced. |
| Estimated / actual rows | 16,000.7 / 10,107 | 17,253.3 / 10,107 | Comparable | Both plans read the same 10,107 target rows. |
| Reported row count | 10,107 | 10,107 | Identical | Both forms count the same approved-lifecycle bookings. |
| Result rows | 63 | 63 | Identical | Weekday/hour bucket set unchanged. |
| Key lookup | None | None | Unchanged | The index covers the only column the query needs. |

## Correctness Verification

- The before and after predicates and semester parameters were identical (`Fall 2024`).
- Both phases returned the same 10,107 counted bookings and the same 63 weekday/hour result rows.
- The half-open boundary rule is not affected: this report uses inclusive semester bounds on `requested_start`, and the index changes only lookup cost, not which rows satisfy the predicate.
- The index does not alter `booking_status` or any interval semantics; it only narrows the rows considered to the approved-lifecycle statuses already required by the query.
- No correctness-sensitive booking or approval operation uses `NOLOCK`, and this tuning does not touch `dbo.sp_ApproveBooking` or the Step 12 locking protocol.

## Write and Maintenance Cost

The filtered index adds storage and maintenance for rows in the `Approved`, `Checked In`, or `Completed` status, rather than all booking rows. Inserts or status transitions into those statuses, and changes to `requested_start`, incur index maintenance. This is an acceptable trade-off for the observed 74% filtered subset and the 1,962-page read reduction, but index size and update overhead should be monitored after production workload characteristics are known.

## Limitations

- Measurements use the Fall 2024 semester on the generated dataset. Other semesters, and the selected status set, should be re-measured before extrapolating to every report invocation.
- The elapsed after-index values are small (6 ms median), so the exact percentage improvement should be interpreted with the machine's timer resolution in mind; the reads reduction is the more stable signal.
- Warm-cache results are intentionally reported; cold-cache behavior was not measured.
- The index is sized for the current 74% approved-lifecycle share; a materially different status distribution would change its selectivity.

## Conclusion

Retain `IX_BOOKING_WeekdayHour`. It is nonredundant with `PK_BOOKING` and the booking-conflict index, matches the report's exact status predicate, preserved the 63-row result set and the 10,107 counted bookings, and reduced observed logical reads from 1,988 to 26 with a median elapsed-time reduction from 26 ms to 6 ms.

# Available Spaces by Capacity, Facilities, and Time Period (Query 3 — Room Finder)

## Business Context

Facility managers and event planners use this query to find a bookable space matching a required capacity, facility set, and time window. It is a read-only search with no concurrency requirement of its own — the returned list is advisory; an actual booking attempt is still validated independently by `TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE` and the Step 12 approval path.

## Baseline Query

Tuning targets the query's two correlated `NOT EXISTS` overlap checks, each evaluated once per space row surviving the capacity and facility filters:

```sql
-- Approved/Checked-In booking overlap
AND NOT EXISTS (
    SELECT 1 FROM BOOKING b
    WHERE b.space_code = s.space_code
      AND b.booking_status IN ('Approved', 'Checked In')
      AND b.requested_start < @EndTime
      AND b.requested_end   > @StartTime
)

-- Out-of-service maintenance overlap
AND NOT EXISTS (
    SELECT 1 FROM MAINTENANCERECORD m
    WHERE m.space_code = s.space_code
      AND m.maintenance_status IN ('Reported', 'In Progress')
      AND m.impact_level = 'out-of-service'
      AND m.start_time < @EndTime
      AND ISNULL(m.completion_time, '9999-12-31') > @StartTime
)
```

## Dataset and Test Environment

Same dataset as the prior two benchmarks (Step 14 generator output; `BOOKING` 105,000 rows). `MAINTENANCERECORD` rows: 3,500. `BOOKING` rows: 105,000. `SPACE` rows: 60. Test window: `@RequiredCapacity = 10`, `@StartTime = 2023-09-01 09:00:00`, `@EndTime = 2023-09-01 12:00:00`. Cache and run protocol unchanged: warm cache, one `STATISTICS PROFILE` run plus two steady-state runs, median reported.

## Baseline Plan and Measurements

Before this tuning pass, `BOOKING` carried `PK_BOOKING` and `IX_BOOKING_Approved_Space_Start` which excludes `Checked In`, while `MAINTENANCERECORD` carried only its primary key. Neither `NOT EXISTS` check had a usable index, so both fell back to clustered scans.

- BOOKING access: `Clustered Index Scan` on `PK_BOOKING`, rebound once per surviving space row (35 executions), 3,302,950 rows read cumulatively.
- BOOKING logical reads: 62,562 
- MAINTENANCERECORD access: `Clustered Index Scan` on `PK_MAINTENANCERECORD`, 28 executions, 98,000 rows read cumulatively.
- MAINTENANCERECORD logical reads: 2,660.
- Query-level CPU / elapsed time: 3,993 ms / 5,416 ms.
- Result rows: 28

## Selected Indexes

```sql
CREATE NONCLUSTERED INDEX IX_BOOKING_OCCUPYING_OVERLAP
ON dbo.BOOKING (space_code, requested_start)
INCLUDE (requested_end, booking_status)
WHERE booking_status IN ('Approved', 'Checked In');

CREATE NONCLUSTERED INDEX IX_MAINTENANCE_OOS_OVERLAP
ON dbo.MAINTENANCERECORD (space_code, start_time, completion_time)
INCLUDE (maintenance_status)
WHERE impact_level = 'out-of-service';
```

`IX_BOOKING_OCCUPYING_OVERLAP` supersedes `IX_BOOKING_Approved_Space_Start`: its filter is a strict superset (`Approved`/`Checked In` vs. `Approved`-only) and it covers every column both the conflict-check and Query 3 need, so the Approved-only index becomes redundant and should be dropped. `IX_MAINTENANCE_OOS_OVERLAP` filters to out-of-service records only, since advisory maintenance never disqualifies a space.

## After-Index Plan and Measurements

- BOOKING access: `Index Seek` on `IX_BOOKING_OCCUPYING_OVERLAP` (filter widened to `IN ('Approved','Checked In')`), 35 executions, 8 rows read cumulatively. Logical reads: 74.
- MAINTENANCERECORD access: `Index Seek` on `IX_MAINTOOS_OVERLAP`, 28 executions, 2 rows read cumulatively. Logical reads: 56.
- Query-level CPU / elapsed time (Trial 3): 0 ms / 0 ms — below SSMS's 1 ms reporting resolution; client processing time 9 ms, total execution time 15 ms.
- Result rows: 28, confirmed via the results grid (matches baseline).

## Before-and-After Comparison

| Metric | Before | After | Change |
| --- | ---: | ---: | ---: |
| BOOKING access | Clustered scan on `PK_BOOKING` | Index seek on `IX_BOOKING_OCCUPYING_OVERLAP` | Improved |
| MAINTENANCERECORD access | Clustered scan on `PK_MAINTENANCERECORD` | Index seek on `IX_MAINTOOS_OVERLAP` | Improved |
| BOOKING logical reads | 62,562 | 74 | -62,488 (99.88%) |
| MAINTENANCERECORD logical reads | 2,660 | 56 | -2,604 (97.89%) |
| Query CPU time | 3,993 ms | sub-millisecond (~0 ms) | ~100% reduction |
| Query elapsed time | 5,416 ms | sub-millisecond (~0 ms) | ~100% reduction |
| Result rows | 28 | 28 | Identical |

## Correctness Verification

- Same query and parameters run before and after index creation; result sets compared row-for-row.
- Adding `Checked In` to the booking filter changes which statuses count as occupying (matching the enforcement trigger), not the half-open interval overlap rule itself.
- `impact_level = 'out-of-service'` and the status set are unchanged from the original query

## Limitations

- Measured on one representative capacity/time/facility combination; benefit will vary with how selective the capacity and facility filters are.
- `IX_BOOKING_Approved_Space_Start` should be dropped once `IX_BOOKING_OCCUPYING_OVERLAP` is confirmed in use, to avoid maintaining two overlapping filtered indexes on the same table.

## Conclusion

Retain `IX_BOOKING_OCCUPYING_OVERLAP` (Approved/Checked-In filter) and `IX_MAINTOOS_OVERLAP`. Both `NOT EXISTS` checks moved from clustered scans to filtered index seeks: BOOKING logical reads fell from 62,562 to 74 (99.88%), MAINTENANCERECORD from 2,660 to 56 (97.89%), and query time dropped from a 3,993 ms / 5,416 ms CPU/elapsed baseline to below the 1 ms reporting resolution, while the 28-row result set was identical before and after.