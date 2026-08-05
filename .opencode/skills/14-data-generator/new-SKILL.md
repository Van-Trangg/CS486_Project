---
name: python-data-generator-step14
description: Generate a large, realistic, reproducible Phase 2 dataset with Python and bulk-load it safely into Microsoft SQL Server.
compatibility: opencode
---

# Step 14 — Python Data Generator Skill

Use this skill after the Phase 2 schema migration is complete and the user asks to generate the large dataset required for Step 14.

Python is responsible for generating realistic data and inserting it in batches. SQL Server remains responsible for constraints, integrity enforcement, analytical queries, and final validation.

## Required output directory

Create or update:

`outputs/14-new-data-generator-G02/`

Required files:

```text
outputs/14-new-data-generator-G02/
├── generate_data.py
├── generator_config.json
├── requirements.txt
├── README.md
└── 02-validate-data.sql
```

Optional supporting files may include `helpers.py`, `data/`, and `logs/`.

Do not create large CSV files unless they are explicitly useful and documented.

---

## 1. Inspect the project first

Before generating code:

1. Run `ls -la`.
2. Read fully:
   - `outputs/03-logical-design-G02.md`
   - `outputs/05-db-definition-G02.sql`
   - `outputs/09-updated-erd-and-logical-design-G02.md`
   - `outputs/10-schema-migration-G02.sql`
   - `outputs/11-concurrency-design-G02.md`
   - `outputs/12-concurrency-implementation-G02.sql`
   - Relevant review files under `docs/`
   - `req/business-requirement-phase2.md` 
3. Verify exact table names, column names, data types, keys, constraints, allowed statuses, approval paths, maintenance impact levels, and acknowledgement design.
4. Do not guess physical names when the repository already defines them.
5. If a required object is missing or inconsistent, report it before generating insertion code.

---

## 2. Minimum Phase 2 dataset

The generator must create at least:

- Three academic years of data
- 100,000 booking records

Use these defaults:

```json
{
  "booking_count": 105000,
  "academic_year_count": 3,
  "batch_size": 10000,
  "random_seed": 48602
}
```

The dataset must include meaningful examples of:

- Approved, pending, rejected, cancelled, completed, and no-show bookings, when supported by the schema
- Instant approvals and staff approvals
- Advisory and Out-of-Service maintenance
- Several active maintenance records for the same space
- Maintenance escalation cases
- Advisory acknowledgements
- Spaces with different capacities and facility combinations
- Bookings distributed across multiple semesters, weekdays, and hours

Do not leave important analytical categories empty.

---

## 3. Safety requirements

The target database must be supplied by command-line argument, environment variable, or configuration. Never hardcode `University` or another project database.

Preferred execution:

```powershell
python generate_data.py --server localhost --database Step14ReviewG02
```

### Disposable-database guard

The script must refuse to run against unsafe database names by default.

Example behavior:

```python
if not database.startswith(("Step14", "Test", "Dev")):
    raise RuntimeError(
        "Refusing to generate data outside an approved disposable database."
    )
```

Allow bypass only with an explicit flag such as:

```text
--allow-non-disposable
```

and print a strong warning.

### Deletion policy

Do not delete all rows from project tables automatically.

Use one of these approaches:

1. Run only in a disposable database.
2. Tag generated rows with a stable prefix or generation ID.
3. Delete only rows created by this generator.
4. Require `--reset-generated-data` before deleting generated rows.

Never execute broad destructive statements against an unverified database.

---

## 4. Python technology

Use:

- Python 3.11 or later where available
- `pyodbc`
- Standard-library modules where practical
- Optional `Faker` only when it improves realism

Recommended `requirements.txt`:

```text
pyodbc>=5.1
Faker>=25.0
```

Do not add pandas unless it is actually needed.

---

## 5. Reproducibility

Use a configurable random seed:

```python
random.seed(config.random_seed)
```

The same seed and configuration should produce the same logical dataset.

Document identity-generated values that may differ between runs.

---

