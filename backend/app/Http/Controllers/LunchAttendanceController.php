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
use Illuminate\Support\Facades\DB;

class LunchAttendanceController extends Controller
{
    public function todayStatus(Request $request): JsonResponse
    {
        $user = $request->user();
        $employee = $user->employee;

        if (! $employee && ! $user->isAdmin()) {
            return response()->json(['success' => false, 'message' => 'Employee profile not found.'], 404);
        }

        LunchAttendance::processAutoAttendanceForDate();

        $settings = MealSettings::first();
        $now = Carbon::now('Asia/Dhaka');
        $todayStr = $now->toDateString();
        $currentTimeStr = $now->format('H:i:s');

        $startTimeStr = $settings->attendance_start_time;
        $endTimeStr = $settings->attendance_end_time;

        // Window status
        if ($currentTimeStr < $startTimeStr) {
            $windowStatus = 'NOT STARTED';
        } elseif ($currentTimeStr > $endTimeStr) {
            $windowStatus = 'CLOSED';
        } else {
            $windowStatus = 'OPEN';
        }

        $schedule = null;
        $attendance = null;

        if ($employee) {
            $schedule = LunchSchedule::where('employee_id', $employee->id)
                ->where('lunch_date', $todayStr)
                ->first();

            $attendance = LunchAttendance::where('employee_id', $employee->id)
                ->where('lunch_date', $todayStr)
                ->first();
        }

        return response()->json([
            'success' => true,
            'message' => "Today's lunch status retrieved.",
            'data' => [
                'server_time' => $now->toIso8601String(),
                'server_time_formatted' => $now->format('h:i A'),
                'today_date' => $todayStr,
                'window_status' => $windowStatus, // NOT STARTED, OPEN, CLOSED
                'attendance_start_time' => Carbon::createFromTimeString($startTimeStr)->format('h:i A'),
                'attendance_end_time' => Carbon::createFromTimeString($endTimeStr)->format('h:i A'),
                'raw_start_time' => $startTimeStr,
                'raw_end_time' => $endTimeStr,
                'is_scheduled' => $schedule && in_array($schedule->status, ['PLANNED', 'CONFIRMED', 'ATTENDED']),
                'schedule_status' => $schedule ? $schedule->status : 'NOT_SCHEDULED',
                'is_attended' => $attendance !== null,
                'attendance_time' => $attendance ? $attendance->attended_at->format('h:i A') : null,
                'can_attend' => ($windowStatus === 'OPEN') && (! $attendance) && (! $schedule || $schedule->status !== 'CANCELLED'),
            ],
        ]);
    }

