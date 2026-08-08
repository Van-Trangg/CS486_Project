# 1. Review Summary

**Package reviewed:** `outputs/14-data-generator-G02/`, including all five required files.

**Review type:** Runtime-verified review with static package analysis. Python syntax, CLI help, configuration validation, repeat offline dry-runs, protected-target refusal, connected schema inspection, and independent SQL validation were executed. The current full-generation transcript was also reviewed against the live disposable database.

**Most important strength:** The package combines strict target guards, exact migrated-schema inspection, deterministic interval-safe generation, and scalable batched loading. The preserved clean full load generated 105,000 bookings in 132.2 seconds, and current runtime checks found zero approved-lifecycle conflicts or integrity failures.

**Most important risk:** An unattainable overall `instant_approval_ratio` can be accepted and silently capped rather than rejected, although the current `0.35` setting is attainable and deterministic.

**Observed database result:** 105,000 bookings from `2023-09-01 08:00:00` through `2026-05-31 20:00:00`, covering academic-year starts 2023, 2024, and 2025.

**Overall Step 15 readiness:** The generated disposable database is suitable for Step 15. Only minor configuration hardening remains.

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
- `docs/14-generator-runtime-output-G02.txt`
- Relevant Step 5 and Step 8 through Step 14 reviews under `docs/`

All required package files exist and are non-empty. The JSON is valid, the entry point exists, no helper import is unresolved, and `requirements.txt` declares the only third-party import, `pyodbc`.

# 3. Safety Assessment

| Safety Check | Expected | Finding | Status | Evidence |
| --- | --- | --- | --- | --- |
| Target selection | No hardcoded target | Server and database come from CLI | Pass | `build_connection_string()` |
| Protected database | Never target `University` | Unconditionally refused, including bypass | Pass executed | Protected dry-run returned an error |
| Disposable guard | Unsafe names rejected by default | Only `Step14*`, `Test*`, and `Dev*` pass by default | Pass | `validate_target_database()` |
| Explicit bypass | Required for other names | Explicit warning; reset remains prohibited | Pass | CLI and target validation |
| Existing data | No implicit overwrite | Non-empty targets stop without reset | Pass | `prepare_target()` |
| Reset authorization | Explicit and disposable-only | Requires both reset flag and disposable target | Pass executed | `Step14ReviewG02_20260805` reset completed |
| Reset order | Child before parent | All nine tables are deleted in FK-safe order | Pass executed | Full reset/load succeeded |
| Credentials | No plaintext password | SQL password comes from a named environment variable | Pass | Connection builder and README |
| Dry-run writes | None | Returns before trigger, reset, identity, or insert operations | Pass executed | Repeat offline and connected dry-runs |
| Connection context | Exact selected database | `DB_NAME()` must match CLI target | Pass executed | Connected schema inspection |
| Trigger restoration | Restore original enabled set | Restoration runs in `finally` and verifies state | Pass executed | Validator found zero disabled triggers |
| Destructive SQL | Guarded | Only explicit disposable reset uses broad `DELETE`; no `TRUNCATE`, `DROP`, `USE University`, or `ALTER DATABASE` | Pass | Required destructive-SQL search |

The reviewed target was verified as disposable through its `Step14` name, prior review documentation, exact database context, generator-only user/space prefixes, and matching deterministic row counts before reset. No credentials were printed.

# 4. Schema Compatibility

| Area | Expected | Generator Mapping | Status | Notes |
| --- | --- | --- | --- | --- |
| Tables/schema | Nine `dbo` data tables | Exact names and qualification | Pass runtime | Connected inspection passed |
| `USER` | Seven baseline columns and approved domains | Exact columns, six roles, three account states | Pass runtime | 600 rows |
| `SPACE` | Nine baseline columns and approved domains | Exact columns and values | Pass runtime | 60 rows |
| `FACILITY` | Identity PK and unique names | Explicit deterministic IDs 1-12 | Pass runtime | 12 rows |
| `SPACE_FACILITY` | Composite PK and valid domains | Exact five-column mapping | Pass runtime | 343 rows |
| `BOOKING` | Baseline plus `resolution_path` | Exact writable columns and valid state combinations | Pass runtime | 105,000 rows |
| `USAGESESSION` | Booking PK/FK and staff references | Exact eight-column mapping | Pass runtime | 61,950 rows |
| Maintenance | Baseline plus `impact_level` | Exact eleven-column mapping | Pass runtime | 3,500 rows |
| Advisory acknowledgement | Identity, two FKs, unique pair | Exact four-column mapping | Pass runtime | 70,250 rows |
| Impact history | Identity, maintenance/user FKs, transitions | Exact six-column mapping | Pass runtime | 700 rows |
| Identities | Five identity tables | `IDENTITY_INSERT` only for those tables | Pass runtime | Schema inspection passed |
| Load order | Parent before child | FK-safe order | Pass runtime | Full load succeeded with constraints trusted |

