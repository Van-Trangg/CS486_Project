---
name: python-data-generator-step14-review
description: Review the Step 14 Python data generator, SQL Server bulk-load safety, generated-data quality, and readiness for Step 15.
compatibility: opencode
---

# Step 14 Review — Python Data Generator

Use this skill after the Python-based Step 14 package has been created or updated.

Expected directory:

`outputs/14-new-data-generator-G02/`

Expected files:

```text
outputs/14-new-data-generator-G02/
├── generate_data.py
├── generator_config.json
├── requirements.txt
├── README.md
└── 02-validate-data.sql
```

Optional files may include:

```text
helpers.py
data/
logs/
```

The review must determine whether the package can safely and reproducibly generate the required large Phase 2 dataset and whether the result is ready for Step 15 indexing and query tuning.

Do not approve the package merely because Python code exists or because the configuration says `105000`. Verify that the code can actually generate and bulk-load valid data without destructive behavior, hidden assumptions, fabricated metrics, or accidental use of the real `University` database.

---

## Review prompt

Examine the complete package critically and answer:

> Is the Python data generator safe, schema-compatible, reproducible, scalable, and capable of producing a valid 100,000+ booking dataset across at least three academic years for Step 15 tuning and Step 16 analytical queries?

Compare the package with:

1. The Phase 2 requirements.
2. The approved Phase 1 schema.
3. Step 9 updated design.
4. Step 10 schema migration.
5. Step 11–12 concurrency design and implementation.
6. The Step 14 Python generation skill.
7. The actual generated database when runtime execution is safe and available.

If the generator needs manual schema repair, hardcoded database replacement, broad table deletion, per-row insertion, or undocumented post-processing, mark it as not ready.

---

## Required inputs

Read fully:

- `.opencode/skills/14-data-generator/new-SKILL.md`
- `outputs/14-new-data-generator-G02/generate_data.py`
- `outputs/14-new-data-generator-G02/generator_config.json`
- `outputs/14-new-data-generator-G02/requirements.txt`
- `outputs/14-new-data-generator-G02/README.md`
- `outputs/14-new-data-generator-G02/02-validate-data.sql`
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `req/business-requirement-phase2.md`
- Relevant review files under `docs/`

Read optional helper files when present.

---

## Output file

Create or update:

`docs/14-python-data-generator-review-G02.md`

Do not modify the generator automatically unless the user explicitly requests correction.

---

## 1. Package completeness

Verify that all required files exist and are non-empty.

Check:

- Python entry point exists.
- Configuration file is valid JSON.
- Requirements list matches imported third-party packages.
- README commands match actual CLI arguments.
- Validation SQL is executable independently.
- Optional helper imports resolve correctly.
- There are no unresolved placeholders, TODO-only sections, or copied sample names that do not match Group G02.

Missing core files are blocking issues.

---

## 2. Schema compatibility

Compare all generated and inserted fields with the migrated SQL Server schema.

Verify:

- Table names
- Schema names
- Column names
- Data types and lengths
- Identity columns
- Primary keys
- Foreign keys
- Unique constraints
- Check constraints
- Allowed booking statuses
- Approval paths
- Maintenance impact levels
- Advisory acknowledgement structure
- Nullable and required fields
- Role values

Check insertion order against foreign-key dependencies.

A generator that references nonexistent objects or invalid values is not ready.

---

## 3. Database safety

Verify that:

- No database name is hardcoded.
- `University` is not used as an automatic target.
- Server and database are supplied through CLI, environment, or config.
- A disposable-database guard exists.
- Unsafe targets are rejected by default.
- Bypass requires an explicit flag.
- Passwords are not stored in source or JSON.
- Broad `DELETE`, `TRUNCATE`, or reset operations require explicit authorization.
- Reset removes only generated rows or runs only inside a verified disposable database.
- `--dry-run` performs no writes.
- Logs do not expose credentials.

### Required destructive-SQL inspection

Search Python strings and executed SQL for:

```text
DELETE
TRUNCATE
DROP
USE University
ALTER DATABASE
```

Classify each occurrence and verify its guard.

Any automatic broad deletion against an unverified database is blocking.

---

## 4. Command-line interface

Verify that the actual CLI supports the documented arguments:

```text
--server
--database
--config
--trusted-connection
--username
--password-env
--reset-generated-data
--allow-non-disposable
--dry-run
```

Reasonable naming differences are acceptable only when README and code agree.

Check:

- Required arguments are validated.
- Invalid values return nonzero exit status.
- Password environment variable is handled safely.
- Trusted connection works on the intended Windows setup.
- Help output is clear.
- `main()` returns an appropriate exit code.

---

## 5. Configuration validation

Verify that `generator_config.json` and Python validation cover:

