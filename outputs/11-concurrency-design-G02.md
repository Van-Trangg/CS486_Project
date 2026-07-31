# Step 11: Concurrency Design

---

## 1. Identified Conflict: Phantom Insert on Booking Approval

**Source:** Phase 2 BRA §1.2 (New operating conditions: concurrent booking and approval).

**Quoted requirement:** *"Because users and staff may perform booking operations concurrently, multiple operations may check the availability of the same space before any of them records its result. Without appropriate concurrency control, conflicting bookings may be approved."* The BRA further requires: *"The system must ensure that two approved bookings cannot use the same space during overlapping time periods, regardless of whether the bookings are created through instant-booking or staff approval."*

**The two approval paths involved:** Step 9 (Decision 3) introduced `BOOKING.approval_path` to distinguish an **instant-booking path** (approved automatically at submission, no staff involvement) from a **staff approval path** (request stays `Pending` until a staff member decides). Both paths can produce the same race:

1. Session A queries `BOOKING` for existing `Approved` rows on `space_code = X` overlapping the new request's time range. No conflict found.
2. Before Session A commits, Session B performs the identical check for the same space and an overlapping window. Under read-committed isolation, Session B is not blocked by Session A's uncommitted work and also finds no conflict.
3. Both sessions approve/insert. Both commit. The space now has two approved, overlapping bookings, a violation of the Phase 1 baseline rule and the Phase 2 concurrency requirement.

This is a **phantom-insert / check-then-act race**, not a lost-update: the two transactions each act on a *different*, not-yet-inserted `BOOKING` row, so no shared row's version is ever compared.

**The gap exists for all three pairings:** instant/instant, staff/staff, and instant/staff, regardless of how long the gap between check and decision happens to be in practice. The design below must close it uniformly rather than treating the staff path as a special case.

**The concurrency problem lives at the moment of approval, not the moment of review.** A staff member can look at availability at any point while a request sits `Pending`, which is unrelated to the transaction the race takes place. What matters is the check performed the instant the booking is actually approved (see Section 4).

---

## 2. Candidate Mechanisms Considered

### Option A: Default (Read Committed) Locking (Rejected)
Row-level shared locks are released as soon as the availability-check read completes, before the transaction's own insert/approval commits. This does not address the main concurrency problem of to-be-inserted rows.

*Note:* Step 9 (Decision 4)'s `row_version` on `BOOKING` addresses lost updates, not phantom-insert conflicts.

### Option B: Per-Space Update Locking (Strict 2PL) (Selected)
Lock the **space**, not a time range: any operation that could result in an approved booking for a given `space_code` must acquire a transaction-held update lock on the corresponding `SPACE` row (`WITH (UPDLOCK, HOLDLOCK)`) before re-checking overlap and recording its own result. Only one transaction can hold a U lock on a given resource at a time, so a second session is forced to wait. `HOLDLOCK` keeps that lock held for the duration of the transaction rather than releasing it as soon as the read completes.

Every approval attempt for the same space is serialized against every other attempt for that space, regardless of approval path; a second session waits until the first commits or rolls back, then performs its own fresh check. Approvals for different spaces run concurrently, unaffected.

This is standard strict 2PL: lock acquired in the growing phase, held to commit. It is simple to reason about and test because correctness depends only on the lock, not on how the overlap predicate is written or indexed.

### Option C: Trigger-Based Prevention (Rejected as primary, worth revisiting as a backstop)
SQL Server has no native range-exclusion constraint. An `AFTER INSERT, UPDATE` trigger that re-validates and rolls back on conflict is a possible additional defense layer, but harder to reason about in isolation (trigger recursion, nested transactions) and doesn't by itself close the check-then-act window.

---

## 3. Selected Concurrency Control Strategy

**Decision:** Every operation that can result in an approved booking (instant approval, staff approval, or any future administrative approval) acquires a per-space update lock, then re-checks overlap, then records its result, all inside one short transaction (Section 4). The same per-space lock is also acquired by maintenance escalation to `Out-of-Service` (Section 5), so the two kinds of operations are serialized against each other as well as against themselves.

**Rationale:**
- Directly closes the check-then-act race for all three pairings, uniformly, because the lock is keyed to the space, not to a specific query shape.
- Correctness comes from the lock and the fresh recheck it guards.
- `row_version` stays in place unmodified for its own, separate lost-update scenario; the two mechanisms are complementary.

---

## 4. Locking Scope and Approval Workflow

The lock-and-recheck sequence in Section 3 is enforced through a single stored procedure, `sp_ApproveBooking`, which is the only path by which a booking may reach `Approved` status. Instant approval at submission, facility-staff approval, facility-manager approval, and any future administrative approval path all call this same procedure. Application and workflow accounts must not have permission to approve a booking through a direct table update, they must execute `sp_ApproveBooking`. Any path that bypasses the procedure also bypasses the locking design in Section 3.

This gives the design a clean boundary between the human workflow and the transactional one. A staff member may look at a space's availability at any point while a request sits `Pending`; that look is advisory and holds no lock. The transaction that matters is the one `sp_ApproveBooking` opens at the moment approval is actually recorded: acquire the space lock, recheck for conflicts, and commit. Keeping that transaction short and separate from the (arbitrarily long) human review period keeps the locking design in Section 3 correct without ever holding a lock across a review that could take minutes or hours.

Error handling follows from the same boundary: `sp_ApproveBooking` rolls back and surfaces a deadlock (error 1205) rather than retrying internally, so the transaction it owns stays short. Retrying the operation, as a whole, after a short delay, is left to the caller. This keeps retry policy separate from the locking mechanism and avoids masking repeated deadlocks inside the procedure.

The procedure's exact body, the overlap predicate, and error-handling code are implemented in Step 12.

---

## 5. Interaction with Maintenance Escalation

A second race exists between booking approval and maintenance escalation, distinct from the phantom-insert race in Section 1 but closed by the same mechanism:

1. Session A (approval) locks/checks the space and is about to approve a booking.
2. Session B (maintenance escalation) raises the space's maintenance impact level from `Advisory` to `Out-of-Service`.
3. Session B does not see Session A's booking, since A has not yet committed.
4. Session A commits its approval, unaware that the space has just been marked `Out-of-Service`. Because the booking was approved after Session B had already built its affected-bookings list, it never gets flagged as affected.

**Decision:** Any operation that escalates a space's maintenance impact level to `Out-of-Service` must acquire the same per-space update lock (Section 3) before changing the impact level and identifying affected bookings. This serializes maintenance escalation with booking approval on a given space:
- If approval runs first, escalation waits, then sees the newly approved booking and includes it in the affected bookings list.
- If escalation runs first, approval waits, then sees the `Out-of-Service` status and does not approve.

Because both operation types lock the same `SPACE` row, no second locking scheme is needed. The per-space lock now serializes every operation that reads or write a space's booking/availability state, not only approvals against each other.

---

The procedure(s) implementing this locking discipline, the overlap predicate, and error-handling code are implemented in Step 12. The demonstration scripts and two-session test cases proving this design closes both races are implemented in Step 13.