# Step 11: Concurrency Design

---

## 1. Identified Conflict: Phantom Insert on Booking Approval

**Source:** Phase 2 BRA §1.2 (New operating conditions: concurrent booking and approval).

**Quoted requirement:** *"Because users and staff may perform booking operations concurrently, multiple operations may check the availability of the same space before any of them records its result. Without appropriate concurrency control, conflicting bookings may be approved."* The BRA further requires: *"The system must ensure that two approved bookings cannot use the same space during overlapping time periods, regardless of whether the bookings are created through instant-booking or staff approval."*

**The two approval paths involved:** Step 9 (Decision 3) introduced `BOOKING.approval_path` to distinguish two ways a booking reaches `Approved` status. On the **instant-booking path**, a request for a qualifying space type that satisfies usage policy is approved automatically at submission time, with no staff involvement and effectively no delay between the availability check and the approval being recorded. On the **staff approval path**, a request stays `Pending` until a facility staff member reviews it, leaving a gap between "availability was checked" and "approval is recorded" that can span minutes or hours long, enabling the following situation to occur:

**Phantom-insert:**
1. Session A (either path) queries `BOOKING` for existing rows where `space_code = X` and `booking_status = 'Approved'` with a time range overlapping the new request. No conflicting row is found.
2. Before Session A commits its own approval, Session B performs the identical check for the same space and an overlapping time window. Under default read-committed isolation, Session B's read is not blocked by Session A's uncommitted work. It also finds no conflicting row.
3. Both sessions proceed to approve/insert their respective bookings. Both commit. The space now has two approved, time-overlapping bookings, a direct violation of the Phase 1 baseline rule and the Phase 2 concurrency requirement.

A staff member reviewing a pending request has no way to know, at the moment they check availability, whether an instant-booking request for an overlapping slot on the same space is being submitted at that same moment. Since staff-approved bookings operating window is human-paced, it likely stays open far longer than the instant-booking path's window, resulting in a high probability of collision in practice. The conflict also applies to both paths individually: two long windows of staff-approved bookings can easily overlap, while the possiblity of two instant bookings being requested at the same time always exists.

Therefore, the concurrency design must uniformly prevent collisions for all three pairings (instant/instant, staff/staff, instant/staff), rather than prioritizing the staff path as the only risk.

The concurrency problem described above is a **phantom-insert / check-then-act race**, not a lost-update. The two transactions never touch the same existing row, where each is inserting or updating a *different* `BOOKING` row. Rather, it involves two transactions each acting on a **different** `BOOKING` row that has not yet been inserted, where neither transaction's write is aware of the other row's version.

---

## 2. Candidate Mechanisms Considered

### Option A: Default (Read Committed) Locking
Standard row-level shared locks are released as soon as the availability-check read completes, before the transaction commits its own insert/approval. This is precisely the gap described in Section 1, so this option alone does not close the race window.

**Note on Step 9 (Decision 4) previously proposed addition of `row_version` to `BOOKING`:** the mechanism also only resolves **lost updates**, which does not address the concurrency control requirement.

### Option B: Strict 2-Phase Locking via `SERIALIZABLE` Isolation or `UPDLOCK, HOLDLOCK` Hints
Wrapping the availability-check-then-insert/approve sequence in a single transaction under `SERIALIZABLE` isolation (or applying `WITH (UPDLOCK, HOLDLOCK)` to the availability-check query under a lower isolation level) causes SQL Server to take **range locks**, not just row locks, across the queried time/space key range. A second transaction attempting to check or insert into that same range is blocked until the first transaction commits or rolls back.

This is the standard application of **two-phase locking (2PL)**, specifically *strict* 2PL, which SQL Server implements natively under these isolation settings: locks are acquired during a growing phase and held until commit (the shrinking phase), preventing another transaction from observing or modifying the locked range in between. This addresses the insertion of conflicting row that does not exist yet at the time of the check. 

### Option C: Trigger-Based Prevention
SQL Server has no native range-exclusion constraint (unlike PostgreSQL's `EXCLUDE`). An equivalent effect could be built with an `AFTER INSERT, UPDATE` trigger that re-validates no overlapping approved booking exists for the same space and rolls back the transaction if one is found. This provides a database-enforced backstop independent of application logic, but is harder to reason about and test in isolation (trigger recursion, nested transaction behavior, interaction with the approval workflow's own state transitions), and does not by itself close the check-then-act window if the offending check occurs outside the trigger's transaction. 

---

## 3. Selected Concurrency Control Strategy
Option A: **Rejected**

Option B: **Selected**

Option C: **Rejected as primary mechanism**, worth revisiting in Step 12 as an additional defense layer alongside Option B, but not a substitute for it.

**Decision:**
To address the concurrency problem described in Section 1, the database will adopt a locking strategy via `SERIALIZABLE` transaction isolation (or equivalent `UPDLOCK, HOLDLOCK` table hints). This will be applied to the combined availability-check-and-approve/insert sequence and scoped to the specific `space_code` and requested time range being evaluated.

**Rationale:**
- Directly targets the check-then-act race named in Phase 2 BRA §1.2, for both the instant-booking and staff-approval paths (`BOOKING.approval_path`, Step 9 Decision 3), and for every combination of the two.
- Range-locking behavior specifically closes the phantom-insert gap that ordinary row-level 2PL does not address.
- Applies uniformly regardless of which approval path produced the conflicting attempt, satisfying the BRA's explicit requirement that the rule "remain valid even when multiple users or staff members perform booking and approval operations simultaneously."
- Keeps `row_version` in place, unmodified, as the separate mechanism for its own narrower lost-update scenario. The two mechanisms are complementary, not competing.

**Implementation stage considerations:**
- If `UPDLOCK, HOLDLOCK` is adopted rather than `SERIALIZABLE` transaction isolation, efficient key-range locks are only provided if there is a suitable index on `(space_code, time range)` to lock against. Without one, SQL Server may escalate to a full table/page lock. The booking-conflict index to be tuned later is the same index this concurrency mechanism depends on for correctness, not just performance.
- It is also worth flagging that Strict 2PL with range locks can deadlock when two sessions lock overlapping ranges in different orders. Step 12's stored procedure should include a retry-on-deadlock (`TRY...CATCH` with error 1205) to handle this possibility.


In light of this proposed concurrency control design, the exact transaction/stored-procedure code implementing it is deferred to Step 12, while conflict/prevention demonstration scripts are deferred to Step 13.