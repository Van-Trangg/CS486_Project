"""Deterministic, guarded Step 14 data generator for SQL Server."""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, time as day_time, timedelta
from pathlib import Path
from typing import Any, Iterable, Sequence


ALLOWED_STATUSES = (
    "Pending",
    "Approved",
    "Rejected",
    "Cancelled",
    "Checked In",
    "Completed",
    "No-Show",
)
APPROVAL_LIFECYCLE_STATUSES = {"Approved", "Checked In", "Completed", "No-Show"}
DISPOSABLE_PREFIXES = ("step14", "test", "dev")
TABLES = (
    "USER",
    "SPACE",
    "FACILITY",
    "SPACE_FACILITY",
    "MAINTENANCERECORD",
    "BOOKING",
    "USAGESESSION",
    "BOOKING_ADVISORY_ACK",
    "MAINTENANCE_IMPACT_HISTORY",
)
IDENTITY_TABLES = ("FACILITY", "MAINTENANCERECORD", "BOOKING", "BOOKING_ADVISORY_ACK", "MAINTENANCE_IMPACT_HISTORY")


@dataclass(frozen=True)
class GeneratorConfig:
    booking_count: int
    academic_year_count: int
    batch_size: int
    random_seed: int
    user_count: int
    space_count: int
    maintenance_count: int
    facility_count: int
    status_ratios: dict[str, float]
    instant_approval_ratio: float
    start_date: date
    end_date: date
    odbc_driver: str


@dataclass
class Dataset:
    users: list[tuple[Any, ...]]
    facilities: list[tuple[Any, ...]]
    spaces: list[tuple[Any, ...]]
    space_facilities: list[tuple[Any, ...]]
    maintenance: list[tuple[Any, ...]]
    bookings: list[tuple[Any, ...]]
    usage_sessions: list[tuple[Any, ...]]
    acknowledgements: list[tuple[Any, ...]]
    impact_history: list[tuple[Any, ...]]


def load_config(path: Path) -> GeneratorConfig:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"Cannot load configuration {path}: {exc}") from exc

    required = {
        "booking_count", "academic_year_count", "batch_size", "random_seed",
        "user_count", "space_count", "maintenance_count", "facility_count",
        "status_ratios", "instant_approval_ratio", "start_date", "end_date",
        "odbc_driver",
    }
    missing = sorted(required - raw.keys())
    unknown = sorted(raw.keys() - required)
    if missing:
        raise ValueError(f"Missing configuration keys: {', '.join(missing)}")
    if unknown:
        raise ValueError(f"Unsupported configuration keys: {', '.join(unknown)}")

    try:
        config = GeneratorConfig(
            booking_count=int(raw["booking_count"]),
            academic_year_count=int(raw["academic_year_count"]),
            batch_size=int(raw["batch_size"]),
            random_seed=int(raw["random_seed"]),
            user_count=int(raw["user_count"]),
            space_count=int(raw["space_count"]),
            maintenance_count=int(raw["maintenance_count"]),
            facility_count=int(raw["facility_count"]),
            status_ratios={str(k): float(v) for k, v in raw["status_ratios"].items()},
            instant_approval_ratio=float(raw["instant_approval_ratio"]),
            start_date=date.fromisoformat(raw["start_date"]),
            end_date=date.fromisoformat(raw["end_date"]),
            odbc_driver=str(raw["odbc_driver"]),
        )
    except (TypeError, ValueError) as exc:
        raise ValueError(f"Invalid configuration value: {exc}") from exc
    validate_config(config)
    return config


def validate_config(config: GeneratorConfig) -> None:
    errors: list[str] = []
    if config.booking_count < 100_000:
        errors.append("booking_count must be at least 100000")
    if config.academic_year_count < 3:
        errors.append("academic_year_count must be at least 3")
    if config.batch_size <= 0:
        errors.append("batch_size must be positive")
    if config.user_count < 400:
        errors.append("user_count must be at least 400")
    if config.space_count < 50:
        errors.append("space_count must be at least 50")
    if config.maintenance_count < 3000:
        errors.append("maintenance_count must be at least 3000")
    if config.facility_count != 12:
        errors.append("facility_count must be 12 because the approved benchmark catalog defines 12 facilities")
    if set(config.status_ratios) != set(ALLOWED_STATUSES):
        errors.append("status_ratios must contain exactly the seven schema statuses")
    if any(value <= 0 or value > 1 for value in config.status_ratios.values()):
        errors.append("every required status ratio must be greater than 0 and at most 1")
    if abs(sum(config.status_ratios.values()) - 1.0) > 1e-9:
        errors.append("status ratios must sum to exactly 1.0")
    if not 0 < config.instant_approval_ratio <= 1:
        errors.append("instant_approval_ratio must be greater than 0 and at most 1")
    if config.start_date >= config.end_date:
        errors.append("start_date must be earlier than end_date")
    covered_academic_years = {
        value.year if value.month >= 9 else value.year - 1
        for value in _date_range(config.start_date, config.end_date)
    }
    if len(covered_academic_years) < config.academic_year_count:
        errors.append("configured date range cannot cover academic_year_count")
    if not config.odbc_driver.strip():
        errors.append("odbc_driver must not be empty")
    if errors:
        raise ValueError("Invalid configuration: " + "; ".join(errors))


