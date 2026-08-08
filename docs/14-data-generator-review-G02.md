# 1. Review Summary

**Package reviewed:** `outputs/14-data-generator-G02/`, including every required package file.

**Review type:** Static package review using supplied runtime validation evidence for database `Step14ReviewG02_20260805`. The generator, dry-run, validation SQL, and database lifecycle operations were not rerun, as explicitly prohibited. A Python AST parse was used for a non-executing syntax check.

**Most important strength:** The package combines strict target-database guards, deterministic generation, exact migrated-schema mappings, correct interval-based conflict avoidance, and scalable batched loading. Independent runtime validation reports `49` passed checks and `0` failed checks.

**Most important risk:** The named generator runtime transcript `docs/14-generator-runtime-output-G02.txt` is not present in the repository. The supplied validation transcript proves the resulting database contents but does not independently preserve the Python version, ODBC driver, generator exit code, elapsed load time, or reset/rerun outcome.

**Observed result:** `105,000` bookings from `2023-09-01 08:00:00.000` through `2026-05-31 20:00:00.000`, covering academic years beginning `2023`, `2024`, and `2025`.

**Overall Step 15 readiness:** The generated database is suitable for Step 15. No blocking or major issue was found; only minor evidence and general configuration-validation improvements remain.

# 2. Files Reviewed

- `.opencode/skills/14-data-generator/new-SKILL.md`
- `.opencode/skills/14-data-generator/new-review-SKILL.md`
- `outputs/14-data-generator-G02/generate_data.py`
- `outputs/14-data-generator-G02/generator_config.json`
- `outputs/14-data-generator-G02/requirements.txt`
- `outputs/14-data-generator-G02/README.md`
- `outputs/14-data-generator-G02/02-validate-data.sql`
- `req/business-requirement-phase2.md`
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- Relevant Step 5, Step 8 through Step 14 reviews and accepted Step 12 feedback under `docs/`
- `docs/14-generator-validation-output-G02.txt`

All five required package files exist and are non-empty. No optional helper file is present or required. The JSON is structurally valid, and `requirements.txt` declares the only third-party import, `pyodbc`.

# 3. Safety Assessment

| Safety Check | Expected | Finding | Status | Evidence |
| --- | --- | --- | --- | --- |
| Target selection | No hardcoded target database | `--database` supplies the connection target; no `USE` statement exists | Pass | `build_connection_string()`, CLI |
| Protected database | Never target `University` | `University` is unconditionally refused, including with bypass | Pass | `validate_target_database()` |
| Disposable guard | Unsafe names rejected by default | Only `Step14*`, `Test*`, or `Dev*` pass by default | Pass | `DISPOSABLE_PREFIXES` |
| Explicit bypass | Required for other names | `--allow-non-disposable` is explicit and emits a warning | Pass | CLI and target validation |
| Reset policy | Explicit and disposable-only | Reset requires `--reset-generated-data`; non-disposable reset is always rejected | Pass | `main()`, `prepare_target()` |
| Existing data | No implicit overwrite | Any non-empty target fails unless disposable reset is authorized | Pass | `prepare_target()` |
| Destructive SQL | Guarded | Only broad `DELETE` in explicit disposable reset; no `TRUNCATE`, `DROP`, `USE University`, or `ALTER DATABASE` | Pass | Destructive-SQL search |
| Dry-run writes | None | Dry-run returns before trigger changes, reset, identity operations, or inserts | Pass statically | `main()` dry-run branch |
| Credentials | No plaintext secret | Password is read from the environment named by `--password-env` | Pass | `build_connection_string()` |
| Connection context | Exact target required | `SELECT DB_NAME()` must equal the CLI database before writes | Pass | `inspect_schema()` |
| Trigger restoration | Restore original enabled set | Enabled protected-table triggers are captured, disabled, and restored in `finally` | Pass runtime | Validator reports `0` disabled protected-table triggers |

The reset deletes all rows in the nine project tables, but only after both an explicit reset flag and disposable-name verification. Trigger disablement is limited to the three tables whose Phase 1/Step 12 triggers would reject historical benchmark states. Foreign keys and check constraints remain enabled and trusted.

# 4. Schema Compatibility

