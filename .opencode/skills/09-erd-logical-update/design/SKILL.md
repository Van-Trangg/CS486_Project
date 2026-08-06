---
name: erd-logical-update-design
description: Instructs the agent to produce an updated Entity-Relationship Diagram and updated relational logical schema for the Campus Space Management System, extending the Phase 1 baseline according to the scope defined in the Step 8 (Requirement Change Analysis).
compatibility: opencode
---

## 1. Purpose
This skill instructs the agent to produce Step 9 of Phase 2: an **updated** ERD (Mermaid `erDiagram`) and an **updated** relational logical schema, built on top of the approved Phase 1 baseline. This is a delta task, not a redesign: every entity, attribute, relationship, table, and column that Step 8 did not flag as affected must be carried forward unchanged. Only elements tied to a Step 8 Change ID may be added, modified, or reinterpreted.

Unlike the Step 2 design skill — which is a purely mechanical, zero-interpretation transcription of a BRA — this skill must sometimes exercise **controlled invention**: the Phase 2 BRA and Step 8 analysis intentionally leave some representational choices open (see Step 8 §11 Open Questions) and explicitly assign them to Step 9. Where this happens, the agent must design its own resolution and document it transparently — this is the one place where inventing something not explicitly stated in a source document is required, not forbidden.

---

## 2. Required Input
Before beginning, the agent MUST have all of the following loaded and fully read:

| Input | File | Role |
|---|---|---|
| Phase 1 conceptual baseline | `outputs/02-erd-design-G02.md` | The ERD being extended — carry forward unless flagged |
| Phase 1 logical baseline | `outputs/03-logical-design-G02.md` | The relational schema being extended — carry forward unless flagged |
| Phase 1 validation (recommended) | `outputs/04-design-validation-G02.md` | Sanity check so the update doesn't reintroduce an already-resolved issue |
| **Scope authority** | `outputs/08-requirement-change-analysis-G02.md` | Defines *what* changes: the authoritative boundary of what may be touched |
| Ground truth for wording | `req/business-requirement-phase2.md` | Defines *how* — exact impact-level values, acknowledgement wording, concurrency wording |

If any required file is absent, halt and request it. Do not proceed from memory, and do not re-derive the Phase 1 ERD/schema from the Phase 1 BRA — Step 8 and the Phase 1 artifacts are the inputs, not the original Phase 1 BRA.

---

## 3. Execution Pipeline

Execute the following stages in strict order.

### Stage 0 — Change Ledger Extraction
Read Step 8 §2 (Requirement Change Summary), §4 (Affected Entities), §5 (Affected Relationships), §6 (Business Rules), and §9 (Downstream Design Update Map). Build a **Change Ledger** table before touching the ERD, using this shape:

| Change ID | Source Step 8 Section | Affected Element | Required Schema Action |
|---|---|---|---|

> **This table must be derived from the actual `outputs/08-requirement-change-analysis-G02.md` document, not copied from memory or from any example.** The row content below illustrates the *expected shape* of a Change Ledger — it is a worked example of the pattern, not a literal answer key, and its count of change areas is illustrative only. The agent must read Step 8's actual Change IDs, section citations, and required actions and populate the table from that source, including every change area Step 8 defines even if it is not represented below. If the real Step 8 document's Change IDs, count, or content differ from the illustration below, the real document governs.
>
> Illustrative example:
>
> | Change ID | Source Step 8 Section | Affected Element | Required Schema Action |
> |---|---|---|---|
> | C08-01 | §2, §4, §6 (P2-BR-01/02) | `MAINTENANCERECORD` | ADD ATTRIBUTE (impact level) |
> | C08-02 | §2, §4, §5, §6 (P2-BR-03) | `BOOKING` ↔ `MAINTENANCERECORD` | ADD ENTITY + ADD RELATIONSHIP (disclosure/acknowledgement) |
> | C08-03 | §2, §4, §5, §6 (P2-BR-05/06) | `MAINTENANCERECORD` | ADD ATTRIBUTE and/or ADD ENTITY (escalation representation — open question, resolve in Stage 1) |
> | C08-04 | §2, §6, §7 (P2-BR-07, CC-01–03) | `BOOKING` | ADD ATTRIBUTE (resolution-path column carried over from the Stage 1 resolution-path decision; no separate version/rowversion column — see Stage 1 item 4) |
> | C08-05 | §2, §6, §8 (P2-BR-08/09) | none structural | NO SCHEMA CHANGE (query/index work, Steps 14–16) |
> | C08-06 | §6 (P2-BR-10/11) | `BOOKING` | ADD write-once constraint documentation for the resolution-path column; eligibility is evaluated against existing columns, no new eligibility column |

