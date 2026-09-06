# AppiMeal Automated & Manual Testing Strategy
**Company:** Appifly BD Limited

---

## 1. Backend Testing (PHPUnit Feature Tests)

To execute backend automated tests:
```bash
cd backend
php artisan test
```

### Verified Scenarios:
- `test_health_check_endpoint`: Verifies API availability.
- `test_login_successful_for_admin`: Tests token issuance and user payload.
- `test_login_fails_with_invalid_password`: Verifies 401 unauthorized handling.
- `test_employee_lunch_scheduling`: Verifies schedule opt-in.
- `test_duplicate_attendance_prevention`: Verifies HTTP 409 Conflict handling on second check-in press.
- `test_admin_records_payment_and_updates_ledger`: Verifies payment registration and ledger formula updates.
- `test_catering_dashboard_access`: Verifies catering viewer authorization.

---

## 2. Frontend Testing (Flutter Static Analysis & Tests)

To execute Flutter static analysis and tests:
```bash
cd frontend
flutter analyze
flutter test
```

### Verified Scenarios:
- Zero syntax errors & zero lint warnings across all Dart files.
- Widget tree smoke test and Riverpod ProviderScope initialization verified.

---

## 3. Manual Verification Checklist

1. **Timezone Verification:** Check-in during `12:30 PM - 02:00 PM Asia/Dhaka` succeeds; check-in outside window returns proper status message.
2. **Duplicate Attendance Test:** Tapping "ATTEND LUNCH" a second time shows snackbar notification that attendance is already recorded.
3. **Catering Dashboard Live View:** Observe real-time counter updates on catering screen upon employee attendance confirmation.
4. **Historical Price Test:** Change meal rate in Settings; verify prior charges maintain original snapshot rate.