| Area | Expected | Generator Mapping | Status | Notes |
| --- | --- | --- | --- | --- |
| Schema and tables | Nine `dbo` data tables after Steps 5 and 10 | Exact names and `dbo` qualification | Pass runtime | All loaded and validated |
| `USER` | Seven baseline columns and six role values | Exact columns, lengths-compatible values, unique IDs/emails | Pass runtime | 600 rows; six roles and three statuses |
| `SPACE` | Nine baseline columns and approved domains | Exact columns and values | Pass runtime | 60 rows; all six types and five statuses |
| `FACILITY` | Identity PK and unique name | Explicit deterministic identities 1-12 | Pass runtime | 12 unique facilities |
| `SPACE_FACILITY` | Composite PK and valid domains | Exact five-column mapping | Pass runtime | 343 rows; no orphans |
| `BOOKING` | Baseline fields plus `approval_path`; server `row_version` | Inserts every writable column and omits server-generated `row_version` | Pass runtime | 105,000 rows and all domains |
| `USAGESESSION` | Booking PK/FK and staff references | Exact eight-column mapping | Pass runtime | 61,950 valid rows |
| Maintenance | `impact_level` with exact lowercase values | Exact eleven-column mapping | Pass runtime | 3,500 rows and both impacts |
| Advisory acknowledgement | Identity PK, two FKs, unique pair | Exact four-column mapping | Pass runtime | 58,962 valid rows; no duplicates or omissions |
| Impact history | Identity PK, maintenance/user FKs, impact domains | Exact six-column mapping | Pass runtime | 700 valid rows; consistent chains/current state |
| Identity metadata | Five migrated identity columns | `IDENTITY_INSERT` only for those five tables | Pass | Matches Steps 5 and 10 |
| Insertion order | Parent before child | User, facility, space, space-facility, maintenance, booking, usage, acknowledgement, history | Pass | FK-safe |

`inspect_schema()` requires exact column sets for all nine tables, verifies the five identity mappings, checks correctness-sensitive data types/nullability, and rejects disabled or untrusted foreign-key/check constraints. The successful load and zero-orphan validation provide runtime confirmation beyond the static mapping.

# 5. Configuration and Reproducibility

| Setting | Configured Value | Assessment |
| --- | ---: | --- |
| Booking count | 105,000 | Meets the required minimum and was observed |
| Academic-year count | 3 | Meets the minimum and was observed |
| Batch size | 10,000 | Positive, configurable, and used by bulk insertion |
| Random seed | 48,602 | Fixed and configurable |
| Users | 600 | Above required benchmark minimum |
| Spaces | 60 | Above required benchmark minimum |
| Maintenance records | 3,500 | Above required benchmark minimum |
| Facilities | 12 | Matches the deterministic catalog |
| Date range | 2023-09-01 to 2026-05-31 | Three observed academic years |

Configuration loading rejects missing and unknown keys, unsupported statuses, insufficient counts, non-positive batch sizes, invalid ratios, date-order errors, and empty ODBC driver names. Status ratios must contain exactly all seven schema statuses and sum to `1.0` without silent normalization.

Generation uses a local `random.Random(config.random_seed)` instance. No Faker or uncontrolled random source is used. Explicit generated identity values make logical rows and foreign-key relationships deterministic; the README correctly notes that SQL Server `row_version` values remain server-generated.

The general date-range validator counts covered calendar years rather than deriving distinct academic years using the same September boundary as the SQL validator. The current configuration is unaffected because runtime validation proves three academic years, but another accepted date range could theoretically under-cover the configured academic-year count.

# 6. Generation Logic Review

## Users

- IDs and emails are deterministic and unique.
- All six approved roles and all three account statuses are represented.
- Approval, assignment, usage-session, and impact-change staff references use active Facility Staff or Facility Manager users only.

## Spaces and Facilities

- Six space types, five statuses, four buildings, 21 capacities, and 19 facility combinations were observed.
- Facility quantity and operation status vary within the approved domains.
- Popular, medium, and lower-volume space pools provide useful conflict-check selectivity.
- Capacity and all-facility room-finder predicates have both qualifying and non-qualifying spaces.

## Bookings

- All seven statuses are deterministically allocated: Approved 15,750; Cancelled 8,400; Checked In 4,200; Completed 57,750; No-Show 5,250; Pending 3,150; Rejected 10,500.
- Both approval paths were observed: Instant 36,905 and Staff 68,095.
- Instant selection is limited to configured eligible Meeting Room and Student Workspace rows.
- Staff decisions reference active staff; instant decisions use a null approver.
- Rejected rows have a reason, pending rows have no decision, and participant counts stay within space capacity.
- Completed and Checked In rows receive usage sessions; runtime checks found no missing or unsupported sessions.
- Demand is weighted toward Fall/Spring dates, weekdays, peak hours, and popular spaces.

