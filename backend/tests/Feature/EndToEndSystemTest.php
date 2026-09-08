<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\LunchAttendance;
use App\Models\LunchSchedule;
use App\Models\MealSettings;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EndToEndSystemTest extends TestCase
{
    use RefreshDatabase;

    protected User $adminUser;
    protected User $employeeUser;
    protected User $cateringUser;
    protected Employee $employeeModel;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();

        $this->adminUser = User::where('email', 'info@appiflybd.com')->first();
        $this->employeeUser = User::where('email', 'tusher@appiflybd.com')->first();
        $this->cateringUser = User::where('email', 'catering@appiflybd.com')->first();
        $this->employeeModel = $this->employeeUser->employee;
    }

    /* =========================================================================
     * 1. ADMIN ROLE FUNCTIONALITY TESTS
     * ========================================================================= */

    public function test_admin_dashboard_summary(): void
    {
        $response = $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/dashboard/admin');
        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'data' => [
                    'meal_price',
                    'currency',
                    'today' => ['date', 'scheduled', 'attended', 'pending', 'cancelled', 'cost', 'attendees'],
                    'monthly' => ['total_meals', 'total_cost', 'paid', 'due'],
                    'totals' => ['total_paid', 'total_due'],
                    'charts' => ['daily_trend', 'department_usage'],
                ]
            ]);
    }

    public function test_admin_employee_management_crud(): void
    {
        // 1. List Employees
        $listRes = $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/employees');
        $listRes->assertStatus(200)->assertJsonPath('success', true);

        // 2. Create Employee
        $createRes = $this->actingAs($this->adminUser, 'sanctum')->postJson('/api/employees', [
            'full_name' => 'Testing User',
            'employee_id' => 'EMP-TEST-99',
            'email' => 'e2e_test@appiflybd.com',
            'password' => 'Password123!',
            'phone' => '01711998877',
            'designation' => 'QA Automation',
            'department' => 'SQA & Testing',
            'join_date' => '2026-01-01',
            'status' => 'ACTIVE',
        ]);
        $createRes->assertStatus(201)->assertJsonPath('success', true);
        $newEmpId = $createRes->json('data.id');

        // 3. Show Employee
        $showRes = $this->actingAs($this->adminUser, 'sanctum')->getJson("/api/employees/{$newEmpId}");
        $showRes->assertStatus(200)->assertJsonPath('data.full_name', 'Testing User');

        // 4. Update Employee
        $updateRes = $this->actingAs($this->adminUser, 'sanctum')->putJson("/api/employees/{$newEmpId}", [
            'full_name' => 'Testing User Updated',
            'phone' => '01711998877',
            'designation' => 'Senior SQA Automation',
            'department' => 'SQA & Testing',
            'status' => 'ACTIVE',
        ]);
        $updateRes->assertStatus(200)->assertJsonPath('data.full_name', 'Testing User Updated');

        // 5. Toggle Employee Status
        $toggleRes = $this->actingAs($this->adminUser, 'sanctum')->patchJson("/api/employees/{$newEmpId}/status");
        $toggleRes->assertStatus(200)->assertJsonPath('data.status', 'inactive');
    }

    public function test_admin_record_employee_payment_and_ledger(): void
    {
        $today = Carbon::today('Asia/Dhaka')->toDateString();

        $paymentRes = $this->actingAs($this->adminUser, 'sanctum')->postJson('/api/payments', [
            'employee_id' => $this->employeeModel->id,
            'amount' => 1200.00,
            'payment_date' => $today,
            'payment_method' => 'bKash',
            'reference' => 'BKASH_E2E_99',
            'notes' => 'Testing employee ledger payment',
        ]);
        $paymentRes->assertStatus(201)->assertJsonPath('success', true);

        // Verify Payments List & Employee Payments
        $paymentsList = $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/payments');
        $paymentsList->assertStatus(200)->assertJsonPath('success', true);

        $empPayments = $this->actingAs($this->adminUser, 'sanctum')->getJson("/api/employees/{$this->employeeModel->id}/payments");
        $empPayments->assertStatus(200)->assertJsonPath('success', true);

        // Verify Employee Ledger
        $ledgerRes = $this->actingAs($this->adminUser, 'sanctum')->getJson("/api/ledger/employees/{$this->employeeModel->id}");
        $ledgerRes->assertStatus(200)->assertJsonPath('success', true);
    }

    public function test_admin_manual_meal_management(): void
    {
        $targetDate = Carbon::tomorrow('Asia/Dhaka')->toDateString();

        // 1. Get Manage List
        $listRes = $this->actingAs($this->adminUser, 'sanctum')->getJson("/api/admin/lunch/manage-list?date={$targetDate}");
        $listRes->assertStatus(200)->assertJsonPath('success', true);

        // 2. Mark Attended manually
        $attendRes = $this->actingAs($this->adminUser, 'sanctum')->postJson('/api/admin/lunch/manual-entry', [
            'employee_id' => $this->employeeModel->id,
            'lunch_date' => $targetDate,
            'status' => 'ATTENDED',
            'notes' => 'Admin manual attendance override',
        ]);
        $attendRes->assertStatus(200)->assertJsonPath('success', true);

        // 3. Mark Planned manually (Schedule)
        $planRes = $this->actingAs($this->adminUser, 'sanctum')->postJson('/api/admin/lunch/manual-entry', [
            'employee_id' => $this->employeeModel->id,
            'lunch_date' => $targetDate,
            'status' => 'PLANNED',
            'notes' => 'Admin reset to planned',
        ]);
        $planRes->assertStatus(200)->assertJsonPath('success', true);

        // 4. Mark Cancelled manually
        $cancelRes = $this->actingAs($this->adminUser, 'sanctum')->postJson('/api/admin/lunch/manual-entry', [
            'employee_id' => $this->employeeModel->id,
            'lunch_date' => $targetDate,
            'status' => 'CANCELLED',
            'notes' => 'Admin cancelled meal',
        ]);
        $cancelRes->assertStatus(200)->assertJsonPath('success', true);

        // 5. Remove Schedule (NOT_SCHEDULED)
        $removeRes = $this->actingAs($this->adminUser, 'sanctum')->postJson('/api/admin/lunch/manual-entry', [
            'employee_id' => $this->employeeModel->id,
            'lunch_date' => $targetDate,
            'status' => 'NOT_SCHEDULED',
            'notes' => 'Admin removed schedule',
        ]);
        $removeRes->assertStatus(200)->assertJsonPath('success', true);
    }

    public function test_admin_catering_billing_and_settlement(): void
    {
        $summaryRes = $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/catering/summary');
        $summaryRes->assertStatus(200)->assertJsonPath('success', true);

        $breakdownRes = $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/catering/employee-breakdown');
        $breakdownRes->assertStatus(200)->assertJsonPath('success', true);

        $payRes = $this->actingAs($this->adminUser, 'sanctum')->postJson('/api/catering/payments', [
            'amount' => 4500.00,
            'payment_date' => Carbon::today('Asia/Dhaka')->toDateString(),
            'payment_method' => 'Bank Transfer',
            'reference' => 'CAT_BANK_REF_88',
            'notes' => 'Catering vendor payment',
        ]);
        $payRes->assertStatus(201)->assertJsonPath('success', true);

        $catPayments = $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/catering/payments');
        $catPayments->assertStatus(200)->assertJsonPath('success', true);
    }

    public function test_admin_reports_and_analytics(): void
    {
        $today = Carbon::today('Asia/Dhaka')->toDateString();

        $this->actingAs($this->adminUser, 'sanctum')->getJson("/api/reports/daily?date={$today}")->assertStatus(200);
        $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/reports/monthly')->assertStatus(200);
        $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/reports/employees')->assertStatus(200);
        $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/reports/dues')->assertStatus(200);
        $this->actingAs($this->adminUser, 'sanctum')->postJson('/api/reports/export', ['report_type' => 'daily'])->assertStatus(200);
    }

    public function test_admin_settings_and_audit_logs(): void
    {
        $getSettings = $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/settings');
        $getSettings->assertStatus(200)->assertJsonPath('success', true);

        $putSettings = $this->actingAs($this->adminUser, 'sanctum')->putJson('/api/settings', [
            'company_name' => 'Appifly BD Limited',
            'timezone' => 'Asia/Dhaka',
            'currency' => 'BDT',
            'currency_symbol' => '৳',
            'current_meal_price' => 125.00,
            'attendance_start_time' => '12:00:00',
            'attendance_end_time' => '14:30:00',
            'cancellation_cutoff_time' => '11:00:00',
            'allow_employee_cancellation' => true,
            'charge_on_attendance_only' => true,
            'max_planning_days' => 30,
            'weekend_days' => ['Friday', 'Saturday'],
        ]);
        $putSettings->assertStatus(200)->assertJsonPath('data.current_meal_price', '125.00');

        $auditLogs = $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/audit-logs');
        $auditLogs->assertStatus(200)->assertJsonPath('success', true);
    }

    /* =========================================================================
     * 2. EMPLOYEE ROLE FUNCTIONALITY TESTS
     * ========================================================================= */

    public function test_employee_dashboard_and_today_status(): void
    {
        $dashRes = $this->actingAs($this->employeeUser, 'sanctum')->getJson('/api/dashboard/employee');
        $dashRes->assertStatus(200)->assertJsonPath('success', true);

        $statusRes = $this->actingAs($this->employeeUser, 'sanctum')->getJson('/api/lunch/today-status');
        $statusRes->assertStatus(200)->assertJsonPath('success', true);
    }

    public function test_employee_calendar_scheduling_and_cancellation(): void
    {
        $tomorrow = Carbon::tomorrow('Asia/Dhaka')->toDateString();

        // 1. View Calendar
        $calRes = $this->actingAs($this->employeeUser, 'sanctum')->getJson('/api/lunch/calendar');
        $calRes->assertStatus(200)->assertJsonPath('success', true);

        // 2. Schedule Meal
        $schedRes = $this->actingAs($this->employeeUser, 'sanctum')->postJson('/api/lunch/schedule', [
            'lunch_date' => $tomorrow,
            'participate' => true,
        ]);
        $schedRes->assertStatus(200)->assertJsonPath('data.status', 'PLANNED');

        // 3. Cancel Meal
        $cancelRes = $this->actingAs($this->employeeUser, 'sanctum')->postJson('/api/lunch/cancel', [
            'lunch_date' => $tomorrow,
            'cancellation_reason' => 'Offsite client meeting',
        ]);
        $cancelRes->assertStatus(200)->assertJsonPath('data.status', 'CANCELLED');
    }

    public function test_employee_attendance_and_ledger(): void
    {
        $settings = MealSettings::first();
        $settings->attendance_start_time = '00:00:00';
        $settings->attendance_end_time = '23:59:59';
        $settings->save();

        $today = Carbon::today('Asia/Dhaka')->toDateString();

        // Clean today's schedule/attendance
        \App\Models\MealCharge::where('employee_id', $this->employeeModel->id)->where('charge_date', $today)->delete();
        LunchAttendance::where('employee_id', $this->employeeModel->id)->where('lunch_date', $today)->delete();
        LunchSchedule::where('employee_id', $this->employeeModel->id)->where('lunch_date', $today)->delete();

        // Unplanned lunch: employee manually clicks attend during open window
        $attendRes = $this->actingAs($this->employeeUser, 'sanctum')->postJson('/api/lunch/attend');
        $attendRes->assertStatus(200)->assertJsonPath('success', true);

        // Check My Ledger
        $ledgerRes = $this->actingAs($this->employeeUser, 'sanctum')->getJson('/api/ledger/me');
        $ledgerRes->assertStatus(200)->assertJsonPath('success', true);

        // Notifications
        $notifRes = $this->actingAs($this->employeeUser, 'sanctum')->getJson('/api/notifications');
        $notifRes->assertStatus(200)->assertJsonPath('success', true);
    }

    /* =========================================================================
     * 3. CATERING ROLE FUNCTIONALITY TESTS
     * ========================================================================= */

    public function test_catering_dashboard_and_today_list(): void
    {
        $catDash = $this->actingAs($this->cateringUser, 'sanctum')->getJson('/api/dashboard/catering');
        $catDash->assertStatus(200)->assertJsonPath('success', true);

        $todayList = $this->actingAs($this->cateringUser, 'sanctum')->getJson('/api/lunch/today-list');
        $todayList->assertStatus(200)->assertJsonPath('success', true);
    }
}
