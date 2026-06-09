---
name: erd-design
description: This skill instructs the agent to produce a complete, faithful Entity-Relationship Diagram (ERD) in crow's foot notation for the Campus Space Management System, rendered as Mermaid code. The ERD must be derived exclusively from the approved Step 1 Business Requirement Analysis document.
compatibility: opencode
-----------------------

## 1. Purpose

This skill instructs the agent to produce a complete, faithful Entity-Relationship Diagram 
(ERD) in Chen notation for the Campus Space Management System, rendered as Mermaid
`erDiagram` code. The ERD must be derived exclusively from the approved Step 1 Business
Requirement Analysis document (`01-business-requirement-analysis-G02.md`). No
entities, attributes, or relationships may be invented or omitted.

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
- Do not include FK columns as attributes in Mermaid `erDiagram` syntax — relationships
  are expressed via relationship lines, not repeated FK columns.
  Exception: `UsageSession.booking_id` is both PK and FK — include it with label `PK, FK`.
- Preserve every attribute name exactly as written in the BRA. Do not rename,
  abbreviate, or merge attributes.

### Stage 3 — Relationship Line Construction

For each of the 10 relationships in §5 of the BRA, construct one Mermaid relationship line.
Use the cardinality specified in §6 as the authoritative source.

**Cardinality translation table** (BRA notation → Mermaid crow's-foot tokens):

| BRA side notation | Meaning | Mermaid left token | Mermaid right token |
|---|---|---|---|
| `(0,1)` | Zero or one | `o` | `|` |
| `(1,1)` | Exactly one | `\|` | `\|` |
| `(0,N)` | Zero or many | `o` | `{` |
| `(1,N)` | One or many | `\|` | `{` |
| `(0,M)` | Zero or many (M-side of M:N) | `o` | `{` |

Mermaid relationship line syntax:
```
ENTITY_A relationship_token--relationship_token ENTITY_B : "label"
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
[ ] Every BRA §4 attribute appears in the correct entity block
[ ] No FK-only columns duplicated as attributes (except UsageSession.booking_id)
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

5. **FK exclusion rule.** FK-only columns (e.g., `space_code` in Booking,
   `requester_id` in Booking) must not appear as attributes in the Mermaid entity block
   because Mermaid expresses those via relationship lines. The one exception is
   `UsageSession.booking_id`, which is both PK and FK and must be declared.

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