---
name: database-implementation
description: Generate a complete Microsoft SQL Server DDL implementation from the validated logical design, applying only mandatory schema fixes identified during design validation.
compatibility: opencode
---

## 1. Purpose

This skill instructs the agent to generate a complete, executable SQL DDL script for Microsoft SQL Server.

The objective is to:

* Exactly implement the Logical Database Design from Step 3.
* Apply only mandatory schema fixes identified during Step 4 validation.
* Preserve all approved design decisions.
* Prevent the introduction of undocumented schema elements.

The generated DDL must remain fully traceable to the validated design.

The output is saved as:

`outputs/05-db-definition-G02.sql`

---

## 2. Required Inputs

Before beginning, the agent MUST load and fully read:

* `outputs/03-logical-design-G02.md`
* `outputs/04-design-validation-G02.md`

If any required file is unavailable:

* Halt execution.
* Request the missing file.
* Do not proceed from memory.
* Do not infer missing information.

---

## 3. Source Authority (Conflict Resolution)

When conflicting information exists, use the following priority order.

Higher-priority sources override lower-priority sources.

1. Mandatory schema fixes identified in Step 4.
2. Relational schema definitions in Step 3.
3. Supporting explanations in Step 3.
4. Examples and illustrations.

---

## 4. Execution Pipeline

Execute the following stages in strict order.

### Stage 1 — Parse Logical Design (Step 3)

Extract exactly:

#### Tables

* Table names

#### Columns

* Column names
* Data types
* Nullability
* Default values

#### Keys

* Primary keys
* Foreign keys
* Composite primary keys
* Composite foreign keys
* Candidate keys
* Alternate keys

#### Constraints

* UNIQUE constraints
* CHECK constraints
* DEFAULT constraints

#### Referential Integrity

* ON DELETE actions
* ON UPDATE actions

Record all schema elements exactly as defined.

Do not infer additional schema objects.

---

### Stage 2 — Identify Mandatory Schema Fixes

Review the Design Validation report.

A schema modification is permitted only if ALL of the following conditions are satisfied:

#### Requirement 1

The issue is classified as:

```text
High Risk
```

#### Requirement 2

The issue explicitly identifies a business-rule violation.

#### Requirement 3

The violation cannot be resolved through:

* Application logic
* Triggers
* Stored procedures
* Operational procedures
* User workflows

#### Requirement 4

The recommendation explicitly requires modification of the database schema.

Only issues satisfying all four requirements are considered mandatory schema fixes.

---

### Stage 3 — Ignore Non-Mandatory Recommendations

The following findings MUST NOT modify the schema:

#### Risk Levels

* Medium Risk
* Low Risk

#### Recommendation Types

* Future enhancements
* Optional improvements
* Performance recommendations
* Index recommendations
* Trigger recommendations
* Stored procedure recommendations
* Application-level validations

Examples include:

* Double-booking prevention
* Capacity validation
* Future-time validation
* Maintenance scheduling logic
* Role-based approval restrictions
* Workflow restrictions

Document these limitations if necessary, but do not modify the schema.

---

### Stage 4 — Apply Mandatory Fixes

Begin with the exact schema defined in Step 3.

Apply only mandatory fixes identified during Stage 2.

For every modification:

* Preserve the original schema wherever possible.
* Modify only the affected schema element.
* Add a SQL comment documenting the change.

Example:

```sql
-- Step 4 High-Risk Fix (BR-18)
-- Historical records must be preserved.
-- Changed ON DELETE CASCADE to ON DELETE NO ACTION.
```

No additional modifications are permitted.

---

### Stage 5 — Generate SQL DDL Script

Write a single SQL file.

#### 5.0 Database Creation and Context

The script **must** create and use a dedicated database to avoid polluting the `master` database.
Use the database name from the project context. If no name is given, default to `University`.

Generate the following immediately after the header comment:

```sql
-- ============================================================
-- Database creation and context
-- ============================================================
IF DB_ID('University') IS NULL
    CREATE DATABASE University;
GO

USE University;
GO
```

#### 5.1 Header Comment

Example:

```sql
-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 5: Database Implementation (DDL)
-- Based on Step 3 logical design with mandatory fixes from Step 4
-- ============================================================
```

#### 5.2 Cleanup Section

