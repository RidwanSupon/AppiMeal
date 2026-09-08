<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\LunchSchedule;
use App\Models\MealSettings;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AppiMealApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_health_check_endpoint(): void
    {
        $response = $this->getJson('/api/health');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('system', 'AppiMeal REST API');
    }

    public function test_login_successful_for_admin(): void
    {
        $response = $this->postJson('/api/login', [
            'email' => 'info@appiflybd.com',
            'password' => 'appifly@meal',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'data' => ['token', 'user' => ['id', 'email', 'role']],
            ]);
    }

    public function test_login_fails_with_invalid_password(): void
    {
        $response = $this->postJson('/api/login', [
            'email' => 'info@appiflybd.com',
            'password' => 'WrongPassword',
        ]);

        $response->assertStatus(401)
            ->assertJsonPath('success', false);
    }

    public function test_employee_lunch_scheduling(): void
    {
        $user = User::where('email', 'tusher@appiflybd.com')->first();
        $tomorrow = Carbon::tomorrow('Asia/Dhaka')->toDateString();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/lunch/schedule', [
            'lunch_date' => $tomorrow,
            'participate' => true,
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'PLANNED');
    }

    public function test_planned_lunch_automatically_satisfied_when_window_starts(): void
    {
        $user = User::where('email', 'tusher@appiflybd.com')->first();
        $employee = $user->employee;
        $todayStr = Carbon::today('Asia/Dhaka')->toDateString();

        $settings = MealSettings::first();
        $settings->attendance_start_time = '00:00:00';
        $settings->attendance_end_time = '23:59:59';
        $settings->save();

        \App\Models\MealCharge::where('employee_id', $employee->id)->where('charge_date', $todayStr)->delete();
        \App\Models\LunchAttendance::where('employee_id', $employee->id)->where('lunch_date', $todayStr)->delete();
        LunchSchedule::where('employee_id', $employee->id)->where('lunch_date', $todayStr)->delete();

        LunchSchedule::create([
            'employee_id' => $employee->id,
            'lunch_date' => $todayStr,
            'status' => 'PLANNED',
            'scheduled_at' => now(),
        ]);

        // Status request triggers auto-attendance recognition
        $statusRes = $this->actingAs($user, 'sanctum')->getJson('/api/lunch/today-status');
        $statusRes->assertStatus(200)
            ->assertJsonPath('data.is_attended', true)
            ->assertJsonPath('data.schedule_status', 'ATTENDED')
            ->assertJsonPath('data.can_attend', false);

        // Verify attendance record & charge were created
        $this->assertDatabaseHas('lunch_attendances', [
            'employee_id' => $employee->id,
            'lunch_date' => $todayStr,
        ]);

        // Manual attend press is NOT allowed/needed and returns 409 Conflict
        $attendRes = $this->actingAs($user, 'sanctum')->postJson('/api/lunch/attend');
        $attendRes->assertStatus(409);
    }

    public function test_unplanned_lunch_requires_manual_attendance_during_window(): void
    {
        $user = User::where('email', 'tusher@appiflybd.com')->first();
        $employee = $user->employee;
        $todayStr = Carbon::today('Asia/Dhaka')->toDateString();

        $settings = MealSettings::first();
        $settings->attendance_start_time = '00:00:00';
        $settings->attendance_end_time = '23:59:59';
        $settings->save();

        \App\Models\MealCharge::where('employee_id', $employee->id)->where('charge_date', $todayStr)->delete();
        \App\Models\LunchAttendance::where('employee_id', $employee->id)->where('lunch_date', $todayStr)->delete();
        LunchSchedule::where('employee_id', $employee->id)->where('lunch_date', $todayStr)->delete();

        // Unplanned: no schedule row
        $statusRes = $this->actingAs($user, 'sanctum')->getJson('/api/lunch/today-status');
        $statusRes->assertStatus(200)
            ->assertJsonPath('data.is_attended', false)
            ->assertJsonPath('data.can_attend', true);

        // First manual attendance succeeds
        $res1 = $this->actingAs($user, 'sanctum')->postJson('/api/lunch/attend');
        $res1->assertStatus(200)->assertJsonPath('success', true);

        // Second manual attendance attempt returns 409 Conflict
        $res2 = $this->actingAs($user, 'sanctum')->postJson('/api/lunch/attend');
        $res2->assertStatus(409)->assertJsonPath('success', false);
    }

    public function test_admin_records_payment_and_updates_ledger(): void
    {
        $admin = User::where('email', 'info@appiflybd.com')->first();
        $employee = Employee::first();

        $response = $this->actingAs($admin, 'sanctum')->postJson('/api/payments', [
            'employee_id' => $employee->id,
            'amount' => 500.00,
            'payment_date' => Carbon::today('Asia/Dhaka')->toDateString(),
            'payment_method' => 'bKash',
            'reference' => 'BKASH123456',
            'notes' => 'Test payment recording',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true);
    }

    public function test_catering_dashboard_access(): void
    {
        $catering = User::where('email', 'catering@appiflybd.com')->first();

        $response = $this->actingAs($catering, 'sanctum')->getJson('/api/dashboard/catering');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'data' => ['total_expected', 'lunch_taken', 'pending', 'cancelled', 'employees'],
            ]);
    }

    public function test_admin_catering_payment_recording(): void
    {
        $admin = User::where('email', 'info@appiflybd.com')->first();

        $response = $this->actingAs($admin, 'sanctum')->postJson('/api/catering/payments', [
            'amount' => 5000.00,
            'payment_date' => Carbon::today('Asia/Dhaka')->toDateString(),
            'payment_method' => 'Bank Transfer',
            'reference' => 'REF-CAT-001',
            'notes' => 'Weekly catering vendor settlement',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.amount', '5000.00');

        $summaryRes = $this->actingAs($admin, 'sanctum')->getJson('/api/catering/summary');
        $summaryRes->assertStatus(200)
            ->assertJsonPath('success', true);
    }

    public function test_admin_settings_weekend_days_update(): void
    {
        $admin = User::where('email', 'info@appiflybd.com')->first();

        $response = $this->actingAs($admin, 'sanctum')->putJson('/api/settings', [
            'company_name' => 'Appifly BD Limited',
            'timezone' => 'Asia/Dhaka',
            'currency' => 'BDT',
            'currency_symbol' => '৳',
            'current_meal_price' => 130.00,
            'attendance_start_time' => '12:30:00',
            'attendance_end_time' => '14:00:00',
            'cancellation_cutoff_time' => '11:00:00',
            'allow_employee_cancellation' => true,
            'charge_on_attendance_only' => true,
            'max_planning_days' => 30,
            'weekend_days' => ['Friday', 'Saturday'],
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.weekend_days', ['Friday', 'Saturday']);
    }

    public function test_employee_calendar_reflects_custom_admin_weekend_days(): void
    {
        $admin = User::where('email', 'info@appiflybd.com')->first();
        $employeeUser = User::where('email', 'tusher@appiflybd.com')->first();

        // 1. Admin updates weekend days to Sunday only
        $this->actingAs($admin, 'sanctum')->putJson('/api/settings', [
            'company_name' => 'Appifly BD Limited',
            'timezone' => 'Asia/Dhaka',
            'currency' => 'BDT',
            'currency_symbol' => '৳',
            'current_meal_price' => 120.00,
            'attendance_start_time' => '12:30:00',
            'attendance_end_time' => '14:00:00',
            'cancellation_cutoff_time' => '11:00:00',
            'allow_employee_cancellation' => true,
            'charge_on_attendance_only' => true,
            'max_planning_days' => 30,
            'weekend_days' => ['Sunday'],
        ]);

        // 2. Employee retrieves calendar
        $calendarRes = $this->actingAs($employeeUser, 'sanctum')->getJson('/api/lunch/calendar');
        $calendarRes->assertStatus(200);

        $days = $calendarRes->json('data.days');
        foreach ($days as $day) {
            $date = Carbon::parse($day['date']);
            if ($date->format('l') === 'Sunday') {
                $this->assertTrue($day['is_weekend'], "Sunday should be marked as weekend");
            } else {
                $this->assertFalse($day['is_weekend'], "{$date->format('l')} should NOT be marked as weekend when weekend_days=['Sunday']");
            }
        }

        // 3. Employee attempts to schedule lunch on next Sunday (should fail with 422)
        $nextSunday = Carbon::now('Asia/Dhaka')->next(Carbon::SUNDAY)->toDateString();
        $schedRes = $this->actingAs($employeeUser, 'sanctum')->postJson('/api/lunch/schedule', [
            'lunch_date' => $nextSunday,
            'participate' => true,
        ]);

        $schedRes->assertStatus(422)
            ->assertJsonPath('success', false);
    }
}