## Approved-Booking Conflict Invariant

The in-memory schedule stores complete `(start, end)` intervals per space and rejects a new approved-lifecycle interval unless every existing interval is separate or adjacent. This is equivalent to negating the required half-open conflict predicate:

```text
existing_start < new_end
and existing_end > new_start
```

Durations vary from one to three hours, so this is stronger than checking exact start slots. The independent SQL self-join uses the same half-open rule and observed `0` approved-lifecycle overlap pairs across all 105,000 bookings.

## Maintenance and Acknowledgements

- Both advisory and out-of-service impacts, all four statuses, all six problem types, and open/completed records were observed.
- Multiple broad active advisories exist on selected spaces, allowing one booking to acknowledge multiple advisories.
- Escalation and downgrade history occurs within maintenance lifecycles and forms valid transition chains.
- Runtime validation observed 400 escalation events, 300 downgrade events, and 604 escalation-affected bookings.
- Acknowledgements reference the same space, an overlapping advisory period, and a timestamp between booking creation and requested start.
- Runtime validation found zero invalid, missing, duplicate, or orphan acknowledgement rows.

# 7. Bulk-Load and Performance Review

| Requirement | Finding | Status |
| --- | --- | --- |
| Driver | `pyodbc` is declared and imported only for connected execution | Pass |
| Fast execution | `cursor.fast_executemany = True` precedes `executemany()` | Pass |
| Batching | Uses configurable `batch_size` | Pass |
| Transactions | Commits once per batch, not per row | Pass |
| Failure handling | Rolls back the failing batch and stops | Pass statically |
| Failure visibility | Reports table and row range; no silent skip | Pass |
| Progress | Prints cumulative inserted rows per table | Pass |
| Procedure use | Does not call `sp_ApproveBooking` per historical booking | Pass |
| Resource cleanup | Connection context manager and trigger-restoration `finally` | Pass |

The generator intentionally permits committed earlier batches to remain after a later batch failure. This is documented, and recovery requires an explicit reset in the same verified disposable database. That policy is acceptable for this benchmark loader and avoids one unbounded transaction over the full dataset.

# 8. Data Distribution Review

| Distribution | Runtime-Observed Result | Assessment |
| --- | --- | --- |
| Booking volume | 105,000 | Sufficient for Step 15 |
| Academic years | 2023, 2024, 2025 starts | Three-year coverage |
| Statuses | All seven; counts listed above | Useful selective/non-selective predicates |
| Approval paths | 36,905 Instant; 68,095 Staff | Both paths are substantial |
| Weekdays | All seven | Weekday-skew workload observed |
| Start hours | Nine distinct hours | Peak/off-peak workload observed |
| Spaces | 44 booked spaces with visible high/medium/low tiers | Useful conflict-query selectivity |
| Capacity | 21 distinct capacities | Useful room-finder selectivity |
| Facilities | 19 distinct combinations | Useful all-facility matching cases |
| Maintenance | Both impacts across all statuses | Nontrivial maintenance workload |
| Acknowledgements | 58,962 rows for 29,481 bookings | Nontrivial advisory workload |
| Escalation effects | 604 affected bookings | Non-empty Report 4 workload |

# 9. Validation SQL Assessment

`02-validate-data.sql` contains no `USE` statement, refuses `University`, and can be run independently with `sqlcmd -d`. It checks or reports:

1. Booking count, major-table row counts, date span, and academic-year count.
2. Counts by status, approval path, academic year, weekday/hour, and space.
3. User, space, facility, purpose, maintenance, and operation-status domain coverage.
4. Booking, decision, usage-session, and maintenance chronology.
5. Capacity validity and status/path field combinations.
6. Approved-lifecycle overlaps with the correct half-open predicate.
7. Usage-session completeness and exclusivity.
8. Advisory acknowledgement temporal validity, same-space relationship, completeness, uniqueness, and multiple-advisory coverage.
9. Impact-history lifecycle, actor role, chain, current-state consistency, escalations, and downgrades.
10. Unexplained out-of-service overlaps and intentional escalation-affected bookings.
11. Foreign-key orphans across all dependent tables.
12. Building, capacity, facility-combination, weekday, hour, and per-space variation.
13. Protected trigger restoration.
14. Overall PASS/FAIL and a raised SQL error when any required check fails.

