---
name: erd-design
description: Instructs the agent to produce a complete, faithful Entity-Relationship Diagram (ERD) in crow's foot notation rendered as Mermaid code, dynamically derived from any standard Business Requirement Analysis (BRA) document.
compatibility: opencode
---

## 1. Purpose
This skill instructs the agent to produce a complete, faithful Entity-Relationship Diagram (ERD) in crow's foot notation, rendered as Mermaid `erDiagram` code. The ERD must be derived exclusively from the provided Business Requirement Analysis (BRA) document. No entities, attributes, or relationships may be invented or omitted.

## 2. Required Input
Before beginning, the agent MUST have the following document loaded and fully read:
- **Ground Truth:** `outputs/01-business-requirement-analysis-G02.md`
If the input file is not present in context, halt and request it. Do not proceed from memory.

## 3. Execution Pipeline
Execute the following stages in strict order. Do not skip or reorder steps.
### Stage 1 — Entity Inventory
Scan §3 of the BRA. Dynamically extract the complete list of all candidate entities along with their identified Primary Keys (PKs). Verify the total entity count before proceeding.

### Stage 2 — Attribute Mapping
For each identified entity, map every attribute listed in §4 of the BRA. 
- Preserve every attribute name exactly as written in the BRA. Do not rename,
  abbreviate, or merge attributes.
- **Preserve Types Verbatim:** Retain data types exactly as written in the BRA (e.g., `VARCHAR(50)`, `INT`). Do not shorten or translate them.
- **Foreign Keys:** Ensure all Foreign Key (FK) columns defined in the BRA are explicitly mapped inside their respective entity blocks and carry the `FK` suffix label. If a column serves as both a primary and foreign key, label it `PK, FK`.

### Stage 3 — Relationship Line Construction
For each relationship defined in §5 of the BRA, construct one Mermaid relationship line using the authoritative cardinalities specified in §6.
| BRA notation | Token | Critical note |
|---|---|---|
| `(0,1)` | `o\|` | **Optional singular** — the `o` means zero is allowed. Do NOT use `\|\|` for this. |
| `(1,1)` | `\|\|` | **Mandatory singular** — both pipes mean exactly one, always present. |
| `(0,N)` or `(0,M)` | `o{` | Optional plural |
| `(1,N)` | `\|{` | Mandatory plural |

> ⚠️ **Most common error:** Confusing `(0,1)` with `(1,1)`. These are different tokens.
> `(0,1)` → `o|` (the entity is optional — it may not exist)
> `(1,1)` → `||` (the entity is mandatory — it must always exist)
> A BOOKING that has no UsageSession yet is `(0,1)` on the BOOKING side — use `o|`, never `||`.

**Line Assembly Rules:**
Given a BRA relationship `ENTITY_A (x,y) : (a,b) ENTITY_B`, construct the Mermaid line using this exact procedure:
1. Look up the token for ENTITY_A's cardinality `(x,y)` using the token table above → this becomes the **left token** (placed immediately left of `--`).
2. Look up the token for ENTITY_B's cardinality `(a,b)` → this becomes the **right token** (placed immediately right of `--`).
3. Format as: `ENTITY_A <left_token>--<right_token> ENTITY_B : "label"`

**The left token always belongs to ENTITY_A. The right token always belongs to ENTITY_B. Never swap them.**

Do not guess token placement by symmetry or by reading the label — always derive from the BRA cardinality values.

Mermaid relationship line syntax:
```
ENTITY_A left_token--right_token ENTITY_B : "label"
```

**Worked examples:**

BRA §6.1: `User (0,N) : (1,1) Booking` — User side = `o{`, Booking side = `||`
→ `USER o{--|| BOOKING : "requests"` ✅
→ `USER ||--o{ BOOKING` ❌ direction reversed

BRA §6.3: `Space (0,N) : (1,1) Booking` — Space side = `o{`, Booking side = `||`
→ `SPACE o{--|| BOOKING : "hosts"` ✅
→ `SPACE ||--o{ BOOKING` ❌ direction reversed

