# 02-erd-design-G02.md

## 1. Design Decisions
This ERD maps the entities and relationships required for the Campus Space Management System. The design reflects a centralized system tracking users, space management, booking, usage tracking, and maintenance. To handle the M:N relationship between `Space` and `Facility` without introducing junction entities, we define a direct relationship as requested. All entities include primary keys as defined in the Business Requirement Analysis, with foreign key relationships enforcing referential integrity.

## 2. Entity-Relationship Diagram

```mermaid
erDiagram
    %% Relationships sourced from §5 of BRA
    USER o{--|| BOOKING : "submits"
    USER o{--o| BOOKING : "approves"
    SPACE o{--|| BOOKING : "hosts"
    SPACE }o--o{ FACILITY : "contains"
    BOOKING ||--|o USAGESESSION : "tracked by"
    USER o{--|| USAGESESSION : "checks in"
    USER o{--o| USAGESESSION : "checks out"
    SPACE o{--|| MAINTENANCERECORD : "requires"
    USER o{--|| MAINTENANCERECORD : "reports"
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
        INT booking_id PK, FK
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

## 3. Relationship Summary Table

| Relationship | Entities | Cardinality | Participation | Source BRA § |
| :--- | :--- | :--- | :--- | :--- |
| User_Requests_Booking | USER:BOOKING | (0,N):(1,1) | Optional:Mandatory | 5.1 |
| User_Approves_Booking | USER:BOOKING | (0,N):(0,1) | Optional:Optional | 5.2 |
| Space_Hosts_Booking | SPACE:BOOKING | (0,N):(1,1) | Optional:Mandatory | 5.3 |
| Space_Equipped_With_Facility | SPACE:FACILITY | (0,M):(0,N) | Optional:Optional | 5.4 |
| Booking_Has_UsageSession | BOOKING:USAGESESSION | (0,1):(1,1) | Optional:Mandatory | 5.5 |
| User_ChecksIn_UsageSession | USER:USAGESESSION | (0,N):(1,1) | Optional:Mandatory | 5.6 |
| User_ChecksOut_UsageSession | USER:USAGESESSION | (0,N):(0,1) | Optional:Optional | 5.7 |
| Space_Requires_Maintenance | SPACE:MAINTENANCERECORD | (0,N):(1,1) | Optional:Mandatory | 5.8 |
| User_Reports_Maintenance | USER:MAINTENANCERECORD | (0,N):(1,1) | Optional:Mandatory | 5.9 |
| User_Assigned_To_Maintenance | USER:MAINTENANCERECORD | (0,N):(0,1) | Optional:Optional | 5.10 |

## 4. Attribute Traceability

### 4.1. USER
| Attribute | PK/FK | Nullable | Data Type | Source |
| :--- | :--- | :--- | :--- | :--- |
| user_id | PK | No | VARCHAR(50) | BRA 4.1 |
| email | - | No | VARCHAR(150) | BRA 4.1 |
| full_name | - | No | VARCHAR(150) | BRA 4.1 |
| phone_number | - | Yes | VARCHAR(20) | BRA 4.1 |
| role | - | No | VARCHAR(50) | BRA 4.1 |
| department | - | No | VARCHAR(100) | BRA 4.1 |
| account_status | - | No | VARCHAR(20) | BRA 4.1 |

### 4.2. SPACE
| Attribute | PK/FK | Nullable | Data Type | Source |
| :--- | :--- | :--- | :--- | :--- |
| space_code | PK | No | VARCHAR(50) | BRA 4.2 |
| space_name | - | No | VARCHAR(100) | BRA 4.2 |
| space_type | - | No | VARCHAR(50) | BRA 4.2 |
| building | - | No | VARCHAR(50) | BRA 4.2 |
| floor | - | No | VARCHAR(10) | BRA 4.2 |
| room_number | - | No | VARCHAR(20) | BRA 4.2 |
| capacity | - | No | INT | BRA 4.2 |
| current_status | - | No | VARCHAR(20) | BRA 4.2 |
| usage_policy | - | No | NVARCHAR(MAX) | BRA 4.2 |

### 4.3. FACILITY
| Attribute | PK/FK | Nullable | Data Type | Source |
| :--- | :--- | :--- | :--- | :--- |
| facility_id | PK | No | INT | BRA 4.3 |
| facility_name | - | No | VARCHAR(100) | BRA 4.3 |
| facility_description | - | No | NVARCHAR(MAX) | BRA 4.3 |

### 4.4. BOOKING
| Attribute | PK/FK | Nullable | Data Type | Source |
| :--- | :--- | :--- | :--- | :--- |
| booking_id | PK | No | INT | BRA 4.4 |
| space_code | FK | No | VARCHAR(50) | BRA 4.4 |
| requester_id | FK | No | VARCHAR(50) | BRA 4.4 |
| requested_start | - | No | DATETIME | BRA 4.4 |
| requested_end | - | No | DATETIME | BRA 4.4 |
| purpose | - | No | VARCHAR(100) | BRA 4.4 |
| expected_participants| - | No | INT | BRA 4.4 |
| booking_status | - | No | VARCHAR(30) | BRA 4.4 |
| created_at | - | No | DATETIME | BRA 4.4 |
| approver_id | FK | Yes | VARCHAR(50) | BRA 4.4 |
| decision_time | - | Yes | DATETIME | BRA 4.4 |
| decision_note | - | Yes | NVARCHAR(MAX) | BRA 4.4 |
| rejection_reason | - | Yes | VARCHAR(255) | BRA 4.4 |

### 4.5. USAGESESSION
| Attribute | PK/FK | Nullable | Data Type | Source |
| :--- | :--- | :--- | :--- | :--- |
| booking_id | PK, FK | No | INT | BRA 4.5 |
| check_in_staff_id | FK | No | VARCHAR(50) | BRA 4.5 |
| actual_start | - | No | DATETIME | BRA 4.5 |
| initial_condition | - | No | NVARCHAR(MAX) | BRA 4.5 |
| check_out_staff_id | FK | Yes | VARCHAR(50) | BRA 4.5 |
| actual_end | - | Yes | DATETIME | BRA 4.5 |
| final_condition | - | Yes | NVARCHAR(MAX) | BRA 4.5 |
| usage_notes | - | Yes | NVARCHAR(MAX) | BRA 4.5 |

### 4.6. MAINTENANCERECORD
| Attribute | PK/FK | Nullable | Data Type | Source |
| :--- | :--- | :--- | :--- | :--- |
| maintenance_id | PK | No | INT | BRA 4.6 |
| space_code | FK | No | VARCHAR(50) | BRA 4.6 |
| reporter_id | FK | No | VARCHAR(50) | BRA 4.6 |
| assigned_staff_id | FK | Yes | VARCHAR(50) | BRA 4.6 |
| problem_type | - | No | VARCHAR(50) | BRA 4.6 |
| problem_description | - | No | NVARCHAR(MAX) | BRA 4.6 |
| start_time | - | No | DATETIME | BRA 4.6 |
| completion_time | - | Yes | DATETIME | BRA 4.6 |
| maintenance_status | - | No | VARCHAR(20) | BRA 4.6 |
| result_note | - | Yes | NVARCHAR(MAX) | BRA 4.6 |
