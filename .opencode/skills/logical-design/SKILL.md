---
name: logical-design
description: Guidelines for transforming an ERD and Business Requirements into a logical database design.
compatibility: opencode
---

# Logical Database Design Guidelines

This skill defines how to transform a conceptual ERD (`outputs/02-erd-design-G02.md`) and Business Requirements (`outputs/01-business-requirement-analysis-G02.md`) into a complete logical database design document for Microsoft SQL Server.

## Database Schema Design Rules

1. **Table and Column Mapping**:
   - Create a table for each entity in the ERD. Use UPPERCASE singular names for tables and lowercase `snake_case` for columns.
   - Resolve Many-to-Many (M:N) relationships using junction tables.
   - Map One-to-One (1:1) relationships correctly, typically by sharing primary keys or using unique foreign keys.

2. **Referential Integrity**:
   - Define foreign keys clearly.
   - Set referential actions appropriately. Use `ON DELETE CASCADE` for junction tables, and `ON DELETE NO ACTION` for transactions and logs to preserve history and auditability.

3. **Data Types and Nullability**:
   - Use compatible SQL Server data types (e.g. `VARCHAR`, `NVARCHAR` for Unicode/Vietnamese support, `INT`, `DATETIME`).
   - Specify correct nullability (primary keys and mandatory fields must be `NOT NULL`).

4. **Database Constraints**:
   - Define Primary Keys, Foreign Keys, and Unique constraints.
   - Add CHECK constraints for status/role enums and range/logic rules (e.g., positive capacities, date ordering like end_time > start_time).
   - Implement DEFAULT constraints where needed (e.g. created_at timestamps).

5. **Traceability Matrix**:
   - Include a table mapping every relational column back to its ERD attribute source and the business requirements reference.

## Document Format

Save the logical design to `outputs/03-logical-design-G02.md` using this layout:
- **1. Relational Schema Mapping Decisions**: Explain naming, M:N resolution, 1:1 setup, and referential actions.
- **2. Table Schema Specifications**: Tables detailing columns, types, nullability, keys, constraints, and descriptions.
- **3. Check and Constraint Specifications**: Declarative SQL constraint definitions.
- **4. Traceability Matrix**: Mappings back to ERD and requirements.
- **5. Assumptions and Open Questions**: List explicit design assumptions.
