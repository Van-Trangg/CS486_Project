---
name: db-review-step2
description: Instructs the agent to act as an independent reviewer and systematically validate a generated Mermaid ERD against a BRA document dynamically.
compatibility: opencode
---

## 1. Purpose
This skill instructs the agent to act as an independent reviewer and systematically validate the generated ERD produced in Step 2 (`02-erd-design-G02.md`) against the approved Business Requirement Analysis (`01-business-requirement-analysis-G02.md`). The reviewer must identify every deviation — missing, incorrect, or invented elements — and produce a structured review report with a clear readiness verdict.
This skill is executed **after** the Step 2 ERD is produced and **before** proceeding to
Step 3 (Logical Design). The goal is to catch errors at the cheapest possible stage.

---
## 2. Required Inputs
Both documents must be loaded and fully read before any review begins:

| Input | File | Role |
|---|---|---|
| Ground truth | `outputs/01-business-requirement-analysis-G02.md` | What the ERD must represent |
| Subject under review | `outputs/02-erd-design-G02.md` | What the ERD actually represents |

If either file is absent, halt and request it.

---

## 3. Review Pipeline
Execute each check in order. For each check, produce a result of PASS, WARN, or FAIL
with a specific justification. Do not produce vague summaries — cite exact line numbers,
entity names, and attribute names.

---

### Check 1 — Entity Completeness
**Procedure:**
1. Extract the list of entity names from BRA §3 and keep track of count (important)
2. Extract the list of entity names from the ERD Mermaid block.
3. Compare. Flag any entity present in BRA but absent in ERD (omission) or present in
   ERD but absent in BRA (invention).

**Pass condition:** ERD entity set = BRA entity set exactly. Count must match.

**Common failure modes:**
- Logical-level constructs that are not an conceptual entity in the BRA is included and added into the ERD.
- An entity from BRA §3 missing from the Mermaid block.

---

### Check 2 — Attribute Completeness and Accuracy
**Procedure:**
For each entity, compare BRA §4 attributes against ERD attributes line by line:

| Sub-check | What to verify |
|---|---|
| 2a. No omissions | Every BRA §4 attribute appears in the correct ERD entity block |
| 2b. No inventions | No attribute in ERD is absent from BRA §4 |
| 2c. Name fidelity | Attribute names match BRA exactly (no abbreviations, renames, or case changes) |
| 2d. Type fidelity | Every attribute's type token in the ERD matches the BRA §4 data type **verbatim** (e.g., `VARCHAR(50)`, `INT`, `DATETIME`, `NVARCHAR(MAX)`). The reviewer must scan every attribute line for the known-bad patterns listed below and flag any match as FAIL. |

**Check 2d — known-bad type patterns (scan every attribute line for these):**

| Pattern to scan for | Why it is wrong | Correct form |
|---|---|---|
| `string` | Generic alias, not a SQL type | `VARCHAR(n)` per BRA |
| `text` | Generic alias, not a SQL type | `NVARCHAR(MAX)` per BRA |
| `int` (lowercase) | Case mismatch; also a generic alias signal | `INT` |
| `datetime` (lowercase) | Case mismatch | `DATETIME` |
| `INT(Identity)` | Appends an implementation qualifier that is not a data type; also breaks Mermaid's parser when written as `INT (Identity)` with a space | `INT` — auto-increment is a Step 5 DDL concern |
| `INT (Identity)` (with space) | Same as above; the space additionally causes a Mermaid parse error | `INT` |
| Any `INT` variant with a parenthetical qualifier | e.g. `INT(1)`, `INT(11)`, `INT(PK)` — none of these are valid BRA types | `INT` unless BRA explicitly specifies otherwise |
| `VARCHAR` without length specifier | e.g. bare `VARCHAR` with no `(n)` | Must match BRA exactly, e.g. `VARCHAR(50)` |


**Pass condition:** All sub-checks pass for all entities.

---

