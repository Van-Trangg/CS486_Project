---
name: erd-design
description: This skill instructs the agent to produce a complete, faithful Entity-Relationship Diagram (ERD) in crow's foot notation for the Campus Space Management System, rendered as Mermaid code. The ERD must be derived exclusively from the approved Step 1 Business Requirement Analysis document.
compatibility: opencode
-----------------------

## 1. Purpose

This skill instructs the agent to produce a complete, faithful Entity-Relationship Diagram
(ERD) in crow's foot notation for the Campus Space Management System, rendered as
Mermaid `erDiagram` code. The ERD must be derived exclusively from the approved Step 1
Business Requirement Analysis document (`01-business-requirement-analysis-G02.md`).
No entities, attributes, or relationships may be invented or omitted.

---

## 2. Required Input

Before beginning, the agent MUST have the following document loaded and fully read:

| Input | File | Purpose |
|---|---|---|
| Business Requirement Analysis | `outputs/01-business-requirement-analysis-G02.md` | Single source of truth for all ERD decisions |

If the input file is not present in context, halt and request it. Do not proceed from memory.

---

## 3. Execution Pipeline

Execute the following stages in strict order. Do not skip or reorder steps.

### Stage 1 — Entity Inventory

Scan §3 of the BRA. Build an explicit list of all entities with their PKs. Expected entities:

```
User            PK: user_id
Space           PK: space_code
Facility        PK: facility_id
Booking         PK: booking_id
UsageSession    PK: booking_id  (shared/identifying FK from Booking)
MaintenanceRecord PK: maintenance_id
```

Confirm count = 6 before proceeding.

### Stage 2 — Attribute Mapping

For each entity in Stage 1, extract every attribute from §4 of the BRA. Apply the
following classification rules:

| BRA Category | Mermaid label suffix | Nullable? |
|---|---|---|
| PK / Identifier (Primary) | `PK` | Never |
| PK / FK (shared key) | `PK, FK` | Never |
| FK only | `FK` | Per BRA |
| Descriptive, not nullable | *(no suffix)* | No |
| Descriptive, nullable | *(no suffix)* | Yes — noted in Attribute Traceability table only |

Rules:
- Preserve BRA data types exactly as written (e.g., `VARCHAR(50)`, `INT`, `DATETIME`,
  `NVARCHAR(MAX)`). Do not translate or shorten them. The full type names are retained
  so they can be used directly in SQL DDL at Step 5 without ambiguity.
- Include ALL attributes from BRA §4 for each entity, including FK-only columns. FK
  columns must appear in the entity block with the `FK` suffix label. Do not omit any
  attribute regardless of its category.
- Preserve every attribute name exactly as written in the BRA. Do not rename,
  abbreviate, or merge attributes.

### Stage 3 — Relationship Line Construction

For each of the 10 relationships in §5 of the BRA, construct one Mermaid relationship line.
Use the cardinality specified in §6 as the authoritative source.

**Step 1 — token lookup table** ((min,max) → two-character token):

| BRA notation | Token |
|---|---|
| `(0,1)` | `o\|` |
| `(1,1)` | `\|\|` |
| `(0,N)` or `(0,M)` | `o{` |
| `(1,N)` | `\|{` |

**Step 2 — line assembly rule (critical — read carefully):**

Given a BRA relationship written as `ENTITY_A (x,y) : (a,b) ENTITY_B`, construct the
Mermaid line using this exact procedure:

1. Look up the token for ENTITY_A's cardinality `(x,y)` → this becomes the **left token** (goes immediately left of `--`).
2. Look up the token for ENTITY_B's cardinality `(a,b)` → this becomes the **right token** (goes immediately right of `--`).
3. Write: `ENTITY_A <left_token>--<right_token> ENTITY_B : "label"`

**The left token always belongs to ENTITY_A. The right token always belongs to ENTITY_B. Never swap them.**

**Worked examples — follow this process for every relationship:**

BRA §6.1: `User (0,N) : (1,1) Booking`
- ENTITY_A = USER, cardinality = (0,N) → token = `o{` → goes LEFT of `--`
- ENTITY_B = BOOKING, cardinality = (1,1) → token = `||` → goes RIGHT of `--`
- Result: `USER o{--|| BOOKING : "requests"` 
- Common mistake: `USER ||--o{ BOOKING` (this reverses which entity is mandatory)

BRA §6.3: `Space (0,N) : (1,1) Booking`
- ENTITY_A = SPACE, cardinality = (0,N) → token = `o{` → goes LEFT of `--`
- ENTITY_B = BOOKING, cardinality = (1,1) → token = `||` → goes RIGHT of `--`
- Result: `SPACE o{--|| BOOKING : "hosts"` 
- Common mistake: `SPACE ||--o{ BOOKING` (this makes Space mandatory (wrong) and Booking optional (wrong))

BRA §6.5: `Booking (0,1) : (1,1) UsageSession`
- ENTITY_A = BOOKING, cardinality = (0,1) → token = `o|` → goes LEFT of `--`
- ENTITY_B = USAGESESSION, cardinality = (1,1) → token = `||` → goes RIGHT of `--`
- Result: `BOOKING o|--|| USAGESESSION : "tracked by"` 
- Common mistake: `BOOKING ||--|| USAGESESSION` (this makes Booking mandatory (wrong))

Apply this same two-step process to all 10 relationships. Do not guess token placement
by symmetry or by reading the label — always derive from the BRA cardinality values.

Mermaid relationship line syntax:
```
ENTITY_A left_token--right_token ENTITY_B : "label"
```