def validate_target_database(database: str, allow_non_disposable: bool) -> bool:
    normalized = database.strip().lower()
    if not normalized:
        raise ValueError("A target database is required")
    if normalized == "university":
        raise RuntimeError("Refusing to target University under any generator option.")
    disposable = normalized.startswith(DISPOSABLE_PREFIXES)
    if not disposable and not allow_non_disposable:
        raise RuntimeError(
            "Refusing to generate data outside an approved disposable database "
            "(Step14*, Test*, or Dev*)."
        )
    if not disposable:
        print("WARNING: explicit non-disposable bypass is active; reset remains prohibited.", file=sys.stderr)
    return disposable


def _allocate_values(total: int, ratios: dict[str, float], rng: random.Random) -> list[str]:
    values: list[str] = []
    remainders: list[tuple[float, str]] = []
    for name, ratio in ratios.items():
        exact = total * ratio
        count = int(exact)
        values.extend([name] * count)
        remainders.append((exact - count, name))
    for _, name in sorted(remainders, reverse=True)[: total - len(values)]:
        values.append(name)
    rng.shuffle(values)
    return values


def _date_range(start: date, end: date) -> list[date]:
    return [start + timedelta(days=i) for i in range((end - start).days + 1)]


def generate_dataset(config: GeneratorConfig, booking_limit: int | None = None) -> Dataset:
    rng = random.Random(config.random_seed)
    booking_count = booking_limit or config.booking_count

    roles = (
        "Student", "Lecturer", "Teaching Assistant", "Facility Staff",
        "Department Administrator", "Facility Manager",
    )
    departments = ("Computer Science", "Mathematics", "Engineering", "Business", "Library Services")
    account_statuses = ("Active", "Suspended", "Inactive")
    users: list[tuple[Any, ...]] = []
    for n in range(1, config.user_count + 1):
        role = roles[(n - 1) % len(roles)]
        status = account_statuses[(n // len(roles)) % len(account_statuses)]
        if role in ("Facility Staff", "Facility Manager") and n <= 120:
            status = "Active"
        users.append((
            f"G02-U{n:05d}", f"g02.user{n:05d}@example.edu", f"Generated User {n:05d}",
            f"+1-555-{n % 10000:04d}", role, departments[n % len(departments)], status,
        ))
    active_staff = [row[0] for row in users if row[4] in ("Facility Staff", "Facility Manager") and row[6] == "Active"]
    requesters = [row[0] for row in users if row[6] == "Active"]
    instant_requesters = [
        row[0] for row in users
        if row[4] in ("Lecturer", "Teaching Assistant") and row[6] == "Active"
    ]

    facility_names = (
        "Projector", "Whiteboard", "Video Conferencing", "Desktop Computers",
        "High-Speed Network", "Audio System", "Accessible Seating", "3D Printer",
        "Laboratory Bench", "Power Outlets", "Air Conditioning", "Recording Equipment",
    )
    facilities = [
        (n, facility_names[n - 1], f"Generated benchmark facility: {facility_names[n - 1]}")
        for n in range(1, config.facility_count + 1)
    ]

    space_types = (
        "Auditorium", "Classroom", "Computer Laboratory", "Project Laboratory",
        "Meeting Room", "Student Workspace",
    )
    space_statuses = ("Available", "Available", "Available", "In Use", "Under Maintenance", "Temporarily Closed", "Retired")
    buildings = ("Turing Hall", "Lovelace Center", "Hopper Building", "Knuth Annex")
    base_capacities = (180, 60, 36, 28, 16, 48)
    spaces: list[tuple[Any, ...]] = []
    for n in range(1, config.space_count + 1):
        type_index = (n - 1) % len(space_types)
        code = f"G02-S{n:03d}"
        spaces.append((
            code, f"Generated {space_types[type_index]} {n:03d}", space_types[type_index],
            buildings[(n - 1) % len(buildings)], str(1 + (n % 5)), f"R{100 + n}",
            base_capacities[type_index] + (n % 5) * 4, space_statuses[(n - 1) % len(space_statuses)],
            "Synthetic Step 14 usage policy; booking requires an active university account.",
        ))
    space_by_code = {row[0]: row for row in spaces}

    space_facilities: list[tuple[Any, ...]] = []
    for n, space in enumerate(spaces, 1):
        type_index = space_types.index(space[2])
        required = {5, 7, 10, 11, 1 + type_index, 1 + ((n * 3) % config.facility_count)}
        if n % 4 == 0:
            required.add(3)
        if n % 7 == 0:
            required.add(12)
        for facility_id in sorted(required):
            status = ("Operational", "Operational", "Operational", "Partially Operational", "Broken")[(n + facility_id) % 5]
            space_facilities.append((space[0], facility_id, 1 + ((n + facility_id) % 8), status, "Generated condition record"))

    all_dates = _date_range(config.start_date, config.end_date)
    weighted_dates: list[date] = []
    for value in all_dates:
        semester_weight = 5 if value.month in (1, 2, 3, 4, 5, 9, 10, 11, 12) else 2
        weekday_weight = 4 if value.weekday() < 5 else 1
        weighted_dates.extend([value] * semester_weight * weekday_weight)
    weighted_hours = [8] * 3 + [9] * 5 + [10] * 7 + [11] * 5 + [13] * 7 + [14] * 6 + [15] * 4 + [16] * 3 + [18]
    statuses = _allocate_values(booking_count, config.status_ratios, rng)
    purposes = ("Lecture", "Examination", "Seminar", "Workshop", "Meeting", "Student Activity", "Administrative Event")
    bookable_codes = [row[0] for row in spaces if row[7] not in ("Temporarily Closed", "Retired")]
    instant_codes = [
        row[0] for row in spaces
        if row[2] == "Classroom" and row[7] not in ("Temporarily Closed", "Retired")
    ]
    weighted_bookable = [code for i, code in enumerate(bookable_codes) for _ in range(8 if i < 10 else 3 if i < 30 else 1)]
    weighted_instant = [code for i, code in enumerate(instant_codes) for _ in range(5 if i < 4 else 2)]
    schedules: dict[str, list[tuple[datetime, datetime]]] = defaultdict(list)
    bookings: list[tuple[Any, ...]] = []
    usage_sessions: list[tuple[Any, ...]] = []
    instant_eligible_ratio = sum(config.status_ratios[s] for s in APPROVAL_LIFECYCLE_STATUSES | {"Cancelled"})
    instant_probability = min(1.0, config.instant_approval_ratio / instant_eligible_ratio)

    def choose_nonconflicting(code_choices: Sequence[str], forced_date: date | None = None) -> tuple[str, datetime, datetime]:
        for _ in range(500):
            code = rng.choice(code_choices)
            chosen_date = forced_date or rng.choice(weighted_dates)
            start = datetime.combine(chosen_date, day_time(rng.choice(weighted_hours), 0))
            duration = rng.choice((1, 1, 2, 2, 2, 3))
            end = start + timedelta(hours=duration)
            if all(existing_start >= end or existing_end <= start for existing_start, existing_end in schedules[code]):
                schedules[code].append((start, end))
                return code, start, end
        raise RuntimeError("Unable to allocate a non-overlapping approved-lifecycle booking slot")

    for index, status in enumerate(statuses, 1):
        instant_allowed = status in APPROVAL_LIFECYCLE_STATUSES | {"Cancelled"}
        resolution_path = "Instant" if instant_allowed and rng.random() < instant_probability else "Staff"
        choices = weighted_instant if resolution_path == "Instant" else weighted_bookable
        forced_date = config.start_date if index == 1 else config.end_date if index == 2 else None
        if status in APPROVAL_LIFECYCLE_STATUSES:
            space_code, requested_start, requested_end = choose_nonconflicting(choices, forced_date)
        else:
            space_code = rng.choice(choices)
            chosen_date = forced_date or rng.choice(weighted_dates)
            requested_start = datetime.combine(chosen_date, day_time(rng.choice(weighted_hours), 0))
            requested_end = requested_start + timedelta(hours=rng.choice((1, 1, 2, 2, 3)))
        created_at = requested_start - timedelta(days=rng.randint(7, 30), hours=rng.randint(0, 12))
        decision_status = (
            status in APPROVAL_LIFECYCLE_STATUSES | {"Rejected"}
            or (status == "Cancelled" and (resolution_path == "Instant" or index % 2 == 0))
        )
        decision_time = (
            created_at
            if decision_status and resolution_path == "Instant"
            else created_at + timedelta(hours=rng.randint(2, 48))
            if decision_status and resolution_path == "Staff"
            else None)
        approver_id = rng.choice(active_staff) if decision_status and resolution_path == "Staff" else None
        decision_note = "Generated staff decision" if decision_status and resolution_path == "Staff" else None
        rejection_reason = "Usage policy or availability requirements were not met" if status == "Rejected" else None
        capacity = space_by_code[space_code][6]
        participants = rng.randint(1, max(1, min(capacity, int(capacity * rng.uniform(0.25, 1.0)))))
        requester_id = rng.choice(instant_requesters if resolution_path == "Instant" else requesters)
        bookings.append((
            index, space_code, requester_id, requested_start, requested_end,
            purposes[(index - 1) % len(purposes)], participants, status, created_at,
            approver_id, decision_time, decision_note, rejection_reason, resolution_path,
        ))
        if status in ("Completed", "Checked In"):
            actual_start = requested_start + timedelta(minutes=rng.choice((-5, 0, 5, 10)))
            completed = status == "Completed"
            usage_sessions.append((
                index, rng.choice(active_staff), actual_start, "Room checked and ready",
                rng.choice(active_staff) if completed else None,
                actual_start + (requested_end - requested_start) - timedelta(minutes=5) if completed else None,
                "Room returned in acceptable condition" if completed else None,
                "Generated usage session",
            ))

    problem_types = ("Projector Failure", "Air-Conditioning Issue", "Cleaning Issue", "Furniture Damage", "Network Issue", "Other")
    maintenance_statuses = ("Reported", "In Progress", "Resolved", "Resolved", "Resolved", "Cancelled")
    maintenance: list[tuple[Any, ...]] = []
    impact_history: list[tuple[Any, ...]] = []
    broad_advisory_ids_by_space: dict[str, list[int]] = defaultdict(list)
    lifecycle_bookings = [row for row in bookings if row[7] in APPROVAL_LIFECYCLE_STATUSES]
    escalation_count = min(100, len(lifecycle_bookings), config.maintenance_count - 20)
    downgrade_count = min(300, max(0, config.maintenance_count - 20 - escalation_count))
    history_id = 1

    for maintenance_id in range(1, config.maintenance_count + 1):
        reporter = requesters[maintenance_id % len(requesters)]
        assigned = active_staff[maintenance_id % len(active_staff)]
        if maintenance_id <= 20:
            space_code = spaces[(maintenance_id - 1) % 10][0]
            impact = "advisory"
            status = "In Progress"
            start_time = datetime.combine(config.start_date - timedelta(days=31), day_time(0, 0))
            completion_time = None
            broad_advisory_ids_by_space[space_code].append(maintenance_id)
        elif maintenance_id <= 20 + escalation_count:
            booking = lifecycle_bookings[maintenance_id - 21]
            space_code = booking[1]
            impact = "out-of-service"
            status = "Resolved"
            start_time = booking[3] - timedelta(hours=1)
            completion_time = booking[4] + timedelta(days=1)
            changed_at = booking[3] - timedelta(minutes=15)
            impact_history.append((history_id, maintenance_id, "advisory", "out-of-service", changed_at, assigned))
            history_id += 1
        elif maintenance_id <= 20 + escalation_count + downgrade_count:
            space_code = spaces[(maintenance_id * 7) % len(spaces)][0]
            impact = "advisory"
            status = "Resolved"
            chosen_date = all_dates[(maintenance_id * 13) % len(all_dates)]
            start_time = datetime.combine(chosen_date, day_time(1, 0))
            completion_time = start_time + timedelta(hours=12)
            first_change = start_time + timedelta(hours=2)
            second_change = start_time + timedelta(hours=7)
            impact_history.append((history_id, maintenance_id, "advisory", "out-of-service", first_change, assigned))
            history_id += 1
            impact_history.append((history_id, maintenance_id, "out-of-service", "advisory", second_change, assigned))
            history_id += 1
        else:
            space_code = spaces[(maintenance_id * 11) % len(spaces)][0]
            impact = "advisory" if maintenance_id % 10 < 7 else "out-of-service"
            status = maintenance_statuses[maintenance_id % len(maintenance_statuses)]
            chosen_date = all_dates[(maintenance_id * 17) % len(all_dates)]
            if status in ("Reported", "In Progress"):
                start_time = datetime.combine(config.end_date + timedelta(days=1 + maintenance_id % 30), day_time(1, 0))
                completion_time = None
            else:
                start_time = datetime.combine(chosen_date, day_time(1, 0))
                completion_time = start_time + timedelta(hours=2 + maintenance_id % 5)
        maintenance.append((
            maintenance_id, space_code, reporter, assigned, problem_types[(maintenance_id - 1) % len(problem_types)],
            f"Generated maintenance issue {maintenance_id}", start_time, completion_time, status,
            "Generated maintenance outcome" if completion_time else None, impact,
        ))

    acknowledgements: list[tuple[Any, ...]] = []
    ack_id = 1
    for booking in bookings:
        for maintenance_id in broad_advisory_ids_by_space.get(booking[1], []):
            acknowledgements.append((ack_id, booking[0], maintenance_id, booking[8] + timedelta(minutes=5)))
            ack_id += 1

    return Dataset(
        users, facilities, spaces, space_facilities, maintenance, bookings,
        usage_sessions, acknowledgements, impact_history,
    )


def build_connection_string(args: argparse.Namespace, config: GeneratorConfig) -> str:
    parts = [
        f"DRIVER={{{config.odbc_driver}}}", f"SERVER={args.server}",
        f"DATABASE={args.database}", "Encrypt=yes", "TrustServerCertificate=yes",
        "APP=CS486 Step14 G02 Generator",
    ]
    if args.trusted_connection and args.username:
        raise ValueError("--trusted-connection and --username are mutually exclusive")
    if args.password_env and not args.username:
        raise ValueError("--password-env requires --username")
    if args.username:
        if not args.password_env:
            raise ValueError("--password-env is required with --username")
        password = os.environ.get(args.password_env)
        if password is None:
            raise ValueError(f"Password environment variable {args.password_env!r} is not set")
        parts.extend((f"UID={args.username}", f"PWD={password}"))
    else:
        parts.append("Trusted_Connection=yes")
    return ";".join(parts) + ";"


def inspect_schema(connection: Any, expected_database: str) -> None:
    cursor = connection.cursor()
    actual_database = cursor.execute("SELECT DB_NAME()").fetchval()
    if actual_database.lower() != expected_database.lower():
        raise RuntimeError(f"Connection context mismatch: expected {expected_database}, got {actual_database}")
    expected_columns = {
        "USER": {"user_id", "email", "full_name", "phone_number", "role", "department", "account_status"},
        "SPACE": {"space_code", "space_name", "space_type", "building", "floor", "room_number", "capacity", "current_status", "usage_policy"},
        "FACILITY": {"facility_id", "facility_name", "facility_description"},
        "SPACE_FACILITY": {"space_code", "facility_id", "quantity", "operation_status", "description"},
        "BOOKING": {"booking_id", "space_code", "requester_id", "requested_start", "requested_end", "purpose", "expected_participants", "booking_status", "created_at", "approver_id", "decision_time", "decision_note", "rejection_reason", "resolution_path"},
        "USAGESESSION": {"booking_id", "check_in_staff_id", "actual_start", "initial_condition", "check_out_staff_id", "actual_end", "final_condition", "usage_notes"},
        "MAINTENANCERECORD": {"maintenance_id", "space_code", "reporter_id", "assigned_staff_id", "problem_type", "problem_description", "start_time", "completion_time", "maintenance_status", "result_note", "impact_level"},
        "BOOKING_ADVISORY_ACK": {"ack_id", "booking_id", "maintenance_id", "acknowledged_at"},
        "MAINTENANCE_IMPACT_HISTORY": {"history_id", "maintenance_id", "old_impact_level", "new_impact_level", "changed_at", "changed_by_user_id"},
    }
    rows = cursor.execute(
        "SELECT t.name, c.name, ty.name, c.max_length, c.is_nullable, c.is_identity "
        "FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id "
        "JOIN sys.types ty ON ty.user_type_id=c.user_type_id "
        "WHERE SCHEMA_NAME(t.schema_id)='dbo' ORDER BY t.name, c.column_id"
    ).fetchall()
    actual: dict[str, dict[str, tuple[str, int, bool, bool]]] = defaultdict(dict)
    for table_name, column_name, type_name, max_length, is_nullable, is_identity in rows:
        actual[table_name.upper()][column_name.lower()] = (
            type_name.lower(), max_length, bool(is_nullable), bool(is_identity)
        )
    problems = [
        f"dbo.{table}: expected columns {sorted(columns)}, found {sorted(actual.get(table, {}))}"
        for table, columns in expected_columns.items() if columns != set(actual.get(table, {}))
    ]
    expected_identity = {
        ("FACILITY", "facility_id"), ("MAINTENANCERECORD", "maintenance_id"),
        ("BOOKING", "booking_id"), ("BOOKING_ADVISORY_ACK", "ack_id"),
        ("MAINTENANCE_IMPACT_HISTORY", "history_id"),
    }
    actual_identity = {
        (table, column) for table, columns in actual.items()
        for column, metadata in columns.items() if metadata[3] and table in expected_columns
    }
    if actual_identity != expected_identity:
        problems.append(f"identity columns expected {sorted(expected_identity)}, found {sorted(actual_identity)}")
    expected_constraints = {
        "PK": {
            "PK_USER", "PK_SPACE", "PK_FACILITY", "PK_SPACE_FACILITY", "PK_BOOKING",
            "PK_USAGESESSION", "PK_MAINTENANCERECORD", "PK_BOOKING_ADVISORY_ACK",
            "PK_MAINTENANCE_IMPACT_HISTORY",
        },
        "UQ": {
            "UQ_USER_EMAIL", "UQ_SPACE_LOCATION", "UQ_FACILITY_NAME",
            "UQ_BOOKING_MAINTENANCE_ACK",
        },
        "FK": {
            "FK_SPACE_FACILITY_SPACE", "FK_SPACE_FACILITY_FACILITY", "FK_BOOKING_SPACE",
            "FK_BOOKING_USER_REQUESTER", "FK_BOOKING_USER_APPROVER", "FK_USAGESESSION_BOOKING",
            "FK_USAGESESSION_USER_CHECKIN", "FK_USAGESESSION_USER_CHECKOUT",
            "FK_MAINTENANCERECORD_SPACE", "FK_MAINTENANCERECORD_USER_REPORTER",
            "FK_MAINTENANCERECORD_USER_ASSIGNED", "FK_ACK_BOOKING", "FK_ACK_MAINTENANCE",
            "FK_HIST_MAINTENANCE", "FK_HIST_USER",
        },
        "CK": {
            "CK_USER_ROLE", "CK_USER_ACCOUNT_STATUS", "CK_SPACE_TYPE", "CK_SPACE_CAPACITY",
            "CK_SPACE_CURRENT_STATUS", "CK_SPACE_FACILITY_QUANTITY", "CK_SPACE_FACILITY_STATUS",
            "CK_BOOKING_TIME_ORDER", "CK_BOOKING_PARTICIPANTS", "CK_BOOKING_PURPOSE",
            "CK_BOOKING_STATUS", "CK_BOOKING_FUTURE_START", "CK_BOOKING_REJECTION_REASON",
            "CK_BOOKING_CAPACITY_LIMIT", "CK_USAGE_TIME_ORDER", "CK_MAINTENANCE_TIME_ORDER",
            "CK_MAINTENANCE_STATUS", "CK_MAINTENANCE_PROBLEM_TYPE",
            "CK_MAINTENANCERECORD_IMPACT_LEVEL", "CK_BOOKING_RESOLUTION_PATH",
            "CK_HIST_OLD_IMPACT", "CK_HIST_NEW_IMPACT", "CK_HIST_TRANSITION",
        },
        "DF": {
            "DF_SPACE_FACILITY_QUANTITY", "DF_SPACE_FACILITY_STATUS", "DF_BOOKING_CREATED_AT",
            "DF_MAINTENANCERECORD_IMPACT_LEVEL", "DF_BOOKING_RESOLUTION_PATH",
            "DF_BOOKING_ADVISORY_ACK_ACKNOWLEDGED_AT",
            "DF_MAINTENANCE_IMPACT_HISTORY_CHANGED_AT",
        },
    }
    constraint_rows = cursor.execute(
        "SELECT 'PK', kc.name FROM sys.key_constraints kc WHERE kc.type='PK' "
        "UNION ALL SELECT 'UQ', kc.name FROM sys.key_constraints kc WHERE kc.type='UQ' "
        "UNION ALL SELECT 'FK', fk.name FROM sys.foreign_keys fk "
        "UNION ALL SELECT 'CK', ck.name FROM sys.check_constraints ck "
        "UNION ALL SELECT 'DF', dc.name FROM sys.default_constraints dc"
    ).fetchall()
    actual_constraints: dict[str, set[str]] = defaultdict(set)
    for constraint_type, constraint_name in constraint_rows:
        actual_constraints[constraint_type].add(constraint_name)
    for constraint_type, expected_names in expected_constraints.items():
        missing_names = sorted(expected_names - actual_constraints[constraint_type])
        if missing_names:
            problems.append(f"missing required {constraint_type} constraints {missing_names}")
    required_metadata = {
        ("BOOKING", "booking_id"): ("int", 4, False),
        ("BOOKING", "space_code"): ("varchar", 50, False),
        ("BOOKING", "requested_start"): ("datetime", 8, False),
        ("BOOKING", "requested_end"): ("datetime", 8, False),
        ("BOOKING", "booking_status"): ("varchar", 30, False),
        ("BOOKING", "resolution_path"): ("varchar", 20, False),
        ("MAINTENANCERECORD", "maintenance_id"): ("int", 4, False),
        ("MAINTENANCERECORD", "impact_level"): ("varchar", 20, False),
        ("BOOKING_ADVISORY_ACK", "ack_id"): ("int", 4, False),
        ("BOOKING_ADVISORY_ACK", "booking_id"): ("int", 4, False),
        ("BOOKING_ADVISORY_ACK", "maintenance_id"): ("int", 4, False),
        ("MAINTENANCE_IMPACT_HISTORY", "history_id"): ("int", 4, False),
        ("MAINTENANCE_IMPACT_HISTORY", "old_impact_level"): ("varchar", 20, False),
        ("MAINTENANCE_IMPACT_HISTORY", "new_impact_level"): ("varchar", 20, False),
        ("MAINTENANCE_IMPACT_HISTORY", "changed_by_user_id"): ("varchar", 50, False),
    }
    for key, expected in required_metadata.items():
        observed = actual.get(key[0], {}).get(key[1])
        if observed is None or observed[:3] != expected:
            problems.append(f"dbo.{key[0]}.{key[1]} metadata expected {expected}, found {observed}")
    bad_constraints = cursor.execute(
        "SELECT COUNT_BIG(*) FROM ("
        "SELECT is_disabled, is_not_trusted FROM sys.check_constraints WHERE parent_object_id IN "
        "(SELECT object_id FROM sys.tables WHERE schema_id=SCHEMA_ID('dbo') AND name IN ("
        "'USER','SPACE','FACILITY','SPACE_FACILITY','BOOKING','USAGESESSION','MAINTENANCERECORD','BOOKING_ADVISORY_ACK','MAINTENANCE_IMPACT_HISTORY')) "
        "UNION ALL SELECT is_disabled, is_not_trusted FROM sys.foreign_keys WHERE parent_object_id IN "
        "(SELECT object_id FROM sys.tables WHERE schema_id=SCHEMA_ID('dbo') AND name IN ("
        "'USER','SPACE','FACILITY','SPACE_FACILITY','BOOKING','USAGESESSION','MAINTENANCERECORD','BOOKING_ADVISORY_ACK','MAINTENANCE_IMPACT_HISTORY'))) c "
        "WHERE is_disabled=1 OR is_not_trusted=1"
    ).fetchval()
    if bad_constraints:
        problems.append(f"{bad_constraints} required check/foreign-key constraints are disabled or untrusted")
    if problems:
        raise RuntimeError("Schema inspection failed: " + "; ".join(problems))
    print("Schema inspection: PASS (Step 5 + Step 10 objects detected).")


def _quote_identifier(name: str) -> str:
    return "[" + name.replace("]", "]]" ) + "]"


def capture_and_disable_triggers(connection: Any) -> list[tuple[str, str]]:
    rows = connection.cursor().execute(
        "SELECT OBJECT_SCHEMA_NAME(t.parent_id), OBJECT_NAME(t.parent_id), t.name "
        "FROM sys.triggers t WHERE t.parent_class=1 AND t.is_disabled=0 "
        "AND t.parent_id IN (OBJECT_ID('dbo.BOOKING'), OBJECT_ID('dbo.MAINTENANCERECORD'), OBJECT_ID('dbo.USAGESESSION'))"
    ).fetchall()
    enabled = [(f"{schema}.{table}", trigger) for schema, table, trigger in rows]
    cursor = connection.cursor()
    disabled: list[tuple[str, str]] = []
    try:
        for parent, trigger in enabled:
            schema, table = parent.split(".", 1)
            cursor.execute(f"DISABLE TRIGGER {_quote_identifier(trigger)} ON {_quote_identifier(schema)}.{_quote_identifier(table)}")
            disabled.append((parent, trigger))
        connection.commit()
    except Exception:
        connection.rollback()
        restore_triggers(connection, disabled)
        raise
    return enabled


def restore_triggers(connection: Any, triggers: Sequence[tuple[str, str]]) -> None:
    cursor = connection.cursor()
    recovery_statements: list[str] = []
    try:
        for parent, trigger in triggers:
            schema, table = parent.split(".", 1)
            statement = f"ENABLE TRIGGER {_quote_identifier(trigger)} ON {_quote_identifier(schema)}.{_quote_identifier(table)}"
            recovery_statements.append(statement + ";")
            cursor.execute(statement)
        connection.commit()
        remaining_disabled = cursor.execute(
            "SELECT COUNT_BIG(*) FROM sys.triggers t "
            "WHERE t.is_disabled=1 AND t.name IN (" + ",".join("?" for _ in triggers) + ")",
            tuple(trigger for _, trigger in triggers),
        ).fetchval()
        if remaining_disabled:
            raise RuntimeError(f"{remaining_disabled} protected triggers remain disabled")
    except Exception as exc:
        connection.rollback()
        recovery_sql = " ".join(recovery_statements)
        raise RuntimeError(
            "CRITICAL: protected trigger restoration failed. Do not use the database until an "
            f"administrator runs: {recovery_sql} Original error: {exc}"
        ) from exc


def prepare_target(connection: Any, reset: bool, disposable: bool) -> None:
    cursor = connection.cursor()
    counts = {table: cursor.execute(f"SELECT COUNT_BIG(*) FROM dbo.{_quote_identifier(table)}").fetchval() for table in TABLES}
    nonempty = {table: count for table, count in counts.items() if count}
    if nonempty and not reset:
        raise RuntimeError(f"Target is not empty ({nonempty}); use --reset-generated-data only for a disposable database")
    if reset:
        if not disposable:
            raise RuntimeError("Reset is prohibited for non-disposable database names, even with bypass")
        try:
            for table in ("MAINTENANCE_IMPACT_HISTORY", "BOOKING_ADVISORY_ACK", "USAGESESSION", "BOOKING", "MAINTENANCERECORD", "SPACE_FACILITY", "FACILITY", "SPACE", "USER"):
                cursor.execute(f"DELETE FROM dbo.{_quote_identifier(table)}")
            for table in IDENTITY_TABLES:
                cursor.execute(f"DBCC CHECKIDENT ('dbo.{table}', RESEED, 0) WITH NO_INFOMSGS")
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        print("Explicit disposable-database reset completed.")


def bulk_insert(connection: Any, table: str, columns: Sequence[str], rows: Sequence[tuple[Any, ...]], batch_size: int, identity: bool = False) -> None:
    if not rows:
        return
    cursor = connection.cursor()
    cursor.fast_executemany = True
    qualified = f"dbo.{_quote_identifier(table)}"
    column_sql = ", ".join(_quote_identifier(column) for column in columns)
    placeholders = ", ".join("?" for _ in columns)
    statement = f"INSERT INTO {qualified} ({column_sql}) VALUES ({placeholders})"
    try:
        if identity:
            cursor.execute(f"SET IDENTITY_INSERT {qualified} ON")
        for start in range(0, len(rows), batch_size):
            batch = rows[start:start + batch_size]
            try:
                cursor.executemany(statement, batch)
                connection.commit()
            except Exception:
                connection.rollback()
                raise RuntimeError(f"Bulk insert failed for {table}, rows {start + 1}-{start + len(batch)}")
            print(f"{table}: inserted {start + len(batch):,}/{len(rows):,}")
    finally:
        if identity:
            cursor.execute(f"SET IDENTITY_INSERT {qualified} OFF")
            connection.commit()


def load_dataset(connection: Any, dataset: Dataset, batch_size: int) -> None:
    specifications = (
        ("USER", ("user_id", "email", "full_name", "phone_number", "role", "department", "account_status"), dataset.users, False),
        ("FACILITY", ("facility_id", "facility_name", "facility_description"), dataset.facilities, True),
        ("SPACE", ("space_code", "space_name", "space_type", "building", "floor", "room_number", "capacity", "current_status", "usage_policy"), dataset.spaces, False),
        ("SPACE_FACILITY", ("space_code", "facility_id", "quantity", "operation_status", "description"), dataset.space_facilities, False),
        ("MAINTENANCERECORD", ("maintenance_id", "space_code", "reporter_id", "assigned_staff_id", "problem_type", "problem_description", "start_time", "completion_time", "maintenance_status", "result_note", "impact_level"), dataset.maintenance, True),
        ("BOOKING", ("booking_id", "space_code", "requester_id", "requested_start", "requested_end", "purpose", "expected_participants", "booking_status", "created_at", "approver_id", "decision_time", "decision_note", "rejection_reason", "resolution_path"), dataset.bookings, True),
        ("USAGESESSION", ("booking_id", "check_in_staff_id", "actual_start", "initial_condition", "check_out_staff_id", "actual_end", "final_condition", "usage_notes"), dataset.usage_sessions, False),
        ("BOOKING_ADVISORY_ACK", ("ack_id", "booking_id", "maintenance_id", "acknowledged_at"), dataset.acknowledgements, True),
        ("MAINTENANCE_IMPACT_HISTORY", ("history_id", "maintenance_id", "old_impact_level", "new_impact_level", "changed_at", "changed_by_user_id"), dataset.impact_history, True),
    )
    for table, columns, rows, identity in specifications:
        bulk_insert(connection, table, columns, rows, batch_size, identity)


def print_plan(config: GeneratorConfig, dataset: Dataset, sample: bool) -> None:
    label = "sample" if sample else "full"
    print(f"Generation plan ({label}, seed {config.random_seed}):")
    print(f"  configured bookings: {config.booking_count:,}")
    print(f"  configured date span: {config.start_date} through {config.end_date}")
    print(f"  users/spaces/facilities: {len(dataset.users):,}/{len(dataset.spaces):,}/{len(dataset.facilities):,}")
    print(f"  generated preview bookings: {len(dataset.bookings):,}")
    print(f"  maintenance/acks/history: {len(dataset.maintenance):,}/{len(dataset.acknowledgements):,}/{len(dataset.impact_history):,}")
    conflicts = 0
    schedules: dict[str, list[tuple[datetime, datetime]]] = defaultdict(list)
    for row in dataset.bookings:
        if row[7] not in APPROVAL_LIFECYCLE_STATUSES:
            continue
        for start, end in schedules[row[1]]:
            conflicts += int(start < row[4] and end > row[3])
        schedules[row[1]].append((row[3], row[4]))
    print(f"  preview approved-lifecycle overlap pairs: {conflicts}")


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate deterministic Step 14 data in a guarded SQL Server database.")
    parser.add_argument("--server", help="SQL Server host or instance; required for connected dry-run/full load")
    parser.add_argument("--database", help="Target database; University is always refused")
    parser.add_argument("--config", type=Path, default=Path(__file__).with_name("generator_config.json"))
    authentication = parser.add_mutually_exclusive_group()
    authentication.add_argument("--trusted-connection", action="store_true", help="Use Windows authentication (default when no username is supplied)")
    authentication.add_argument("--username", help="SQL authentication user")
    parser.add_argument("--password-env", help="Environment variable containing the SQL password")
    parser.add_argument("--reset-generated-data", action="store_true", help="Delete project rows only in a verified disposable target")
    parser.add_argument("--allow-non-disposable", action="store_true", help="Explicitly bypass the disposable-name guard; reset remains prohibited")
    parser.add_argument("--dry-run", action="store_true", help="Validate and generate an in-memory preview without writes")
    parser.add_argument("--validate-config", action="store_true", help="Validate configuration without database access")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        config = load_config(args.config)
        print(f"Configuration validation: PASS ({args.config})")
        if args.validate_config and not args.dry_run:
            return 0
        if not args.database:
            raise ValueError("--database is required unless only --validate-config is used")
        disposable = validate_target_database(args.database, args.allow_non_disposable)
        if args.reset_generated_data and not disposable:
            raise RuntimeError("--reset-generated-data requires a disposable database name")

        if args.dry_run:
            sample_count = min(2_000, config.booking_count)
            dataset = generate_dataset(config, sample_count)
            print_plan(config, dataset, sample=True)
            if args.server:
                import pyodbc
                with pyodbc.connect(build_connection_string(args, config), timeout=5) as connection:
                    inspect_schema(connection, args.database)
            else:
                print("Schema inspection: SKIPPED (offline dry-run; provide --server to inspect).")
            print("Dry-run completed: no SQL write statements were executed.")
            return 0

        if not args.server:
            raise ValueError("--server is required for full generation")
        import pyodbc
        started = time.perf_counter()
        with pyodbc.connect(build_connection_string(args, config), autocommit=False, timeout=10) as connection:
            inspect_schema(connection, args.database)
            enabled_triggers: list[tuple[str, str]] = []
            try:
                enabled_triggers = capture_and_disable_triggers(connection)
                prepare_target(connection, args.reset_generated_data, disposable)
                dataset = generate_dataset(config)
                print_plan(config, dataset, sample=False)
                load_dataset(connection, dataset, config.batch_size)
            except Exception:
                connection.rollback()
                raise
            finally:
                if enabled_triggers:
                    restore_triggers(connection, enabled_triggers)
        print(f"Generation completed in {time.perf_counter() - started:.1f} seconds. Run 02-validate-data.sql independently.")
        return 0
    except (ValueError, RuntimeError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:
        print(f"ERROR: SQL Server generation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
