# Step 2: ERD Design — Campus Space Management System

---

## 1. Design Decisions

We utilize the crow's foot notation rendered via Mermaid's `erDiagram` for the Campus Space Management System, as it provides a clear, standardized representation of relationships and cardinalities. Multi-role relationships (such as User interacting as Requester, Approver, Reporter, etc.) are handled by defining distinct, labeled relationship lines for each role, ensuring that the specific function of the user in each context is explicit. Many-to-Many (M:N) relationships, specifically between `Space` and `Facility`, are managed by defining the relationship as specified, though Mermaid's `erDiagram` parser handles M:N visual rendering as a bridge in implementation (logical model). We adhere strictly to the cardinalities provided in the BRA to maintain data integrity and project requirements.

---

## 2. Entity-Relationship Diagram

```mermaid
erDiagram

    %% ── Entities ──────────────────────────────────────────────
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

    %% ── Relationships ─────────────────────────────────────────
    %% BRA §5.1 — User_Requests_Booking
    USER o{--|| BOOKING : "requests"
    %% BRA §5.2 — User_Approves_Booking
    USER o{--o| BOOKING : "approves"
    %% BRA §5.3 — Space_Hosts_Booking
    SPACE o{--|| BOOKING : "hosts"
    %% BRA §5.4 — Space_Equipped_With_Facility
    SPACE o{--o{ FACILITY : "contains"
    %% BRA §5.5 — Booking_Has_UsageSession
    BOOKING o|--|| USAGESESSION : "tracked by"
    %% BRA §5.6 — User_ChecksIn_UsageSession
    USER o{--|| USAGESESSION : "checks in"
    %% BRA §5.7 — User_ChecksOut_UsageSession
    USER o{--o| USAGESESSION : "checks out"
    %% BRA §5.8 — Space_Requires_Maintenance
    SPACE o{--|| MAINTENANCERECORD : "requires"
    %% BRA §5.9 — User_Reports_Maintenance
    USER o{--|| MAINTENANCERECORD : "reports"
    %% BRA §5.10 — User_Assigned_To_Maintenance
    USER o{--o| MAINTENANCERECORD : "assigned to"
```

---

## 3. Relationship Summary Table

| # | Relationship Name | Entity A | Cardinality | Entity B | Notes |
|---|---|---|---|---|---|
| 1 | User_Requests_Booking | User | (0,N) : (1,1) | Booking | Requester role. |
| 2 | User_Approves_Booking | User | (0,N) : (0,1) | Booking | Approver role. |
| 3 | Space_Hosts_Booking | Space | (0,N) : (1,1) | Booking | Hosting role. |
| 4 | Space_Equipped_With_Facility | Space | (0,M) : (0,N) | Facility | M:N relationship. |
| 5 | Booking_Has_UsageSession | Booking | (0,1) : (1,1) | UsageSession | 1:1 relationship. |
| 6 | User_ChecksIn_UsageSession | User | (0,N) : (1,1) | UsageSession | Check-in role. |
| 7 | User_ChecksOut_UsageSession | User | (0,N) : (0,1) | UsageSession | Check-out role. |
| 8 | Space_Requires_Maintenance | Space | (0,N) : (1,1) | MaintenanceRecord | Maintenance context. |
| 9 | User_Reports_Maintenance | User | (0,N) : (1,1) | MaintenanceRecord | Reporter role. |
| 10 | User_Assigned_To_Maintenance | User | (0,N) : (0,1) | MaintenanceRecord | Assigned staff role. |

---

## 4. Attribute Traceability

### Entity: User
| Attribute Name | Source |
|---|---|
| `user_id` | §4.1 |
| `email` | §4.1 |
| `full_name` | §4.1 |
| `phone_number` | §4.1 |
| `role` | §4.1 |
| `department` | §4.1 |
| `account_status` | §4.1 |

### Entity: Space
| Attribute Name | Source |
|---|---|
| `space_code` | §4.2 |
| `space_name` | §4.2 |
| `space_type` | §4.2 |
| `building` | §4.2 |
| `floor` | §4.2 |
| `room_number` | §4.2 |
| `capacity` | §4.2 |
| `current_status` | §4.2 |
| `usage_policy` | §4.2 |

### Entity: Facility
| Attribute Name | Source |
|---|---|
| `facility_id` | §4.3 |
| `facility_name` | §4.3 |
| `facility_description` | §4.3 |

### Entity: Booking
| Attribute Name | Source |
|---|---|
| `booking_id` | §4.4 |
| `space_code` | §4.4 (FK) |
| `requester_id` | §4.4 (FK) |
| `requested_start` | §4.4 |
| `requested_end` | §4.4 |
| `purpose` | §4.4 |
| `expected_participants` | §4.4 |
| `booking_status` | §4.4 |
| `created_at` | §4.4 |
| `approver_id` | §4.4 (FK) |
| `decision_time` | §4.4 |
| `decision_note` | §4.4 |
| `rejection_reason` | §4.4 |

### Entity: UsageSession
| Attribute Name | Source |
|---|---|
| `booking_id` | §4.5 (PK, FK) |
| `check_in_staff_id` | §4.5 (FK) |
| `actual_start` | §4.5 |
| `initial_condition` | §4.5 |
| `check_out_staff_id` | §4.5 (FK) |
| `actual_end` | §4.5 |
| `final_condition` | §4.5 |
| `usage_notes` | §4.5 |

### Entity: MaintenanceRecord
| Attribute Name | Source |
|---|---|
| `maintenance_id` | §4.6 |
| `space_code` | §4.6 (FK) |
| `reporter_id` | §4.6 (FK) |
| `assigned_staff_id` | §4.6 (FK) |
| `problem_type` | §4.6 |
| `problem_description` | §4.6 |
| `start_time` | §4.6 |
| `completion_time` | §4.6 |
| `maintenance_status` | §4.6 |
| `result_note` | §4.6 |