    public function attend(Request $request): JsonResponse
    {
        $user = $request->user();
        $employee = $user->employee;

        if (! $employee) {
            return response()->json([
                'success' => false,
                'message' => 'Only active employees can record lunch attendance.',
            ], 403);
        }

        LunchAttendance::processAutoAttendanceForDate();

        $settings = MealSettings::first();
        $now = Carbon::now('Asia/Dhaka');
        $todayStr = $now->toDateString();
        $currentTimeStr = $now->format('H:i:s');

        // 1. Verify lunch attendance window
        if ($currentTimeStr < $settings->attendance_start_time || $currentTimeStr > $settings->attendance_end_time) {
            $startTimeFmt = Carbon::createFromTimeString($settings->attendance_start_time)->format('h:i A');
            $endTimeFmt = Carbon::createFromTimeString($settings->attendance_end_time)->format('h:i A');

            return response()->json([
                'success' => false,
                'message' => "Lunch attendance window is closed. Attendance is allowed strictly between {$startTimeFmt} and {$endTimeFmt}.",
            ], 422);
        }

        // 2. Verify duplicate attendance
        $existingAttendance = LunchAttendance::where('employee_id', $employee->id)
            ->where('lunch_date', $todayStr)
            ->first();

        if ($existingAttendance) {
            return response()->json([
                'success' => false,
                'message' => 'Lunch attendance has already been recorded for today at ' . $existingAttendance->attended_at->format('h:i A') . '.',
                'data' => [
                    'attendance_time' => $existingAttendance->attended_at->format('h:i A'),
                ],
            ], 409);
        }

        // 3. Verify schedule status if cancelled or already attended
        $schedule = LunchSchedule::where('employee_id', $employee->id)
            ->where('lunch_date', $todayStr)
            ->first();

        if ($schedule && $schedule->status === 'CANCELLED') {
            return response()->json([
                'success' => false,
                'message' => 'Your lunch schedule for today was cancelled.',
            ], 422);
        }

        if ($schedule && $schedule->status === 'ATTENDED') {
            return response()->json([
                'success' => false,
                'message' => 'Lunch attendance has already been recorded for today.',
            ], 409);
        }

        return DB::transaction(function () use ($employee, $schedule, $todayStr, $now, $settings, $user, $request) {
            if (! $schedule) {
                $schedule = LunchSchedule::create([
                    'employee_id' => $employee->id,
                    'lunch_date' => $todayStr,
                    'status' => 'ATTENDED',
                    'scheduled_at' => $now,
                ]);
            } else {
                $schedule->status = 'ATTENDED';
                $schedule->save();
            }
            // Record Attendance
            $attendance = LunchAttendance::create([
                'employee_id' => $employee->id,
                'schedule_id' => $schedule->id,
                'lunch_date' => $todayStr,
                'attended_at' => $now,
                'status' => 'ATTENDED',
                'ip_address' => $request->ip(),
            ]);

            // Update Schedule status
            $schedule->status = 'ATTENDED';
            $schedule->save();

            // Record Meal Charge with price snapshot
            $priceSnapshot = (float) $settings->current_meal_price;
            $charge = MealCharge::create([
                'employee_id' => $employee->id,
                'attendance_id' => $attendance->id,
                'schedule_id' => $schedule->id,
                'charge_date' => $todayStr,
                'amount' => $priceSnapshot,
                'price_snapshot' => $priceSnapshot,
                'status' => 'BILLED',
            ]);

            // Update Ledger
            $ledger = EmployeeLedger::firstOrCreate(
                ['employee_id' => $employee->id],
                ['opening_balance' => 0.00, 'total_meal_charges' => 0.00, 'total_adjustments' => 0.00, 'total_payments' => 0.00, 'current_due' => 0.00]
            );
            $ledger->total_meal_charges += $priceSnapshot;
            $ledger->recalculateDue();

            AuditLog::log('lunch.attended', 'LunchAttendance', (string) $attendance->id, null, [
                'employee' => $employee->full_name,
                'date' => $todayStr,
                'time' => $now->format('h:i A'),
                'amount' => $priceSnapshot,
            ], $user);

            return response()->json([
                'success' => true,
                'message' => '✓ Lunch attendance recorded successfully at ' . $now->format('h:i A') . '.',
                'data' => [
                    'attendance_id' => $attendance->id,
                    'attended_at' => $now->toIso8601String(),
                    'attendance_time' => $now->format('h:i A'),
                    'meal_price' => $priceSnapshot,
                    'status' => 'ATTENDED',
                ],
            ]);
        });
    }

    public function todayList(Request $request): JsonResponse
    {
        LunchAttendance::processAutoAttendanceForDate();
        $todayStr = Carbon::today('Asia/Dhaka')->toDateString();
        $settings = MealSettings::first();

        $employees = Employee::with(['user', 'schedules' => function ($q) use ($todayStr) {
            $q->where('lunch_date', $todayStr);
        }, 'attendances' => function ($q) use ($todayStr) {
            $q->where('lunch_date', $todayStr);
        }])->where('status', 'active')->get();

        $list = [];
        $totalScheduled = 0;
        $totalAttended = 0;
        $totalPending = 0;
        $totalCancelled = 0;

        foreach ($employees as $emp) {
            $sched = $emp->schedules->first();
            $att = $emp->attendances->first();

            $isScheduled = $sched && in_array($sched->status, ['PLANNED', 'CONFIRMED', 'ATTENDED']);
            $isCancelled = $sched && $sched->status === 'CANCELLED';
            $isAttended = $att !== null;

            if ($isScheduled) {
                $totalScheduled++;
            }
            if ($isAttended) {
                $totalAttended++;
            } elseif ($isScheduled && ! $isCancelled) {
                $totalPending++;
            }
            if ($isCancelled) {
                $totalCancelled++;
            }

            $list[] = [
                'employee_id' => $emp->employee_id,
                'full_name' => $emp->full_name,
                'department' => $emp->department,
                'designation' => $emp->designation,
                'is_scheduled' => $isScheduled,
                'is_attended' => $isAttended,
                'is_cancelled' => $isCancelled,
                'status' => $isAttended ? 'ATTENDED' : ($isCancelled ? 'CANCELLED' : ($isScheduled ? 'PENDING' : 'NOT SCHEDULED')),
                'attendance_time' => $att ? $att->attended_at->format('h:i A') : null,
            ];
        }

        $estimatedCost = $totalAttended * (float) $settings->current_meal_price;

        return response()->json([
            'success' => true,
            'message' => "Today's lunch list retrieved.",
            'data' => [
                'date' => $todayStr,
                'meal_price' => (float) $settings->current_meal_price,
                'total_employees' => count($employees),
                'total_scheduled' => $totalScheduled,
                'total_attended' => $totalAttended,
                'total_pending' => $totalPending,
                'total_cancelled' => $totalCancelled,
                'estimated_cost' => $estimatedCost,
                'employees' => $list,
            ],
        ]);
    }

