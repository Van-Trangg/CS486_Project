---
name: erd-logical-update-review
description: Instructs the agent to act as an independent reviewer and systematically validate the updated ERD and logical design produced in Step 9 against the Step 8 requirement change analysis, the Phase 2 BRA, and the Phase 1 baseline.
compatibility: opencode
---

## 1. Purpose
This skill instructs the agent to act as an independent reviewer and systematically validate `outputs/09-updated-erd-and-logical-design-G02.md` against three sources: the Step 8 requirement change analysis (the scope authority), the Phase 2 BRA (the ground truth for exact wording), and the Phase 1 baseline artifacts (the thing being extended, which must survive largely intact). The reviewer must identify every deviation — missing changes, unjustified changes, incorrect changes, or damage to unaffected baseline elements — and produce a structured review report with a clear readiness verdict.

This skill runs **after** the Step 9 design skill and **before** Step 10 (Schema Migration). Because Step 9 is a delta task rather than a from-scratch build, this review has two jobs Step 2's review did not: (a) verify everything that should have changed did change, and (b) verify everything that should **not** have changed didn't.

---

## 2. Required Inputs
All of the following must be loaded and fully read before any review begins:

| Input | File | Role |
|---|---|---|
| Scope authority | `outputs/08-requirement-change-analysis-G02.md` | What must change, and what is explicitly left open for Step 9 to decide |
| Ground truth wording | `req/business-requirement-phase2.md` | Exact impact-level values, acknowledgement and concurrency wording |
| Phase 1 baseline (ERD) | `outputs/02-erd-design-G02.md` | What must NOT change without justification |
| Phase 1 baseline (logical) | `outputs/03-logical-design-G02.md` | What must NOT change without justification |
| Subject under review | `outputs/09-updated-erd-and-logical-design-G02.md` | What Step 9 actually produced |

If any file is absent, halt and request it.

---

## 3. Review Pipeline
Execute each check in order. For each check, produce a result of PASS, WARN, or FAIL with a specific justification. Cite exact Change IDs, entity names, attribute names, and section numbers — never a vague summary.

---

### Check 1 — Change Ledger Completeness
**Procedure:**
1. List every Change ID from Step 8 §2 (C08-01 through C08-05).
2. For each, confirm the Step 9 output's Change Scope Summary (§1) contains a corresponding row.
3. For each structural Change ID (C08-01, C08-02, C08-03, C08-04), confirm the required schema action actually appears in the updated ERD/schema (§3/§5) — not just named in the ledger.
4. Confirm C08-05 is correctly marked as no schema change (it is query/index scope for later steps), and that the Step 9 output does not fabricate unnecessary schema changes for it.

**Pass condition:** All 5 Change IDs are present in the ledger, and all structurally-required ones are visibly implemented in the diagram/schema.

---

### Check 2 — Open Question Resolution Completeness
**Procedure:**
1. List every row in Step 8 §11 whose "Affected Later Step" includes Step 9.
2. For each, confirm §2 of the Step 9 output (Design Decisions and Open-Question Resolutions) contains an explicit resolution: chosen representation + rationale + traceability to a Step 8 rule/conflict.
3. Flag any open question left unresolved, resolved only implicitly (e.g., a column appears with no accompanying rationale), or resolved in a way that contradicts the Step 8 "Working Assumption" without saying so.

**Pass condition:** All Step-9-assigned open questions have an explicit, rationale-backed resolution. An unresolved or silently-assumed open question is a FAIL, not a WARN — this is the Step 9 equivalent of an omission.

---

### Check 3 — Baseline Preservation
This check has two parts. Part (a) covers entities/tables untouched by any Change ID. Part (b) covers the *other* columns inside a table that a Change ID did touch — a table being MODIFIED does not excuse its unrelated columns from preservation. Both parts must run; passing (a) alone is not sufficient for a Check 3 PASS.

**3a — Unaffected Entities/Tables (Whole-Element Preservation)**
**Procedure:**
1. Build the full set of Phase 1 entities/attributes/relationships (from `02-erd-design-G02.md`) and Phase 1 tables/columns (from `03-logical-design-G02.md`).
2. Subtract every element referenced by a Change ID in the Step 9 Change Ledger — this is the "should not change" set of whole entities/tables/relationships.
3. Compare that set against the Step 9 updated ERD and schema, element by element.
4. Flag any unaffected element that was renamed, retyped, had its cardinality altered, had a comment removed, or was otherwise modified without a Change ID justifying it.