- Booking count at least 100,000
- At least three academic years
- Positive batch size
- Fixed random seed
- Valid user, space, and maintenance counts
- Status ratios sum to 1.0
- Approval ratios are within `[0, 1]`
- Counts are sufficient for foreign-key references
- Unsupported statuses are rejected
- Missing required keys cause a clear error
- Invalid configuration is not silently normalized

Record the configured default booking target.

---

## 6. Reproducibility

Verify that:

- A local random-number generator is seeded from configuration.
- Faker is seeded when used.
- Uncontrolled calls to current time do not materially change the logical dataset.
- Generated IDs and distributions are deterministic where practical.
- Re-running with the same seed produces the same logical data.
- Database identity values that may vary are documented.
- The generator does not depend on unordered database results without deterministic sorting.

When runtime is available, compare two dry runs or two clean disposable-database runs using the same seed.

---

## 7. Data-generation correctness

Review generation logic for:

### Users

- Unique identifiers and emails
- Valid roles and account statuses
- Enough staff and managers
- Staff-only references do not point to students

### Spaces and facilities

- Capacity variation
- Facility variation
- Valid space-facility references
- Popular and less-popular spaces
- Data suitable for room-finder selectivity

### Bookings

- At least 100,000 rows
- At least three academic years
- Multiple semesters, weekdays, and hours
- Required statuses represented
- Both approval paths represented
- Status-dependent fields are consistent
- `requested_start < requested_end`
- Valid requester and space references
- No impossible dates

### Maintenance

- Advisory and Out-of-Service records
- Open and completed records
- Valid time ranges
- Multiple records for some spaces
- Escalation cases only when supported by the schema

### Advisory acknowledgements

- Valid booking-maintenance references
- Same-space relationship
- Advisory active at the relevant time
- No duplicate pair unless allowed
- Enough rows for nontrivial Query 4 and related analysis

---

## 8. Approved-booking conflict invariant

Verify the Python logic that prevents two approved bookings from overlapping for the same space.

Check whether the in-memory schedule correctly accounts for:

- Space
- Date
- Start time
- End time
- Multiple slot lengths
- Cross-midnight bookings, if permitted
- Adjacent intervals
- Multiple academic years

The correct rule is:

```text
existing_start < new_end
and existing_end > new_start
```

A set keyed only by exact start time is insufficient when variable-duration intervals exist.

The validation SQL must independently check approved conflicts using the same overlap rule.

Expected unintended conflict count:

```text
0
```

---

## 9. Bulk insertion and scalability

Verify that:

- `pyodbc` is used correctly.
- `cursor.fast_executemany = True` is enabled before bulk insertion.
- `executemany()` is used.
- Batch size comes from configuration.
- Commits occur per batch, not per row.
- Errors roll back the current batch.
- Failed rows are not silently skipped.
- Progress is displayed.
- The code does not hold all unnecessarily large dependent data structures in memory.
- There is no loop issuing 100,000 individual `execute()` and `commit()` calls.
- `sp_ApproveBooking` is not called for every historical booking.
- Connections and cursors close safely.

A row-by-row insertion design is a major or blocking scalability issue.

---

## 10. Rerun and reset behavior

Verify what happens when the generator is executed twice.

Classify the package as one of:

- Safely rerunnable with deterministic cleanup
- Safely append-only with documented behavior
- One-time execution with a clear guard
- Unsafe because it creates duplicates or deletes unrelated data

Check:

- Primary-key collisions
- Duplicate generated users/spaces
- Reset scope
- Generation identifiers or prefixes
- Transaction behavior when reset partially fails
- Whether reset order respects foreign keys

Do not accept undocumented destructive rerun behavior.

---

## 11. Dry-run validation

Execute `--dry-run` when Python dependencies and SQL Server connectivity are available.

Verify that dry-run:

- Loads configuration
- Validates the target database name
- Inspects schema if documented
- Generates a small sample
- Prints planned counts
- Performs no insert, update, delete, truncate, or drop
- Returns exit code 0 when valid
- Returns nonzero on invalid config or unsafe database

If database access is not needed for dry-run, confirm that this is documented.

---

## 12. Runtime execution policy

Runtime generation may occur only when all conditions hold:

1. SQL Server is reachable.
2. A disposable database is available.
3. The scripts do not redirect to another database.
4. Schema setup can be completed without manually altering approved scripts.
5. Destructive behavior is confined to the disposable database.
6. The user did not prohibit execution.

Preferred database name:

```text
Step14ReviewG02_<timestamp>
```

Run the clean sequence:

1. Create disposable database.
2. Apply Step 5 schema.
3. Apply Step 10 migration.
4. Apply Step 12 implementation only if required.
5. Install Python dependencies in the active environment if safe.
6. Run `generate_data.py --dry-run`.
7. Run the full generator.
8. Run `02-validate-data.sql`.
9. Optionally test rerun/reset behavior.
10. Drop the disposable database after evidence is recorded, unless preservation is required for Step 15.

