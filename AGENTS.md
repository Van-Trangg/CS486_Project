# AGENTS.md — cs486-demo

CS486 database systems teaching demo. Repository is empty; expect code to be added during sessions.

## Recurring context

- Root directory: 
- This is a demo project, not production.
- Run `ls -la` to detect new files before assuming anything exists.

# Database Design Agent Rules

This project transforms business requirements into database design artifacts.

## Workflow Order
Always follow this order:

1. Analyze business requirements.
2. Conceptual Database Design (ERD).
3. Logical Database Design (Relational schema).
4. Database Design Validation.
5. Database Implementation

Do not jump directly to DDL. The documents from the prior steps should be followed in the later steps.

## Required Outputs

- `outputs/01-business-requirement-analysis-G02.md`
- `outputs/02-erd-design-G02.md`
- `outputs/03-logical-design-G02.md`
- `outputs/04-design-validation-G02.md`
- `outputs/05-db-definition-G02.sql`

## DBMS

Use Microsoft SQL Server.

## Design Rules

- Record assumptions explicitly.
- Record open questions explicitly.
- Preserve traceability from requirement → entity → relationship → table → constraint.
- Use Mermaid `erDiagram` for ERD.
- Do not silently invent business rules.

## Quality Requirements
For every output:
- Use structured headings.
- Justify every identified entity (for BRA).
- Do not invent requirements that are not stated.
- Distinguish explicit requirements from assumptions.
- Provide traceability from requirement text to identified entities and relationships.
