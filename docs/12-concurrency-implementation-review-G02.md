# 1. Review Summary

**Reviewed:** `outputs/12-concurrency-implementation-G02.sql` against the approved Phase 2 requirements, Steps 9-11, and the Phase 1 DDL baseline.

**Runtime execution:** Not performed. `sqlcmd` is installed, but no SQL Server instance was discoverable from this workspace. This is a static review; Step 13 must execute the procedures in a dedicated test database.

**Most important strength:** Both approval and advisory-to-out-of-service escalation serialize on the same `SPACE` row through `UPDLOCK, HOLDLOCK`, acquired after `BEGIN TRANSACTION` and before the availability checks.

**Most important risk:** The access-path policy must be applied at deployment: application identities must not directly update booking approval fields. The repository defines no database roles to enforce that policy in this script.

**Readiness for Step 13:** The protected operations have stable names, parameters, transaction boundaries, and observable errors. Static review finds no blocking or major issue.

# 2. Documents Reviewed

- `req/business-requirement-phase2.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `docs/09-updated-erd-and-logical-design-review-G02.md`
- `docs/10-schema-migration-review-G02.md`

# 3. Implementation Mapping

| Step 11 Decision | Implemented In | Correct? | Evidence | Gap |
| --- | --- | --- | --- | --- |
| Per-space lock | Both procedures | Yes | `SPACE WITH (UPDLOCK, HOLDLOCK)` after `BEGIN TRANSACTION` | None |
| Short transaction | Both procedures | Yes | Lock, validation, state change, and commit occur in one procedure transaction | Procedures reject caller-owned transactions to avoid extending the lock scope |
| Fresh conflict recheck | `dbo.sp_ApproveBooking` | Yes | Approved-booking overlap check occurs after the `SPACE` lock | None |
| Unified approval procedure | `dbo.sp_ApproveBooking` | Yes | `approval_path` determines staff versus instant field validation in one procedure | Deployment permissions remain required |
| Maintenance escalation lock | `dbo.sp_EscalateMaintenanceImpact` | Yes | Same locked `SPACE` resource is held through update, history insert, and affected-booking query | None |
| Consistent lock order | Both procedures | Yes | Preliminary read identifies the key; transactional protected access is `SPACE` then `BOOKING` or `MAINTENANCERECORD` | None |
| Caller-owned deadlock retry | Section 4 notes | Yes | Procedures rethrow errors and do not retry error 1205 | Caller implementation is outside repository scope |

# 4. SQL and Schema Compatibility Check

| Object or Rule | Expected | Actual | Status | Notes |
| --- | --- | --- | --- | --- |
| Space key | `dbo.SPACE(space_code VARCHAR(50))` | Used by both procedures | Pass | Exact Phase 1 name and type |
| Booking attributes | Step 9/10 booking columns and statuses | `booking_id`, `space_code`, requested interval, status, path, decision fields | Pass | Uses only defined values: `Pending`, `Approved`, `Instant`, `Staff` |
| Maintenance attributes | Step 9/10 columns and values | Open statuses, interval, and lowercase impact values | Pass | Uses `Reported`, `In Progress`, `advisory`, `out-of-service` |
| Impact history | `dbo.MAINTENANCE_IMPACT_HISTORY` | Inserted as part of escalation | Pass | Matches Step 9 representation |
| Approval overlap logic | Half-open interval | `existing_start < requested_end AND existing_end > requested_start` | Pass | Excludes the booking being approved and permits adjacency |
| Open-ended maintenance | `completion_time` nullable | `ISNULL(completion_time, '9999-12-31')` | Pass | Treats open maintenance as continuing indefinitely |
| Phase 1 maintenance triggers | Must support Phase 2 advisory and escalation rules | Booking trigger revised; bidirectional maintenance trigger removed | Pass | Step 10 did not reconcile these Phase 1 triggers; Step 12 corrects the blocking inconsistency |

# 5. Issues Found

## Issue R12-1 -- Runtime execution unavailable

- **Severity:** Observation
- **Issue:** No SQL Server instance was discoverable, so the script was not compiled or executed.
- **Evidence:** `sqlcmd` is installed; `sqlcmd -L` returned no server instance.
- **Why this is a problem:** Static review cannot prove deployment permissions, trigger compilation, or runtime error behavior.
- **Downstream impact on Step 13:** Run the Step 12 script in the Step 13 test database before opening the two test sessions.
- **Suggested correction:** Execute the verification queries and the non-concurrent success, conflict, maintenance-block, and rollback cases described by the review skill before or during Step 13 setup.

# 6. Transaction and Locking Walkthrough

1. **Successful approval:** `sp_ApproveBooking` identifies the booking space, starts its transaction, and locks that one `SPACE` row. It rereads the pending booking, validates its path, finds no approved booking or active out-of-service maintenance overlap, updates the decision fields, then commits and releases the lock.
2. **Rejected overlapping approval:** The procedure locks the space before checking approved bookings. The half-open overlap predicate detects the existing approved row, throws error 51012, rolls back, and releases the lock without changing the pending booking.
3. **Approval blocked by out-of-service maintenance:** After the space lock, the procedure checks only open maintenance with `impact_level = 'out-of-service'`. A matching interval throws error 51013. Advisory maintenance does not satisfy that predicate and therefore does not block approval.
4. **Maintenance escalation concurrent with approval:** `sp_EscalateMaintenanceImpact` locks the same `SPACE` row before reading the maintenance record. If approval commits first, escalation obtains the lock afterward and its affected-booking query includes that approval. If escalation runs first, it updates impact and commits; a waiting approval then observes the active out-of-service record and fails. The lock is released only at commit or rollback.

# 7. Step 13 Readiness Examination

1. **Can both sessions call a clearly defined protected operation?** Yes: `dbo.sp_ApproveBooking` and `dbo.sp_EscalateMaintenanceImpact`.
2. **Is the transaction boundary visible and correct?** Yes: each procedure starts its own transaction before its space lock and commits immediately after its protected work.
3. **Is the lock acquired before the protected checks?** Yes.
4. **Are approval and maintenance escalation serialized consistently?** Yes, on the same `dbo.SPACE` row and with the same lock hints.
5. **Can tests distinguish unsafe behavior from protected behavior?** Yes. Tests can contrast direct unsynchronized checks with the procedure calls, without placing timing code in production procedures.
6. **Are expected business-rule errors observable?** Yes: custom errors distinguish missing or ineligible bookings, approved-booking conflict, and out-of-service maintenance conflict.
7. **Are object names stable enough for test scripts?** Yes.
8. **Are there direct-update bypasses that invalidate prevention tests?** No repository workflow SQL directly approves bookings. Privileged direct updates remain a deployment-security risk addressed by the documented permission policy.
9. **Are there unresolved blocking schema mismatches?** No. The Phase 1 trigger behavior conflicting with Phase 2 was explicitly corrected in Step 12.
10. **Would a tester need to modify production SQL before testing?** No.

**Ready elements:** protected approval, protected escalation, half-open conflict checks, consistent per-space locks, trigger alignment with advisory and escalation requirements, and safe rollback/rethrow behavior.

**Blocking gaps:** None.

**Non-blocking improvements:** Apply the documented execute-only permission policy when application identities are introduced, and perform runtime setup checks before the concurrent test cases.

# 8. Scores

| Category | Score |
| --- | --- |
| Completeness | 10/10 |
| Schema Compatibility | 10/10 |
| Transaction Safety | 10/10 |
| Locking Correctness | 10/10 |
| Conflict Detection | 10/10 |
| Maintenance Interaction | 10/10 |
| Workflow Enforcement | 9/10 |
| Step 13 Readiness | 9/10 |

# 9. Required Revisions Before Step 13

No blocking revisions are required before Step 13.

# 10. Final Readiness Verdict

**READY FOR STEP 13**

The script faithfully implements the approved Step 11 per-space strict 2PL protocol, prevents both required approval conflicts, and serializes escalation with approval. Runtime behavior remains to be demonstrated in the Step 13 test database.
