# AppiMeal REST API Documentation
**Company:** Appifly BD Limited  
**Base URL:** `http://10.0.2.2:8000/api` (Android Emulator) / `http://localhost:8000/api`  
**Authentication:** Bearer Token (Laravel Sanctum)

---

## Response Structure

All endpoints return a standardized JSON envelope:
```json
{
  "success": true,
  "message": "Human readable response summary",
  "data": { ... },
  "errors": null
}
```

---

## 1. Authentication Endpoints

### `POST /api/login`
- **Auth Required:** No
- **Request Body:**
  ```json
  {
    "email": "admin@appiflybd.com",
    "password": "Password123!"
  }
  ```
- **Response:** Returns Bearer Token and User Profile.

### `GET /api/me`
- **Auth Required:** Yes (Sanctum)
- **Response:** Current logged-in user details, employee profile, and ledger balance.

### `POST /api/logout`
- **Auth Required:** Yes (Sanctum)
- **Response:** Revokes current token.

---

## 2. Employee Lunch & Attendance Endpoints

### `GET /api/lunch/today-status`
- **Auth Required:** Yes (Employee / Admin)
- **Response:** Today's schedule status, attendance status, server time formatted in `Asia/Dhaka`, window status (`NOT STARTED`, `OPEN`, `CLOSED`).

### `POST /api/lunch/attend`
- **Auth Required:** Yes (Employee)
- **Validation:**
  1. Attendance window must be OPEN (`12:30 PM - 02:00 PM Asia/Dhaka`).
  2. Employee must have scheduled lunch.
  3. No prior attendance recorded for today (prevents 409 Conflict).
- **Response:** Attended timestamp (e.g. `01:12 PM`) and generated charge.

### `GET /api/lunch/calendar?month=9&year=2026`
- **Auth Required:** Yes
- **Response:** List of calendar days with statuses (`PLANNED`, `CONFIRMED`, `ATTENDED`, `CANCELLED`, `MISSED`, `LOCKED`).

### `POST /api/lunch/schedule`
- **Auth Required:** Yes (Employee)
- **Request Body:**
  ```json
  {
    "lunch_date": "2026-09-07",
    "participate": true
  }
  ```

---

## 3. Financial & Ledger Endpoints

### `GET /api/ledger/me`
- **Auth Required:** Yes (Employee)
- **Response:** Personal ledger breakdown (`Opening Balance`, `Meal Charges`, `Payments`, `Current Due`).

### `POST /api/payments`
- **Auth Required:** Yes (Admin / Super Admin)
- **Request Body:**
  ```json
  {
    "employee_id": 1,
    "amount": 500.00,
    "payment_date": "2026-09-06",
    "payment_method": "bKash",
    "reference": "TXN123456",
    "notes": "Partial payment"
  }
  ```
- **Response:** Returns created payment record with unique sequence ID (`PAY-YYYYMMDD-XXXX`).

---

## 4. Catering Terminal Endpoint

### `GET /api/dashboard/catering`
- **Auth Required:** Yes (Catering Viewer / Admin)
- **Response:** High-performance payload with `total_expected`, `lunch_taken`, `pending`, `cancelled`, `estimated_cost`, and employee checklist.