**Pass condition (3a):** Every unaffected Phase 1 entity/table/relationship is reproduced identically.

**3b — Modified Tables (Column-Level Preservation)**
**Procedure:**
1. For each table/entity that a Change ID DOES touch (e.g. `MAINTENANCERECORD`, `BOOKING`), list every Phase 1 column/attribute the table had **before** the change, from `02-erd-design-G02.md` / `03-logical-design-G02.md`.
2. Subtract only the specific column(s) the Change Ledger names for that table — this is the "should not change" set *within* the modified table.
3. Compare each remaining pre-existing column against the Step 9 output for that same table: name, type, nullability, key/constraint labels, and description must match exactly.
4. Flag any pre-existing, non-Change-ID column on a modified table that was dropped, renamed, retyped, or had its key/constraint status altered.

**Pass condition (3b):** Every pre-existing column on every modified table survives unchanged except the column(s) explicitly named by a Change ID. A dropped or silently altered unrelated column on a modified table is a FAIL, not a WARN — this is the specific failure mode 3b exists to catch, since 3a's whole-element diff cannot see inside a table that was legitimately touched elsewhere.

**Pass condition (overall):** Both 3a and 3b pass. Any unexplained drift in either part is a FAIL — silent edits to out-of-scope elements, whether a whole untouched table or one stray column on a touched table, are exactly the failure mode this check exists to catch.

---

### Check 4 — Bounded Invention Check
**Procedure:**
For every new entity, attribute, or relationship in the Step 9 ERD/schema that does not exist in the Phase 1 baseline:
1. Confirm it traces to either a Change Ledger row or a Stage-1-style resolution documented in §2 of the output.
2. Flag any new element with no traceability — an invention violation just as serious as a missing change.

**Pass condition:** Every new structural element has a stated justification. Zero unexplained additions.

---

### Check 5 — Value and Wording Fidelity
**Procedure:**
For any new attribute whose allowed values are defined by the Phase 2 BRA text (e.g., the maintenance impact-level values), verify the exact wording/casing used in the Step 9 output against Phase 2 BRA §1.1 verbatim.

Also scan every new/changed attribute line in the Step 9 output against this known-bad-patterns table:

| Pattern to scan for | Why it is wrong | Correct form |
|---|---|---|
| `string` | Generic alias, not a SQL type | `VARCHAR(n)` |
| `text` | Generic alias, not a SQL type | `NVARCHAR(MAX)` |
| `int` (lowercase) | Case mismatch; also a generic alias signal | `INT` |
| `datetime` (lowercase) | Case mismatch | `DATETIME` |
| `INT(Identity)` | Appends an implementation qualifier that is not a data type; also breaks Mermaid's parser when written with a space | `INT` — auto-increment is a Step 10 migration concern |
| `INT (Identity)` (with space) | Same as above; the space additionally causes a Mermaid parse error | `INT` |
| Any `INT` variant with a parenthetical qualifier | e.g. `INT(1)`, `INT(11)`, `INT(PK)` — none are valid types | `INT` unless explicitly justified |
| `VARCHAR` without length specifier | e.g. bare `VARCHAR` with no `(n)` | Must specify an explicit length, e.g. `VARCHAR(50)` |

**Pass condition:** All new attribute values and types match source wording exactly; no paraphrased enum values, no generic type aliases, no matches against the known-bad-patterns table above.

---

### Check 6 — Cardinality Fidelity (New/Changed Relationships Only)
**Procedure:**
For each relationship line marked NEW or MODIFIED in the Step 9 output's Relationship Delta Summary, **explicitly decode** the Mermaid crow's-foot tokens back to (min,max) notation and compare against the cardinality derived from Step 8 §5 and/or the corresponding §2 open-question resolution. This must be performed mechanically, token by token — not by impression, not by re-reading the label, and not skipped because "most of the diagram is unchanged."

**Decoding reference — all valid Mermaid crow's foot token combinations:**

| Token (left or right of `--`) | Decoded (min,max) |
|---|---|
| `\|\|` | (1,1) — exactly one, mandatory |
| `o\|` | (0,1) — zero or one, optional singular |
| `\|o` | (0,1) — zero or one (right-side form) |
| `\|{` | (1,N) — one or many, mandatory plural |
| `o{` | (0,N) — zero or many, optional plural |
| `}\|` or `{\|` | (1,N) — one or many (alternative form) |
| `}o` or `{o` | (1,N) — **NOT (0,N)**. The `}`/`{` symbol means "many"; the adjacent `o`/`\|` indicates the minimum on the *other* end. Do NOT misread `}o` as (0,N). |