For relationships where User participates in multiple distinct roles with the same entity
(Booking and UsageSession), each role must be a **separate named relationship line**.
Use distinct label strings to differentiate:
- `"requests"` vs `"approves"` for User→Booking
- `"checks in"` vs `"checks out"` for User→UsageSession
- `"reports"` vs `"assigned to"` for User→MaintenanceRecord

The M:N relationship `Space_Equipped_With_Facility` must appear as a direct line
between Space and Facility. Mermaid handles M:N natively — do not introduce a
`SpaceFacility` junction entity in the `erDiagram` block (it will appear at the logical
design stage, Step 3).

### Stage 4 — Mermaid Code Assembly

Assemble the final Mermaid block using this template structure:

````markdown
```mermaid
erDiagram

    %% ── Entities ──────────────────────────────────────────────
    USER {
        <attributes>
    }

    SPACE {
        <attributes>
    }

    FACILITY {
        <attributes>
    }

    BOOKING {
        <attributes>
    }

    USAGESESSION {
        <attributes>
    }

    MAINTENANCERECORD {
        <attributes>
    }

    %% ── Relationships ─────────────────────────────────────────
    <relationship lines>
```
````

Formatting rules:
- Entity names in ALL_CAPS with no spaces (Mermaid convention).
- Attribute names in `snake_case`, matching BRA exactly.
- One attribute per line, indented 8 spaces inside the entity block.
- Relationship lines in the order they appear in §5 of the BRA.
- Each relationship line must be preceded by a `%%` comment on its own separate line
  citing the BRA source (e.g., `%% BRA §5.1 — User_Requests_Booking`). The comment
  must never appear on the same line as a relationship or attribute declaration.
- No fabricated attributes, entities, or relationships.

### Stage 5 — Self-Consistency Pre-Check

Before writing the final output, run through this checklist mentally and confirm each item:

```
[ ] Entity count = 6
[ ] Every BRA §4 attribute appears in the correct entity block, including all FK columns
[ ] FK-only columns carry the FK suffix label; UsageSession.booking_id carries PK, FK
[ ] Every BRA §5 relationship has exactly one Mermaid line
[ ] Every Mermaid line cardinality matches BRA §6 exactly
[ ] Multi-role User relationships have distinct labels (requests/approves, checks in/checks out, reports/assigned to)
[ ] No entities, attributes, or relationships invented beyond the BRA
[ ] No entities, attributes, or relationships from the BRA omitted
```

If any check fails, correct before writing output.

---

## 4. Output Format

Produce the output as a Markdown file with the following structure:

```
# Step 2: ERD Design — Campus Space Management System

---

## 1. Design Decisions

<A short paragraph (4–6 sentences) explaining:>
- Which ERD notation is used and why (crow's foot, rendered via Mermaid erDiagram)
- How multi-role User relationships are represented
- How the M:N Space↔Facility relationship is represented
- Where the SpaceFacility junction will appear (Step 3 logical design)

---

## 2. Entity-Relationship Diagram

<Mermaid code block from Stage 4>

---

## 3. Relationship Summary Table

| # | Relationship Name | Entity A | Cardinality | Entity B | Notes |
|---|---|---|---|---|---|
<One row per BRA §5 relationship>

---

## 4. Attribute Traceability

<One sub-table per entity listing every attribute and its BRA §4 source>
```

Save output as: `outputs/02-erd-design-G02.md`

---

## 5. Critical Constraints

These rules are absolute and override any other instruction:

1. **No invention rule.** Every element in the ERD must trace to a specific line in the BRA.
   If something is not in the BRA, it does not appear in the ERD.

2. **No omission rule.** Every entity, attribute, and relationship defined in the BRA §3,
   §4, and §5 must appear in the ERD. Omitting anything that is in the BRA is an error.

3. **Cardinality fidelity rule.** Mermaid cardinality tokens must exactly reflect the
   (min,max) notation in BRA §6. Do not infer or adjust cardinalities.

4. **Role disambiguation rule.** Where User participates in multiple roles with the same
   entity, each role must be a distinct labeled relationship line. Collapsing them into one
   line is an error.

5. **FK inclusion rule.** All FK columns defined in BRA §4 must appear as attributes in
   their respective Mermaid entity blocks with the `FK` suffix label. Omitting FK columns
   is a violation of the no omission rule. The only special case is `UsageSession.booking_id`,
   which carries both `PK, FK` labels as it is simultaneously the primary key and a foreign key.

---

## 6. Known Mermaid Syntax Rules

- Entity names must be a single token (no spaces). Use `USAGESESSION`, not
  `USAGE SESSION`.
- Attribute type must precede attribute name: `VARCHAR(50) user_id PK`
- Data types with parentheses (e.g., `VARCHAR(50)`, `NVARCHAR(MAX)`) are valid in
  Mermaid `erDiagram` and must be written exactly as they appear in the BRA.
- Relationship label string is mandatory: the trailing `"label"` after the colon is required
  by Mermaid's parser. Empty strings `""` are allowed but discouraged — use a
  meaningful verb phrase.
- Both `o|`, `||`, `o{`, `|{` are valid crow's-foot tokens. Use `}` on the right side
  of a many-end: `||--o{` means "exactly one to zero-or-many".
- Comments use `%%` prefix and must always occupy their own dedicated line. Never
  place a `%%` comment on the same line as an attribute declaration or relationship line.
- Mermaid does not support composite or multi-valued attributes natively — document
  any such cases in the Design Decisions section instead of attempting to encode them.