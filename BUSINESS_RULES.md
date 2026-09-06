# AppiMeal Core Business Rules
**Company:** Appifly BD Limited

---

## 1. Attendance Time Window Enforcement
- **Start Time:** Configurable (Default: `12:30 PM Asia/Dhaka`)
- **End Time:** Configurable (Default: `02:00 PM Asia/Dhaka`)
- **Server-Time Validation:** The server evaluates the current time strictly in `Asia/Dhaka` time zone. Device clock manipulation on client applications is completely ignored.
- **Window States:**
  - `NOT STARTED`: Button disabled, displays "Window opens at 12:30 PM".
  - `OPEN`: Button enabled for employees with scheduled lunch.
  - `CLOSED`: Button disabled, displays "Attendance window closed for today".

## 2. Attendance Qualification & Duplicate Prevention
- To attend lunch on any given day, an employee **MUST** have a valid schedule status of `PLANNED` or `CONFIRMED`.
- An employee cannot check in twice on the same date. The unique constraint `(employee_id, lunch_date)` in both API and database prevents duplicate check-ins (returning HTTP `409 Conflict`).

## 3. Cancellation Cutoff Engine
- **Cutoff Time:** Configurable (Default: `11:00 AM Asia/Dhaka`)
- **Self-Service Cancellation:** Employees can cancel their scheduled lunch for today only **BEFORE** the 11:00 AM cutoff.
- **Admin Override:** System Administrators can cancel or alter schedules at any time.

## 4. Meal Price History & Billing Snapshots
- When an employee attends lunch (or is billed for a scheduled meal based on system configuration), a `MealCharge` record is generated.
- The `price_snapshot` attribute stores the exact rate active at the moment of attendance (e.g. ৳120.00).
- If the Admin increases the meal rate to ৳150.00 in the future, past meal charges remain billed at ৳120.00.

## 5. Employee Ledger Formula
- **Formula:** `Due = Opening Balance + Total Meal Charges + Total Adjustments - Total Payments`
- **Non-Negative Constraint:** Payments cannot be negative.
- Payments automatically reduce `current_due` atomically inside database transactions.

## 6. Catering Viewer Isolation
- The Catering Staff role has **read-only** access to live distribution metrics.
- Catering terminals cannot modify attendance, record payments, or edit employee accounts.