**Token disambiguation rule:** the token immediately adjacent to `--` (touching the dashes) belongs to the entity on that side. The character further from `--` indicates the minimum participation (`o` = optional/zero, `\|` = mandatory/one); the character closest to the entity name indicates multiplicity (`{`/`}` = many, `\|` = one).

**Critical direction rule:** in a line of the form `ENTITY_A token--token ENTITY_B`, the token immediately next to `ENTITY_A` describes **ENTITY_A's own participation** in the relationship — how many instances of ENTITY_B a single ENTITY_A instance may relate to. Likewise the token next to `ENTITY_B` describes ENTITY_B's own participation. Example: `USER o{--|| BOOKING` → USER token `o{` = (0,N) is USER's own cardinality (one user may submit zero to many bookings); BOOKING token `||` = (1,1) is BOOKING's own cardinality (every booking requires exactly one user). Do NOT read the token next to an entity as a constraint imposed by the *other* entity — it is always that entity's own participation count, full stop.

**Independent-derivation rule (mandatory):** "Decoded" and "Expected" must come from two separate reads, not one:
- **Decoded A/B** is derived *only* by reading the literal crow's-foot token printed in the Step 9 Mermaid ERD line under review, and translating it via the decoding reference table above. The reviewer does not consult Step 8 or the §2 resolutions while doing this step.
- **Expected A/B** is derived *only* by reading the Step 8 §5 relationship text, the relevant §2 open-question resolution, or (for a foreign-key–driven new entity) the `NOT NULL`/nullable status of the FK column in the Step 9 output's §5 schema — never by reading the ERD's own token and echoing it back. The reviewer does not look at the diagram while doing this step.
- The **Expected A/B** column must contain a short quoted or closely paraphrased fragment of the source it was derived from, plus a citation (a Step 8 section number, a §2 resolution number, or the specific FK column and its nullability, e.g. "`booking_id NOT NULL FK` in §5.2.1 → ACK is the mandatory-single side"). A bare cardinality pair with no source fragment is an incomplete row and fails Check 6 on formality grounds alone, because it cannot be distinguished from a token copied out of the diagram.
- Only after both columns are independently filled does the reviewer compare them and mark Match? YES/NO.

**Strict Match equality rule:** the Match column is YES if and only if the decoded value is character-for-character identical to the expected value. If decoded is `(1,N)` and expected is `(0,N)`, the match is NO — even if the relationship "looks right" from the label or context. A reviewer who writes YES where the values differ has made a verification error, invalidating the entire Check 6 result.

The reviewer must dynamically generate and fill out this table for every NEW/MODIFIED relationship before issuing a verdict:

| # | Relationship | ERD Left Token | Decoded A | Expected A (quoted/paraphrased source + citation) | Match? | ERD Right Token | Decoded B | Expected B (quoted/paraphrased source + citation) | Match? |
|---|---|---|---|---|---|---|---|---|---|

**Pass condition:** All new/changed relationships match their derived cardinalities, with every Expected cell independently sourced and cited as above. Any `(0,1)` vs `(1,1)` confusion is a FAIL.

**No-repair rule (mandatory):** The reviewer is a validator, not a co-author. If Decoded and Expected do not match, the correct action is to mark that row **Match? NO**, mark Check 6 **FAIL**, and add a BLOCKING item to "Required Changes Before Step 10" describing exactly what the Step 9 output's ERD line currently says and what it must be changed to. The reviewer must never edit, "correct," or silently update the Mermaid diagram, the relationship table, or any other part of the artifact under review as part of running this check — doing so and then reporting PASS is a fabricated verdict, not a review, regardless of whether the correction the reviewer made was itself accurate. A review report containing any note describing an in-place correction made "during review" (e.g. "was updated during review from X to Y") is invalid on its face and must be rejected — the corrected artifact has to come back from a re-run of the Step 9 design skill, not from the reviewer's own edit.

*Anti-rubber-stamp rule: if this table is missing, empty, or has any Expected cell without a quoted/paraphrased source citation for any NEW/MODIFIED relationship, the review is invalid.*

---

