<?php

namespace App\Http\Controllers;

use App\Models\Employee;
use App\Models\EmployeeLedger;
use App\Models\LunchAttendance;
use App\Models\LunchSchedule;
use App\Models\MealCharge;
use App\Models\MealSettings;
use App\Models\Payment;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function adminSummary(Request $request): JsonResponse
    {
        LunchAttendance::processAutoAttendanceForDate();
        $todayStr = Carbon::today('Asia/Dhaka')->toDateString();
        $startOfMonth = Carbon::now('Asia/Dhaka')->startOfMonth()->toDateString();
        $endOfMonth = Carbon::now('Asia/Dhaka')->endOfMonth()->toDateString();
        $settings = MealSettings::first();

        // Today metrics
        $todayScheduled = LunchSchedule::where('lunch_date', $todayStr)
            ->whereIn('status', ['PLANNED', 'CONFIRMED', 'ATTENDED'])
            ->count();

        $todayAttended = LunchAttendance::where('lunch_date', $todayStr)->count();

        $todayCancelled = LunchSchedule::where('lunch_date', $todayStr)
            ->where('status', 'CANCELLED')
            ->count();

        $todayPending = max(0, $todayScheduled - $todayAttended - $todayCancelled);

        $todayMealCost = $todayAttended * (float) $settings->current_meal_price;

        // Today's attendees list with employee details
        $todayAttendees = LunchAttendance::with('employee')
            ->where('lunch_date', $todayStr)
            ->latest('attended_at')
            ->get()
            ->map(function ($att) {
                return [
                    'id' => $att->id,
                    'employee_id' => $att->employee ? $att->employee->employee_id : null,
                    'full_name' => $att->employee ? $att->employee->full_name : 'Unknown Employee',
                    'department' => $att->employee ? $att->employee->department : null,
                    'designation' => $att->employee ? $att->employee->designation : null,
                    'avatar_url' => $att->employee ? $att->employee->avatar_url : null,
                    'attended_at' => $att->attended_at ? $att->attended_at->toIso8601String() : null,
                    'attendance_time' => $att->attended_at ? $att->attended_at->format('h:i A') : 'Attended',
                ];
            });

        // Monthly metrics
        $monthlyMeals = LunchAttendance::whereBetween('lunch_date', [$startOfMonth, $endOfMonth])->count();
        $monthlyCost = MealCharge::whereBetween('charge_date', [$startOfMonth, $endOfMonth])->sum('amount');
        $monthlyPaid = Payment::whereBetween('payment_date', [$startOfMonth, $endOfMonth])->sum('amount');

        // Total system due & paid
        $totalDue = EmployeeLedger::sum('current_due');
        $totalPaidAllTime = Payment::sum('amount');

        // Daily chart data for past 7 days
        $dailyTrend = [];
        for ($i = 6; $i >= 0; $i--) {
            $d = Carbon::today('Asia/Dhaka')->subDays($i);
            $dStr = $d->toDateString();
            $dailyTrend[] = [
                'day' => $d->format('D'),
                'date' => $dStr,
                'scheduled' => LunchSchedule::where('lunch_date', $dStr)->whereIn('status', ['PLANNED', 'ATTENDED'])->count(),
                'attended' => LunchAttendance::where('lunch_date', $dStr)->count(),
            ];
        }

        // Department breakdown
        $departmentUsage = Employee::select('department', \DB::raw('count(*) as employee_count'))
            ->groupBy('department')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Admin dashboard summary fetched.',
            'data' => [
                'meal_price' => (float) $settings->current_meal_price,
                'currency' => $settings->currency_symbol,
                'today' => [
                    'date' => $todayStr,
                    'scheduled' => $todayScheduled,
                    'attended' => $todayAttended,
                    'pending' => $todayPending,
                    'cancelled' => $todayCancelled,
                    'cost' => $todayMealCost,
                    'attendees' => $todayAttendees,
                ],
                'monthly' => [
                    'total_meals' => $monthlyMeals,
                    'total_cost' => (float) $monthlyCost,
                    'paid' => (float) $monthlyPaid,
                    'due' => (float) $totalDue,
                ],
                'totals' => [
                    'total_due' => (float) $totalDue,
                    'total_paid' => (float) $totalPaidAllTime,
                ],
                'charts' => [
                    'daily_trend' => $dailyTrend,
                    'department_usage' => $departmentUsage,
                ],
            ],
        ]);
    }

    public function employeeSummary(Request $request): JsonResponse
    {
        $user = $request->user();
        $employee = $user->employee;

        if (! $employee) {
            return response()->json(['success' => false, 'message' => 'Employee profile not found.'], 404);
        }

        LunchAttendance::processAutoAttendanceForDate();

        $todayStr = Carbon::today('Asia/Dhaka')->toDateString();
        $startOfMonth = Carbon::now('Asia/Dhaka')->startOfMonth()->toDateString();
        $endOfMonth = Carbon::now('Asia/Dhaka')->endOfMonth()->toDateString();
        $settings = MealSettings::first();

        $schedule = LunchSchedule::where('employee_id', $employee->id)->where('lunch_date', $todayStr)->first();
        $attendance = LunchAttendance::where('employee_id', $employee->id)->where('lunch_date', $todayStr)->first();

        $monthlyMeals = LunchAttendance::where('employee_id', $employee->id)
            ->whereBetween('lunch_date', [$startOfMonth, $endOfMonth])
            ->count();

        $monthlyCost = MealCharge::where('employee_id', $employee->id)
            ->whereBetween('charge_date', [$startOfMonth, $endOfMonth])
            ->sum('amount');

        $monthlyPaid = Payment::where('employee_id', $employee->id)
            ->whereBetween('payment_date', [$startOfMonth, $endOfMonth])
            ->sum('amount');

        $ledger = EmployeeLedger::where('employee_id', $employee->id)->first();

        $now = Carbon::now('Asia/Dhaka');
        $currentTimeStr = $now->format('H:i:s');
        if ($currentTimeStr < $settings->attendance_start_time) {
            $windowStatus = 'NOT STARTED';
        } elseif ($currentTimeStr > $settings->attendance_end_time) {
            $windowStatus = 'CLOSED';
        } else {
            $windowStatus = 'OPEN';
        }

        return response()->json([
            'success' => true,
            'message' => 'Employee dashboard summary fetched.',
            'data' => [
                'employee' => [
                    'name' => $employee->full_name,
                    'employee_id' => $employee->employee_id,
                    'department' => $employee->department,
                    'designation' => $employee->designation,
                    'avatar_url' => $employee->avatar_url,
                ],
                'today' => [
                    'date' => $todayStr,
                    'is_scheduled' => $schedule && in_array($schedule->status, ['PLANNED', 'CONFIRMED', 'ATTENDED']),
                    'is_attended' => $attendance !== null,
                    'attendance_time' => $attendance ? $attendance->attended_at->format('h:i A') : null,
                    'schedule_status' => $schedule ? $schedule->status : 'NOT SCHEDULED',
                    'can_attend' => ($windowStatus === 'OPEN') && (! $attendance) && (! $schedule || $schedule->status !== 'CANCELLED'),
                ],
                'window' => [
                    'start_time' => Carbon::createFromTimeString($settings->attendance_start_time)->format('h:i A'),
                    'end_time' => Carbon::createFromTimeString($settings->attendance_end_time)->format('h:i A'),
                ],
                'monthly' => [
                    'meals_taken' => $monthlyMeals,
                    'meal_cost' => (float) $monthlyCost,
                    'paid' => (float) $monthlyPaid,
                    'current_due' => (float) ($ledger ? $ledger->current_due : 0.00),
                ],
            ],
        ]);
    }

    public function cateringSummary(Request $request): JsonResponse
    {
        LunchAttendance::processAutoAttendanceForDate();
        $todayStr = Carbon::today('Asia/Dhaka')->toDateString();
        $startOfMonth = Carbon::now('Asia/Dhaka')->startOfMonth()->toDateString();
        $endOfMonth = Carbon::now('Asia/Dhaka')->endOfMonth()->toDateString();
        $settings = MealSettings::first();

        // Today metrics
        $todayScheduled = LunchSchedule::where('lunch_date', $todayStr)
            ->whereIn('status', ['PLANNED', 'CONFIRMED', 'ATTENDED'])
            ->count();

        $todayAttended = LunchAttendance::where('lunch_date', $todayStr)->count();

        $todayCancelled = LunchSchedule::where('lunch_date', $todayStr)
            ->where('status', 'CANCELLED')
            ->count();

        $todayPending = max(0, $todayScheduled - $todayAttended - $todayCancelled);

        // Overall Catering Financial & Delivery Metrics
        $totalMealsDelivered = LunchAttendance::count();
        $totalCateringBill = (float) MealCharge::sum('amount');
        $companyPaid = (float) Payment::sum('amount');
        $cateringDue = (float) EmployeeLedger::sum('current_due');

        // Daily delivery history (past 30 days)
        $dailyHistory = [];
        for ($i = 0; $i < 30; $i++) {
            $d = Carbon::today('Asia/Dhaka')->subDays($i);
            $dStr = $d->toDateString();
            $count = LunchAttendance::where('lunch_date', $dStr)->count();
            $scheduled = LunchSchedule::where('lunch_date', $dStr)->whereIn('status', ['PLANNED', 'CONFIRMED', 'ATTENDED'])->count();

            if ($count > 0 || $scheduled > 0 || $i < 7) {
                $dailyHistory[] = [
                    'date' => $dStr,
                    'day_name' => $d->format('l, d M Y'),
                    'meals_delivered' => $count,
                    'meals_scheduled' => $scheduled,
                    'daily_cost' => $count * (float) $settings->current_meal_price,
                ];
            }
        }

        $todayAttendeesList = Employee::with(['schedules' => function ($q) use ($todayStr) {
            $q->where('lunch_date', $todayStr);
        }, 'attendances' => function ($q) use ($todayStr) {
            $q->where('lunch_date', $todayStr);
        }])->where('status', 'active')->get()->map(function ($emp) {
            $sched = $emp->schedules->first();
            $att = $emp->attendances->first();
            $isScheduled = $sched && in_array($sched->status, ['PLANNED', 'CONFIRMED', 'ATTENDED']);
            $isCancelled = $sched && $sched->status === 'CANCELLED';
            $isAttended = $att !== null;

            return [
                'employee_id' => $emp->employee_id,
                'full_name' => $emp->full_name,
                'department' => $emp->department,
                'designation' => $emp->designation,
                'avatar_url' => $emp->avatar_url,
                'is_scheduled' => $isScheduled,
                'is_attended' => $isAttended,
                'is_cancelled' => $isCancelled,
                'status' => $isAttended ? 'ATTENDED' : ($isCancelled ? 'CANCELLED' : ($isScheduled ? 'PENDING' : 'NOT SCHEDULED')),
                'attendance_time' => $att && $att->attended_at ? $att->attended_at->format('h:i A') : null,
            ];
        });

        return response()->json([
            'success' => true,
            'message' => 'Catering dashboard data fetched.',
            'data' => [
                'date' => $todayStr,
                'total_expected' => $todayScheduled,
                'lunch_taken' => $todayAttended,
                'pending' => $todayPending,
                'cancelled' => $todayCancelled,
                'total_meals_delivered' => $totalMealsDelivered,
                'total_catering_bill' => $totalCateringBill,
                'company_paid' => $companyPaid,
                'catering_due' => $cateringDue,
                'meal_price' => (float) $settings->current_meal_price,
                'daily_history' => $dailyHistory,
                'employees' => $todayAttendeesList,
                'today_attendees' => $todayAttendeesList,
            ],
        ]);
    }
}
