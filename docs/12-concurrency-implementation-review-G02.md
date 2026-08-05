# 1. Review Summary

**Reviewed:** The latest `outputs/12-concurrency-implementation-G02.sql` against the Phase 2 requirements, approved Steps 9-11, the Phase 1 DDL baseline, accepted Step 12 feedback, and relevant downstream review artifacts.

**Runtime execution:** Not performed. SQL Server is reachable, but the script contains `USE University`; executing it while selecting a differently named disposable database would redirect execution. No command was run against the potentially valuable shared database. Compilation, permissions, and non-concurrent procedure behavior remain runtime-unverified.

**Most important strength:** Approval and maintenance escalation use the same transaction-held `UPDLOCK, HOLDLOCK` on the relevant `SPACE` row before their protected checks and state changes. The corrected access policy now prevents normal application-role bypasses for booking approval and maintenance escalation.

**Most important risk:** Runtime deployment and single-session behavior have not been demonstrated in a safe database. Static review cannot prove that grants/denials, ownership chaining, triggers, and rollback behavior execute exactly as intended.

**Readiness for Step 13:** No blocking or major static issue remains. The script is ready for Step 13 after minor verification/documentation work and safe application of Step 12 in the test database.

# 2. Documents Reviewed

- `.opencode/commands/review-phase2-step12.md`
- `.opencode/skills/12-concurrency-implementation/review-SKILL.md`
- `req/business-requirement-phase2.md`
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `docs/09-updated-erd-and-logical-design-review-G02.md`
- `docs/10-schema-migration-review-G02.md`
- `docs/feedback_step12.md`
- `docs/13-concurrency-tests-review-G02.md`

# 3. Implementation Mapping

| Step 11 Decision | Implemented In | Correct? | Evidence | Gap |
| --- | --- | --- | --- | --- |
| Per-space lock | Both procedures | Yes | `dbo.SPACE WITH (UPDLOCK, HOLDLOCK)` after `BEGIN TRANSACTION` | Runtime lock behavior belongs to Step 13 |
| Short transaction | Both procedures | Yes | Protected reads, validation, state change, result, and commit occur in procedure-owned transactions | None statically |
| Fresh conflict recheck | `dbo.sp_ApproveBooking` | Yes | Approved overlap query runs after the space lock | None |
| Unified approval procedure | `dbo.sp_ApproveBooking` | Yes | Staff and Instant paths share one procedure; direct approval-field updates are denied | Permission result unverified at runtime |
| Maintenance escalation lock | `dbo.sp_EscalateMaintenanceImpact` | Yes | Same space lock covers validation, impact update, history insert, and affected-booking query | Permission result unverified at runtime |
| Consistent lock order | Both procedures | Yes | Preliminary target lookup, then protected `SPACE`, then booking or maintenance access | Changed space keys are detected after locking |
| Caller-owned deadlock retry | Both procedures and notes | Yes | Procedures rethrow errors, including 1205; no internal retry loop exists | Caller retry remains outside Step 12 |

# 4. SQL and Schema Compatibility Check

| Object or Rule | Expected | Actual | Status | Notes |
| --- | --- | --- | --- | --- |
| Space key | `dbo.SPACE(space_code VARCHAR(50))` | Exact object, column, and type mapping | Pass | One row is locked by PK |
| Booking key/FK | `booking_id INT`, `space_code VARCHAR(50)` | Exact mapping | Pass | Current booking excluded by ID |
| Booking interval | `requested_start`, `requested_end` | Exact columns with `DATETIME` variables | Pass | Half-open overlap logic |
| Booking status | `Pending`, `Approved` | Exact schema literals | Pass | Finalized bookings cannot be reapproved |
| Approval path | `Instant`, `Staff` | Exact schema literals | Pass | Path-specific approver validation |
| Space status | Retired/closed spaces rejected | Checked while holding the space lock | Pass | Resolves accepted feedback item 1 |
| Maintenance table | `dbo.MAINTENANCERECORD` | Exact physical schema name | Pass | Generic command wording correctly resolves to baseline name |
| Maintenance impact | `advisory`, `out-of-service` | Exact lowercase literals | Pass | Advisory does not block approval |
| Open maintenance | `Reported`, `In Progress`; nullable completion | Correct status and period predicates | Pass | NULL completion treated as open-ended |
| Impact history | Step 10 history structure | Exact insert columns and values | Pass | Same transaction as escalation |
| Booking bypass policy | Deny direct updates to protected approval fields | Valid column-level `DENY UPDATE (...) ON OBJECT::...` | Pass statically | Resolves accepted feedback item 2 |
| Escalation bypass policy | Deny direct impact update/history insertion | Both denials are present | Pass statically | Procedure execution remains granted |
| Rerun safety | Re-applicable object/security definitions | Role guarded; trigger/procedures use create-or-alter; grants/denials are repeatable | Pass statically | Trigger drop is idempotent |

# 5. Issues Found

## Issue R12-1 - Runtime deployment and non-concurrent checks remain unverified

