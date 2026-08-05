# Step 14 Python Data Generator - Group G02

This package deterministically generates the migrated Campus Space Management System dataset. It targets Microsoft SQL Server, creates 105,000 bookings by default, and does not contain a database-selection statement.

## Safety Model

- `University` is always refused, including with `--allow-non-disposable`.
- Full generation accepts disposable names beginning with `Step14`, `Test`, or `Dev` by default.
- Existing rows cause generation to stop unless `--reset-generated-data` is supplied.
- Reset is allowed only for a disposable database name and deletes all nine project tables in foreign-key-safe order.
- `--allow-non-disposable` permits loading only into an empty non-disposable target; it never permits reset.
- `--dry-run` performs no insert, update, delete, trigger, or identity operation.
- Passwords are read only from the environment variable named by `--password-env`.

The reset is intended only for a database created specifically for Step 14. Never point this tool at a database containing valuable data.

## Prerequisites

- Python 3.11 or later
- Microsoft ODBC Driver 17 or later for SQL Server (the configured driver must be installed)
- `pyodbc`
- A disposable database to which the approved Step 5 and Step 10 schema have been applied
- Step 12 objects when the benchmark will also exercise protected approval and escalation procedures

Install the Python dependency from this directory:

```powershell
python -m pip install -r requirements.txt
```

The approved Step 5, Step 10, and Step 12 repository scripts contain literal `University` database context. Do not run those scripts unchanged while preparing a differently named disposable database because they redirect execution. Database provisioning must preserve the approved DDL while ensuring every statement is applied to the disposable target. This package does not create or migrate databases.

## Configuration And Dry Run

Validate JSON without connecting:

```powershell
python generate_data.py --validate-config --config generator_config.json
```

Run an offline deterministic preview:

```powershell
python generate_data.py --database Step14ReviewG02 --config generator_config.json --dry-run
```

Add `--server localhost` to the dry run to inspect the migrated schema. An offline dry run deliberately reports schema inspection as skipped.

## Safe Full Generation

Windows authentication:

```powershell
python generate_data.py --server localhost --database Step14ReviewG02 --trusted-connection --config generator_config.json
```

An existing disposable dataset must be reset explicitly:

```powershell
python generate_data.py --server localhost --database Step14ReviewG02 --trusted-connection --config generator_config.json --reset-generated-data
```

SQL authentication reads the password from an environment variable:

```powershell
$env:STEP14_SQL_PASSWORD = "<set outside source control>"
python generate_data.py --server localhost --database Step14ReviewG02 --username step14_loader --password-env STEP14_SQL_PASSWORD
```

## Generated Coverage

- Booking dates from 2023-09-01 through 2026-05-31, spanning three academic years
- All seven booking statuses and both approval paths
- Weighted Fall/Spring, weekday, peak-hour, and popular-space demand
- Six space types, five current statuses, varied capacity, and varied facility combinations
- Advisory and out-of-service maintenance, overlapping active advisories, and open/completed records
- Valid advisory acknowledgements for every booking overlapping the deliberately active benchmark advisories
- Escalation and downgrade history occurring inside the maintenance lifecycle
- Usage sessions for every `Completed` and `Checked In` booking
- No overlapping approved-lifecycle bookings on the same space under half-open interval rules

Identity values are inserted explicitly so the same seed/configuration produces stable foreign-key relationships. SQL Server `row_version` values remain server-generated and may differ.

## Loading Behavior

The generator checks the selected database context and exact migrated columns before writing. It keeps foreign keys and check constraints enabled, temporarily disables only currently enabled triggers on `BOOKING`, `MAINTENANCERECORD`, and `USAGESESSION`, and restores those trigger states in `finally`. Inserts use `pyodbc.fast_executemany`, configurable batches, per-batch commits, rollback on batch failure, and progress output.

A failed load can leave committed earlier batches. Re-run only with `--reset-generated-data` against the same disposable database.

## Independent Validation

Run the validator against the selected database; the file contains no `USE` statement:

```powershell
sqlcmd -S localhost -E -C -d Step14ReviewG02 -b -i 02-validate-data.sql
```

Runtime counts, date spans, and PASS results are observed only after full generation and independent validation. Configured or dry-run values must not be reported as runtime evidence.
