# AppiMeal Database Schema Specification
**Company:** Appifly BD Limited  
**Engine:** SQLite (Local Dev) / PostgreSQL / MySQL (Production)

---

## Entity Relationship Summary

```
roles (1) ───< users (N) ───(1) employees (1) ───< lunch_schedules (N)
                                   │              └───< lunch_attendances (N)
                                   ├───< meal_charges (N)
                                   ├───< payments (N)
                                   └───(1) employee_ledgers (1)
```

---

## Table Definitions

### 1. `roles`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGINT | PK, Auto Increment | Primary key |
| `name` | VARCHAR | Unique, Not Null | SUPER ADMIN, ADMIN, EMPLOYEE, CATERING VIEWER |
| `slug` | VARCHAR | Unique, Not Null | `super_admin`, `admin`, `employee`, `catering_viewer` |
| `description` | TEXT | Nullable | Role overview |

### 2. `users`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGINT | PK, Auto Increment | Primary key |
| `name` | VARCHAR | Not Null | User display name |
| `email` | VARCHAR | Unique, Not Null | User login email |
| `password` | VARCHAR | Not Null | Bcrypt hashed password |
| `role_id` | BIGINT | FK -> roles(id) | Assigned user role |
| `is_active` | BOOLEAN | Default true | Active account flag |

### 3. `employees`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGINT | PK, Auto Increment | Primary key |
| `user_id` | BIGINT | FK -> users(id), Unique | Associated user account |
| `employee_id` | VARCHAR | Unique, Not Null | Company ID e.g. `EMP-001` |
| `full_name` | VARCHAR | Not Null | Full employee name |
| `department` | VARCHAR | Not Null | Department name |
| `designation` | VARCHAR | Not Null | Designation title |

### 4. `lunch_schedules`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGINT | PK, Auto Increment | Primary key |
| `employee_id` | BIGINT | FK -> employees(id) | Employee reference |
| `lunch_date` | DATE | Not Null | Date of scheduled lunch |
| `status` | ENUM | Not Null | `PLANNED`, `CONFIRMED`, `ATTENDED`, `CANCELLED`, `MISSED`, `LOCKED` |

> **Unique Constraint:** `(employee_id, lunch_date)`

### 5. `lunch_attendances`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGINT | PK, Auto Increment | Primary key |
| `employee_id` | BIGINT | FK -> employees(id) | Employee reference |
| `schedule_id` | BIGINT | FK -> lunch_schedules(id) | Schedule reference |
| `lunch_date` | DATE | Not Null | Attendance date |
| `attended_at` | TIMESTAMP | Not Null | Exact server check-in time |

> **Unique Constraint:** `(employee_id, lunch_date)`

### 6. `meal_charges`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGINT | PK, Auto Increment | Primary key |
| `employee_id` | BIGINT | FK -> employees(id) | Employee reference |
| `amount` | DECIMAL(10,2) | Not Null | Charge amount |
| `price_snapshot` | DECIMAL(10,2) | Not Null | Historical price snapshot rate |

### 7. `payments`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGINT | PK, Auto Increment | Primary key |
| `payment_id` | VARCHAR | Unique, Not Null | Sequence ID e.g. `PAY-20260906-0001` |
| `amount` | DECIMAL(10,2) | Not Null | Payment amount |
| `payment_method` | VARCHAR | Not Null | `Cash`, `Bank Transfer`, `bKash`, `Nagad`, `Other` |

### 8. `employee_ledgers`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGINT | PK, Auto Increment | Primary key |
| `employee_id` | BIGINT | FK -> employees(id), Unique | Employee reference |
| `opening_balance` | DECIMAL(10,2) | Default 0.00 | Initial starting balance |
| `total_meal_charges` | DECIMAL(10,2) | Default 0.00 | Total accumulated meal charges |
| `total_payments` | DECIMAL(10,2) | Default 0.00 | Total payments recorded |
| `current_due` | DECIMAL(10,2) | Default 0.00 | `Opening + Charges + Adjustments - Payments` |
