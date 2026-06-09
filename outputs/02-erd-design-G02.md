# 02-erd-design-G02.md (Corrected)

## 1. Design Decisions
This ERD maps the entities and relationships required for the Campus Space Management System. The design reflects a centralized system tracking users, space management, booking, usage tracking, and maintenance. To handle the M:N relationship between `Space` and `Facility` without introducing junction entities, we define a direct relationship as requested. All entities include primary keys as defined in the Business Requirement Analysis, with foreign key relationships enforcing referential integrity.

## 2. Entity-Relationship Diagram

```mermaid
erDiagram
    %% 5.1
    USER o{--|| BOOKING : "submits"
    %% 5.2
    USER o{--o| BOOKING : "approves"
    %% 5.3
    SPACE o{--|| BOOKING : "hosts"
    %% 5.4
    SPACE o{--o{ FACILITY : "contains"
    %% 5.5
    BOOKING |o--|| USAGESESSION : "tracked by"
    %% 5.6
    USER o{--|| USAGESESSION : "checks in"
    %% 5.7
    USER o{--o| USAGESESSION : "checks out"
    %% 5.8
    SPACE o{--|| MAINTENANCERECORD : "requires"
    %% 5.9
    USER o{--|| MAINTENANCERECORD : "reports"
    %% 5.10
    USER o{--o| MAINTENANCERECORD : "assigned to"

    USER {
        VARCHAR(50) user_id PK
        VARCHAR(150) email
        VARCHAR(150) full_name
        VARCHAR(20) phone_number
        VARCHAR(50) role
        VARCHAR(100) department
        VARCHAR(20) account_status
    }

    SPACE {
        VARCHAR(50) space_code PK
        VARCHAR(100) space_name
        VARCHAR(50) space_type
        VARCHAR(50) building
        VARCHAR(10) floor
        VARCHAR(20) room_number
        INT capacity
        VARCHAR(20) current_status
        NVARCHAR(MAX) usage_policy
    }

    FACILITY {
        INT facility_id PK
        VARCHAR(100) facility_name
        NVARCHAR(MAX) facility_description
    }

    BOOKING {
        INT booking_id PK
        VARCHAR(50) space_code FK
        VARCHAR(50) requester_id FK
        DATETIME requested_start
        DATETIME requested_end
        VARCHAR(100) purpose
        INT expected_participants
        VARCHAR(30) booking_status
        DATETIME created_at
        VARCHAR(50) approver_id FK
        DATETIME decision_time
        NVARCHAR(MAX) decision_note
        VARCHAR(255) rejection_reason
    }

    USAGESESSION {
        INT booking_id PK
        VARCHAR(50) check_in_staff_id FK
        DATETIME actual_start
        NVARCHAR(MAX) initial_condition
        VARCHAR(50) check_out_staff_id FK
        DATETIME actual_end
        NVARCHAR(MAX) final_condition
        NVARCHAR(MAX) usage_notes
    }

    MAINTENANCERECORD {
        INT maintenance_id PK
        VARCHAR(50) space_code FK
        VARCHAR(50) reporter_id FK
        VARCHAR(50) assigned_staff_id FK
        VARCHAR(50) problem_type
        NVARCHAR(MAX) problem_description
        DATETIME start_time
        DATETIME completion_time
        VARCHAR(20) maintenance_status
        NVARCHAR(MAX) result_note
    }
```