    public function adminManageList(Request $request): JsonResponse
    {
        $dateStr = $request->get('date', Carbon::today('Asia/Dhaka')->toDateString());
        LunchAttendance::processAutoAttendanceForDate($dateStr);
        $settings = MealSettings::first();

        $query = Employee::with(['user', 'schedules' => function ($q) use ($dateStr) {
            $q->where('lunch_date', $dateStr);
        }, 'attendances' => function ($q) use ($dateStr) {
            $q->where('lunch_date', $dateStr);
        }])->where('status', 'active');

        if ($request->filled('search')) {
            $search = $request->get('search');
            $query->where(function ($q) use ($search) {
                $q->where('full_name', 'like', "%{$search}%")
                  ->orWhere('employee_id', 'like', "%{$search}%")
                  ->orWhere('department', 'like', "%{$search}%");
            });
        }

        if ($request->filled('department')) {
            $query->where('department', $request->get('department'));
        }

        $employees = $query->orderBy('full_name')->get();

        $list = [];
        $totalScheduled = 0;
        $totalAttended = 0;
        $totalPending = 0;
        $totalCancelled = 0;

        foreach ($employees as $emp) {
            $sched = $emp->schedules->first();
            $att = $emp->attendances->first();

            $isAttended = $att !== null;
            $isScheduled = $sched && in_array($sched->status, ['PLANNED', 'CONFIRMED', 'ATTENDED']);
            $isCancelled = $sched && $sched->status === 'CANCELLED';

            $status = 'NOT_SCHEDULED';
            if ($isAttended) {
                $status = 'ATTENDED';
                $totalAttended++;
                $totalScheduled++;
            } elseif ($isCancelled) {
                $status = 'CANCELLED';
                $totalCancelled++;
            } elseif ($isScheduled) {
                $status = 'PLANNED';
                $totalScheduled++;
                $totalPending++;
            }

            $list[] = [
                'id' => $emp->id,
                'employee_id' => $emp->employee_id,
                'full_name' => $emp->full_name,
                'department' => $emp->department,
                'designation' => $emp->designation,
                'avatar_url' => $emp->avatar_url,
                'status' => $status,
                'schedule_id' => $sched?->id,
                'attendance_id' => $att?->id,
                'attendance_time' => $att ? $att->attended_at->format('h:i A') : null,
                'cancellation_reason' => $sched?->cancellation_reason,
            ];
        }

        return response()->json([
            'success' => true,
            'message' => "Manage meal list retrieved for {$dateStr}.",
            'data' => [
                'date' => $dateStr,
                'meal_price' => (float) $settings->current_meal_price,
                'total_employees' => count($employees),
                'total_scheduled' => $totalScheduled,
                'total_attended' => $totalAttended,
                'total_pending' => $totalPending,
                'total_cancelled' => $totalCancelled,
                'employees' => $list,
            ],
        ]);
    }

