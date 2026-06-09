---
name: db-review-step2
description: This skill instructs the agent to act as an independent reviewer and systematically validate the ERD produced in Step 2 against the approved Business Requirement Analysis
compatibility: opencode
-----------------------

## 1. Purpose

This skill instructs the agent to act as an independent reviewer and systematically
validate the ERD produced in Step 2 (`02-erd-design-G02.md`) against the approved
Business Requirement Analysis (`01-business-requirement-analysis-G02.md`). The
reviewer must identify every deviation — missing, incorrect, or invented element — and
produce a structured review report with a clear readiness verdict.

This skill is executed **after** the Step 2 ERD is produced and **before** proceeding to
Step 3 (Logical Design). The goal is to catch errors at the cheapest possible stage.

---

## 2. Required Inputs

Both documents must be loaded and fully read before any review begins:

| Input | File | Role |
|---|---|---|
| Ground truth | `outputs/01-business-requirement-analysis-G02.md` | What the ERD must represent |
| Subject under review | `docs/02-erd-design-G02.md` | What the ERD actually represents |

If either file is absent, halt and request it.

---

## 3. Review Pipeline

Execute each check in order. For each check, produce a result of PASS, WARN, or FAIL
with a specific justification. Do not produce vague summaries — cite exact line numbers,
entity names, and attribute names.

---

### Check 1 — Entity Completeness

**Procedure:**
1. Extract the list of entity names from BRA §3.
2. Extract the list of entity names from the ERD Mermaid block.
3. Compare. Flag any entity present in BRA but absent in ERD (omission) or present in
   ERD but absent in BRA (invention).

**Pass condition:** ERD entity set = BRA entity set exactly. Count must be 6.

**Common failure modes:**
- `SpaceFacility` added as an entity in the ERD (it is a logical-level construct, not a
  conceptual entity in the BRA).
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
| 2d. Type fidelity | Every attribute's type token in the ERD matches the BRA §4 data type **verbatim** (e.g., `VARCHAR(50)`, `INT`, `DATETIME`, `NVARCHAR(MAX)`, `INT(Identity)`). Generic aliases such as `string`, `text`, `int`, or `datetime` are WRONG and must be flagged as FAIL. |
| 2e. PK labelling | PK attributes carry the `PK` suffix; the shared key `UsageSession.booking_id` carries `PK, FK` |
| 2f. FK exclusion | FK-only columns (e.g., `requester_id`, `space_code` in Booking) do not appear as attributes in the Mermaid block |

**Pass condition:** All sub-checks pass for all 6 entities.

**Special attention:**
- `UsageSession.booking_id` must appear with `PK, FK` — it is the only attribute that
  is both a primary key and a foreign key at the conceptual level.
- `check_out_staff_id` in UsageSession must use exactly this name (the BRA was
  previously inconsistent — the final version uses `check_out_staff_id`).
- `MaintenanceRecord` must include `problem_type` (added in the final BRA revision).

---

### Check 3 — Relationship Completeness

**Procedure:**
1. List all 10 relationships from BRA §5 by name.
2. For each, find the corresponding Mermaid relationship line in the ERD.
3. Flag any BRA relationship missing from the ERD (omission) or any ERD relationship
   line not traceable to BRA §5 (invention).

Expected relationships (from BRA §5):

| # | BRA Name | Entity A | Entity B |
|---|---|---|---|
| 5.1 | User_Requests_Booking | User | Booking |
| 5.2 | User_Approves_Booking | User | Booking |
| 5.3 | Space_Hosts_Booking | Space | Booking |
| 5.4 | Space_Equipped_With_Facility | Space | Facility |
| 5.5 | Booking_Has_UsageSession | Booking | UsageSession |
| 5.6 | User_ChecksIn_UsageSession | User | UsageSession |
| 5.7 | User_ChecksOut_UsageSession | User | UsageSession |
| 5.8 | Space_Requires_Maintenance | Space | MaintenanceRecord |
| 5.9 | User_Reports_Maintenance | User | MaintenanceRecord |
| 5.10 | User_Assigned_To_Maintenance | User | MaintenanceRecord |

**Pass condition:** All 10 relationships present in ERD; no extra relationships.

**Critical failure modes:**
- Relationships 5.1 and 5.2 collapsed into one line (User→Booking must appear twice,
  with distinct labels `"requests"` and `"approves"`).
- Relationships 5.6 and 5.7 collapsed (User→UsageSession must appear twice).
- Relationships 5.9 and 5.10 collapsed (User→MaintenanceRecord must appear three
  times total: reports, approves/decides, assigned to — wait, 5.9 and 5.10 are two of
  three distinct User→MaintenanceRecord roles).

---

### Check 4 — Cardinality Fidelity

**Procedure:**
For each relationship line in the ERD, **explicitly decode** the Mermaid crow's-foot tokens
back to (min,max) notation and compare against BRA §6. This check must be performed
mechanically, token by token — it must not be done by impression or by re-reading the
label. The reviewer must write out the decoded values for every relationship.

**Decoding reference:**

| Mermaid token pair | Decoded (min,max) |
|---|---|
| `\|\|` | (1,1) — exactly one |
| `o\|` | (0,1) — zero or one |
| `\|{` | (1,N) — one or many |
| `o{` | (0,N) — zero or many |

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

The reviewer must produce the following table for all 10 relationships before issuing a result:

| # | Relationship | ERD left token | ERD Entity A decoded | BRA Entity A | Match? | ERD right token | ERD Entity B decoded | BRA Entity B | Match? |
|---|---|---|---|---|---|---|---|---|---|
| 5.1 | USER→BOOKING (requests) | | | (0,N) | | | | (1,1) | |
| 5.2 | USER→BOOKING (approves) | | | (0,N) | | | | (0,1) | |
| 5.3 | SPACE→BOOKING (hosts) | | | (0,N) | | | | (1,1) | |
| 5.4 | SPACE→FACILITY (equipped) | | | (0,N) | | | | (0,N) | |
| 5.5 | BOOKING→USAGESESSION | | | (0,1) | | | | (1,1) | |
| 5.6 | USER→USAGESESSION (checks in) | | | (0,N) | | | | (1,1) | |
| 5.7 | USER→USAGESESSION (checks out) | | | (0,N) | | | | (0,1) | |
| 5.8 | SPACE→MAINTENANCERECORD | | | (0,N) | | | | (1,1) | |
| 5.9 | USER→MAINTENANCERECORD (reports) | | | (0,N) | | | | (1,1) | |
| 5.10 | USER→MAINTENANCERECORD (assigned) | | | (0,N) | | | | (0,1) | |

Any row with a NO in either Match column is a FAIL for this check.

**Pass condition:** All 20 cardinality comparisons (2 per relationship × 10 relationships) match BRA §6.

**High-risk relationships to check carefully:**

| Relationship | BRA §6 | Common mistake |
|---|---|---|
| Space↔Facility (5.4) | (0,N):(0,N) — both optional | Drawing Space side as (1,N) — mandatory |
| Booking↔UsageSession (5.5) | (0,1):(1,1) — Booking optional, Session mandatory | Reversing the mandatory side |
| User→Booking approver (5.2) | (0,N):(0,1) — both optional | Making Booking side mandatory |
| User→UsageSession check-out (5.7) | (0,N):(0,1) — both optional | Making UsageSession side mandatory |
| Any 1:N relationship | Entity A side should be (0,N) or (1,N) | **Direction reversal** — swapping which entity is the "many" side is the most common error and must be explicitly decoded, never assumed |

---

### Check 5 — Relationship Label Quality

**Procedure:**
For each Mermaid relationship line, check that:
- A label string is present (not empty `""`).
- The label is a verb phrase that accurately describes the direction of the relationship.
- Multi-role relationships between the same two entities have **distinct** labels that
  differentiate the roles.

**Pass condition:** All labels are present, meaningful, and distinct for multi-role pairs.

**Specific label expectations:**
- User→Booking: one line labelled `"requests"` (or equivalent), one labelled `"approves"`.
- User→UsageSession: one labelled `"checks in"`, one labelled `"checks out"`.
- User→MaintenanceRecord: one labelled `"reports"`, one labelled `"assigned to"`.

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

Key rules with structural implications:

| BRA Rule | Structural requirement in ERD |
|---|---|
| Rule 11 (Double Booking Prevention) | `Booking` has `requested_start`, `requested_end`, `booking_status`, and is linked to `Space` |
| Rule 12 (Unavailable Spaces Blocked) | `Space` has `current_status`; `MaintenanceRecord` has `start_time`, `completion_time`, `maintenance_status`; Space linked to MaintenanceRecord |
| Rule 13 (Approval Tracking) | `Booking` has `approver_id` (via User→Booking approver relationship), `decision_time`, `decision_note` |
| Rule 14 (Rejection Justification) | `Booking` has `rejection_reason` |
| Rule 15 (Check-in Logging) | `UsageSession` has `actual_start`, `initial_condition`, `check_in_staff_id` (via relationship) |
| Rule 16 (Completion Logging) | `UsageSession` has `actual_end`, `final_condition`, `usage_notes` |
| Rule 17 (Maintenance Logging) | `MaintenanceRecord` has all required attributes; linked to Space, reporter User, and assigned User |
| Rule 19 (Capacity Limit) | `Space` has `capacity`; `Booking` has `expected_participants` |

**Pass condition:** All rules with structural implications are satisfied by the ERD.

---

### Check 8 — Design Decisions Prose Accuracy

**Procedure:**
Read the §1 Design Decisions section of the ERD output document and verify the following:

| Sub-check | What to verify |
|---|---|
| 8a. No Chen reference | The prose must not claim the ERD uses "Chen notation" or "Chen-style" anything. Mermaid `erDiagram` renders crow's foot exclusively. Any Chen reference is factually wrong and must be flagged as FAIL. |
| 8b. Notation correctly named | The ERD notation must be described as "crow's foot notation" rendered via Mermaid `erDiagram`. |
| 8c. Multi-role representation described | The section must explain how multi-role User relationships (requester/approver, check-in/check-out, reporter/assigned) are handled as separate labeled lines. |
| 8d. M:N Space↔Facility described | The section must state that the M:N relationship is rendered as a direct line and that the junction table is deferred to Step 3. |
| 8e. No false claims | The section must not make technically incorrect statements about Mermaid's capabilities or the ERD's notation. |

**Pass condition:** All sub-checks pass. Any Chen notation reference is an automatic FAIL.

---

## 4. Review Report Format

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

Save output in: `docs/02-erd-design-review-G02.md`

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
explicitly shown its work for Check 4 (the full 10-row decoding table must be present in the
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