The supplied transcript reports `49 PASS`, `0 FAIL`, and overall `PASS`. One acknowledgement-validity result is inserted twice under closely related labels; this is redundant but does not weaken the underlying check or readiness conclusion.

# 10. Runtime Results

The generator and validator were not rerun during this review. The user supplied runtime validation evidence and instructed that it be treated as valid for the current package state.

| Runtime Item | Observed Value |
| --- | --- |
| Database | `Step14ReviewG02_20260805` |
| Booking count | 105,000 |
| Minimum booking start | 2023-09-01 08:00:00.000 |
| Maximum booking end | 2026-05-31 20:00:00.000 |
| Academic-year starts | 2023, 2024, 2025 |
| Validation checks | 49 passed, 0 failed |
| Approved-lifecycle overlaps | 0 |
| Maintenance rows | 3,500 |
| Advisory acknowledgements | 58,962 |
| Impact-history rows | 700 |
| Foreign-key orphans | 0 |
| Unexplained out-of-service overlaps | 0 |
| Disabled protected-table triggers | 0 |

The named `docs/14-generator-runtime-output-G02.txt` transcript was not found. Consequently, Python version, ODBC driver, generator exit code, elapsed generation time, batch-progress transcript, and reset/rerun behavior are not independently available in the repository. This does not invalidate the supplied SQL validation evidence for the current generated database.

CLI help, configuration execution, dry-run, full generation, and SQL validation were not rerun because the user explicitly prohibited executing `generate_data.py`, another dry-run, the validator, or any database operation. Static CLI-to-README comparison passed. Non-executing Python AST parsing passed.

# 11. Issues Found

## Issue R14PY-1 - Academic-year configuration validation uses calendar-year coverage

- **Severity:** Minor
- **Issue:** `validate_config()` compares the number of calendar years touched by the date range with `academic_year_count` rather than deriving distinct September-based academic years.
- **Evidence:** `generate_data.py` lines 140-142 versus the academic-year expression in `02-validate-data.sql` lines 21-26.
- **Why this matters:** A future configuration could pass static configuration validation while spanning fewer requested academic years under the project's academic-year definition.
- **Impact on Step 15:** None for the current dataset; runtime validation proves three academic years.
- **Suggested correction:** Derive distinct academic-year start values from the configured date range using the same September boundary as the SQL validator.

## Issue R14PY-2 - Generator runtime transcript is unavailable

- **Severity:** Observation
- **Issue:** The named generator runtime evidence file is absent, while the independent validation transcript is present.
- **Evidence:** `docs/14-generator-validation-output-G02.txt` exists; `docs/14-generator-runtime-output-G02.txt` was not found.
- **Why this matters:** Load environment, elapsed time, exit code, batch progress, and reset/rerun behavior cannot be audited from repository evidence.
- **Impact on Step 15:** No data-correctness blocker. The validated database is available and all 49 SQL checks passed.
- **Suggested correction:** Preserve the original generator transcript if it remains available; do not rerun generation solely to recreate it without explicit authorization.

# 12. Scores

| Category | Score |
| --- | --- |
| Package Completeness | 10/10 |
| Schema Compatibility | 10/10 |
| Database Safety | 10/10 |
| Configuration Validation | 9/10 |
| Reproducibility | 9/10 |
| Generation Correctness | 10/10 |
| Bulk-Load Scalability | 10/10 |
| Validation Quality | 10/10 |
| Step 15 Readiness | 9/10 |

# 13. Required Revisions Before Step 15

No blocking or major revision is required before Step 15.

The academic-year configuration check should be aligned with the September-based SQL definition when the generator is next maintained. Preserve the missing runtime transcript if it can be recovered without rerunning or changing the database.

# 14. Final Verdict

**READY FOR STEP 15 WITH MINOR REVISIONS**

The package is safe, schema-compatible, reproducible, scalable, and supported by valid runtime evidence from a disposable database. The observed 105,000-row dataset spans three academic years, covers all required statuses and both approval paths, includes substantial maintenance and acknowledgement workloads, and has zero approved-lifecycle conflicts. The remaining items are minor and do not require data repair or regeneration before Step 15.