### Check 3 — Relationship Completeness
**Procedure:**
1. List all relationships from BRA §5 by name.
2. For each, find the corresponding Mermaid relationship line in the ERD.
3. Flag any BRA relationship missing from the ERD (omission) or any ERD relationship
   line not traceable to BRA §5 (invention).

**Pass condition:** All relationships present in ERD; no extra relationships. Flag any collapsed multi-role relationships or unmentioned inventions.

---
### Check 4 — Cardinality Fidelity
**Procedure:**
For each relationship line in the ERD, **explicitly decode** the Mermaid crow's-foot tokens
back to (min,max) notation and compare against BRA §6. This check must be performed
mechanically, token by token — it must not be done by impression or by re-reading the
label. The reviewer must write out the decoded values for every relationship.
**Decoding reference — all valid Mermaid crow's foot token combinations:**

| Token (left or right of `--`) | Decoded (min,max) |
|---|---|
| `\|\|` | (1,1) — exactly one, mandatory |
| `o\|` | (0,1) — zero or one, optional singular |
| `\|o` | (0,1) — zero or one (right-side form) |
| `\|{` | (1,N) — one or many, mandatory plural |
| `o{` | (0,N) — zero or many, optional plural |
| `}\|` or `{\|` | (1,N) — one or many (alternative form) |
| `}o` or `{o` | (1,N) — one or many, **NOT (0,N)**. The `}` or `{` symbol means "many", and the adjacent `o` or `\|` indicates the minimum on the *other* end. When `}` faces the entity it describes, it means that entity has many instances — minimum is determined by the outer symbol. Specifically: `}o` = (1,N), `}|` = (1,N). Do NOT misread `}o` as (0,N). |

**Token disambiguation rule:** The token immediately adjacent to `--` (touching the dashes)
belongs to the entity on that side. Token characters further from `--` indicate the minimum
participation (o = optional/zero, | = mandatory/one). The character closest to the entity name
indicates multiplicity ({ or } = many, | = one).

**Strict Match equality rule:** The Match column must be YES if and only if the decoded
value is **character-for-character identical** to the BRA value. If the decoded value is
(1,N) and BRA says (0,N), the match is NO — even if the relationship "looks right" from the
label or context. The reviewer must not infer or assume correctness; only exact equality counts.
A reviewer who writes YES on a row where the decoded value differs from the BRA value has
made a verification error, and the entire Check 4 result is invalidated.

