<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\CateringPayment;
use App\Models\Employee;
use App\Models\LunchAttendance;
use App\Models\MealCharge;
use App\Models\MealSettings;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CateringPaymentController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = CateringPayment::with('recorder');

        if ($request->filled('payment_method')) {
            $query->where('payment_method', $request->payment_method);
        }

        if ($request->filled('date_from') && $request->filled('date_to')) {
            $query->whereBetween('payment_date', [$request->date_from, $request->date_to]);
        }

        $payments = $query->orderBy('payment_date', 'desc')
            ->orderBy('id', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'success' => true,
            'message' => 'Catering payments fetched successfully.',
            'data' => $payments,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'amount' => 'required|numeric|gt:0',
            'payment_date' => 'required|date',
            'payment_method' => 'required|string|in:Bank Transfer,Cash,bKash,Nagad,Check,Other',
            'reference' => 'nullable|string|max:255',
            'notes' => 'nullable|string|max:500',
        ]);

        return DB::transaction(function () use ($request) {
            $payDate = Carbon::parse($request->payment_date, 'Asia/Dhaka');

            // Generate Unique Sequence: CATPAY-YYYYMMDD-XXXX
            $datePrefix = 'CATPAY-' . $payDate->format('Ymd') . '-';
            $latestCount = CateringPayment::where('payment_id', 'like', "{$datePrefix}%")->count();
            $paymentId = $datePrefix . str_pad($latestCount + 1, 4, '0', STR_PAD_LEFT);

            $payment = CateringPayment::create([
                'payment_id' => $paymentId,
                'amount' => (float) $request->amount,
                'payment_date' => $payDate->toDateString(),
                'payment_method' => $request->payment_method,
                'reference' => $request->reference,
                'notes' => $request->notes,
                'recorded_by' => $request->user()?->id,
            ]);

            AuditLog::log('catering.payment_recorded', 'CateringPayment', (string) $payment->id, null, [
                'payment_id' => $paymentId,
                'amount' => $payment->amount,
                'method' => $payment->payment_method,
                'reference' => $payment->reference,
            ], $request->user());

            return response()->json([
                'success' => true,
                'message' => "Payment of ৳{$payment->amount} to Catering recorded successfully (ID: {$paymentId}).",
                'data' => $payment->load('recorder'),
            ], 201);
        });
    }

    public function employeeBreakdown(): JsonResponse
    {
        $settings = MealSettings::first();
        $mealPrice = $settings ? (float) $settings->current_meal_price : 120.00;

        $employees = Employee::with('user')
            ->orderBy('full_name')
            ->get();

        $breakdown = $employees->map(function ($emp) use ($mealPrice) {
            $mealsCount = LunchAttendance::where('employee_id', $emp->id)->count();
            return [
                'id' => $emp->id,
                'employee_id' => $emp->employee_id,
                'full_name' => $emp->full_name,
                'department' => $emp->department,
                'designation' => $emp->designation,
                'meals_taken' => $mealsCount,
                'total_cost' => $mealsCount * $mealPrice,
            ];
        });

        return response()->json([
            'success' => true,
            'message' => 'Employee meal breakdown fetched successfully.',
            'data' => [
                'meal_price' => $mealPrice,
                'employees' => $breakdown,
            ],
        ]);
    }

    public function summary(): JsonResponse
    {
        $settings = MealSettings::first();
        $mealPrice = $settings ? (float) $settings->current_meal_price : 120.00;

        $totalMeals = LunchAttendance::count();
        $totalBill = (float) MealCharge::sum('amount');
        if ($totalBill <= 0 && $totalMeals > 0) {
            $totalBill = $totalMeals * $mealPrice;
        }

        $totalPaid = (float) CateringPayment::sum('amount');
        $due = max(0.00, $totalBill - $totalPaid);

        return response()->json([
            'success' => true,
            'message' => 'Catering summary fetched successfully.',
            'data' => [
                'total_meals' => $totalMeals,
                'total_bill' => $totalBill,
                'total_paid' => $totalPaid,
                'due_balance' => $due,
                'meal_price' => $mealPrice,
            ],
        ]);
    }
}
