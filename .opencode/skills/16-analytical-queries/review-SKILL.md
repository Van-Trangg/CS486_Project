---
name: analytical-queries-step16-review
description: Review Step 16 analytical query implementations (Queries 1 through 4) against Phase 2 requirements, T-SQL performance guidelines, AGENTS.md §9 criteria, and business logic completeness.
compatibility: opencode
---

# Step 16 — Analytical Queries Review Skill

Use this skill after `outputs/16-analytical-queries-G02.sql` has been generated or updated for any of the four analytical queries.

The purpose of this review is to evaluate whether the implemented analytical queries meet Microsoft SQL Server standards, satisfy Phase 2 requirements, include all 7 required metadata headers, handle edge cases correctly, and produce valid baseline results for Step 15 index tuning.

---

## Review prompt

Examine `outputs/16-analytical-queries-G02.sql` critically for the implemented queries and answer:

> Is the implemented analytical query ready for project integration and Step 15 index tuning without requiring query structure fixes, missing parameter declarations, incorrect status filtering, or invalid overlap logic?

Compare the implementation with:
1. `AGENTS.md` §8.3 and §9 Step 16 rules.
2. The migrated schema (`outputs/10-schema-migration-G02.sql`).
3. `.opencode/skills/16-analytical-queries/SKILL.md`.

---

## Overall Metadata & T-SQL Compliance Checklist (All Queries)

Verify that every implemented query section includes all seven required fields:
- [ ] 1. Business Question
- [ ] 2. Target User
- [ ] 3. Business Value
- [ ] 4. Parameters
- [ ] 5. SQL Statement
- [ ] 6. Correctness Notes
- [ ] 7. Expected Output Meaning

Verify general T-SQL syntax and parameter standards:
- [ ] Uses valid Microsoft SQL Server syntax (`USE University; GO`).
- [ ] Parameterized using explicit T-SQL `DECLARE @...` variables.
- [ ] No hardcoded inline literal filters where parameter variables are expected.

---

## Query-Specific Review Checklists

### Query 1: Total Approved Booking Hours per Space
- [x] **Status:** **Reviewed & Verified**
- [ ] Correctly aggregates total hours per space (`ISNULL(SUM(DATEDIFF(MINUTE, ...)), 0) / 60.0` cast to `DECIMAL(10, 2)`).
- [ ] Filters by semester date parameters (`@SemesterStart` to `@SemesterEnd`).
- [ ] Filters for active approved statuses (`'Approved'`, `'Checked In'`, `'Completed'`).
- [ ] Preserves 0-hour spaces using `LEFT JOIN` on `dbo.SPACE`.
- [ ] Orders results logically (`total_approved_hours DESC, space_code ASC`).

### Query 2: Number of Approved Bookings by Weekday and Hour

### Query 3: Room Finder Query (Capacity, Facilities, Time Period)

### Query 4: Maintenance Escalation Impact Analysis

---

## Verdict Categories

- `READY FOR STEP 15 / STEP 16 PROGRESS`: Implemented queries meet all schema, business, metadata, and T-SQL rules.
- `READY WITH MINOR REVISIONS`: Functionally correct but requires minor formatting or comment adjustments.
- `NOT READY`: Fails correctness logic, omits 0-hour spaces, truncates duration, or lacks required metadata.