Any Step 8 Change ID with no corresponding row is an omission and must be corrected before proceeding.

Every entity, attribute, relationship, and table **not** referenced by a Change ID is out of scope for this stage and must be reproduced identically from the Phase 1 baseline — no renaming, no re-deriving cardinalities, no "improving" unrelated parts.

### Stage 1 — Open Question Resolution (Controlled Invention)
For every row in Step 8 §11 (Open Questions) whose "Affected Later Step" includes Step 9, the agent must produce an explicit, documented resolution **before** building the diagram. Each resolution must state:
- The question, quoted from Step 8 §11.
- The chosen representation.
- The rationale, tied to the corresponding Step 8 §6 business rule or §7 concurrency conflict.
- Confirmation that the choice does not contradict the Step 8 "Working Assumption" column (the working assumption is a floor, not a decision — Step 9 may adopt it as-is or extend it, but must say which).

At minimum, the agent must resolve:
1. **Escalation/downgrade representation** (Step 8 open question row 4): does the schema retain full impact-change history, or only current impact level plus an on-demand affected-bookings query? State the choice and why it is sufficient for the required "approved bookings affected by escalation" report (Step 8 §8).
2. **Advisory acknowledgement representation** (Step 8 §4, "Candidate new entity"): the exact entity/attribute shape needed to record which specific advisories were disclosed to which booking, and when.
3. **Resolution path representation** (Step 8 open question row 3): whether instant vs. staff approval is stored as an explicit column, and if so, its name, type, and allowed values — without inventing a new actor. **Name this column `resolution_path`, not `approval_path`** — Step 8 §6 (P2-BR-10/11) governs the same column for eligibility and immutability, and "approval path" is ambiguous between "the path a request takes" and "an approval decision." If a prior draft used `approval_path`, the rename must be stated as its own decision with rationale, not applied silently.
4. **Concurrency-support schema decision** (C08-04): confirm what design facts C08-04 actually needs, and check first whether the resolution-path column from item 3 already supplies them before adding anything else. **Do not add a per-row version/rowversion/lock column or any other new concurrency-support column unless Step 8 explicitly requires one that resolution_path does not already cover.** Step 8 §9's C08-04 row assigns the atomic-protection *mechanism* to Steps 11–13; Step 9's job is limited to retaining the facts those steps will need (e.g., which path a booking took), not to pre-building mechanism scaffolding. If no additional column is needed, say so explicitly in the ledger and in §5.3 rather than leaving C08-04 unaddressed.
5. **Resolution-path eligibility and write-once basis** (Step 8 §6, P2-BR-10/11 — this is C08-06, not an extension of item 3 to skip): state the eligibility conjunction (space type, requester role, and any other Step 8-named condition) entirely in terms of existing baseline columns, with no new eligibility column; and state, as its own explicit rule, that the resolution-path column is write-once — assigned exactly once, at the same transaction that inserts the row, and never reassigned afterward, including at the moment a later staff decision is recorded on that same row. If the resolution-path column has other fields whose validity depends on it (e.g. approver, decision time, rejection reason), produce an explicit state matrix enumerating every valid combination — see Stage 7 item 4 and the Output Format §5.3–§5.4 shape.

Any structural element introduced in Stage 3 onward that is **not** traceable to either a Step 8 Change ID or a Stage 1 resolution is an invention violation and must be removed. A version/rowversion column added "to be safe" for concurrency, without a Step 8 citation requiring it, is exactly this kind of invention violation.