- **Severity:** Observation
- **Issue:** The corrected script has not been compiled or exercised in a safely isolated database during this review.
- **Evidence:** `outputs/12-concurrency-implementation-G02.sql:16` contains `USE University`, so an externally selected disposable database would not contain execution there.
- **Why this is a problem:** Static review cannot prove role permissions, stored-procedure ownership chaining, trigger compilation, business error results, or rollback state.
- **Downstream impact on Step 13:** Step 13 setup must apply Step 12 successfully and run the required single-session cases before opening the concurrent test sessions.
- **Suggested correction:** Execute the script only in an explicitly disposable database context, then verify object creation, denials/grants, successful approval, overlap rejection, maintenance-block rejection, and rollback.

## Issue R12-2 - Error number 51014 is reused

- **Severity:** Minor
- **Issue:** Error 51014 represents both a retired/temporarily closed booking space and missing maintenance-escalation parameters.
- **Evidence:** `outputs/12-concurrency-implementation-G02.sql:180-183` and `:320-321`.
- **Why this is a problem:** Callers or Step 13 assertions that classify failures by number cannot distinguish these unrelated validation failures without parsing message text.
- **Downstream impact on Step 13:** The existing main conflict tests use other error numbers, so this does not block concurrency testing; boundary-result reporting is less precise.
- **Suggested correction:** Assign a unique error number to the closed-space rejection or the maintenance parameter validation.

## Issue R12-3 - Access-policy verification output is incomplete

- **Severity:** Minor
- **Issue:** The final verification queries report procedures and the booking trigger but do not report `AppServiceRole` grants and denials.
- **Evidence:** `outputs/12-concurrency-implementation-G02.sql:469-483` queries `sys.procedures` and `sys.triggers` only.
- **Why this is a problem:** The access policy is correctness-sensitive, and deployment output does not independently show that the two execute grants and three denials were installed.
- **Downstream impact on Step 13:** Test setup must inspect permissions separately before claiming that application-role bypasses are closed.
- **Suggested correction:** Add a schema-permission verification query over `sys.database_permissions`, `sys.database_principals`, `sys.objects`, and `sys.columns`.

# 6. Transaction and Locking Walkthrough

1. **Successful approval:** The procedure identifies the booking's space, starts its own transaction, and locks that `SPACE` row with `UPDLOCK, HOLDLOCK`. It reads `current_status`, rereads the booking, validates the path and approver, checks approved overlaps and active out-of-service maintenance, updates the decision fields, and commits. Commit releases the lock.
2. **Rejected overlapping approval:** After acquiring the space lock, the half-open predicate detects an existing approved same-space row. Error 51012 is thrown, `CATCH` rolls back, and the pending booking remains unchanged.
3. **Approval blocked by out-of-service maintenance:** While holding the same lock, approval detects an overlapping open maintenance row with `impact_level = 'out-of-service'`. Error 51013 causes rollback. Advisory maintenance does not satisfy this predicate.
4. **Maintenance escalation concurrent with approval:** Escalation locks the same `SPACE` row before rereading the open advisory. Approval-first ordering causes escalation to see and return the committed approved booking. Escalation-first ordering causes the later approval to see out-of-service maintenance and fail. Impact update, history insertion, affected-booking query, and commit all occur while the lock is retained.

# 7. Step 13 Readiness Examination

1. **Can both sessions call a clearly defined protected operation?** Yes: `dbo.sp_ApproveBooking` and `dbo.sp_EscalateMaintenanceImpact`.
2. **Is the transaction boundary visible and correct?** Yes.
3. **Is the lock acquired before the protected checks?** Yes.
4. **Are approval and maintenance escalation serialized consistently?** Yes, on the same `SPACE` row.
5. **Can tests distinguish unsafe behavior from protected behavior?** Yes.
6. **Are expected business-rule errors observable?** Yes; duplicate 51014 usage is a minor boundary-case ambiguity.
7. **Are object names stable enough for test scripts?** Yes.
8. **Are there direct-update bypasses that invalidate prevention tests?** No normal `AppServiceRole` bypass remains statically: protected booking fields, maintenance impact, and history insertion are denied.
9. **Are there unresolved blocking schema mismatches?** No.
10. **Would a tester need to modify production SQL before testing?** No. Safe deployment and permission verification are still required.

**Ready elements:** Correct transaction boundaries, shared per-space lock protocol, complete half-open overlap checks, explicit space-status check, advisory/out-of-service distinction, atomic escalation/history/result behavior, corrected booking permission syntax, escalation bypass denials, and stable procedure contracts.

**Blocking gaps:** None.

**Non-blocking improvements:** Use unique error numbers, add permission catalog verification, and record safe runtime results.

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

Before concurrent sessions are used as evidence, apply Step 12 in a safe disposable database and verify its compilation, procedure existence, application-role grants/denials, one successful approval, one overlap rejection, one maintenance-block rejection, and rollback behavior. Unique error numbering and catalog-based permission output are minor recommended revisions.

# 10. Final Readiness Verdict

**READY FOR STEP 13 WITH MINOR REVISIONS**

The latest script resolves the prior blocking permission syntax and maintenance bypass findings. Its procedure bodies faithfully implement the approved Step 11 strict-2PL design, and no blocking or major static issue remains. Runtime deployment evidence, unique error numbering, and explicit permission verification are still recommended before Step 13 results are treated as observed proof.
