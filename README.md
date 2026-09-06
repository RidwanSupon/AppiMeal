# AppiMeal — Employee Lunch & Attendance Management System
**Company:** Appifly BD Limited  
**Target Platform:** Android (Flutter 3.x) & Backend (Laravel 11 REST API)

AppiMeal is a production-ready enterprise lunch scheduling, attendance verification, meal pricing, billing ledger, catering viewer, and audit reporting application built specifically for **Appifly BD Limited**.

---

## Key System Features

- **Employee Lunch Scheduling:** Opt-in / opt-out calendar planning for future dates with cutoff rule enforcement.
- **Strict Server-Time Attendance Window:** Attend Lunch button active strictly within admin-configured daily time window (`12:30 PM - 02:00 PM Asia/Dhaka`).
- **Catering Staff Dashboard:** Ultra-readable, high-contrast dashboard with giant numbers auto-refreshing today's meal count (Expected vs Attended vs Pending vs Cancelled).
- **Billing & Ledger Engine:** Formula `Due = Opening Balance + Meal Charges + Adjustments - Payments`. Historical pricing snapshots ensure old charges remain untouched by price updates.
- **Role-Based Access Control (RBAC):** SUPER ADMIN, ADMIN, EMPLOYEE, CATERING VIEWER with permissions enforced on both API endpoints and Flutter router.
- **Payment Management:** Admin payment recording with unique sequence numbers (`PAY-YYYYMMDD-XXXX`).
- **Audit Logs & Export:** Read-only immutable audit trail and exportable PDF/CSV/Excel reports.

---

## Project Structure

```
AppiMeal/
├── backend/                  # Laravel 11 REST API Application
│   ├── app/
│   │   ├── Http/Controllers/ # Auth, Employee, Schedule, Attendance, Payment, Ledger, Dashboard, Report, Settings, Audit
│   │   ├── Http/Middleware/  # Role & Permission Middleware
│   │   └── Models/          # User, Role, Employee, Schedule, Attendance, Charge, Payment, Ledger, Settings, AuditLog
│   ├── database/
│   │   ├── migrations/      # 17 Normalized database migrations
│   │   └── seeders/         # DatabaseSeeder populating full test dataset
│   ├── routes/api.php        # REST API Routes
│   └── tests/Feature/        # PHPUnit Feature Test Suite
│
├── frontend/                 # Flutter 3.x Android Application
│   ├── lib/
│   │   ├── core/            # Theme, Router, Network (Dio), Storage (SecureStorage), Constants, Utils
│   │   ├── features/        # Auth, Employee, Admin, Catering, Notifications
│   │   └── shared/          # Reusable Material 3 Widgets (Buttons, TextFields, Badges, Loaders)
│   └── test/                # Flutter Unit & Widget Tests
│
├── README.md
├── API_DOCUMENTATION.md
├── DATABASE_SCHEMA.md
├── BUSINESS_RULES.md
├── DEPLOYMENT.md
└── TESTING.md
```

---

## Environment Setup & Quick Start

### 1. Backend Setup (Laravel)
```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate:fresh --seed
php artisan serve --host=0.0.0.0 --port=8000
```

### 2. Frontend Setup (Flutter Android App)
```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run
```

---

## Test Credentials (Development)

| Role | Email | Password |
|---|---|---|
| Super Admin | `superadmin@appiflybd.com` | `Password123!` |
| Admin | `admin@appiflybd.com` | `Password123!` |
| Catering Staff | `catering@appiflybd.com` | `Password123!` |
| Employee 1 | `employee1@appiflybd.com` | `Password123!` |
| Employee 2 | `employee2@appiflybd.com` | `Password123!` |

> [!WARNING]
> Test seed credentials MUST NOT be used in production deployments.