## 6. Configuration

Create `generator_config.json` with configurable values such as:

```json
{
  "booking_count": 105000,
  "academic_year_count": 3,
  "batch_size": 10000,
  "random_seed": 48602,
  "user_count": 5000,
  "space_count": 60,
  "maintenance_count": 500,
  "approved_ratio": 0.55,
  "pending_ratio": 0.10,
  "rejected_ratio": 0.08,
  "cancelled_ratio": 0.10,
  "completed_ratio": 0.12,
  "no_show_ratio": 0.05,
  "instant_approval_ratio": 0.35
}
```

Adjust values to match the actual schema and status set.

Validate configuration explicitly. Status ratios must sum to 1.0. Do not silently normalize invalid values.

---

## 7. Foreign-key-safe generation order

Use the actual dependency order. A typical order is:

1. Users
2. Facilities
3. Spaces
4. Space-facility relationships
5. Maintenance records
6. Bookings
7. Advisory acknowledgements
8. Other dependent tables

---

## 8. User generation

Generate only roles supported by the schema, such as:

- Student
- Lecturer
- Teaching Assistant
- Facility Staff
- Department Administrator
- Facility Manager

Requirements:

- Unique user IDs and emails where required
- Valid account status
- Valid phone format and length
- Enough facility staff and managers for approvals and maintenance references
- No staff-only foreign key may reference a student-only account

---

## 9. Space and facility generation

Generate variation in:

- Space type
- Building
- Floor
- Room number
- Capacity
- Current status
- Usage policy
- Facility combinations

Ensure:

- Some spaces satisfy common room-finder requests
- Some fail due to capacity
- Some fail due to missing facilities
- Some spaces are popular and others less popular
- Bookings are not concentrated almost entirely in one space

---

## 10. Booking generation

### Academic periods

Generate bookings across at least three academic years and multiple semesters.

If semester is derived from dates, document the derivation in `README.md`.

### Time slots

Use realistic controlled slots, for example:

```python
TIME_SLOTS = [
    (8, 10),
    (10, 12),
    (13, 15),
    (15, 17),
    (18, 20),
]
```

### Approved-booking conflict avoidance

Approved bookings must not overlap for the same space.

Maintain an in-memory schedule keyed by space, date, and slot. Assign each approved booking to an unused slot.

Overlapping pending, rejected, or cancelled requests may be generated when allowed and useful.

Do not call `sp_ApproveBooking` 100,000 times merely to generate historical data. That procedure belongs to protected workflow and concurrency tests, not bulk generation.

### Status consistency

Generate fields consistently with status:

- Approved: valid approval path and required decision data
- Rejected: rejection reason present
- Completed: actual start/end present when required
- No-show: no successful check-in
- Pending: no final decision fields unless explicitly allowed

Do not generate contradictory combinations.

### Approval paths

Generate both instant and staff approval rows. Staff-approved rows must reference valid staff users where required.

---

## 11. Maintenance generation

Generate:

- Advisory maintenance
- Out-of-Service maintenance
- Open and completed maintenance
- Multiple maintenance records on one space
- Some overlapping maintenance records with different impact levels
- Escalation cases when the schema supports escalation history

Requirements:

- Valid start/completion order
- Valid assigned staff
- Allowed impact values only
- Open maintenance uses the approved null representation

Do not claim historical escalation when the schema stores only the current impact level.

---

## 12. Advisory acknowledgement generation

Generate an acknowledgement only when:

1. The maintenance record is advisory.
2. The advisory is active at booking time under the approved design.
3. The booking uses the same space.
4. The booking status permits acknowledgement.

Requirements:

- One booking may acknowledge multiple advisories
- No duplicate booking-maintenance pair unless the schema allows it
- Every row references valid booking and maintenance records
- Generate enough rows for nontrivial analytical results

---

## 13. Bulk insertion

Use:

```python
cursor.fast_executemany = True
```

Insert in batches:

