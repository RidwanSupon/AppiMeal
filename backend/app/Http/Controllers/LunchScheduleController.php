<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Employee;
use App\Models\EmployeeLedger;
use App\Models\LunchAttendance;
use App\Models\LunchSchedule;
use App\Models\MealCharge;
use App\Models\MealSettings;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LunchScheduleController extends Controller
{
    public function calendar(Request $request): JsonResponse
    {
        LunchAttendance::processAutoAttendanceForDate();
        $user = $request->user();
        $employee = $user->employee;

        if (! $employee && ! $user->isAdmin()) {
            return response()->json(['success' => false, 'message' => 'Employee profile not found.'], 404);
        }

        $employeeId = $request->get('employee_id', $employee?->id);
        $month = $request->get('month', now('Asia/Dhaka')->month);
        $year = $request->get('year', now('Asia/Dhaka')->year);

        $startDate = Carbon::createFromDate($year, $month, 1, 'Asia/Dhaka')->startOfMonth();
        $endDate = $startDate->copy()->endOfMonth();

        $schedules = LunchSchedule::where('employee_id', $employeeId)
            ->whereBetween('lunch_date', [$startDate->toDateString(), $endDate->toDateString()])
            ->get()
            ->keyBy(function ($item) {
                return $item->lunch_date->format('Y-m-d');
            });

        $calendarDays = [];
        $today = Carbon::today('Asia/Dhaka');
        $settings = MealSettings::first();
        $weekendDays = $settings->weekend_days ?? ['Friday', 'Saturday'];

        for ($date = $startDate->copy(); $date->lte($endDate); $date->addDay()) {
            $dateStr = $date->toDateString();
            $schedule = $schedules->get($dateStr);

            $status = $schedule ? $schedule->status : 'NONE';

            // Mark locked for past dates
            if ($date->lt($today) && ($status === 'NONE' || $status === 'PLANNED')) {
                $status = ($status === 'PLANNED') ? 'MISSED' : 'LOCKED';
            }

            $isWeekend = in_array($date->format('l'), $weekendDays);

            $calendarDays[] = [
                'date' => $dateStr,
                'day_name' => $date->format('D'),
                'day_number' => $date->day,
                'is_today' => $date->isToday(),
                'is_past' => $date->lt($today),
                'is_weekend' => $isWeekend,
                'status' => $status,
                'schedule_id' => $schedule?->id,
                'scheduled_at' => $schedule?->scheduled_at?->toIso8601String(),
                'cancelled_at' => $schedule?->cancelled_at?->toIso8601String(),
                'cancellation_reason' => $schedule?->cancellation_reason,
            ];
        }

        return response()->json([
            'success' => true,
            'message' => 'Lunch schedule calendar retrieved.',
            'data' => [
                'month' => (int) $month,
                'year' => (int) $year,
                'days' => $calendarDays,
            ],
        ]);
    }

    public function schedule(Request $request): JsonResponse
    {
        $request->validate([
            'lunch_date' => 'required|date|after_or_equal:today',
            'participate' => 'required|boolean',
        ]);

        $user = $request->user();
        $employee = $user->employee;

        if (! $employee) {
            return response()->json(['success' => false, 'message' => 'Employee profile not found.'], 404);
        }

        $lunchDate = Carbon::parse($request->lunch_date, 'Asia/Dhaka')->startOfDay();
        $today = Carbon::today('Asia/Dhaka');
        $settings = MealSettings::first();
        $weekendDays = $settings->weekend_days ?? ['Friday', 'Saturday'];

        if (in_array($lunchDate->format('l'), $weekendDays)) {
            return response()->json([
                'success' => false,
                'message' => 'Lunch scheduling is disabled on company weekend days (' . implode(', ', $weekendDays) . ').',
            ], 422);
        }

        // Validate max planning days
        if ($lunchDate->diffInDays($today) > $settings->max_planning_days) {
            return response()->json([
                'success' => false,
                'message' => "Lunch planning is allowed only up to {$settings->max_planning_days} days in advance.",
            ], 422);
        }

        // If for today, check cutoff time
        if ($lunchDate->isToday()) {
            $nowTime = Carbon::now('Asia/Dhaka')->format('H:i:s');
            if ($nowTime >= $settings->cancellation_cutoff_time) {
                return response()->json([
                    'success' => false,
                    'message' => "Today's lunch participation cut-off time ({$settings->cancellation_cutoff_time}) has passed.",
                ], 422);
            }
        }

        $schedule = LunchSchedule::firstOrNew([
            'employee_id' => $employee->id,
            'lunch_date' => $lunchDate->toDateString(),
        ]);

        if ($request->participate) {
            $schedule->status = 'PLANNED';
            $schedule->scheduled_at = now('Asia/Dhaka');
            $schedule->cancelled_at = null;
            $schedule->cancellation_reason = null;
            $schedule->save();
            $actionStr = 'scheduled';
        } else {
            $schedule->status = 'CANCELLED';
            $schedule->cancelled_at = now('Asia/Dhaka');
            $schedule->cancellation_reason = 'Opt-out by employee';
            $schedule->save();

            // Clean up any attendance or meal charge if present
            $attendance = LunchAttendance::where('employee_id', $employee->id)
                ->where('lunch_date', $lunchDate->toDateString())
                ->first();

            if ($attendance) {
                $charge = MealCharge::where('attendance_id', $attendance->id)->first();
                if ($charge) {
                    $ledger = EmployeeLedger::where('employee_id', $employee->id)->first();
                    if ($ledger) {
                        $ledger->total_meal_charges = max(0, $ledger->total_meal_charges - (float) $charge->amount);
                        $ledger->recalculateDue();
                    }
                    $charge->delete();
                }
                $attendance->delete();
            }

            $actionStr = 'opted-out';
        }

        AuditLog::log("lunch.{$actionStr}", 'LunchSchedule', (string) $schedule->id, null, [
            'date' => $lunchDate->toDateString(),
            'status' => $schedule->status,
        ], $user);

        return response()->json([
            'success' => true,
            'message' => "Lunch {$actionStr} successfully for {$lunchDate->format('M d, Y')}.",
            'data' => $schedule,
        ]);
    }

    public function cancel(Request $request): JsonResponse
    {
        $request->validate([
            'lunch_date' => 'required|date',
            'reason' => 'nullable|string|max:255',
        ]);

        $user = $request->user();
        $employee = $user->employee;

        if (! $employee && ! $user->isAdmin()) {
            return response()->json(['success' => false, 'message' => 'Employee profile not found.'], 404);
        }

        $employeeId = $request->get('employee_id', $employee?->id);
        $lunchDate = Carbon::parse($request->lunch_date, 'Asia/Dhaka')->startOfDay();
        $settings = MealSettings::first();

        $schedule = LunchSchedule::where('employee_id', $employeeId)
            ->where('lunch_date', $lunchDate->toDateString())
            ->first();

        if (! $schedule || $schedule->status === 'CANCELLED') {
            return response()->json(['success' => false, 'message' => 'No active lunch schedule found for this date.'], 404);
        }

        if ($schedule->status === 'ATTENDED') {
            return response()->json(['success' => false, 'message' => 'Attended lunch cannot be cancelled.'], 422);
        }

        // Non-admin cutoff check
        if (! $user->isAdmin() && $lunchDate->isToday()) {
            $nowTime = Carbon::now('Asia/Dhaka')->format('H:i:s');
            if ($nowTime >= $settings->cancellation_cutoff_time) {
                return response()->json([
                    'success' => false,
                    'message' => "Lunch cancellation cutoff time ({$settings->cancellation_cutoff_time}) has passed for today.",
                ], 422);
            }
        }

        $schedule->status = 'CANCELLED';
        $schedule->cancelled_at = now('Asia/Dhaka');
        $schedule->cancellation_reason = $request->get('reason', 'Cancelled by employee');
        $schedule->save();

        // Clean up any attendance or meal charge if present
        $attendance = LunchAttendance::where('employee_id', $employeeId)
            ->where('lunch_date', $lunchDate->toDateString())
            ->first();

        if ($attendance) {
            $charge = MealCharge::where('attendance_id', $attendance->id)->first();
            if ($charge) {
                $ledger = EmployeeLedger::where('employee_id', $employeeId)->first();
                if ($ledger) {
                    $ledger->total_meal_charges = max(0, $ledger->total_meal_charges - (float) $charge->amount);
                    $ledger->recalculateDue();
                }
                $charge->delete();
            }
            $attendance->delete();
        }

        AuditLog::log('lunch.cancelled', 'LunchSchedule', (string) $schedule->id, null, [
            'date' => $lunchDate->toDateString(),
            'reason' => $schedule->cancellation_reason,
        ], $user);

        return response()->json([
            'success' => true,
            'message' => 'Lunch cancelled successfully.',
            'data' => $schedule,
        ]);
    }
}
