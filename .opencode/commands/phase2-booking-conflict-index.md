---
description: Tune the Step 12 booking-conflict check, review the evidence, and revise only its Step 15 section
---

Use the booking-conflict tuning skill in:

`.opencode/skills/15-booking-conflict-index-tuning/SKILL.md`

Use the booking-conflict tuning review skill in:

`.opencode/skills/15-booking-conflict-index-tuning/Review-SKILL.md`

Treat as baseline:

- `req/business-requirement.md`
- `outputs/03-logical-design-G02.md`
- `outputs/05-db-definition-G02.sql`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- Step 14 generator and validation files
- Existing `outputs/15-index-tuning-report-G02.md`
- Existing database indexes
- Relevant reviews under `docs/`

Use `$ARGUMENTS` only as optional instructions.

Run this workflow:

1. Inspect and read all inputs.
2. Extract the real conflict-check SQL from `sp_ApproveBooking`.
3. Validate dataset scale and approved-booking distributions.
4. Inventory existing `BOOKING` indexes.
5. Create or update:
   - `outputs/15-booking-conflict-index-tuning-G02.sql`
   - Only the Booking Conflict Check section of `outputs/15-index-tuning-report-G02.md`
6. Capture baseline plan, logical reads, CPU, elapsed time, and result count when runtime is available.
7. Evaluate candidates and select one nonredundant index.
8. Capture after-index evidence using identical queries, parameters, and data.
9. Verify identical results and unchanged concurrency semantics.
10. Do not modify room-finder or other reporting sections.
11. Do not remove the per-space lock or make correctness depend on the index.
12. Run the review and create:
   - `docs/16-booking-conflict-index-tuning-review-G02.md`
13. Fix blocking, major, and safe minor issues only within this tuning scope, then review again.
14. Stop when ready or when runtime/data limitations require user input.

At the end, report:

- Files updated
- Selected index
- Final verdict
- Runtime or static status
- Observed improvement, if actually measured
- Remaining limitation