`inspect_schema()` verifies exact column sets, identity mappings, required named PK/UQ/FK/CK/default constraints, selected type/nullability metadata, and trusted FK/CHECK state before any write. The current generator uses `resolution_path` and does not reference obsolete `approval_path` or `row_version` names.

# 5. Configuration and Reproducibility

| Setting | Configured Value | Assessment |
| --- | ---: | --- |
| Booking count | 105,000 | Meets and achieved required minimum |
| Academic years | 3 | September-based coverage achieved |
| Batch size | 10,000 | Positive, configurable, and used |
| Random seed | 48,602 | Fixed and configurable |
| Users | 600 | Sufficient role and requester coverage |
| Spaces | 60 | Sufficient room-finder selectivity |
| Maintenance | 3,500 | Nontrivial maintenance workload |
| Facilities | 12 | Deterministic approved catalog |
| Date range | 2023-09-01 to 2026-05-31 | Three academic years |

Configuration loading rejects missing/unknown keys, insufficient required counts, unsupported statuses, invalid ratio totals, non-positive batch sizes, invalid date order, and empty driver names. A local `random.Random` is seeded from configuration; there is no Faker or uncontrolled random source. Two dry-runs were identical, and the preserved full-generation transcript exactly matches the live database counts and distributions. An unattainable Instant target ratio is still silently capped as described in Issue R14PY-1.

# 6. Generation Logic Review

## Users

- IDs and emails are deterministic and unique.
- All six schema roles and all three account statuses are represented.
- Approvers, usage staff, assigned maintenance staff, and impact actors reference active Facility Staff or Facility Manager users.

## Spaces and Facilities

- All six space types, five statuses, four buildings, 21 capacities, and 19 facility combinations are represented.
- Facility quantities and operation states vary within valid domains.
- Weighted high-, medium-, and low-demand rooms support conflict and room-finder selectivity.

## Bookings

- All seven statuses are present: Approved 15,750; Cancelled 8,400; Checked In 4,200; Completed 57,750; No-Show 5,250; Pending 3,150; Rejected 10,500.
- Both resolution paths are substantial: Instant 36,789; Staff 68,211.
- Instant rows use Classroom spaces and active Lecturer or Teaching Assistant requesters, matching Step 12.
- All 36,789 Instant rows have `decision_time = created_at`.
- Staff decisions reference active staff and include decision notes; rejected rows have rejection reasons; pending rows have no decision fields.
- Requested ranges, creation/decision chronology, and participant counts are valid.
- Completed and Checked In rows have valid usage sessions.

## Approved-Booking Conflict Invariant

The schedule stores complete `(start, end)` intervals per space and rejects overlap using the half-open equivalent of:

```text
existing_start < new_end
and existing_end > new_start
```

One-to-three-hour durations, adjacent intervals, multiple dates, and all three academic years are handled correctly. The full generation plan and independent SQL self-join both observed zero approved-lifecycle overlap pairs.

## Maintenance and Acknowledgements

- Both impact levels, all four maintenance statuses, open/completed records, overlapping records, escalations, and downgrades are represented.
- Runtime validation observed 400 escalations, 300 downgrades, and 762 escalation-affected bookings.
- Acknowledgements are unique same-space booking-maintenance pairs for overlapping active advisories.
- Runtime validation found zero invalid, missing, duplicate, or orphan acknowledgements.

# 7. Bulk-Load and Performance Review

| Requirement | Finding | Status |
| --- | --- | --- |
| Driver | Python 3.13.5, `pyodbc 5.2.0`, ODBC Driver 17 | Pass executed |
| Fast execution | `cursor.fast_executemany = True` before bulk calls | Pass |
| Bulk API | Uses `executemany()` | Pass |
| Batching | Uses configured 10,000-row batches | Pass executed |
| Commit frequency | Commits once per batch, not per row | Pass |
| Rollback | Rolls back the failing batch and stops | Pass static |
| Failure visibility | Reports table and row range | Pass static |
| Progress | Reports cumulative rows after each batch | Pass executed |
| Procedure use | Does not call approval procedures per historical row | Pass |
| Cleanup | Context manager plus trigger-restoration `finally` | Pass executed |

The preserved full reset and generation completed in 132.2 seconds. Earlier successful batches remain committed if a later batch fails; this behavior and the required disposable reset recovery are documented. No failed batch was induced against the validated database.

# 8. Data Distribution Review

| Distribution | Runtime-Observed Result | Assessment |
| --- | --- | --- |
| Booking volume | 105,000 | Sufficient for Step 15 |
| Academic years | 2023, 2024, 2025 starts | Required span achieved |
| Statuses | All seven | Useful selective/non-selective values |
| Resolution paths | 36,789 Instant; 68,211 Staff | Both substantial |
| Weekdays | All seven | Useful distribution |
| Start hours | Nine | Peak/off-peak variation |
| Booked spaces | 44 | Popular/medium/low tiers |
| Capacities | 21 distinct | Room-finder selectivity |
| Facility combinations | 19 distinct | All-facility matching cases |
| Maintenance | Both impacts and all statuses | Nontrivial workload |
| Acknowledgements | 70,250 | Nontrivial advisory workload |
| Impact history | 700 | Escalation/downgrade coverage |
| Approved conflicts | 0 | Required invariant holds |