**Critical direction rule:** In a Mermaid relationship line of the form
`ENTITY_A token--token ENTITY_B`, the **left token** describes the cardinality of
**ENTITY_A** as seen from ENTITY_B's perspective (i.e., how many A's relate to one B),
and the **right token** describes the cardinality of **ENTITY_B** as seen from ENTITY_A's
perspective (i.e., how many B's relate to one A). Specifically:

- Left side of `--`: the token immediately to the left of `--` is the ENTITY_A cardinality.
- Right side of `--`: the token immediately to the right of `--` is the ENTITY_B cardinality.

Example: `USER ||--o{ BOOKING` → USER side = `||` = (1,1); BOOKING side = `o{` = (0,N).
This means: every Booking must have exactly 1 User; a User may have 0-or-many Bookings.
Compare against BRA §6: User (0,N) : Booking (1,1) — **this would be a mismatch and must be flagged**.


The reviewer **must dynamically generate and fill out** this table for every relationship found in the BRA before issuing a verdict:

| # | Relationship | ERD Left Token | ERD Entity A Decoded | BRA Entity A | Match? | ERD Right Token | ERD Entity B Decoded | BRA Entity B | Match? |

Any row with a NO in either Match column is a FAIL for this check.
**High-risk relationships to check carefully:**
- Any 1:N relationship: direction reversal — swapping which entity is the "many" side is the most common error and must be explicitly decoded, never assumed.
- Any relationship where one side is `(0,1)`: this is the second most common error. `(0,1)` decodes to `o|` and `(1,1)` decodes to `||`. These are different tokens. An agent that writes `||--||` when the BRA says `(0,1):(1,1)` has collapsed the optional side into mandatory. Treat every `||--||` line with suspicion — decode both sides from the BRA before accepting it.
**Pass condition:** All a×b cardinality comparisons (a per relationship × b relationships) match BRA §6.
*Anti-Rubber-Stamp Rule: If this decoded table is missing or left empty, the entire review is invalid.*

### Check 5 — Relationship Label Quality

**Procedure:**
For each Mermaid relationship line, check that:
- A label string is present (not empty `""`).
- The label is a verb phrase that accurately describes the direction of the relationship.
- Multi-role relationships between the same two entities have **distinct** labels that differentiate the roles.

**Pass condition:** All labels are present, meaningful, and distinct for multi-role pairs.

---

### Check 6 — Mermaid Syntax and Formatting Validity

**Procedure:**
Parse the Mermaid block for the following syntax errors and formatting violations:

| Rule | What to check |
|---|---|
| Entity names | Single token, no spaces (e.g., `USAGESESSION` not `USAGE SESSION`) |
| Attribute declarations | Type before name (e.g., `VARCHAR(50) user_id PK`) |
| Type verbatim | Types are BRA-exact, not generic aliases (covered in Check 2d; flag here too if found) |
| PK/FK suffixes | Space-separated after name: `INT booking_id PK, FK` |
| Relationship lines | Both sides have tokens, `--` separator present, colon present, label in quotes |
| No illegal characters | No special characters in entity/attribute names except `_` |
| **Inline comment prohibition — attributes** | No `%%` comment may appear on the same line as an attribute declaration. Any `%% Nullable`, `%% optional`, or any other annotation on an attribute line is a FAIL. Nullable status belongs in the Attribute Traceability table only. |
| **Inline comment prohibition — relationships** | No `%%` comment may appear on the same line as a relationship line (e.g., `USER \|\|--o{ BOOKING : "requests" %% BRA §5.1` is a FAIL). BRA source citations must be on their own preceding `%%` comment line. |
| **Comment placement** | Every `%%` comment must occupy its own dedicated line. A comment line must not contain a relationship or attribute declaration. |

**Pass condition:** No syntax errors and no formatting violations detected. Any inline comment
on an attribute or relationship line is an automatic FAIL for this check.

**Common failure pattern:** The agent may annotate nullable attributes with `%% Nullable`
inline and relationship lines with `%% BRA §5.X` inline. Both are explicit violations of the
design skill formatting rules and must be flagged.

---
### Check 7 — BRA Business Rule Traceability

**Procedure:**
For each business rule in BRA §7 that has a structural implication (i.e., requires a
specific entity, attribute, or relationship to exist), verify that the ERD structurally
supports it.
**Pass condition:** All rules with structural implications are satisfied by the ERD.

---
### Check 8 — Design Decisions Prose Accuracy

**Procedure:**
Read the §1 Design Decisions section of the ERD output document and verify the following:

| Sub-check | What to verify |
|---|---|
| 8a. No Chen reference | The prose must not claim the ERD uses "Chen notation" or "Chen-style" anything. Mermaid `erDiagram` renders crow's foot exclusively. Any Chen reference is factually wrong and must be flagged as FAIL. |
| 8b. Notation correctly named | The ERD notation must be described as "crow's foot notation" rendered via Mermaid `erDiagram`. |
| 8c. Multi-role representation described | The section must explain how multi-role relationships (where one entity participates in multiple distinct roles with another) are handled as separate labeled lines. |
| 8d. M:N relationships described | If any M:N relationship exists in the BRA, the section must state that it is represented as a direct line in the conceptual ERD and that any junction entity is deferred to Step 3 logical design. |
| 8e. No false claims | The section must not make technically incorrect statements about Mermaid's capabilities or the ERD's notation. |

**Pass condition:** All sub-checks pass. Any Chen notation reference is an automatic FAIL.

---
## 4. Review Report Format

> **OUTPUT PATH — MANDATORY**
> Save the review report to: `docs/02-erd-design-review-G02.md`
> Do NOT write to `outputs/` or any other directory.

Produce the review report as a Markdown file with this structure:

```
# Step 2 Review Report — ERD Validation

---

## Verdict

<One of: APPROVED / APPROVED WITH MINOR ISSUES / REQUIRES REVISION>

<Two to four sentences summarising the overall finding.>

---

## Check Results

| Check | Description | Result | Issues Found |
|---|---|---|---|
| 1 | Entity Completeness | PASS/WARN/FAIL | <count> issues |
| 2 | Attribute Completeness & Accuracy | PASS/WARN/FAIL | <count> issues |
| 3 | Relationship Completeness | PASS/WARN/FAIL | <count> issues |
| 4 | Cardinality Fidelity | PASS/WARN/FAIL | <count> issues |
| 5 | Relationship Label Quality | PASS/WARN/FAIL | <count> issues |
| 6 | Mermaid Syntax & Formatting | PASS/WARN/FAIL | <count> issues |
| 7 | Business Rule Traceability | PASS/WARN/FAIL | <count> issues |
| 8 | Design Decisions Prose Accuracy | PASS/WARN/FAIL | <count> issues |

---
## Detailed Findings

### Check N — <Name>
**Result:** PASS / WARN / FAIL

<For PASS: one sentence confirming what was verified.>
<For WARN or FAIL: itemised list of specific issues. Each issue must cite:>
- The exact element (entity name, attribute name, relationship name)
- What was found in the ERD
- What was expected per the BRA (cite BRA section)
- Severity: BLOCKING (must fix before Step 3) or ADVISORY (should fix, non-blocking)

---

## Required Changes Before Step 3

<Numbered list of all BLOCKING issues only, each with a specific correction instruction.>
<If no blocking issues: state "None — ERD is cleared to proceed to Step 3.">

---

## Recommended Improvements

<Numbered list of ADVISORY issues only. These do not block Step 3 but should be addressed.>
<If none: state "None.">
```

**Save output to: `docs/02-erd-design-review-G02.md` NOT `outputs/` or any other location.**

---

## 5. Verdict Criteria

| Verdict | Condition |
|---|---|
| **APPROVED** | All 8 checks PASS. No issues of any severity. |
| **APPROVED WITH MINOR ISSUES** | All checks PASS or WARN. Zero FAIL results. Zero BLOCKING issues. Advisory issues documented. |
| **REQUIRES REVISION** | Any check returns FAIL, OR any BLOCKING issue is found regardless of check result. ERD must be corrected and re-reviewed before Step 3. |

If the verdict is REQUIRES REVISION, the agent must:
1. List every blocking issue clearly.
2. Produce a corrected Mermaid block with all blocking issues resolved.
3. Re-run checks 1–8 on the corrected block and confirm all blocking issues are resolved.

**Anti-rubber-stamp rule:** An APPROVED verdict is only valid if the reviewer has
explicitly shown its work for Check 4 (the full decoding table must be present in the
report) and has read every attribute in every entity block for Check 2. A verdict issued
without the Check 4 decoding table present is invalid and must be rejected.

---
## 6. Reviewer Stance

The reviewer must treat the BRA as the single authoritative source. It is not the
reviewer's role to second-guess the BRA's design decisions — only to verify that the
ERD faithfully implements them.

The reviewer must not:
- Accept "close enough" cardinalities (e.g., `(1,N)` when BRA says `(0,N)`).
- Overlook collapsed multi-role relationships because "the meaning is implied."
- Skip attribute checks because the entity "looks right overall."
- Approve an ERD that has any BLOCKING issue, regardless of how minor it appears.

The reviewer must be constructive: every FAIL or WARN finding includes a specific,
actionable correction instruction, not just a description of what is wrong.