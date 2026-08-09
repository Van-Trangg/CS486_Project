# Step 13 Execution Results

## Environment

- Executed: 2026-08-09
- Tester: OpenCode agent
- Server: `DESKTOP-MJJHKPQ`
- SQL Server: 16.0.1000.6, Enterprise Evaluation Edition (64-bit)
- Baseline source: `Step14ReviewG02_20260805`, verified to contain the current `sp_SubmitBooking`, `sp_ApproveBooking`, `sp_EscalateMaintenanceImpact`, and both immutable audit triggers
- Scenario databases: fresh normal restores named `Step13G02_U1`, `Step13G02_P1`, `Step13G02_P2`, `Step13G02_P3`, `Step13G02_M1`, `Step13G02_M2`, and `Step13G02_B1`
- Isolation: every concurrent worker explicitly used `READ COMMITTED`; setup recorded `READ_COMMITTED_SNAPSHOT = OFF` and snapshot isolation `OFF`
- Baseline guard: every setup verified the migrated columns, protected procedure signatures, `UPDLOCK`/`HOLDLOCK` definitions, enabled immutable triggers, and absence of production `WAITFOR`
- Client: twelve separate concurrent `sqlcmd` processes produced the retained final U1, P1, P2, P3, M1, and M2 evidence without a SQLCMD error
- Cleanup: all seven databases were dropped through `09-cleanup-test-data.sql`; final remaining `Step13G02_*` database count was `0`
- Negative safety test: cleanup rejected `DatabaseName=University` with error `52090`

The source database was backed up with `COPY_ONLY`, `CHECKSUM`, and `COMPRESSION`; `RESTORE VERIFYONLY` passed. Each scenario used a fresh normal restore, not a reused row-level test state. An initial M1 Session B launch encountered a client login timeout while all scenarios were started together; that attempt was discarded, `Step13G02_M1` was recreated from the verified backup, and the retained M1 evidence is from a successful isolated two-session rerun.

## Observed Results

| Test | Observed result | Invariant result | Verdict |
| --- | --- | --- | --- |
| U1 unsafe | A checked at `13:57:36.7870816`; B checked at `13:57:36.8901548` before A committed; both inserted Approved helper rows | Unsafe overlap count `1`; `UNSAFE_RACE_DEMONSTRATED` | Pass |
| P1 Staff/Staff | A approved and held the transaction; B called the real procedure while A was uncommitted, then received `51012` after A committed | `STAFF_STAFF_HOLDS`; Approved `1`, Pending `1`; protected overlap count `0` | Pass |
| P2 Instant/Instant | B's queued real submission created booking `105010` as Instant/Approved; A's real submission rechecked and created booking `105011` as Staff/Pending | `INSTANT_INSTANT_HOLDS`; protected overlap count `0` | Pass |
| P3 Instant/Staff | B's queued real Staff approval approved booking `105010`; A's real submission rechecked and created booking `105011` as Staff/Pending | `INSTANT_STAFF_HOLDS`; protected overlap count `0` | Pass |
| M1 approval first | A approved booking `105001` and held its transaction; B waited, escalated, and the actual procedure result between markers returned booking `105001` | `M1_APPROVAL_FIRST_HOLDS`; affected count `1`; transition count `1`; protected overlap count `0` | Pass |
| M2 escalation first | B queued and escalated first; its marked procedure result contained no booking row; A then rechecked and received `51013` | `M2_ESCALATION_FIRST_HOLDS`; affected count `0`; transition count `1`; protected overlap count `0` | Pass |
| B1 boundaries | Same-space non-overlap, different-space overlap, adjacency, and advisory approval succeeded; equal interval returned `51012`; Out-of-Service returned `51013`; re-approval returned `51006` | `BOUNDARY_CASES_HOLD`; `ADVISORY_ACK_HOLDS`; protected overlap count `0` | Pass |

## Evidence Index

- U1: `runtime-evidence/U1-session-a.txt`, `U1-session-b.txt`, `U1-invariants.txt`, `U1-reset.txt`, `U1-post-reset-invariants.txt`, `U1-cleanup.txt`
- P1: `runtime-evidence/P1-session-a.txt`, `P1-session-b.txt`, `P1-invariants.txt`, `P1-cleanup.txt`
- P2: `runtime-evidence/P2-session-a.txt`, `P2-session-b.txt`, `P2-invariants.txt`, `P2-cleanup.txt`
- P3: `runtime-evidence/P3-session-a.txt`, `P3-session-b.txt`, `P3-invariants.txt`, `P3-cleanup.txt`
- M1: `runtime-evidence/M1-session-a.txt`, `M1-session-b.txt`, `M1-invariants.txt`, `M1-cleanup.txt`
- M2: `runtime-evidence/M2-session-a.txt`, `M2-session-b.txt`, `M2-invariants.txt`, `M2-cleanup.txt`
- B1: `runtime-evidence/B1-results.txt`, `B1-invariants.txt`, `B1-cleanup.txt`
- Setup/configuration evidence: corresponding `*-setup.txt` and `P1-config.txt`, `P2-config.txt`, `P3-config.txt`
- Cleanup guard: `runtime-evidence/cleanup-guard-negative.txt`
- Cleanup final count: `runtime-evidence/cleanup-final-count.txt`

## Evidence Notes

- U1 was reset after evidence collection; the post-reset unsafe overlap count was `0`.
- Every retained concurrent worker output reported `worker_open_transaction_count = 0`; every separate invariant session also reported `current_open_transaction_count = 0`.
- M1/M2 procedure-result markers distinguish the real Step 12 result set from the separate durable helper assertion.
- All maintenance invariants required exactly one matching advisory-to-out-of-service history transition.
- The run proves the recorded interleavings and final states; it does not claim exhaustive scheduler coverage.