Generate a drop section that removes **all** objects the script might create, in correct dependency order:

1. Triggers (if defined in Step 3)
2. Tables (child → parent)
3. Functions (if defined in Step 3)

Use `DROP … IF EXISTS` for everything. After the drop block, a single `GO`.

Example:

```sql
DROP TRIGGER IF EXISTS TR_BOOKING_STATUS_AND_AUDIT;
DROP TRIGGER IF EXISTS TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE;
DROP TABLE IF EXISTS MAINTENANCERECORD;
DROP TABLE IF EXISTS USAGESESSION;
DROP TABLE IF EXISTS BOOKING;
DROP TABLE IF EXISTS SPACE_FACILITY;
DROP TABLE IF EXISTS FACILITY;
DROP TABLE IF EXISTS SPACE;
DROP TABLE IF EXISTS [USER];
DROP FUNCTION IF EXISTS dbo.fn_CheckSpaceCapacity;
GO
```

### Stage 5.2.1 — Reserved Keyword Handling

Before generating SQL identifiers, verify whether any table name, column name, constraint name, or other schema identifier matches a Microsoft SQL Server reserved keyword.

Examples include (not exhaustive):

* USER
* ORDER
* GROUP
* TABLE
* INDEX
* KEY
* SELECT
* INSERT
* UPDATE
* DELETE
* PRIMARY
* FOREIGN
* REFERENCES
* VIEW
* TRIGGER

If an identifier matches a reserved keyword or contains characters that require escaping (such as spaces or special characters), the generated SQL MUST preserve the original schema name and delimit the identifier using SQL Server square brackets.

Examples:

```
[USER]
[ORDER]
[GROUP]
[Employee Name]
```

Example:

```
CREATE TABLE [USER] (
    [user_id] INT NOT NULL,

    CONSTRAINT PK_USER
        PRIMARY KEY ([user_id])
);
```

Do not rename schema objects unless Step 3 explicitly defines a different name.

The purpose of this rule is SQL Server compatibility only and must not be treated as a schema modification.

---

### Identifier Safety

When generating SQL Server DDL:

* Preserve all table names from Step 3 exactly.
* Preserve all column names from Step 3 exactly.
* Preserve all constraint names from Step 3 exactly.
* If an identifier contains spaces, special characters, or reserved keywords, wrap it in square brackets.
* Constraint names should only be bracketed when required by SQL Server syntax.

Example:

```
CREATE TABLE [USER] (
    [user_id] INT NOT NULL,
    [full name] NVARCHAR(100) NOT NULL,

    CONSTRAINT PK_USER
        PRIMARY KEY ([user_id])
);
```

Do not rename identifiers solely to avoid SQL Server reserved keywords.

This rule exists only to ensure SQL Server compatibility while preserving traceability to Step 3.


#### 5.3 Table Creation

Generate:

```sql
CREATE TABLE ...
```

Requirements:

* Parent tables before child tables.
* Explicit constraint declarations.
* Explicit constraint names.

**CRITICAL: DEFAULT constraints MUST be defined inline on the column definition, NOT as a separate table-level `CONSTRAINT ... DEFAULT ... FOR column` clause.**  
Use the form:

```sql
column_name data_type NOT NULL CONSTRAINT DF_Table_Column DEFAULT default_value,
```

Do **not** use:

```sql
column_name data_type NOT NULL,
...
CONSTRAINT DF_Table_Column DEFAULT default_value FOR column_name,
```

This ensures compatibility across all SQL Server environments.

After each table:

```sql
GO
```

#### 5.4 Referential Integrity

If Step 3 explicitly defines:

* ON DELETE
* ON UPDATE

the generated SQL must match exactly.

If Step 3 omits the action, the agent may emit SQL Server's default behavior explicitly:

```sql
ON DELETE NO ACTION
ON UPDATE NO ACTION
```

for implementation clarity.

If Step 4 requires a mandatory correction, implement the corrected action.

#### 5.5 No Extra Objects

Do not create:

* Views
* Triggers
* Stored procedures
* Functions
* Indexes

unless explicitly defined in Step 3.

---

### Stage 6 — Verification

Before finalizing, verify:

#### Completeness

Every Step 3:

* Table
* Column
* Primary Key
* Foreign Key
* UNIQUE constraint
* CHECK constraint
* DEFAULT constraint

exists in the generated SQL.

Except where modified by a mandatory Step 4 fix.

#### Count Verification

Verify:

```text
Number of tables in Step 3
=
Number of tables in generated SQL
```

#### Constraint Verification

Verify:

```text
Primary Keys in Step 3
=
Primary Keys in generated SQL

Foreign Keys in Step 3
=
Foreign Keys in generated SQL
```

except where modified by mandatory fixes.

#### Purity Verification

Verify that no additional:

* Tables
* Columns
* Constraints
* Defaults
* Foreign keys
* Indexes
* Database objects

have been introduced.

#### SQL Server Compatibility

Verify:

* Valid T-SQL syntax.
* Uses DROP TABLE IF EXISTS.
* Uses GO separators.
* Script can be executed repeatedly without error.
* **All DEFAULT constraints are inline on columns**, not table-level with `FOR column`.

---

## 5. Naming Convention

All constraints MUST be explicitly named.

| Constraint Type    | Pattern                         |
| ------------------ | ------------------------------- |
| Primary Key        | `PK_<Table>`                    |
| Foreign Key        | `FK_<ChildTable>_<ParentTable>` |
| Unique Constraint  | `UQ_<Table>_<Column>`           |
| Check Constraint   | `CK_<Table>_<Description>`      |
| Default Constraint | `DF_<Table>_<Column>`           |

These conventions apply equally to single-column and composite constraints.

---

## 6. Critical Constraints

### 1. Do Not Redesign the Schema

Implement the validated design.

Do not redesign it.

---

### 2. Do Not Invent Schema Elements

Do not invent:

* Tables
* Columns
* Primary Keys
* Foreign Keys
* Unique Constraints
* Check Constraints
* Default Values
* Indexes
* Views
* Triggers
* Stored Procedures
* Functions

unless explicitly defined in Step 3 or required by a mandatory Step 4 fix.

---

### 3. Mandatory Fixes Only

Apply schema changes only when:

* The issue is High Risk.
* A business rule is violated.
* The violation requires schema modification.
* Step 4 explicitly recommends a schema change.

---

### 4. No Assumptions

Do not infer:

* Missing constraints
* Missing relationships
* Missing defaults
* Missing foreign keys
* Missing referential actions

based on best practices or personal judgment.

Only implement documented requirements.

---

### 5. No Optional Recommendations

Ignore:

* Medium Risk findings
* Low Risk findings
* Future enhancements
* Trigger suggestions
* Application-level validations

Do not implement them.

---

### 6. No Sample Data

Do not generate:

```sql
INSERT
UPDATE
DELETE
MERGE
```

statements.

Data population belongs to Step 6.

---

### 7. SQL Server Compatibility

The generated script must:

* Execute successfully on Microsoft SQL Server.
* Be rerunnable.
* Use valid T-SQL syntax.
* Use `DROP TABLE IF EXISTS`.
* Use `GO` separators.

---

## 7. Output Format

Save the generated file exactly as:

`outputs/05-db-definition-G02.sql`

The output file must contain:

1. Header Comment
2. Cleanup Section
3. CREATE TABLE Statements
4. Constraint Definitions
5. Referential Integrity Definitions

The output must contain executable SQL only.

Do not include:

* Markdown
* Analysis
* Explanations
* Summaries

outside SQL comments required for mandatory fixes.

---

## 8. Final Checklist

Before signaling completion, verify:

* [ ] All Step 3 tables are present.
* [ ] Every Step 3 column matches exactly.
* [ ] Every Step 3 constraint is implemented.
* [ ] All mandatory High-Risk fixes from Step 4 are applied.
* [ ] Every mandatory fix is documented with SQL comments.
* [ ] No optional recommendations have been implemented.
* [ ] No additional schema elements have been introduced.
* [ ] The script is valid T-SQL.
* [ ] The script can be executed repeatedly on SQL Server.
* [ ] Output file name is exactly `outputs/05-db-definition-G02.sql`.
* [ ] All DEFAULT constraints are defined inline on columns (not with `FOR column`).
* [ ] The script creates and uses a dedicated database (not master).
* [ ] The cleanup section drops all triggers and functions, not just tables.

Save the file and signal completion.
