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

> **This table must be derived from the actual `outputs/08-requirement-change-analysis-G02.md` document, not copied from memory or from any example.** The row content below illustrates the *expected shape* of a plausible Change Ledger for this project (five change areas covering impact levels, acknowledgement, escalation, concurrency-support, and reporting) — it is a worked example of the pattern, not a literal answer key. The agent must read Step 8's actual Change IDs, section citations, and required actions and populate the table from that source. If the real Step 8 document's Change IDs, count, or content differ from the illustration below, the real document governs.
>
> Illustrative example:
>
> | Change ID | Source Step 8 Section | Affected Element | Required Schema Action |
> |---|---|---|---|
> | C08-01 | §2, §4, §6 (P2-BR-01/02) | `MAINTENANCERECORD` | ADD ATTRIBUTE (impact level) |
> | C08-02 | §2, §4, §5, §6 (P2-BR-03) | `BOOKING` ↔ `MAINTENANCERECORD` | ADD ENTITY + ADD RELATIONSHIP (disclosure/acknowledgement) |
> | C08-03 | §2, §4, §5, §6 (P2-BR-05/06) | `MAINTENANCERECORD` | ADD ATTRIBUTE and/or ADD ENTITY (escalation representation — open question, resolve in Stage 1) |
> | C08-04 | §2, §6, §7 (P2-BR-07, CC-01–03) | `BOOKING` | ADD ATTRIBUTE (concurrency-support column only; no mechanism) |
> | C08-05 | §2, §6, §8 (P2-BR-08/09) | none structural | NO SCHEMA CHANGE (query/index work, Steps 14–16) |

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
3. **Approval path representation** (Step 8 open question row 3): whether instant vs. staff approval is stored as an explicit column, and if so, its name, type, and allowed values — without inventing a new actor.
4. **Concurrency-support schema decision** (C08-04): what column(s), if any, are added now to support the Step 11–13 mechanism (e.g., a version/rowversion column), explicitly scoped as "schema support only, not implementation" per Step 8 §9's C08-04 row.

Any structural element introduced in Stage 3 onward that is **not** traceable to either a Step 8 Change ID or a Stage 1 resolution is an invention violation and must be removed.

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
- `BOOKING`: add the concurrency-support attribute decided in Stage 1, if any.
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
4. State explicitly, for concurrency: this stage adds only the schema column(s) needed to support future concurrency control (per Stage 1 resolution #4); it does not choose or implement the concurrency mechanism itself (that is Steps 11–13, per Step 8 §9's C08-04 row).

### Stage 8 — Self-Consistency Pre-Check
Before writing final output, confirm each item:

```
[ ] Every Step 8 Change ID (C08-01 through C08-05) is addressed somewhere in the ledger and, where structural, in the ERD/schema
[ ] Every Step 8 §11 open question assigned to Step 9 has an explicit, rationale-backed resolution
[ ] Every new entity/attribute/relationship traces to either a Change ID or a Stage 1 resolution — none is unexplained
[ ] Every unaffected Phase 1 entity, attribute, and relationship is reproduced identically (no accidental edits)
[ ] New attribute types are SQL-style verbatim, not generic aliases
[ ] (0,1) vs (1,1) tokens double-checked for every new/changed relationship
[ ] Concurrency section adds schema support only — no mechanism, no isolation level, no locking strategy proposed
[ ] No entity or table from Phase 1 is removed or renamed
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
<Full spec, Step 3-style table, for each new table>

### 5.3 Concurrency Schema Note
<Short statement of what column(s) were added and why, with explicit scope boundary against Steps 11–13>

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
