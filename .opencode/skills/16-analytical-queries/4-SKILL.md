---
name: analytical-query4-maintenance-affected
description: Implement Query 4 for approved bookings affected when maintenance is escalated to Out-of-Service, without overwriting the other analytical queries.
compatibility: opencode
---

# Query 4 — Approved Bookings Affected by Maintenance Escalation

Use this skill to implement the Phase 2 report:

> Approved bookings affected when a maintenance record is escalated to `Out-of-Service`.

This belongs to Step 16. It is a functional analytical query, not the booking-conflict index-tuning task.

## Required output

Create or update:

`outputs/16-analytical-queries-G02.sql`

Update only the clearly marked Query 4 section. Preserve Query 1, Query 2, Query 3, comments, and work owned by other members.

If the shared file does not exist, create it with a clearly marked Query 4 section and placeholders stating that the other queries belong to other members. Do not invent their SQL.

---

## 1. Inspect the project first

1. Run `ls -la`.
2. Locate and read fully:
   - `req/business-requirement.md`
   - `outputs/03-logical-design-G02.md`
   - `outputs/05-db-definition-G02.sql`
   - `outputs/09-updated-erd-and-logical-design-G02.md`
   - `outputs/10-schema-migration-G02.sql`
   - `outputs/11-concurrency-design-G02.md`
   - `outputs/12-concurrency-implementation-G02.sql`
   - `outputs/14-data-generator-G02/01-generate-data.sql`
   - `outputs/14-data-generator-G02/02-validate-data.sql`
   - Existing `outputs/16-analytical-queries-G02.sql`
3. Read relevant review files under `docs/`.
4. Verify the actual SQL Server table, column, status, and key names.
5. Confirm how the schema represents:
   - Maintenance identity and related space
   - Impact level
   - Maintenance start and completion/end time
   - Open maintenance
   - Escalation time or impact-level history, if any
   - Booking requester and contact details

Do not assume escalation history exists. If the schema only stores the current impact level, state that the query finds bookings affected by a maintenance record currently marked `Out-of-Service`, not a historically proven escalation event.

---

## 2. Business meaning

The query must help Facility Staff or the Facility Manager identify requesters who may need to be contacted after maintenance changes from `Advisory` to `Out-of-Service`.

A booking is affected only when:

1. It belongs to the same space as the selected maintenance record.
2. Its status is `Approved`.
3. Its requested interval overlaps the maintenance interval.
4. The maintenance record is confirmed as `Out-of-Service` according to the approved schema.
5. The result does not duplicate the booking.

Use the half-open overlap rule:

```sql
booking_start < maintenance_end
AND booking_end > maintenance_start
```

Adjacent intervals do not overlap.

For open-ended maintenance, use the approved project rule. Do not invent an end date silently.

---

## 3. Required parameter

Prefer a maintenance-record identifier such as:

```sql
@maintenance_id
```

Use the actual identifier and data type from the migrated schema.

Derive the related space and maintenance interval from that record. Do not require callers to repeat stored values.

When escalation events are stored separately, target the relevant escalation event using the approved relationship.

---

## 4. Required result columns

Return useful columns where supported:

- Maintenance ID and impact level
- Maintenance start and end/completion time
- Space ID/code and name
- Booking ID
- Booking requested start and end
- Booking status and approval path
- Requester ID, name, email, and phone
- Purpose and expected participants
- Optional overlap start, overlap end, and overlap duration

Do not fabricate unavailable fields. Use clear aliases.

Return one row per affected booking unless the approved schema explicitly requires one row per booking-escalation event.

---

## 5. Required Query 4 section

The section must contain:

```sql
/* ============================================================
   QUERY 4: APPROVED BOOKINGS AFFECTED BY MAINTENANCE ESCALATION
   ============================================================ */

-- Business Question
-- Target User(s)
-- Business Value
-- Related Requirement(s)
-- Parameters
-- Schema Assumptions or Limitations
-- SQL Statement
-- Expected Behavior
-- Functional Test Cases
```

### Business Question

Use wording equivalent to:

> Which approved bookings overlap the period of a selected maintenance record that has been escalated to Out-of-Service?

### Target users

- Facility Staff
- Facility Manager

### Business value

Explain that the result supports contact, relocation, cancellation, or follow-up for affected requesters.

---

## 6. SQL requirements

The SQL must:

- Target Microsoft SQL Server.
- Use schema-qualified actual object names.
- Use a declared test parameter or executable procedure-style parameter.
- Filter the exact approved status.
- Match the same space.
- Use the correct overlap predicate.
- Avoid `BETWEEN` for interval overlap.
- Avoid duplicate rows from unnecessary joins.
- Avoid `SELECT *`.
- Handle open-ended maintenance according to the approved design.
- Return zero rows, or a clearly documented error, when the record is missing or not Out-of-Service.
- Avoid creating indexes.
- Avoid modifying Step 12 procedures.

A standalone parameterized query is sufficient unless the project explicitly requires a stored procedure.

---

## 7. Functional tests

Prepare or execute cases for:

1. Out-of-service maintenance with multiple affected approved bookings.
2. Out-of-service maintenance with no affected booking.
3. Advisory maintenance not escalated.
4. Booking on another space.
5. Booking ending exactly when maintenance begins.
6. Booking beginning exactly when maintenance ends.
7. Booking fully inside maintenance.
8. Maintenance fully inside the booking.
9. Open-ended maintenance, if supported.
10. Duplicate prevention when multiple related rows exist.

Do not claim tests passed unless they were executed.

---

## 8. Integration safety

- Locate existing Query 4 markers.
- Replace only that section.
- Preserve other members’ SQL and formatting.
- Append a clearly marked Query 4 section if none exists.
- Report merge ambiguity instead of guessing.

---

## 9. Self-review checklist

Confirm that:

- The query uses the migrated schema.
- It targets a selected maintenance record.
- It confirms Out-of-Service impact.
- It filters only approved bookings.
- Same-space matching is present.
- Overlap logic is correct.
- Adjacent intervals are excluded.
- Open-ended maintenance is handled consistently.
- Contact information is returned when available.
- No booking is duplicated.
- Query 1–3 content was preserved.
- No index tuning was performed.
- Test results were not fabricated.

---

## 10. Final response behavior

After generation:

1. State that Query 4 in `outputs/16-analytical-queries-G02.sql` was created or updated.
2. State the tables and columns used.
3. State any limitation related to escalation history.
4. State whether tests were executed or only prepared.
5. Do not proceed to index tuning automatically.