### Check 7 — Scope Boundary Compliance
**Procedure:**
Confirm the Step 9 output does not contain migration SQL (Step 10 scope), a chosen/implemented concurrency mechanism such as an isolation level or locking strategy (Steps 11–13 scope), sample data (Step 14), or analytical queries/index recommendations (Steps 15–16). The concurrency section (§5.3 of the output) must describe schema support only — e.g., naming a version/rowversion column — and must explicitly state it is not choosing the enforcement mechanism.

**Pass condition:** No downstream-step content appears in the Step 9 output. A concurrency section that proposes a specific locking/isolation strategy is a FAIL — that decision belongs to Steps 11–13, and Step 9 overstepping it is itself a scope violation, not a bonus.

---

### Check 8 — Mermaid Syntax, Formatting, and Annotation
**Procedure:**
Parse the full updated Mermaid block for these syntax errors and formatting violations:

| Rule | What to check |
|---|---|
| Entity names | Single token, no spaces (e.g., `ACKNOWLEDGEMENT` not `BOOKING ACKNOWLEDGEMENT`) |
| Attribute declarations | Type before name (e.g., `VARCHAR(50) user_id PK`) |
| Type verbatim | Types are exact per Check 5's known-bad-patterns table; flag here too if found |
| PK/FK suffixes | Space-separated after name: `INT booking_id PK, FK` |
| Relationship lines | Both sides have tokens, `--` separator present, colon present, label in quotes |
| No illegal characters | No special characters in entity/attribute names except `_` |
| **Inline comment prohibition — attributes** | No `%%` comment may appear on the same line as an attribute declaration. Any nullable/optional annotation on an attribute line is a FAIL. |
| **Inline comment prohibition — relationships** | No `%%` comment may appear on the same line as a relationship line (e.g., `USER \|\|--o{ BOOKING : "requests" %% C08-01` is a FAIL). Citations must be on their own preceding `%%` comment line. |
| **Comment placement** | Every `%%` comment must occupy its own dedicated line and must not itself contain a relationship or attribute declaration. |

Additionally, for Step 9 specifically:
- Every NEW/MODIFIED entity block and relationship line must carry its own `%%` comment citing a Change ID.
- Every UNCHANGED entity block and relationship line must retain its original BRA-section comment exactly as it appears in the Phase 1 baseline (`02-erd-design-G02.md`), unaltered.

**Pass condition:** No syntax violations of any rule above; all new/changed elements traceable via comment to a Change ID; all unchanged elements retain original citations. Any inline comment on an attribute or relationship line is an automatic FAIL for this check.

---

### Check 9 — Attribute Traceability Accuracy
**Procedure:**
1. Confirm the Step 9 output's §6 Attribute Traceability table exists and contains one sub-table per new/changed entity.
2. For every new/changed attribute listed in §5 (Updated Logical Schema) or shown as NEW/MODIFIED in §3 (the ERD), confirm it has a corresponding row in §6.
3. For each §6 row, confirm the cited source (a Change ID, or a Stage 1 resolution number) actually matches that attribute — i.e., the Change Ledger row or Stage 1 resolution genuinely calls for that specific attribute, not a loosely related one from the same table.
4. Flag any new/changed attribute missing from §6, any §6 row citing a Change ID/resolution that does not actually justify that attribute, and any §6 row present for an attribute that was NOT actually changed (a stale or fabricated traceability entry).

**Pass condition:** §6 exists, covers every new/changed attribute with no omissions, and every citation in it is verifiably correct against the Change Ledger or Stage 1 resolutions — not just present, but accurate.

---

## 4. Review Report Format

> **OUTPUT PATH — MANDATORY**
> Save the review report to: `docs/09-updated-erd-and-logical-design-review-G02.md`
> Do NOT write to `outputs/` or any other directory.

