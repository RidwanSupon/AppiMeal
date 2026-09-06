<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
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
use Illuminate\Support\Facades\Response;

class ReportController extends Controller
{
    public function daily(Request $request): JsonResponse
    {
        $date = $request->get('date', Carbon::today('Asia/Dhaka')->toDateString());
        $settings = MealSettings::first();

        $attendances = LunchAttendance::with('employee')
            ->where('lunch_date', $date)
            ->get();

        $schedules = LunchSchedule::with('employee')
            ->where('lunch_date', $date)
            ->get();

        $totalAttended = $attendances->count();
        $totalScheduled = $schedules->whereIn('status', ['PLANNED', 'CONFIRMED', 'ATTENDED'])->count();
        $totalCancelled = $schedules->where('status', 'CANCELLED')->count();

        $totalCost = $totalAttended * (float) $settings->current_meal_price;

        return response()->json([
            'success' => true,
            'message' => "Daily Lunch Report for {$date}.",
            'data' => [
                'company' => 'Appifly BD Limited',
                'report_name' => 'Daily Lunch Report',
                'date' => $date,
                'total_scheduled' => $totalScheduled,
                'total_attended' => $totalAttended,
                'total_cancelled' => $totalCancelled,
                'meal_price' => (float) $settings->current_meal_price,
                'total_cost' => $totalCost,
                'attendances' => $attendances,
            ],
        ]);
    }

    public function monthly(Request $request): JsonResponse
    {
        $month = $request->get('month', Carbon::now('Asia/Dhaka')->month);
        $year = $request->get('year', Carbon::now('Asia/Dhaka')->year);
        $settings = MealSettings::first();

        $startDate = Carbon::createFromDate($year, $month, 1, 'Asia/Dhaka')->startOfMonth()->toDateString();
        $endDate = Carbon::createFromDate($year, $month, 1, 'Asia/Dhaka')->endOfMonth()->toDateString();

        $totalScheduled = LunchSchedule::whereBetween('lunch_date', [$startDate, $endDate])
            ->whereIn('status', ['PLANNED', 'CONFIRMED', 'ATTENDED'])
            ->count();

        $totalAttended = LunchAttendance::whereBetween('lunch_date', [$startDate, $endDate])->count();
        $totalCancelled = LunchSchedule::whereBetween('lunch_date', [$startDate, $endDate])->where('status', 'CANCELLED')->count();

        $totalCost = MealCharge::whereBetween('charge_date', [$startDate, $endDate])->sum('amount');
        $totalPaid = Payment::whereBetween('payment_date', [$startDate, $endDate])->sum('amount');
        $totalDue = EmployeeLedger::sum('current_due');

        return response()->json([
            'success' => true,
            'message' => 'Monthly Lunch Report fetched.',
            'data' => [
                'company' => 'Appifly BD Limited',
                'report_name' => 'Monthly Lunch Report',
                'period' => Carbon::createFromDate($year, $month, 1)->format('F Y'),
                'total_scheduled' => $totalScheduled,
                'total_attended' => $totalAttended,
                'total_cancelled' => $totalCancelled,
                'total_cost' => (float) $totalCost,
                'total_paid' => (float) $totalPaid,
                'total_due' => (float) $totalDue,
            ],
        ]);
    }

    public function employeeReport(Request $request): JsonResponse
    {
        $employees = Employee::with(['ledger', 'user'])->get()->map(function ($emp) {
            $totalMeals = LunchAttendance::where('employee_id', $emp->id)->count();

            return [
                'employee_id' => $emp->employee_id,
                'full_name' => $emp->full_name,
                'department' => $emp->department,
                'total_meals' => $totalMeals,
                'total_charges' => (float) ($emp->ledger ? $emp->ledger->total_meal_charges : 0.00),
                'total_paid' => (float) ($emp->ledger ? $emp->ledger->total_payments : 0.00),
                'current_due' => (float) ($emp->ledger ? $emp->ledger->current_due : 0.00),
            ];
        });

        return response()->json([
            'success' => true,
            'message' => 'Employee Meal Report fetched.',
            'data' => [
                'company' => 'Appifly BD Limited',
                'report_name' => 'Employee Meal & Payment Summary Report',
                'employees' => $employees,
            ],
        ]);
    }

    public function dueReport(Request $request): JsonResponse
    {
        $ledgers = EmployeeLedger::with('employee')
            ->where('current_due', '>', 0)
            ->orderBy('current_due', 'desc')
            ->get();

        $totalDueSum = $ledgers->sum('current_due');

        return response()->json([
            'success' => true,
            'message' => 'Outstanding Due Report fetched.',
            'data' => [
                'company' => 'Appifly BD Limited',
                'report_name' => 'Employee Outstanding Due Report',
                'total_due_sum' => (float) $totalDueSum,
                'employees_with_due' => $ledgers,
            ],
        ]);
    }

    public function export(Request $request): JsonResponse
    {
        $type = $request->get('type', 'daily');
        $format = $request->get('format', 'csv'); // csv, json
        $user = $request->user();

        AuditLog::log('report.exported', 'Report', null, null, ['type' => $type, 'format' => $format], $user);

        return response()->json([
            'success' => true,
            'message' => "Report exported successfully as {$format}.",
            'data' => [
                'company' => 'Appifly BD Limited',
                'generated_by' => $user ? $user->name : 'System',
                'generated_date' => now('Asia/Dhaka')->toIso8601String(),
                'export_type' => $type,
                'download_url' => "/api/reports/download?type={$type}&format={$format}",
            ],
        ]);
    }
}