# 9. Validation SQL Assessment

`02-validate-data.sql` contains no `USE`, refuses `University`, runs independently with `sqlcmd -d`, and checks or reports:

1. Booking count, major-table counts, date span, and academic years.
2. Status, resolution path, academic-year, weekday/hour, and per-space distributions.
3. User, space, facility, purpose, maintenance, and operation-status coverage.
4. Booking, decision, usage-session, and maintenance chronology.
5. Capacity, state/path combinations, Instant eligibility, and staff roles.
6. Approved-lifecycle overlaps with the correct half-open predicate.
7. Usage-session completeness and exclusivity.
8. Acknowledgement validity, completeness, uniqueness, and multiple-advisory coverage.
9. Impact-history events, chains, current-state consistency, escalation, and downgrade coverage.
10. Out-of-service overlap cases and escalation-affected bookings.
11. Foreign-key orphans across all dependent tables.
12. Building, capacity, facility-set, weekday, hour, and space variation.
13. Protected trigger restoration.

Current runtime output showed 53 aggregated PASS checks and zero failures. The corrected Instant timestamp check is now part of `#Checks`, the overall result, and the final `THROW` gate.

# 10. Runtime Results

Full runtime generation is preserved in `docs/14-generator-runtime-output-G02.txt` for verified disposable database `Step14ReviewG02_20260805` on SQL Server 2022 `16.0.1000.6` at `DESKTOP-MJJHKPQ`. Full generation was not repeated during this review because the current transcript, deterministic package, and live database already match; avoiding another destructive reset was safer. Connected dry-run and independent validation were rerun.

| Runtime Item | Observed Value |
| --- | --- |
| Python | 3.13.5 |
| `pyodbc` | 5.2.0 |
| ODBC driver | ODBC Driver 17 for SQL Server |
| Connected schema inspection | PASS |
| Generator exit status | Success |
| Reset/rerun result | Explicit disposable reset and full reload succeeded |
| Generation elapsed time | 132.2 seconds |
| Booking count | 105,000 |
| Minimum booking start | 2023-09-01 08:00:00 |
| Maximum booking end | 2026-05-31 20:00:00 |
| Academic-year starts | 2023, 2024, 2025 |
| Validator result | 53 PASS, 0 FAIL |
| Approved-lifecycle conflicts | 0 |
| Instant timestamp violations | 0 |
| Advisory acknowledgements | 70,250 |
| Impact-history rows | 700 |
| Foreign-key orphans | 0 |
| Unexplained out-of-service overlaps | 0 |
| Disabled protected-table triggers | 0 |

# 11. Issues Found

## Issue R14PY-1 - Unattainable Instant target ratios are silently capped

- **Severity:** Minor
- **Issue:** Configuration validation accepts any `instant_approval_ratio` through 1.0, but generation caps its probability when the requested overall ratio exceeds the total ratio of statuses eligible for Instant resolution.
- **Evidence:** `generate_data.py:136-137` accepts 0.99; lines 274-275 use `min(1.0, instant_approval_ratio / instant_eligible_ratio)`. A focused configuration test confirmed 0.99 is accepted under the current status ratios.
- **Why this matters:** A future accepted configuration can produce a lower Instant proportion than requested without a clear validation error.
- **Impact on Step 15:** None for the current 0.35 configuration, whose generated distribution is substantial and deterministic.
- **Suggested correction:** Reject `instant_approval_ratio > instant_eligible_ratio`, or explicitly define the setting as a conditional probability and remove the conversion/cap.

# 12. Scores

| Category | Score |
| --- | --- |
| Package Completeness | 10/10 |
| Schema Compatibility | 10/10 |
| Database Safety | 10/10 |
| Configuration Validation | 9/10 |
| Reproducibility | 10/10 |
| Generation Correctness | 10/10 |
| Bulk-Load Scalability | 10/10 |
| Validation Quality | 10/10 |
| Step 15 Readiness | 9/10 |

# 13. Required Revisions Before Step 15

No blocking or major revisions are required before Step 15.

When the package is next maintained, reject or explicitly document unattainable Instant target ratios.

# 14. Final Verdict

**READY FOR STEP 15 WITH MINOR REVISIONS**

The package is safe, schema-compatible, deterministic, scalable, and runtime-verified through a preserved full reset/load plus current connected inspection and independent validation. The 105,000-row dataset spans three academic years, covers all required scenarios, and has zero approved conflicts or integrity failures. The remaining configuration-hardening issue does not require regeneration before Step 15.