BRA §6.5: `Booking (0,1) : (1,1) UsageSession` — Booking side = `o|`, Session side = `||`
→ `BOOKING o|--|| USAGESESSION : "tracked by"` ✅
→ `BOOKING ||--|| USAGESESSION` ❌ **(0,1) ≠ (1,1) — BOOKING side must be `o|` not `||`**
The booking is optional from the session's perspective: not every booking has a session yet.
Treat `(0,1)` and `(1,1)` as strictly different tokens every time.

### Stage 4 — Mermaid Code Assembly
Assemble the final Mermaid block using this template structure:

````markdown
```mermaid
erDiagram

    %% ── Entities ──────────────────────────────────────────────
    ENTITY_1 {
        <attributes>
    }

    ENTITY_2 {
        <attributes>
    }

    %% ... one block per entity extracted from BRA §3 ...

    %% ── Relationships ─────────────────────────────────────────
    <relationship lines>
```
````

Formatting rules:
- Entity names in ALL_CAPS with no spaces (Mermaid convention).
- Attribute names in `snake_case`, matching BRA exactly.
- One attribute per line, indented 8 spaces inside the entity block.
- Relationship lines in the order they appear in §5 of the BRA.
- Each relationship line must be preceded by a `%%` comment on its own separate line citing the BRA source (e.g., `%% BRA §5.1 — User_Requests_Booking`). The comment must never appear on the same line as a relationship or attribute declaration.
- No fabricated attributes, entities, or relationships.
### Stage 5 — Self-Consistency Pre-Check

Before writing the final output, run through this checklist mentally and confirm each item:

```
[ ] Every BRA §4 attribute appears in the correct entity block, including all FK columns
[ ] FK-only columns carry the FK suffix label; 
[ ] Every BRA §5 relationship has exactly one Mermaid line
[ ] Every Mermaid line cardinality matches BRA §6 exactly
[ ] Multi-role User relationships have distinct labels 
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
- How multi-role relationships are represented and handled
- How M:N relationships are represented and handled

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

1. **No invention rule.** Every element in the ERD must trace to a specific line in the BRA. If something is not in the BRA, it does not appear in the ERD.

2. **No omission rule.** Every entity, attribute, and relationship defined in the BRA §3, §4, and §5 must appear in the ERD. Omitting anything that is in the BRA is an error.

3. **Cardinality fidelity rule.** Mermaid cardinality tokens must exactly reflect the (min,max) notation in BRA §6. Do not infer or adjust cardinalities.

4. **Role disambiguation rule.** Where User participates in multiple roles with the same entity, each role must be a distinct labeled relationship line. Collapsing them into one line is an error.

5. **FK inclusion rule.** All FK columns defined in BRA §4 must appear as attributes in their respective Mermaid entity blocks with the `FK` suffix label. Omitting FK columns is a violation of the no omission rule. The only special case is columns which carries both `PK, FK` labels (act simultaneously the primary key and a foreign key)
---
## 6. Known Mermaid Syntax Rules
- Entity names must be a single token (no spaces). e.g. Use `USAGESESSION`, not `USAGE SESSION`.
- Attribute type must precede attribute name: `VARCHAR(50) user_id PK`
- Data types with parentheses (e.g., `VARCHAR(50)`, `NVARCHAR(MAX)`) are valid in Mermaid `erDiagram` and must be written exactly as they appear in the BRA.
- Relationship label string is mandatory: the trailing `"label"` after the colon is requiredby Mermaid's parser. Empty strings `""` are allowed but discouraged — use a meaningful verb phrase.
- Both `o|`, `||`, `o{`, `|{` are valid crow's-foot tokens. Use `}` on the right side of a many-end: `||--o{` means "exactly one to zero-or-many".
- Comments use `%%` prefix and must always occupy their own dedicated line. Never place a `%%` comment on the same line as an attribute declaration or relationship line.
- Mermaid does not support composite or multi-valued attributes natively — document any such cases in the Design Decisions section instead of attempting to encode them.