---
name: analytical-queries-step16
description: Skill for implementing the four Step 16 analytical queries in Microsoft SQL Server according to Phase 2 requirements and AGENTS.md §9 Step 16 standards.
compatibility: opencode
---

# Step 16 — Analytical Queries Skill

Use this skill after the Phase 2 schema migration (Step 10), concurrency implementation (Step 12), and large-scale data generator (Step 14) have been completed.

The purpose of this step is to implement the four analytical reporting queries required by the Facility Manager and Department Administrators.

## Required output

Create or update:

```
outputs/16-analytical-queries-G02.sql
```

Do not modify approved Phase 1 or earlier Phase 2 output files unless the user explicitly requests it.

---

## 1. Inspect the project before query implementation

1. Run `ls -la` and inspect the repository structure.
2. Read the baseline schema and migration files:
   - `outputs/05-db-definition-G02.sql`
   - `outputs/10-schema-migration-G02.sql`
   - `outputs/14-data-generator-G02/01-generate-data.sql`
3. Identify exact table and column names:
   - `SPACE` (`space_code`, `space_name`, `space_type`, `building`, `floor`, `room_number`, `capacity`, `current_status`)
   - `BOOKING` (`booking_id`, `space_code`, `requester_id`, `requested_start`, `requested_end`, `booking_status`, `approval_path`, `created_at`)
   - `MAINTENANCERECORD` (`maintenance_id`, `space_code`, `impact_level`, `maintenance_status`, `start_time`, `completion_time`)
   - `MAINTENANCE_IMPACT_HISTORY` (`history_id`, `maintenance_id`, `old_impact_level`, `new_impact_level`, `changed_at`)
   - `SPACE_FACILITY` (`space_code`, `facility_id`, `quantity`, `operation_status`)
   - `FACILITY` (`facility_id`, `facility_name`)

---

## 2. Required query structure & metadata format

For **every** analytical query (Queries 1 through 4), include a structured SQL block comment containing all seven required metadata fields specified in `AGENTS.md` §9 Step 16:

```sql
-- ============================================================
-- Query [N]: [Short Query Name]
-- ============================================================
/*
1. Business Question:
   [Explicit question answered by the query]

2. Target User:
   [Role/persona using this report, e.g., Facility Manager]

3. Business Value:
   [Actionable insight or decision enabled by the query]

4. Parameters:
   [Declared T-SQL parameter variables with types and descriptions]

5. SQL Statement:
   [Provided in executable form below the header]

6. Correctness Notes:
   [Detailed notes on filtering, status logic, half-open intervals, handling NULLs]

7. Expected Output Meaning:
   [Explanation of output columns and how results should be interpreted]
*/
```

---

## 3. Required analytical queries scope

### Query 1: Total approved booking hours of each space for a given semester
- **Business Purpose:** Calculate total hours of approved bookings (`Approved`, `Checked In`, `Completed`) for every space during a user-specified semester date range (`@SemesterStart` to `@SemesterEnd`).
- **Core T-SQL Rules:**
  - Must include ALL spaces (use `LEFT JOIN` on `SPACE` so spaces with 0 booking hours are represented).
  - Duration calculation must handle fractional hours accurately (`ISNULL(SUM(DATEDIFF(MINUTE, requested_start, requested_end)), 0) / 60.0` cast to `DECIMAL(10, 2)`).
  - Active booking statuses: `'Approved'`, `'Checked In'`, `'Completed'`.
  - Date filtering must constrain requested booking windows within the semester bounds (`b.requested_start >= @SemesterStart AND b.requested_start <= @SemesterEnd`).

### Query 2: Number of approved bookings by weekday and hour for a given semester

### Query 3: Available spaces satisfying required capacity, facility list, and time period (Room Finder)

### Query 4: Approved bookings affected when maintenance is escalated to out-of-service

---

## 4. T-SQL implementation guidelines

1. Use standard Microsoft SQL Server T-SQL syntax (`USE University; GO`).
2. Declare parameters at the top of query sections using explicit T-SQL variables (e.g., `DECLARE @SemesterStart DATETIME = '2024-09-01';`).
3. Use half-open interval overlap predicates consistently:
   ```sql
   existing_start < requested_end AND existing_end > requested_start
   ```
4. Qualify table columns consistently (`dbo.SPACE s`, `dbo.BOOKING b`).
5. Guarantee idempotent execution and clean formatting.