```
# Step 9 Review Report — Updated ERD and Logical Design Validation

---

## Verdict

<One of: APPROVED / APPROVED WITH MINOR ISSUES / REQUIRES REVISION>

<Two to four sentences summarising the overall finding.>

---

## Check Results

| Check | Description | Result | Issues Found |
|---|---|---|---|
| 1 | Change Ledger Completeness | PASS/WARN/FAIL | <count> |
| 2 | Open Question Resolution Completeness | PASS/WARN/FAIL | <count> |
| 3a | Baseline Preservation — Unaffected Entities/Tables | PASS/WARN/FAIL | <count> |
| 3b | Baseline Preservation — Modified Table Columns | PASS/WARN/FAIL | <count> |
| 4 | Bounded Invention Check | PASS/WARN/FAIL | <count> |
| 5 | Value and Wording Fidelity | PASS/WARN/FAIL | <count> |
| 6 | Cardinality Fidelity (New/Changed) | PASS/WARN/FAIL | <count> |
| 7 | Scope Boundary Compliance | PASS/WARN/FAIL | <count> |
| 8 | Mermaid Syntax, Formatting & Annotation | PASS/WARN/FAIL | <count> |
| 9 | Attribute Traceability Accuracy | PASS/WARN/FAIL | <count> |

---

## Detailed Findings

### Check N — <name>
**Result:** PASS / WARN / FAIL

<For PASS: one sentence confirming what was verified.>
<For WARN or FAIL: itemised list. Each issue must cite:>
- The exact element (Change ID, entity name, attribute name, relationship name)
- What was found in the Step 9 output
- What was expected (per Step 8 section, Phase 2 BRA section, or Phase 1 baseline)
- Severity: BLOCKING (must fix before Step 10) or ADVISORY (should fix, non-blocking)

---

## Required Changes Before Step 10

<Numbered list of all BLOCKING issues only, each with a specific correction instruction.>
<If none: "None — updated design is cleared to proceed to Step 10.">

---

## Recommended Improvements

<Numbered list of ADVISORY issues only.>
<If none: "None.">
```

---

## 5. Verdict Criteria

| Verdict | Condition |
|---|---|
| **APPROVED** | All checks (1, 2, 3a, 3b, 4, 5, 6, 7, 8, 9) PASS. No issues of any severity. |
| **APPROVED WITH MINOR ISSUES** | All checks PASS or WARN. Zero FAIL results. Zero BLOCKING issues. |
| **REQUIRES REVISION** | Any check returns FAIL, OR any BLOCKING issue is found regardless of check result. |

If the verdict is REQUIRES REVISION, the agent must:
1. List every blocking issue clearly.
2. Produce a corrected updated-ERD/schema section with all blocking issues resolved.
3. Re-run checks 1–8 on the corrected version and confirm all blocking issues are resolved.

**Anti-rubber-stamp rule:** An APPROVED verdict is only valid if the reviewer has explicitly shown its work for Check 6 (the decoding table for every NEW/MODIFIED relationship must be present, with every Expected cell independently sourced and cited — never derived from the diagram itself) and has performed the full element-by-element comparison for both Check 3a (unaffected entities/tables) and Check 3b (column-level diff on every modified table) rather than a spot check of either. A verdict issued without all three pieces of shown work is invalid and must be rejected. Passing 3a alone, with 3b skipped on the theory that "the table is already flagged as modified," is itself a rubber-stamp failure. Likewise, a verdict is invalid if the reviewer edited the artifact under review to force a match instead of reporting a mismatch as a BLOCKING correction.

---

## 6. Reviewer Stance

The reviewer must treat Step 8 as the authoritative scope document and the Phase 1 baseline as the authoritative "do not touch without cause" document: Step 8 says *what* may change, Phase 1 says *what must not*.

The reviewer must not:
- Accept an unresolved open question because "the intent is clear from context."
- Overlook a silent edit to an unaffected baseline element because "it's a small tweak."
- Approve a new entity/attribute with no stated justification because "it seems reasonable."
- Let a concurrency section pass because it "sounds like a good mechanism" — mechanism choice is out of scope for this step regardless of quality.
- Approve any output with a BLOCKING issue, regardless of how minor it appears.
- Skip Check 3b on a modified table because the table is "already accounted for" in the Change Ledger — a table having one legitimate change does not vouch for its other columns.
- Accept a §6 Attribute Traceability row at face value without confirming the cited Change ID or Stage 1 resolution actually justifies that specific attribute.
- Edit, patch, or "correct" the Step 9 artifact under review as part of performing any check, then report the corrected state as if it were what the artifact already contained. The reviewer's role ends at producing findings and BLOCKING correction instructions; making the artifact match its own findings and calling that a PASS is a fabricated verdict, not a review. This applies to every check, not only Check 6 — a reviewer that silently fixes a Change Ledger gap, adds a missing traceability row, or renames a column back to its baseline value has stopped reviewing and started ghostwriting the artifact it is supposed to be independently validating.
- Derive an "Expected" value in Check 6 (or any similar decode-and-compare check) by reading the artifact's own output rather than the independent source — this collapses the comparison into a tautology and guarantees a match regardless of correctness.

The reviewer must be constructive: every FAIL or WARN finding includes a specific, actionable correction instruction, not just a description of what is wrong.