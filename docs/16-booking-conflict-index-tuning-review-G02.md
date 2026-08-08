# Step 15 Booking Conflict Index-Tuning Review

## 1. Review Summary

- **Tuning SQL reviewed:** `outputs/16-booking-conflict-index-tuning-G02.sql`, the only current booking-conflict tuning SQL. The tracked 15 file is deleted, and the current companion report is numbered 16.
- **Step 12 conflict query reviewed:** `outputs/12-concurrency-implementation-G02.sql:421-430`.
- **Report reviewed:** `outputs/16-index-tuning-report-G02.md`. No current `outputs/15-index-tuning-report-G02.md` exists.
- **Review status:** Static only. No connection details were supplied through `w`; no SQL Server execution occurred.
- **Issue counts:** Blocking: 0; Major: 2; Minor: 0.
- **Final verdict:** **BOOKING CONFLICT TUNING NOT READY**.

The current SQL is statically reproducible and matches the production conflict predicate. It does not yet provide credible measured improvement because the report and all reported runtime evidence describe the prior Approved-only query, filtered index, and hard-coded parameter set rather than the current candidate.

## 2. Query Fidelity

| Predicate element | sp_ApproveBooking | Tuning SQL | Match? |
| --- | --- | --- | --- |
| Table | `dbo.BOOKING AS b` | `dbo.BOOKING AS b` | Yes |
| Same space | `b.space_code = @LockedSpaceCode` | `b.space_code = @LockedSpaceCode` | Yes |
| Current-booking exclusion | `b.booking_id <> @BookingId` | `b.booking_id <> @BookingId` | Yes |
| Occupying status | `b.booking_status IN ('Approved', 'Checked In')` | Same | Yes |
| Start overlap boundary | `b.requested_start < @RequestedEnd` | Same | Yes |
| End overlap boundary | `b.requested_end > @RequestedStart` | Same | Yes |
| Space parameter type | `@LockedSpaceCode VARCHAR(50)` | Same | Yes |
| Booking parameter type | `@BookingId INT` | Same | Yes |
| Interval parameter types | `@RequestedStart DATETIME`; `@RequestedEnd DATETIME` | Same | Yes |

The script uses the per-request lookup, not the Step 14 self-join, as its performance workload. `OPTION (MAXDOP 1)` appears only on global invariant validation. The script does not modify `sp_ApproveBooking`, and it preserves the transaction-held `dbo.SPACE WITH (UPDLOCK, HOLDLOCK)` protocol. `requested_end` is included for residual evaluation, not represented as a second perfect range seek.

## 3. Before/After Evidence

The report's measurements cannot be attributed to the current query, candidate, or dynamically selected parameters. Current evidence remains unmeasured until the corrected SQL is executed and its output is retained.

| Metric | Before | After | Verified? | Assessment |
| --- | ---: | ---: | --- | --- |
| Logical reads | Not yet measured | Not yet measured | No | Reported reads belong to the obsolete filtered-index test. |
| CPU time | Not yet measured | Not yet measured | No | Current candidate has no observed timing evidence. |
| Elapsed time | Not yet measured | Not yet measured | No | Current candidate has no observed timing evidence. |
| Main access operator | Not yet measured | Not yet measured | No | Current actual plans are not retained. |
| Index used | Not yet measured | Not yet measured | No | Current AFTER index use is not observed. |
| Actual rows | Not yet measured | Not yet measured | No | Current profile output is absent. |
| Estimated rows | Not yet measured | Not yet measured | No | Current profile output is absent. |
| Conflict result | Not yet measured | Not yet measured | No | The script asserts equality, but no current runtime result was supplied. |

## 4. Assumptions

| ID | Assumption | Evidence | Risk if wrong |
| --- | --- | --- | --- |
| A1 | The repository's current Step 12 script is the authoritative production definition for this static review. | `outputs/12-concurrency-implementation-G02.sql:285-540`; no runtime definition was supplied through `w`. | A deployed definition could differ and require a new fidelity review. |
| A2 | `outputs/16-booking-conflict-index-tuning-G02.sql` is the current tuning artifact. | It is the only existing preferred tuning file; the 15 file is deleted; the companion report is numbered 16. | An incomplete rename would require the project owner to designate the authority. |