    public function adminManageMeal(Request $request): JsonResponse
    {
        $request->validate([
            'employee_id' => 'required|exists:employees,id',
            'lunch_date' => 'required|date',
            'status' => 'required|in:ATTENDED,PLANNED,CANCELLED,NOT_SCHEDULED',
            'notes' => 'nullable|string|max:255',
        ]);

        $user = $request->user();
        $employee = Employee::findOrFail($request->employee_id);
        $dateStr = Carbon::parse($request->lunch_date)->toDateString();
        $settings = MealSettings::first();

        return DB::transaction(function () use ($employee, $dateStr, $request, $settings, $user) {
            $schedule = LunchSchedule::where('employee_id', $employee->id)
                ->where('lunch_date', $dateStr)
                ->first();

            $attendance = LunchAttendance::where('employee_id', $employee->id)
                ->where('lunch_date', $dateStr)
                ->first();

            $charge = MealCharge::where('employee_id', $employee->id)
                ->where('charge_date', $dateStr)
                ->first();

            $ledger = EmployeeLedger::firstOrCreate(
                ['employee_id' => $employee->id],
                ['opening_balance' => 0.00, 'total_meal_charges' => 0.00, 'total_adjustments' => 0.00, 'total_payments' => 0.00, 'current_due' => 0.00]
            );

            $targetStatus = $request->status;

            if ($targetStatus === 'ATTENDED') {
                if (! $schedule) {
                    $schedule = LunchSchedule::create([
                        'employee_id' => $employee->id,
                        'lunch_date' => $dateStr,
                        'status' => 'ATTENDED',
                        'scheduled_at' => now('Asia/Dhaka'),
                    ]);
                } else {
                    $schedule->status = 'ATTENDED';
                    $schedule->save();
                }

                if (! $attendance) {
                    $attendance = LunchAttendance::create([
                        'employee_id' => $employee->id,
                        'schedule_id' => $schedule->id,
                        'lunch_date' => $dateStr,
                        'attended_at' => now('Asia/Dhaka'),
                        'status' => 'ATTENDED',
                        'ip_address' => $request->ip(),
                    ]);
                }

                if (! $charge) {
                    $priceSnapshot = (float) $settings->current_meal_price;
                    $charge = MealCharge::create([
                        'employee_id' => $employee->id,
                        'attendance_id' => $attendance->id,
                        'schedule_id' => $schedule->id,
                        'charge_date' => $dateStr,
                        'amount' => $priceSnapshot,
                        'price_snapshot' => $priceSnapshot,
                        'status' => 'BILLED',
                    ]);

                    $ledger->total_meal_charges += $priceSnapshot;
                    $ledger->recalculateDue();
                }

                AuditLog::log('admin.manual_meal_attended', 'LunchAttendance', (string) $attendance->id, null, [
                    'employee' => $employee->full_name,
                    'date' => $dateStr,
                    'notes' => $request->notes,
                ], $user);

            } elseif ($targetStatus === 'PLANNED') {
                if ($attendance) {
                    if ($charge) {
                        $ledger->total_meal_charges -= (float) $charge->amount;
                        $ledger->recalculateDue();
                        $charge->delete();
                    }
                    $attendance->delete();
                }

                if (! $schedule) {
                    $schedule = LunchSchedule::create([
                        'employee_id' => $employee->id,
                        'lunch_date' => $dateStr,
                        'status' => 'PLANNED',
                        'scheduled_at' => now('Asia/Dhaka'),
                    ]);
                } else {
                    $schedule->status = 'PLANNED';
                    $schedule->cancelled_at = null;
                    $schedule->cancellation_reason = null;
                    $schedule->save();
                }

                AuditLog::log('admin.manual_meal_planned', 'LunchSchedule', (string) $schedule->id, null, [
                    'employee' => $employee->full_name,
                    'date' => $dateStr,
                ], $user);

            } elseif ($targetStatus === 'CANCELLED') {
                if ($attendance) {
                    if ($charge) {
                        $ledger->total_meal_charges -= (float) $charge->amount;
                        $ledger->recalculateDue();
                        $charge->delete();
                    }
                    $attendance->delete();
                }

                $reason = $request->notes ?? 'Cancelled manually by Admin';

                if (! $schedule) {
                    $schedule = LunchSchedule::create([
                        'employee_id' => $employee->id,
                        'lunch_date' => $dateStr,
                        'status' => 'CANCELLED',
                        'cancelled_at' => now('Asia/Dhaka'),
                        'cancellation_reason' => $reason,
                    ]);
                } else {
                    $schedule->status = 'CANCELLED';
                    $schedule->cancelled_at = now('Asia/Dhaka');
                    $schedule->cancellation_reason = $reason;
                    $schedule->save();
                }

                AuditLog::log('admin.manual_meal_cancelled', 'LunchSchedule', (string) $schedule->id, null, [
                    'employee' => $employee->full_name,
                    'date' => $dateStr,
                    'reason' => $reason,
                ], $user);

            } elseif ($targetStatus === 'NOT_SCHEDULED') {
                if ($attendance) {
                    if ($charge) {
                        $ledger->total_meal_charges -= (float) $charge->amount;
                        $ledger->recalculateDue();
                        $charge->delete();
                    }
                    $attendance->delete();
                }

                if ($schedule) {
                    $schedule->delete();
                }

                AuditLog::log('admin.manual_meal_removed', 'LunchSchedule', '', null, [
                    'employee' => $employee->full_name,
                    'date' => $dateStr,
                ], $user);
            }

            return response()->json([
                'success' => true,
                'message' => "Meal status for {$employee->full_name} updated to {$targetStatus} for {$dateStr}.",
                'data' => [
                    'employee_id' => $employee->id,
                    'status' => $targetStatus,
                    'date' => $dateStr,
                ],
            ]);
        });
    }
}