Do not modify copied approved scripts merely to bypass hardcoded `USE` statements without reporting that fact.

If safe execution is not possible, perform static review and state exactly why.

---

## 13. Runtime evidence

When execution is performed, record:

- Python version
- ODBC driver
- SQL Server target
- Disposable database name
- Generator exit code
- Elapsed generation time
- Configured and observed booking count
- Minimum and maximum booking dates
- Academic-year or semester span
- Counts by booking status
- Counts by approval path
- Maintenance counts
- Advisory acknowledgement count
- Approved-conflict count
- Orphan and invalid-time counts
- Rerun/reset result
- Any error and rollback behavior

Do not report estimated values as observed.

---

## 14. Validation SQL quality

Verify that `02-validate-data.sql` independently checks:

1. Total booking count
2. Date range
3. Academic-year or semester count
4. Booking status counts
5. Approval-path counts
6. Weekday/hour distributions
7. Booking distribution by space
8. Maintenance by impact level
9. Advisory acknowledgements
10. Orphan rows
11. Invalid null combinations
12. Invalid time ranges
13. Approved overlap invariant
14. Out-of-Service overlap cases
15. Capacity and facility variation
16. Major table row counts

Each important validation should have:

- Clear label
- Actual result
- Expected condition
- Pass/fail interpretation where practical

A validation file that only prints row counts is insufficient.

---

## 15. Step 15 readiness

Answer explicitly:

1. Does the generator safely target a disposable database?
2. Can it generate at least 100,000 bookings?
3. Does it cover at least three academic years?
4. Are required statuses represented?
5. Are both approval paths represented?
6. Are maintenance impact levels represented?
7. Are advisory acknowledgements valid?
8. Are approved conflicts absent?
9. Are space, capacity, facility, weekday, and hour distributions meaningful?
10. Can booking-conflict and room-finder queries produce nontrivial plans?
11. Is the generator reproducible?
12. Is insertion set-oriented or properly batched?
13. Is rerun/reset behavior safe?
14. Does the validation SQL prove the result?
15. Is any manual repair required before Step 15?

Then provide:

- **Ready elements**
- **Blocking gaps**
- **Non-blocking improvements**

---

## 16. Issue severity

Use:

- **Blocking** — unsafe execution, cannot run, corrupts data, schema incompatible, required dataset cannot be generated
- **Major** — material correctness, scalability, reproducibility, or validation weakness
- **Minor** — improvement that does not block Step 15
- **Observation** — informational note

---

## 17. Output format

# 1. Review Summary

State:

- Package reviewed
- Static or runtime review
- Most important strength
- Most important risk
- Observed booking count when executed
- Overall Step 15 readiness

# 2. Files Reviewed

# 3. Safety Assessment

| Safety Check | Expected | Finding | Status | Evidence |
| --- | --- | --- | --- | --- |

# 4. Schema Compatibility

| Area | Expected | Generator Mapping | Status | Notes |
| --- | --- | --- | --- | --- |

# 5. Configuration and Reproducibility

# 6. Generation Logic Review

# 7. Bulk-Load and Performance Review

# 8. Data Distribution Review

Clearly distinguish configured, statically inferred, and runtime-observed values.

# 9. Validation SQL Assessment

# 10. Runtime Results

Use:

`Runtime generation was not performed.`

when execution was unsafe or unavailable, followed by the exact reason.

# 11. Issues Found

For each issue:

## Issue R14PY-X — Short title

- **Severity:** Blocking / Major / Minor / Observation
- **Issue:**
- **Evidence:**
- **Why this matters:**
- **Impact on Step 15:**
- **Suggested correction:**

# 12. Scores

| Category | Score |
| --- | --- |
| Package Completeness | X/10 |
| Schema Compatibility | X/10 |
| Database Safety | X/10 |
| Configuration Validation | X/10 |
| Reproducibility | X/10 |
| Generation Correctness | X/10 |
| Bulk-Load Scalability | X/10 |
| Validation Quality | X/10 |
| Step 15 Readiness | X/10 |

# 13. Required Revisions Before Step 15

List only required revisions.

# 14. Final Verdict

Choose exactly one:

- **READY FOR STEP 15**
- **READY FOR STEP 15 WITH MINOR REVISIONS**
- **NOT READY FOR STEP 15**

Provide a brief justification and state whether runtime generation was executed.

---

## Final response behavior

After review:

1. State that `docs/14-python-data-generator-review-G02.md` was created or updated.
2. State the final verdict.
3. State whether the review was static or runtime-verified.
4. Report observed booking count and academic-year span only when executed.
5. Summarize blocking and major issues only.
6. Do not modify the generator automatically.
7. Do not proceed to Step 15 automatically.
