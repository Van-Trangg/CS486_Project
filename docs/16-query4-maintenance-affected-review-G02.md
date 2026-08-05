# 1. Review Summary

Query 4 in `outputs/16-analytical-queries-G02.sql` is ready for Step 16 integration. It selects a maintenance record by `maintenance_id`, requires both its current `out-of-service` impact and an `advisory` to `out-of-service` history event, and returns only same-space, currently `Approved` bookings with a half-open interval overlap.

The shared analytical-query file was empty before this change; therefore, no Query 1-3 content was overwritten. Query 4 contains no index creation and does not modify Step 12 procedures.

Runtime execution occurred on `localhost`, database `University`, using the generated 105,000-booking dataset. Maintenance ID `18` returned zero rows, matching an independent expected-count query. The generated dataset intentionally prevents approved bookings from overlapping out-of-service maintenance, so the positive affected-booking scenarios remain prepared but unexecuted.

# 2. Documents Reviewed

- `req/business-requirement.md`
- `req/business-requirement-phase2.md`
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/08-requirement-change-analysis-G02.md`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `outputs/13-concurrency-tests-G02/00-setup-test-data.sql`
- `outputs/13-concurrency-tests-G02/12-maintenance-affected-booking.sql`
- `outputs/14-data-generator-G02/01-generate-data.sql`
- `outputs/14-data-generator-G02/02-validate-data.sql`
- `outputs/16-analytical-queries-G02.sql`
- Relevant Phase 2 reviews under `docs/`
- `.opencode/skills/16-analytical-queries/4-SKILL.md`
- `.opencode/skills/16-analytical-queries/4-Review-SKILL.md`

# 3. Requirement and Schema Mapping

| Requirement Element | Expected Schema Support | Query Evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| Selected maintenance record | `dbo.MAINTENANCERECORD.maintenance_id INT` | `@maintenance_id INT` filters `m.maintenance_id` | Pass | The caller supplies one maintenance ID. |
| Confirmed escalation | Current `impact_level` plus `dbo.MAINTENANCE_IMPACT_HISTORY` event | Checks current `'out-of-service'` and `old_impact_level = 'advisory'`, `new_impact_level = 'out-of-service'` | Pass | `CROSS APPLY TOP (1)` returns the latest event without duplicating bookings. |
| Same space | `MAINTENANCERECORD.space_code`, `BOOKING.space_code` | `b.space_code = tm.space_code` | Pass | Both columns are `VARCHAR(50)` foreign-key values. |
| Approved bookings only | `BOOKING.booking_status` includes `Approved` | `b.booking_status = 'Approved'` | Pass | Uses exact schema literal, not completed or checked-in statuses. |
| Maintenance period | `start_time DATETIME`, nullable `completion_time DATETIME` | Half-open predicate with `ISNULL(completion_time, '9999-12-31')` | Pass | Matches Step 12 open-ended maintenance treatment. |
| Requester contact data | `BOOKING.requester_id` to `USER.user_id` | Joins `dbo.[USER]` and returns name, email, and phone | Pass | Supports staff follow-up. |
| Useful result context | Maintenance, space, booking, requester columns | Explicit selected columns | Pass | No `SELECT *`. |

# 4. Result-Correctness Walkthrough

1. The precondition rejects an absent, advisory-only, downgraded, or never-escalated maintenance ID with error 51030.
2. `TargetMaintenance` selects exactly one current out-of-service maintenance record and its latest qualifying escalation event.
3. The `BOOKING` join requires the same `space_code`, exact `Approved` status, and both half-open overlap conditions: `requested_start < completion_time` and `requested_end > start_time`.
4. Adjacent intervals fail one of those predicates and are excluded. Contained, containing, and partial overlaps satisfy both predicates and are included.
5. No acknowledgement or raw history join can multiply a booking. `CROSS APPLY TOP (1)` selects at most one history event for the selected maintenance record.

# 5. Functional Test Coverage

| Test Case | Prepared? | Executed? | Expected | Actual | Status |
| --- | --- | --- | --- | --- | --- |
| Generated-data qualifying escalation with no affected booking (`maintenance_id = 18`) | Yes | Yes | Zero rows | Zero rows; independent count = 0 | Pass |
| Multiple affected approved bookings | Yes | No | One row per affected booking | Not executed | Prepared |
| Advisory-only maintenance | Yes | No | Error 51030 | Not executed | Prepared |
| Overlap on another space | Yes | No | Excluded | Not executed | Prepared |
| Booking ends at maintenance start | Yes | No | Excluded | Not executed | Prepared |
| Booking begins at maintenance completion | Yes | No | Excluded | Not executed | Prepared |
| Booking fully inside maintenance | Yes | No | Included | Not executed | Prepared |
| Maintenance fully inside booking | Yes | No | Included | Not executed | Prepared |
| Open-ended maintenance | Yes | No | Later approved same-space booking included | Not executed | Prepared |
| Multiple history or acknowledgement rows | Yes | No | No duplicate booking IDs | Not executed | Prepared |

The isolated Step 13 M2 case can execute a positive affected-booking test without weakening production controls. It must be run separately because it adds dedicated `T13-` test data.

# 6. Issues Found

No blocking, major, minor, or observation issues were found.

# 7. Scores

| Category | Score |
| --- | --- |
| Integration Safety | 10/10 |
| Schema Compatibility | 10/10 |
| Requirement Correctness | 10/10 |
| Interval Correctness | 10/10 |
| Result Usefulness | 10/10 |
| Duplicate Control | 10/10 |
| Test Coverage | 9/10 |
| Step 16 Readiness | 10/10 |

# 8. Required Revisions

None.

# 9. Final Verdict

**QUERY 4 READY FOR INTEGRATION**

Runtime execution occurred for one qualifying generated-data case and matched the independently calculated result. Positive and boundary cases are prepared but require execution with isolated test data before being cited as observed functional-test evidence.