```python
for start in range(0, len(rows), batch_size):
    batch = rows[start:start + batch_size]
    cursor.executemany(insert_sql, batch)
    connection.commit()
```

Default batch size: `10000`.

Do not:

- Commit every row
- Execute one transaction per row
- Use an unbounded loop
- Hold one enormous transaction for all 105,000 bookings without justification

Print progress after each batch.

---

## 14. Transaction and error handling

Use one transaction per batch.

On failure:

1. Roll back the current batch.
2. Report the table, batch number, row range, and SQL Server error.
3. Stop unless `--continue-on-error` is explicitly supported.

Do not silently skip failed rows.

---

## 15. Command-line interface

`generate_data.py` should support:

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

Prefer trusted connection on Windows.

Passwords must come from an environment variable, not a plain-text config file.

---

## 16. Dry-run mode

`--dry-run` must:

- Load and validate configuration
- Inspect the schema
- Generate a small in-memory sample
- Print planned row counts
- Perform no insert, update, or delete

---

## 17. Validation SQL

Create `02-validate-data.sql` that independently checks:

1. Total booking count
2. Minimum and maximum booking dates
3. Number of academic years or semesters
4. Counts by booking status
5. Counts by approval path
6. Counts by weekday and hour
7. Counts by space
8. Maintenance counts by impact level
9. Advisory acknowledgement count
10. Orphan foreign keys
11. Invalid null combinations
12. Invalid time ranges
13. Approved-booking overlap invariant
14. Out-of-Service overlap cases
15. Capacity and facility variation
16. Row counts for major Phase 2 tables

The approved overlap check must use:

```sql
b1.requested_start < b2.requested_end
AND b1.requested_end > b2.requested_start
```

Expected unintended approved conflicts: `0 rows`.

---

## 18. README requirements

Create `README.md` with:

- Python and ODBC prerequisites
- Package installation
- Safe execution example
- Validation command
- Reset behavior
- Safety warning
- Expected row categories
- Explanation that runtime results must not be claimed before execution

Example:

```powershell
pip install -r requirements.txt
python generate_data.py --server localhost --database Step14ReviewG02 --config generator_config.json
sqlcmd -S localhost -E -d Step14ReviewG02 -i outputs/14-data-generator-G02/02-validate-data.sql
```

---

## 19. Required code quality

The Python code must include:

- `main()`
- Argument parsing
- Config validation
- Connection handling
- Type hints
- Clear helper functions
- Safe rollback
- Progress reporting
- No hardcoded credentials
- No hardcoded database
- No broad destructive SQL without safeguards

Recommended function structure:

```python
def load_config(path: Path) -> GeneratorConfig: ...
def validate_target_database(database: str, allow_non_disposable: bool) -> None: ...
def inspect_schema(connection) -> SchemaMapping: ...
def generate_users(config, rng): ...
def generate_spaces(config, rng): ...
def generate_maintenance(config, rng, schema): ...
def generate_bookings(config, rng, schema): ...
def generate_acknowledgements(...): ...
def bulk_insert(...): ...
def main() -> int: ...
```

---

## 20. Self-review checklist

Confirm that:

- No database name is hardcoded
- Disposable-database guard exists
- Broad deletion is not automatic
- Random seed is configurable
- Default target is at least 105,000 bookings
- At least three academic years are covered
- Required statuses and both approval paths are generated
- Approved bookings do not overlap for the same space
- Advisory and Out-of-Service maintenance are present
- Advisory acknowledgements are consistent
- `fast_executemany` and batch commits are used
- Progress output exists
- Validation SQL is included
- README explains safe execution
- Dry-run performs no writes
- No test result is fabricated
- Earlier project outputs are not modified

---

## 21. Final response behavior

After generating the package:

1. State that `outputs/14-data-generator-G02/` was created or updated.
2. List the generated files.
3. State the default row count and academic-year span.
4. State whether the generator was executed or only prepared.
5. State any unresolved schema mismatch.
6. Do not run it automatically against `University` or another non-disposable database.
7. Do not proceed to Step 15 automatically.