## 5. Open Questions

| ID | Open question | Why it matters | Required evidence/decision |
| --- | --- | --- | --- |
| OQ1 | Which server/database contains the latest Step 12 objects and fully loaded current Step 14 dataset? | Dataset, procedure, and measurement identity must refer to one target. | Connection details through `w`, database name, current `OBJECT_DEFINITION`, and validator output from that target. |
| OQ2 | Which BOOKING indexes exist before the current candidate is removed? | Redundancy and the claimed one-index baseline cannot be confirmed from the stale report. | Captured output from the script's current `sys.indexes`/`sys.index_columns` inventory. |
| OQ3 | What parameters and density does the current selector choose on the tuning target? | The selector is valid statically, but exact values and workload selectivity are runtime facts. | Captured `#BenchmarkParameters` output and supporting density rows. |

## 6. Issues Found

### Issue R15BC-1 — Report and runtime evidence describe the obsolete benchmark

- **Severity:** Major
- **Issue:** The current report documents an Approved-only predicate, `CLS-BD-F1-011` with `booking_id = -1`, and filtered `IX_BOOKING_Approved_Space_Start`. The current SQL uses `Approved` plus `Checked In`, dynamically selects a real conflicting Pending booking from a high-density space, and creates unfiltered `IX_BOOKING_ConflictLookup` on `(space_code, booking_status, requested_start) INCLUDE (requested_end)`.
- **Evidence:** `outputs/16-index-tuning-report-G02.md:9-17,21-31,55-82` versus `outputs/16-booking-conflict-index-tuning-G02.sql:213-284,337-420,421-519`.
- **Impact:** The report's existing-index conclusion, operators, index used, logical reads, timings, row estimates, conflict result, index rationale, and retained-index recommendation do not prove improvement for the real current query or candidate.
- **Suggested correction:** Execute the current SQL on the verified target, retain its actual output/plans, and replace the report's booking-conflict section with only the observed current parameters, inventory, candidate, metrics, results, and plan interpretation.

### Issue R15BC-2 — Current candidate lacks captured plan and cost evidence

- **Severity:** Major
- **Issue:** The current key order is plausible for space equality, two status values, and the requested-start range, with `requested_end` covered for residual evaluation. The script now emits current index inventory and storage-footprint data, but no captured output or actual plan proves nonredundancy, key use, rows read, improvement, or cost. The report's write/storage discussion applies only to the old 15% filtered index.
- **Evidence:** Current inventory, candidate, and storage queries at `outputs/16-booking-conflict-index-tuning-G02.sql:328-352,438-461,537-555`; stale candidate comparison and filtered-index cost discussion at `outputs/16-index-tuning-report-G02.md:55-71,105-107`.
- **Impact:** An evaluator cannot determine whether the current index meaningfully reduces rows read and logical reads, duplicates another deployed access path, or has an acceptable maintenance/storage trade-off across all booking statuses.
- **Suggested correction:** Record the current inventory and actual BEFORE/AFTER plans; report seek and residual predicates, rows read, actual/estimated rows, reads, stable timing evidence, and the unfiltered index's write/storage cost. Retain one candidate only if that evidence supports it.

## 7. Required Revisions

1. Execute the current script against a verified current Step 14 target and retain the selected parameters, index inventory, actual plans, statistics output, and equal conflict results.
2. Replace the stale report content with evidence for `IX_BOOKING_ConflictLookup` and the exact `Approved`/`Checked In` production query.
3. Assess nonredundancy, rows read, residual behavior, and write/storage cost for the current unfiltered candidate before recommending retention.

## 8. Final Verdict

**BOOKING CONFLICT TUNING NOT READY**

Runtime validation did not occur. The current SQL resolves the prior static execution, candidate-state, and parameter-selection defects, but no valid current before/after evidence or matching report exists.
