## 1. `sp_ApproveBooking` never checks `SPACE.current_status` itself

It re-checks booking overlap (error 51012) and out-of-service maintenance overlap (error 51013) explicitly after taking the lock — but it never checks whether the space itself is Retired or Temporarily Closed. That condition only gets caught by the backstop trigger (TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE) when the UPDATE fires, which means:

- A retired/closed space produces a generic trigger error (51001) instead of a purpose-built one like the other two checks get.
- The procedure is relying on the trigger — which Step 11 explicitly scoped as a secondary backstop — to enforce a primary business rule.

Fix: pull `current_status` alongside the other SPACE fields when you take the lock, and throw a dedicated error (e.g. 51013b / renumber) if it's Retired or Temporarily Closed, symmetric with the other two checks. Keep the trigger as-is as the backstop.

## 2. Section 4's permission policy is documented, not enforced

The comment block says application/workflow identities must not have `UPDATE` on `BOOKING.booking_status` etc. and must go through the procedure. Right now nothing stops a direct UPDATE BOOKING SET booking_status = 'Approved' from running. Since Step 12 is "implementation," this should be actual T-SQL:

```sql
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'AppServiceRole' AND type = 'R')
    CREATE ROLE AppServiceRole;
GO

DENY UPDATE ON dbo.BOOKING (booking_status, approver_id, decision_time, decision_note) TO AppServiceRole;
GRANT EXECUTE ON dbo.sp_ApproveBooking TO AppServiceRole;
GRANT EXECUTE ON dbo.sp_EscalateMaintenanceImpact TO AppServiceRole;
GO
```
