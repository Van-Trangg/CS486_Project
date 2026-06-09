# Step 2: ERD Design — Campus Space Management System

---

## 1. Design Decisions

This design uses the crow's foot notation rendered via Mermaid `erDiagram`. This standard notation is ideal for clearly representing cardinality and participation constraints as defined in the Business Requirement Analysis. Multi-role User relationships (e.g., requester vs. approver) are represented as distinct, labeled relationship lines between the User and the related entity, ensuring each role is explicitly typed. The M:N relationship between Space and Facility is represented by a direct line between the two entities in this conceptual model; the logical junction entity (`SpaceFacility`) will be introduced in the upcoming logical design phase (Step 3).

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
        DATETIME requested_start
        DATETIME requested_end
        VARCHAR(100) purpose
        INT expected_participants
        VARCHAR(30) booking_status
        DATETIME created_at
        DATETIME decision_time
        NVARCHAR(MAX) decision_note
        VARCHAR(255) rejection_reason
    }

    USAGESESSION {
        INT booking_id PK, FK
        DATETIME actual_start
        NVARCHAR(MAX) initial_condition
        DATETIME actual_end
        NVARCHAR(MAX) final_condition
        NVARCHAR(MAX) usage_notes
    }

    MAINTENANCERECORD {
        INT maintenance_id PK
        VARCHAR(50) problem_type
        NVARCHAR(MAX) problem_description
        DATETIME start_time
        DATETIME completion_time
        VARCHAR(20) maintenance_status
        NVARCHAR(MAX) result_note
    }

    %% ── Relationships ─────────────────────────────────────────
    %% BRA §5.1 — User_Requests_Booking
    USER o|--o{ BOOKING : "requests"
    %% BRA §5.2 — User_Approves_Booking
    USER o|--o{ BOOKING : "approves"
    %% BRA §5.3 — Space_Hosts_Booking
    SPACE ||--o{ BOOKING : "hosts"
    %% BRA §5.4 — Space_Equipped_With_Facility
    SPACE o{--o{ FACILITY : "equipped with"
    %% BRA §5.5 — Booking_Has_UsageSession
    BOOKING ||--|| USAGESESSION : "tracked by"
    %% BRA §5.6 — User_ChecksIn_UsageSession
    USER ||--o{ USAGESESSION : "checks in"
    %% BRA §5.7 — User_ChecksOut_UsageSession
    USER o|--o{ USAGESESSION : "checks out"
    %% BRA §5.8 — Space_Requires_Maintenance
    SPACE ||--o{ MAINTENANCERECORD : "requires"
    %% BRA §5.9 — User_Reports_Maintenance
    USER ||--o{ MAINTENANCERECORD : "reports"
    %% BRA §5.10 — User_Assigned_To_Maintenance
    USER o|--o{ MAINTENANCERECORD : "assigned to"
```

---

## 3. Relationship Summary Table

| # | Relationship Name | Entity A | Cardinality | Entity B | Notes |
|---|---|---|---|---|---|
| 1 | User_Requests_Booking | User | (0,N) : (1,1) | Booking | Request role |
| 2 | User_Approves_Booking | User | (0,N) : (0,1) | Booking | Approver role |
| 3 | Space_Hosts_Booking | Space | (0,N) : (1,1) | Booking | Host role |
| 4 | Space_Equipped_With_Facility | Space | (0,M) : (0,N) | Facility | M:N relationship |
| 5 | Booking_Has_UsageSession | Booking | (0,1) : (1,1) | UsageSession | 1:1 mapped |
| 6 | User_ChecksIn_UsageSession | User | (0,N) : (1,1) | UsageSession | Mandatory check-in |
| 7 | User_ChecksOut_UsageSession | User | (0,N) : (0,1) | UsageSession | Optional check-out |
| 8 | Space_Requires_Maintenance | Space | (0,N) : (1,1) | MaintenanceRecord | Space maintenance |
| 9 | User_Reports_Maintenance | User | (0,N) : (1,1) | MaintenanceRecord | Reporter role |
| 10 | User_Assigned_To_Maintenance| User | (0,N) : (0,1) | MaintenanceRecord | Assigned staff role |

---

## 4. Attribute Traceability

### User
| Attribute Name | Source (BRA §4.1) |
|---|---|
| `user_id` | PK / Identifier |
| `email` | Descriptive |
| `full_name` | Descriptive |
| `phone_number` | Descriptive (Nullable) |
| `role` | Descriptive |
| `department` | Descriptive |
| `account_status` | Descriptive |

### Space
| Attribute Name | Source (BRA §4.2) |
|---|---|
| `space_code` | PK / Identifier |
| `space_name` | Descriptive |
| `space_type` | Descriptive |
| `building` | Descriptive |
| `floor` | Descriptive |
| `room_number` | Descriptive |
| `capacity` | Descriptive |
| `current_status` | Descriptive |
| `usage_policy` | Descriptive |

### Facility
| Attribute Name | Source (BRA §4.3) |
|---|---|
| `facility_id` | PK / Identifier |
| `facility_name` | Descriptive |
| `facility_description` | Descriptive |

### Booking
| Attribute Name | Source (BRA §4.4) |
|---|---|
| `booking_id` | PK / Identifier |
| `requested_start` | Descriptive |
| `requested_end` | Descriptive |
| `purpose` | Descriptive |
| `expected_participants` | Descriptive |
| `booking_status` | Descriptive |
| `created_at` | Descriptive |
| `decision_time` | Descriptive (Nullable) |
| `decision_note` | Descriptive (Nullable) |
| `rejection_reason` | Descriptive (Nullable) |

### UsageSession
| Attribute Name | Source (BRA §4.5) |
|---|---|
| `booking_id` | PK / FK |
| `actual_start` | Descriptive |
| `initial_condition` | Descriptive |
| `actual_end` | Descriptive (Nullable) |
| `final_condition` | Descriptive (Nullable) |
| `usage_notes` | Descriptive (Nullable) |

### MaintenanceRecord
| Attribute Name | Source (BRA §4.6) |
|---|---|
| `maintenance_id` | PK / Identifier |
| `problem_type` | Descriptive |
| `problem_description` | Descriptive |
| `start_time` | Descriptive |
| `completion_time` | Descriptive (Nullable) |
| `maintenance_status` | Descriptive |
| `result_note` | Descriptive (Nullable) |
