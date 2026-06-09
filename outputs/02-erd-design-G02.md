# Step 2: ERD Design — Campus Space Management System

---

## 1. Design Decisions

For the Campus Space Management System, the Entity-Relationship Diagram (ERD) is rendered using Mermaid's `erDiagram` syntax, which natively supports Chen-style cardinality and crow's-foot notation. Entities were mapped strictly from §3 of the Business Requirement Analysis (BRA), and attributes were assigned based on §4, applying appropriate nullability and data types.

Multi-role relationships, where a `User` participates in distinct roles with the same entity (e.g., `Booking`, `UsageSession`, `MaintenanceRecord`), are represented as separate, labeled relationship lines to maintain clarity and adhere to the strict participation requirements. The M:N relationship between `Space` and `Facility` is represented as a direct relationship line in this logical design, as supported by Mermaid, deferring the junction entity implementation to Step 3.

---

## 2. Entity-Relationship Diagram

```mermaid
erDiagram

    %% ── Entities ──────────────────────────────────────────────
    USER {
        string user_id PK
        string email
        string full_name
        string phone_number %% Nullable
        string role
        string department
        string account_status
    }

    SPACE {
        string space_code PK
        string space_name
        string space_type
        string building
        string floor
        string room_number
        int capacity
        string current_status
        text usage_policy
    }

    FACILITY {
        int facility_id PK
        string facility_name
        text facility_description %% Nullable
    }

    BOOKING {
        int booking_id PK
        datetime requested_start
        datetime requested_end
        string purpose
        int expected_participants
        string booking_status
        datetime created_at
        datetime decision_time %% Nullable
        text decision_note %% Nullable
        string rejection_reason %% Nullable
    }

    USAGESESSION {
        int booking_id PK, FK
        datetime actual_start
        text initial_condition
        datetime actual_end %% Nullable
        text final_condition %% Nullable
        text usage_notes %% Nullable
    }

    MAINTENANCERECORD {
        int maintenance_id PK
        string problem_type
        text problem_description
        datetime start_time
        datetime completion_time %% Nullable
        string maintenance_status
        text result_note %% Nullable
    }

    %% ── Relationships ─────────────────────────────────────────
    USER ||--o{ BOOKING : "requests" %% BRA §5.1
    USER o{--o| BOOKING : "approves" %% BRA §5.2
    SPACE ||--o{ BOOKING : "hosts" %% BRA §5.3
    SPACE o{--o{ FACILITY : "equipped with" %% BRA §5.4
    BOOKING ||--|| USAGESESSION : "tracked by" %% BRA §5.5
    USER ||--|{ USAGESESSION : "checks in" %% BRA §5.6
    USER o|--o{ USAGESESSION : "checks out" %% BRA §5.7
    SPACE ||--o{ MAINTENANCERECORD : "requires" %% BRA §5.8
    USER ||--o{ MAINTENANCERECORD : "reports" %% BRA §5.9
    USER o|--o{ MAINTENANCERECORD : "assigned to" %% BRA §5.10
```

---

## 3. Relationship Summary Table

| # | Relationship Name | Entity A | Cardinality | Entity B | Notes |
|---|---|---|---|---|---|
| 1 | requests | User | (0,N) : (1,1) | Booking | - |
| 2 | approves | User | (0,N) : (0,1) | Booking | - |
| 3 | hosts | Space | (0,N) : (1,1) | Booking | - |
| 4 | equipped with | Space | (0,M) : (0,N) | Facility | M:N relationship |
| 5 | tracked by | Booking | (0,1) : (1,1) | UsageSession | - |
| 6 | checks in | User | (0,N) : (1,1) | UsageSession | - |
| 7 | checks out | User | (0,N) : (0,1) | UsageSession | - |
| 8 | requires | Space | (0,N) : (1,1) | MaintenanceRecord | - |
| 9 | reports | User | (0,N) : (1,1) | MaintenanceRecord | - |
| 10 | assigned to | User | (0,N) : (0,1) | MaintenanceRecord | - |

---

## 4. Attribute Traceability

### User Entity
| Attribute | BRA Source |
|---|---|
| `user_id` | §4.1 |
| `email` | §4.1 |
| `full_name` | §4.1 |
| `phone_number` | §4.1 |
| `role` | §4.1 |
| `department` | §4.1 |
| `account_status` | §4.1 |

### Space Entity
| Attribute | BRA Source |
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

### Facility Entity
| Attribute | BRA Source |
|---|---|
| `facility_id` | §4.3 |
| `facility_name` | §4.3 |
| `facility_description` | §4.3 |

### Booking Entity
| Attribute | BRA Source |
|---|---|
| `booking_id` | §4.4 |
| `requested_start` | §4.4 |
| `requested_end` | §4.4 |
| `purpose` | §4.4 |
| `expected_participants` | §4.4 |
| `booking_status` | §4.4 |
| `created_at` | §4.4 |
| `decision_time` | §4.4 |
| `decision_note` | §4.4 |
| `rejection_reason` | §4.4 |

### UsageSession Entity
| Attribute | BRA Source |
|---|---|
| `booking_id` | §4.5 |
| `actual_start` | §4.5 |
| `initial_condition` | §4.5 |
| `actual_end` | §4.5 |
| `final_condition` | §4.5 |
| `usage_notes` | §4.5 |

### MaintenanceRecord Entity
| Attribute | BRA Source |
|---|---|
| `maintenance_id` | §4.6 |
| `problem_type` | §4.6 |
| `problem_description` | §4.6 |
| `start_time` | §4.6 |
| `completion_time` | §4.6 |
| `maintenance_status` | §4.6 |
| `result_note` | §4.6 |
