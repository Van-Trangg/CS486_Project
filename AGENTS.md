# AGENTS.md — CS486 Campus Space Management System

This repository contains a Microsoft SQL Server database-design project for the CS486 Campus Space Management System.

Phase 1 establishes the approved baseline design. Phase 2 extends that baseline with maintenance impact levels, advisory acknowledgements, concurrent booking and approval, large-scale sample data, analytical queries, index tuning, and normalization validation.

## 1. Repository inspection

Before doing any work:

1. Run `ls -la` at the repository root.
2. Inspect relevant folders such as `req/`, `outputs/`, `docs/`, `templates/`, and `.opencode/skills/`.
3. Read all input files required for the current step before editing an output.
4. Do not assume a file is absent until it has been searched for.
5. Do not overwrite an approved Phase 1 artifact unless the user explicitly asks for a Phase 1 correction.

## 2. Sources of truth

Use this priority order when sources conflict:

1. The Phase 2 requirement document for new or changed requirements.
2. Approved Phase 1 outputs for unchanged requirements and the existing design baseline.
3. Review files for corrections that have already been accepted.
4. Explicitly documented assumptions only when the requirements do not decide an issue.

Never silently invent a business rule, attribute, relationship, status, constraint, or workflow.

When a requirement is ambiguous:

- state the ambiguity;
- record a working assumption;
- explain its design impact; and
- avoid presenting the assumption as a confirmed requirement.

## 3. General workflow rules

- Follow the workflow in dependency order.
- Read and use prior approved outputs before starting a later step.
- Do not jump directly from requirements to DDL.
- Keep requirement, conceptual, logical, implementation, testing, and performance concerns separated.
- Preserve traceability from requirement → entity/relationship → relation → constraint or transaction → test.
- Use Microsoft SQL Server syntax and behavior.
- Use Mermaid `erDiagram` for ERD content.
- Use structured headings and clear tables in Markdown outputs.
- Keep facts, assumptions, design decisions, unresolved questions, and test evidence clearly separated.

## 4. Phase 1 baseline

Treat these files as the existing baseline:

1. `outputs/01-business-requirement-analysis-G02.md`
2. `outputs/02-erd-design-G02.md`
3. `outputs/03-logical-design-G02.md`
4. `outputs/04-design-validation-G02.md`
5. `outputs/05-db-definition-G02.sql`
6. `outputs/06-sample-data-G02.sql`
7. `outputs/07-query-design-G02.sql`

Phase 2 must extend this design rather than recreate it from scratch.

## 5. Phase 2 execution order

Use this working order even though repository filenames are numbered differently:

1. Step 08 — Requirement Change Analysis
2. Step 09 — Updated ERD and Logical Design
3. Step 10 — Schema Migration
4. Step 11 — Concurrency Design
5. Step 12 — Concurrency Implementation
6. Step 13 — Concurrency Tests
7. Step 14 — Data Generator
8. Step 16 — Analytical Queries
9. Step 15 — Index Tuning Report
10. Normalization validation and final report integration

The analytical queries must exist and the large dataset must be loaded before meaningful index-tuning comparisons are performed.

## 6. Required Phase 2 outputs

Create or update the following artifacts:

- `outputs/08-requirement-change-analysis-G02.md`
- `outputs/09-updated-erd-and-logical-design-G02.md`
- `outputs/10-schema-migration-G02.sql`
- `outputs/11-concurrency-design-G02.md`
- `outputs/12-concurrency-implementation-G02.sql`
- `outputs/13-concurrency-tests-G02/`
- `outputs/14-data-generator-G02/`
- `outputs/15-index-tuning-report-G02.md`
- `outputs/16-analytical-queries-G02.sql`

Also update the project-level agent and skill documentation requested for Phase 2.

## 7. Step 08 — update-only requirement analysis

Step 08 must analyze only what Phase 2 adds, changes, replaces, or clarifies.

Do not repeat the full Phase 1 business analysis. Instead:

- identify the Phase 1 rule or design element being affected;
- state the Phase 2 change;
- identify affected actors, entities, attributes, relationships, cardinalities, and business rules;
- explain downstream effects on design, migration, concurrency, queries, indexing, and tests;
- identify possible concurrency conflicts caused by booking and approval operations;
- separate confirmed requirements from assumptions and open questions.

Before Step 09 begins, examine whether Step 08 is ready to guide the design update without requiring the next agent to guess missing requirements or repeat unchanged Phase 1 content.

## 8. Phase 2 requirement rules that must remain visible

### 8.1 Maintenance impact levels

- `out-of-service` maintenance blocks bookings whose requested period overlaps the maintenance period.
- `advisory` maintenance does not block booking.
- At booking time, the requester must be informed of all active advisories affecting the space.
- The system must store acknowledgement that the requester was informed.
- A space may have multiple active maintenance records with different impact levels.
- An open maintenance record may be escalated or downgraded.
- If an advisory is escalated to `out-of-service`, overlapping approved bookings must be identifiable for staff follow-up.

Do not decide the exact table structure for acknowledgement or impact-history tracking during Step 08 unless the requirement explicitly requires that structure. Step 08 identifies the information need; Step 09 chooses the design.

### 8.2 Concurrent booking and approval

The following invariant must always hold:

> Two approved bookings must never use the same space during overlapping time periods.

This must remain true for:

- instant approval versus instant approval;
- staff approval versus staff approval; and
- instant approval versus staff approval.

Do not treat a separate availability check followed later by an insert or update as sufficient. The final solution must make conflict checking and approval atomic under concurrent execution.

### 8.3 Reporting needs

Implement all four reports:

1. Total approved booking hours for each space in a given semester.
2. Number of approved bookings by weekday and hour for a given semester.
3. Available spaces satisfying required capacity, required facilities, and a requested time period — the room finder.
4. Approved bookings affected when maintenance is escalated to `out-of-service`.

For this group’s clarified scope, perform detailed before/after index analysis for:

- the booking-conflict check;
- the room-finder query; and
- one additional reporting query selected by the group.

Record this interpretation as a documented project decision because the Phase 2 handout contains inconsistent wording about one versus two additional reporting queries.

## 9. Step-specific quality rules

### Step 09 — Updated ERD and logical design

- Show only necessary Phase 2 additions and modifications while retaining enough Phase 1 context to understand them.
- Ensure every new conceptual element has a corresponding logical representation.
- Specify keys, foreign keys, candidate keys, nullability, domains, and participation constraints.
- Do not introduce implementation-only details into the conceptual ERD.
- Resolve how advisory acknowledgements and impact-level changes are represented.
- Confirm that the design supports finding affected approved bookings after escalation.

### Step 10 — Schema migration

- Implement changes on top of the Phase 1 schema.
- Preserve existing data or document exactly how it is transformed.
- State default or backfill treatment for existing rows.
- Avoid destructive drops unless they are justified and data preservation is addressed.
- Make migration order explicit so foreign keys and constraints can be applied safely.
- Provide validation queries after migration.

### Steps 11–13 — Concurrency

- Identify at least one concrete race condition.
- Explain the interleaving that allows conflicting approvals.
- Select a SQL Server concurrency-control strategy and justify it.
- Implement the solution transactionally.
- Include separate-session scripts that demonstrate both the unsafe behavior and the prevented conflict.
- State the expected result for each session and the final database state.
- Do not use `NOLOCK` in correctness-sensitive booking or approval operations.

### Step 14 — Data generator

Generate realistic data covering at least:

- three academic years;
- 100,000 booking records;
- approved, rejected, cancelled, completed, and no-show cases where supported by the schema;
- instant and staff approval paths where represented;
- maintenance records with advisory and out-of-service impacts;
- overlapping maintenance periods;
- cancellations, no-shows, and advisory acknowledgements;
- enough selective and non-selective values to make index effects observable.

Prefer deterministic generation through a documented seed or repeatable generation logic. Validate row counts and scenario coverage after generation.

### Step 16 — Analytical queries

For every query include:

- business question;
- target user;
- business value;
- parameters;
- SQL statement;
- correctness notes;
- expected output meaning.

The room finder must require all requested facilities, not merely any one requested facility. It must exclude overlapping approved bookings and overlapping out-of-service maintenance while allowing advisory maintenance to remain discoverable.

### Step 15 — Index tuning

For every tuned operation:

1. Run the baseline without the proposed new index.
2. capture the actual execution plan;
3. record consistent execution statistics;
4. create the index with a clear justification;
5. rerun the same operation with the same parameters and dataset;
6. compare plan shape, scans/seeks, reads, elapsed time, and relevant cost indicators;
7. explain trade-offs and whether the index should be retained.

Do not claim an improvement from estimated cost alone. Do not compare different queries, parameters, or datasets as though they were the same test.

### Normalization validation

- Identify functional dependencies for every relation.
- Identify candidate keys and prime attributes.
- Check 1NF, 2NF, and 3NF explicitly.
- If a relation violates 3NF, show the dependency causing the violation and the decomposition.
- If a relation already satisfies 3NF, provide a proof rather than only stating the conclusion.
- Confirm that any decomposition is lossless and preserves required dependencies where applicable.

## 10. Review gates

Before moving to the next dependent step, perform a readiness review.

### Step 08 gate

Ask:

> Is the requirement-change analysis ready for Step 09, or would the designer still need to guess about a changed requirement, affected design element, concurrency risk, or reporting need?

Allowed verdicts:

- `READY FOR STEP 09`
- `READY FOR STEP 09 WITH MINOR REVISIONS`
- `NOT READY FOR STEP 09`

Do not proceed when the verdict is `NOT READY FOR STEP 09`.

### Later-step gates

For each later artifact, verify:

- completeness against its input requirements;
- consistency with approved earlier artifacts;
- traceability;
- SQL Server compatibility where applicable;
- testability;
- absence of unsupported assumptions;
- readiness for the next dependent step.

When a review file exists, read it and resolve all blocking or major issues before continuing.

## 11. SQL Server implementation rules

- Use valid Microsoft SQL Server syntax.
- Qualify database objects consistently, preferably with `dbo` unless the existing schema uses another convention.
- Use explicit column lists in `INSERT` statements.
- Use appropriate primary keys, foreign keys, unique constraints, check constraints, defaults, and indexes.
- Use `TRY...CATCH`, `XACT_ABORT`, and explicit transactions where failure could leave partial changes.
- Avoid relying on application-side checks for database invariants that must hold under concurrency.
- Use half-open overlap logic consistently when appropriate:

```sql
existing_start < requested_end
AND existing_end > requested_start
```

Document any different boundary rule instead of mixing overlap definitions across scripts.

## 12. Final consistency check

Before finalizing Phase 2, verify that:

- Step 08 contains only changes and impacts, not a duplicated Phase 1 analysis;
- Step 09 reflects every approved Step 08 change;
- Step 10 migrates the actual Phase 1 schema into the Step 09 schema;
- concurrency design, implementation, and tests describe the same solution;
- the generator matches the final schema and covers required cases;
- all four analytical reports are implemented;
- tuning uses the large generated dataset and consistent test conditions;
- functional dependencies and 3NF conclusions match the final relations;
- filenames, group number, table names, attribute names, and status values are consistent across all artifacts;
- the final report includes the required evidence and does not claim unsupported results.