### Stage 2 — Baseline Preservation Check
Before modifying anything, diff the Phase 1 ERD (`02-erd-design-G02.md`) and Phase 1 logical design (`03-logical-design-G02.md`) entity-by-entity and table-by-table against the Change Ledger. Confirm:
- Every unaffected entity/table is reproduced with identical attributes, types, PK/FK labels, and cardinalities.
- Every unaffected relationship line is reproduced identically, including its original BRA §5/§6 source comment.
- No unaffected element is silently renamed, retyped, or re-scoped.

### Stage 3 — Updated Entity Inventory
Starting from the Phase 1 entity set, apply changes only where the Change Ledger or Stage 1 resolutions require them:
- **New entities** introduced by a Stage 1 resolution (e.g., a booking–advisory acknowledgement entity, and/or a maintenance impact-change history entity if Stage 1 chose to retain history) must each get their own Mermaid entity block.
- **Junction-entity exclusion rule (inherited from Step 2, with one exception):** apply the same structural test as the Step 2 design skill — an entity that exists only to bridge an M:N relationship with no descriptive attributes of its own is excluded from the conceptual ERD. **Exception:** if the bridging entity carries its own descriptive attributes beyond the two FKs (for example, an acknowledgement timestamp, or an escalation's old/new impact values and change time), it is a true entity by the same rule the Step 2 skill already uses for entities with independent business justification — it must appear as its own entity block, not be collapsed into a bare M:N line.
- Removed or renamed entities are not permitted — Phase 2 introduces no entity removals.

### Stage 4 — Attribute Updates
For each affected entity in the Change Ledger, add or modify only the attributes required:
- `MAINTENANCERECORD`: add an impact-level attribute (exact allowed values per Phase 2 BRA §1.1 — `advisory` / `out-of-service`; verify exact casing/wording against the BRA text, do not paraphrase the value).
- Any new acknowledgement/history entity: attributes must be minimal and auditable — at minimum a reference to the booking, a reference to the maintenance record, and a timestamp; add further attributes only if a Stage 1 resolution justifies them.
- **Invariant documentation for new audit/history entities:** every new entity whose purpose is to log or disclose an event (an acknowledgement table, an impact-change history table, or similar) must carry an explicit invariants note in the logical schema (Stage 7, alongside the table spec) covering, at minimum: applicability (when a row is valid to write), completeness (whether the requirement is "at least one," "exactly one," or "one per applicable item," and what enforces that), immutability (whether rows may be updated/deleted after creation), and — for any table recording a *transition* (old value → new value) — chain continuity (each new row's "old" value must match the prior row's "new" value), atomicity with the state it logs, and tie-breaking for same-timestamp rows. State plainly that these invariants are documentation only and that their enforcement mechanism (`CHECK` constraints, triggers) is Step 10/12 scope — Step 9 states the rule so it isn't guessed downstream, it does not implement it.
- `BOOKING`: add the resolution-path attribute decided in Stage 1 item 3, and no separate concurrency-support attribute unless Stage 1 item 4 concluded one was independently required.
- Preserve every existing attribute of affected entities exactly as in the Phase 1 baseline; only the specific new/changed attribute is touched.
- **Type verbatim rule:** new attribute types must be written in explicit SQL-style types (e.g., `VARCHAR(20)`, `DATETIME`), never generic aliases. Scan every new/changed attribute line against this known-bad-patterns table before finalizing:

| Pattern to avoid | Why it is wrong | Correct form |
|---|---|---|
| `string` | Generic alias, not a SQL type | `VARCHAR(n)` |
| `text` | Generic alias, not a SQL type | `NVARCHAR(MAX)` |
| `int` (lowercase) | Case mismatch; also a generic alias signal | `INT` |
| `datetime` (lowercase) | Case mismatch | `DATETIME` |
| `INT(Identity)` | Appends an implementation qualifier that is not a data type; also breaks Mermaid's parser when written with a space | `INT` — auto-increment is a Step 10 migration concern, not a Step 9 type |
| `INT (Identity)` (with space) | Same as above; the space additionally causes a Mermaid parse error | `INT` |
| Any `INT` variant with a parenthetical qualifier | e.g. `INT(1)`, `INT(11)`, `INT(PK)` — none of these are valid types | `INT` unless explicitly justified otherwise |
| `VARCHAR` without length specifier | e.g. bare `VARCHAR` with no `(n)` | Must specify an explicit length, e.g. `VARCHAR(50)` |

For an attribute whose exact type is dictated by Phase 2 BRA wording (e.g., an impact-level column), match the BRA's stated values verbatim; for an attribute Stage 1 invents (e.g., an acknowledgement timestamp), choose the most specific SQL-style type consistent with `03-logical-design-G02.md`'s existing conventions.

### Stage 5 — Relationship Updates
Construct new relationship lines only for relationships introduced by the Change Ledger. Use the following cardinality token table — the highest-risk error in this entire pipeline is confusing `(0,1)` with `(1,1)`.

**Cardinality token table:**

| Cardinality | Token | Critical note |
|---|---|---|
| `(0,1)` | `o\|` | **Optional singular** — the `o` means zero is allowed. Do NOT use `\|\|` for this. |
| `(1,1)` | `\|\|` | **Mandatory singular** — both pipes mean exactly one, always present. |
| `(0,N)` or `(0,M)` | `o{` | Optional plural |
| `(1,N)` | `\|{` | Mandatory plural |

**Line Assembly Rules:**
Given a relationship `ENTITY_A (x,y) : (a,b) ENTITY_B`, construct the Mermaid line using this exact procedure:
1. Look up the token for ENTITY_A's cardinality `(x,y)` → this becomes the **left token** (placed immediately left of `--`).
2. Look up the token for ENTITY_B's cardinality `(a,b)` → this becomes the **right token** (placed immediately right of `--`).
3. Format as: `ENTITY_A <left_token>--<right_token> ENTITY_B : "label"`

**The left token always belongs to ENTITY_A. The right token always belongs to ENTITY_B. Never swap them. Do not guess token placement by symmetry or by reading the label — always derive from the cardinality values.**

**Worked example (illustrative pattern, not a literal answer for this project):**
`Booking (0,1) : (1,1) Acknowledgement` — Booking side = `o|`, Acknowledgement side = `||`
→ `BOOKING o|--|| ACKNOWLEDGEMENT : "discloses"` ✅
→ `BOOKING ||--|| ACKNOWLEDGEMENT` ❌ **(0,1) ≠ (1,1)** — if a booking need not have an acknowledgement in every case, the Booking side must be `o|` not `||`.

Derive the actual cardinality for each new/changed relationship from the Stage 1 resolutions (e.g., "a booking may have zero or many acknowledgements; an advisory may be acknowledged by zero or many bookings" from Step 8 §5 becomes an M:N or a direct FK relationship depending on the Stage 1 entity shape chosen) — never from the worked example above, which illustrates mechanics only.

All Phase 1 relationship lines not referenced by the Change Ledger are reproduced identically, in their original order, with their original BRA source comments.

### Stage 6 — Mermaid Diagram Assembly
Assemble the full updated Mermaid `erDiagram` block containing **all** entities (unchanged + updated + new). Formatting rules are inherited unchanged from the Step 2 design skill (ALL_CAPS entity names, `snake_case` attributes, one attribute per line, `%%` comments on their own line only, mandatory relationship labels).

**New annotation rule for Step 9 only:** every entity block and relationship line that is new or changed must be preceded by its own `%%` comment line stating the Step 8 Change ID it traces to (e.g., `%% C08-01 — impact_level added per P2-BR-01/02`), instead of (or in addition to) a BRA section reference. Unchanged entities/relationships keep their original Step 2 BRA-section comments unaltered.

### Stage 7 — Updated Logical Schema
Using the same table-specification format as `03-logical-design-G02.md` (Column Name | SQL Server Data Type | Nullability | Key | Constraints | Description), produce:
1. **Modified table specs** — only the full spec for tables that gained or changed a column (e.g., `MAINTENANCERECORD`, `BOOKING`), with new/changed rows visually distinguishable from carried-forward rows (e.g., a "Change" column marked `NEW` or `—`).
2. **New table specs** — full spec for any new entity/table from Stage 3, in the same format.
3. Do **not** produce full `ALTER TABLE`/`CREATE TABLE` DDL — that is Step 10's responsibility. This stage documents the logical shape only (columns, types, keys, constraints described in prose/table form), consistent with how `03-logical-design-G02.md` itself separates logical design (§1–2) from DDL specifics.
4. State explicitly, for concurrency: this stage relies on the resolution-path column (or, only if Stage 1 item 4 concluded it was independently necessary, an additional named column) to supply the design facts needed by Steps 11–13; it does not add a version/rowversion column by default, and it does not choose or implement the concurrency mechanism itself (that is Steps 11–13, per Step 8 §9's C08-04 row).
5. Document the resolution-path column as write-once, per Stage 1 item 5: it is set once at INSERT and never updated, including when a later staff decision is recorded. If the resolution-path column co-varies with other columns on the same table (status, approver, decision fields), produce an explicit state matrix — one row per valid combination — and state that any combination not listed is invalid. Mark both the write-once rule and the state matrix as documentation only; enforcement (a rejecting trigger, spanning `CHECK` constraints) is Step 10/12 scope.
6. For every new audit/history table from Stage 4, include its invariants note (applicability, completeness, immutability, and — where applicable — chain continuity/atomicity/tie-breaking) directly beneath that table's spec.

### Stage 8 — Self-Consistency Pre-Check
Before writing final output, confirm each item:

```
[ ] Every Step 8 Change ID (all IDs actually present in §2 of Step 8, not assumed from any example) is addressed somewhere in the ledger and, where structural, in the ERD/schema
[ ] Every Step 8 §11 open question assigned to Step 9 has an explicit, rationale-backed resolution
[ ] Every new entity/attribute/relationship traces to either a Change ID or a Stage 1 resolution — none is unexplained
[ ] Every unaffected Phase 1 entity, attribute, and relationship is reproduced identically (no accidental edits)
[ ] New attribute types are SQL-style verbatim, not generic aliases
[ ] (0,1) vs (1,1) tokens double-checked for every new/changed relationship
[ ] Concurrency section adds schema support only — no mechanism, no isolation level, no locking strategy proposed
[ ] No version/rowversion/lock column was added for concurrency support unless Step 8 explicitly requires one beyond the resolution-path column
[ ] The resolution-path (or equivalently named) column is documented as write-once, assigned only at INSERT
[ ] If the resolution-path column co-varies with status/approver/decision fields, a state matrix of valid combinations is present and exhaustive
[ ] Every new audit/history table carries an invariants note (applicability, completeness, immutability, and chain continuity/atomicity/tie-breaking where applicable), scoped as documentation only
[ ] Any rename of a Phase 1 baseline column (e.g. an existing `approval_path`-style column) is documented as its own decision with rationale — never applied silently
[ ] No entity or table from Phase 1 is removed; no baseline column is renamed without a documented decision
```

If any check fails, correct before writing output.

---

## 4. Output Format

```
# Step 9: Updated ERD and Logical Design — Campus Space Management System

---

## 1. Change Scope Summary
<The Change Ledger table from Stage 0>

---

## 2. Design Decisions and Open-Question Resolutions
<One entry per Stage 1 resolution: question, chosen representation, rationale, traceability>

---

## 3. Updated Entity-Relationship Diagram
<Full Mermaid code block from Stage 6 — all entities, unchanged + new/changed>

---

## 4. Relationship Delta Summary

| # | Relationship Name | Entity A | Cardinality | Entity B | Status | Traces To |
|---|---|---|---|---|---|---|
<One row per relationship in the full diagram; Status = UNCHANGED / NEW / MODIFIED; Traces To = BRA §5.x for unchanged, Change ID for new/modified>

---

## 5. Updated Logical Schema

### 5.1 Modified Tables
<Full spec, Step 3-style table, for each changed table>

### 5.2 New Tables
<Full spec, Step 3-style table, for each new table. Directly beneath each new audit/history table's spec, include its Invariants note (applicability, completeness, immutability, and — for transition-logging tables — chain continuity, atomicity, and tie-breaking), explicitly marked as documentation only with enforcement deferred to Step 10/12.>

### 5.3 Resolution Path Write-Once Constraint Note
<State that the resolution-path column is assigned exactly once, at INSERT, and never updated thereafter — including when a later staff decision is recorded on the same row. State the recommended enforcement mechanism (e.g. a rejecting trigger) as a Step 10/12 pointer, not something Step 9 implements. If concurrency (C08-04) relies on this same column rather than a new one, say so here explicitly.>

### 5.4 Booking Resolution State Matrix
<Only required if the resolution-path column co-varies with other columns (status, approver, decision fields, rejection reason). One row per valid combination; state that any combination not listed is invalid. Omit this subsection with a one-line note if no such co-variance exists.>

---

## 6. Attribute Traceability (New/Changed Only)
<One sub-table per new/changed entity, listing every new/changed attribute and its source: Change ID + Step 8 section, or Stage 1 resolution number>
```

Save output as: `outputs/09-updated-erd-and-logical-design-G02.md`

---

## 5. Critical Constraints

These rules are absolute and override any other instruction:

1. **Baseline fidelity rule.** Every Phase 1 entity, attribute, relationship, and table not referenced by a Step 8 Change ID must appear unchanged. This is the Step 9 analogue of Step 2's "no omission" rule.

2. **Bounded invention rule.** New structural elements are permitted **only** when traceable to a Step 8 Change ID or an explicit Stage 1 resolution. This is the inverse of Step 2's "no invention" rule, deliberately relaxed for this step only, and only within these bounds.

3. **Scope boundary rule.** This skill produces ERD and logical design only. It must not produce migration SQL (Step 10), concurrency implementation (Steps 11–13), sample data (Step 14), or analytical queries/indexes (Steps 15–16), even when the underlying Step 8 analysis discusses them for context.

4. **Cardinality fidelity rule (inherited).** Mermaid tokens for any new or modified relationship must exactly reflect the cardinality reasoning derived from Step 8 §5 and the Stage 1 resolutions. Do not infer or default to symmetry.

5. **No silent history decisions.** If Stage 1 resolves to *not* retaining full escalation history, this must be stated explicitly as a decision with rationale, not omitted by default.

6. **No silent renames.** Renaming a Phase 1 baseline column or entity (e.g., adopting `resolution_path` where an earlier draft used `approval_path`) is only permitted when the rename itself is documented as a Stage 1 decision with rationale. A rename that appears in the schema without a corresponding decision entry is a baseline-fidelity violation, not a cosmetic change.

7. **No default concurrency invention.** C08-04 (or its project-specific equivalent) is satisfied by retaining existing design facts (typically the resolution-path column) unless Step 8 explicitly names an additional column. Adding a version/rowversion/lock column by default, "to be safe," is an invention violation under Rule 2 above, not a reasonable extra precaution.

---

## 6. Known Mermaid Syntax Rules
- Entity names must be a single token (no spaces). e.g. Use `ACKNOWLEDGEMENT`, not `BOOKING ACKNOWLEDGEMENT`.
- Attribute type must precede attribute name: `VARCHAR(50) user_id PK`.
- Data types with parentheses (e.g., `VARCHAR(50)`, `NVARCHAR(MAX)`) are valid in Mermaid `erDiagram` and must be written exactly per the type verbatim rule above.
- PK/FK suffixes are space-separated after the attribute name: `INT booking_id PK, FK`.
- Relationship label string is mandatory: the trailing `"label"` after the colon is required by Mermaid's parser. Empty strings `""` are allowed but discouraged — use a meaningful verb phrase.
- Both `o|`, `||`, `o{`, `|{` are valid crow's-foot tokens. Use `}` on the right side of a many-end: `||--o{` means "exactly one to zero-or-many".
- No illegal characters in entity/attribute names except `_`.
- **Inline comment prohibition — attributes:** no `%%` comment may appear on the same line as an attribute declaration. Nullable status or other annotation belongs in the Attribute Traceability table only, never inline.
- **Inline comment prohibition — relationships:** no `%%` comment may appear on the same line as a relationship line (e.g., `USER ||--o{ BOOKING : "requests" %% C08-01` is a violation). Every citation — whether a Change ID or a BRA section — must be on its own preceding `%%` comment line.
- **Comment placement:** every `%%` comment must occupy its own dedicated line and must never itself contain a relationship or attribute declaration.
- Mermaid does not support composite or multi-valued attributes natively — document any such cases in the Design Decisions section instead of attempting to encode them.