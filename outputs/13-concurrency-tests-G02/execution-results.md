# Step 13 Execution Results

## Environment

- Executed: 2026-08-08
- Tester: OpenCode agent
- Server: `DESKTOP-MJJHKPQ`
- SQL Server: 16.0.1000.6 RTM, Enterprise Evaluation Edition (64-bit)
- Database: `University`
- Client: separate concurrent `sqlcmd` processes for U1, P1, P2, P3, M1, and M2
- Baseline: deployed schema and procedure contracts matched the latest Steps 10 and 12 artifacts

## Observed Results

| Test | Observed result | Invariant result | Verdict |
| --- | --- | --- | --- |
| U1 unsafe | A and B both checked before A committed; both inserted Approved rows with unsafe IDs 1 and 2 | Unsafe overlap count = 1; `UNSAFE_RACE_DEMONSTRATED` | Pass |
| P1 Staff/Staff | A approved booking 105234 and held its transaction; B waited, rechecked, received 51012, and booking 105235 remained Pending | `STAFF_STAFF_HOLDS`; protected overlap count = 0 | Pass |
| P2 Instant/Instant | B's queued real submission created booking 105247 as Instant/Approved; A's competing real submission waited/rechecked and created booking 105248 as Staff/Pending | `INSTANT_INSTANT_HOLDS`; protected overlap count = 0 | Pass |
| P3 Instant/Staff | B's queued real Staff approval approved booking 105260; A's competing real submission waited/rechecked and created booking 105261 as Staff/Pending | `INSTANT_STAFF_HOLDS`; protected overlap count = 0 | Pass |
| M1 approval first | A approved booking 105275 and held its transaction; escalation waited, changed maintenance 3569 to out-of-service, wrote history 954, and returned booking 105275 as affected | `M1_APPROVAL_FIRST_HOLDS`; affected count = 1; protected overlap count = 0 | Pass |
| M2 escalation first | Escalation queued first, changed maintenance 3572 to out-of-service, and wrote history 955; A's real approval waited/rechecked, received 51013, and booking 105286 remained Pending | `M2_ESCALATION_FIRST_HOLDS`; affected count = 0; protected overlap count = 0 | Pass |
| B1 boundaries | Same-space non-overlap, different-space overlap, adjacency, and advisory approval succeeded; equal interval returned 51012; Out-of-Service returned 51013; re-approval returned 51006 | `BOUNDARY_CASES_HOLD`; `ADVISORY_ACK_HOLDS`; protected overlap count = 0 | Pass |

## Evidence Notes

- P2 and P3 use the real `dbo.sp_SubmitBooking`; no Instant/Pending row is staged or persisted.
- M1's procedure result displayed approved booking 105275. The test-only helper independently recorded the same post-commit affected predicate because Step 12 intentionally rejects `INSERT...EXEC` caller transactions.
- Every invariant run reported current-session open transaction count 0.
- The optional sequential M3 control also returned expected error 51013 after escalation.
- Cleanup completed after evidence collection. Verification returned zero `T13-` users, spaces, bookings, and maintenance rows, and NULL object IDs for all three Step 13 helper tables.
- These results prove the executed interleavings and do not claim exhaustive coverage of every scheduler ordering.
