<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Employee;
use App\Models\EmployeeLedger;
use App\Models\Payment;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PaymentController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Payment::with(['employee', 'recorder']);

        if ($request->filled('employee_id')) {
            $query->where('employee_id', $request->employee_id);
        }

        if ($request->filled('payment_method')) {
            $query->where('payment_method', $request->payment_method);
        }

        if ($request->filled('date_from') && $request->filled('date_to')) {
            $query->whereBetween('payment_date', [$request->date_from, $request->date_to]);
        }

        $payments = $query->orderBy('payment_date', 'desc')
            ->orderBy('id', 'desc')
            ->paginate($request->get('per_page', 15));

        return response()->json([
            'success' => true,
            'message' => 'Payments fetched successfully.',
            'data' => $payments,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'employee_id' => 'required|exists:employees,id',
            'amount' => 'required|numeric|gt:0',
            'payment_date' => 'required|date',
            'payment_method' => 'required|string|in:Cash,Bank Transfer,bKash,Nagad,Other',
            'reference' => 'nullable|string|max:255',
            'notes' => 'nullable|string|max:500',
        ]);

        return DB::transaction(function () use ($request) {
            $employee = Employee::findOrFail($request->employee_id);
            $payDate = Carbon::parse($request->payment_date, 'Asia/Dhaka');

            // Generate Unique Sequence: PAY-YYYYMMDD-XXXX
            $datePrefix = 'PAY-' . $payDate->format('Ymd') . '-';
            $latestCount = Payment::where('payment_id', 'like', "{$datePrefix}%")->count();
            $paymentId = $datePrefix . str_pad($latestCount + 1, 4, '0', STR_PAD_LEFT);

            $payment = Payment::create([
                'payment_id' => $paymentId,
                'employee_id' => $employee->id,
                'amount' => (float) $request->amount,
                'payment_date' => $payDate->toDateString(),
                'payment_method' => $request->payment_method,
                'reference' => $request->reference,
                'notes' => $request->notes,
                'recorded_by' => $request->user()?->id,
            ]);

            // Update Employee Ledger
            $ledger = EmployeeLedger::firstOrCreate(
                ['employee_id' => $employee->id],
                ['opening_balance' => 0.00, 'total_meal_charges' => 0.00, 'total_adjustments' => 0.00, 'total_payments' => 0.00, 'current_due' => 0.00]
            );

            $ledger->total_payments += (float) $request->amount;
            $currentDue = $ledger->recalculateDue();

            AuditLog::log('payment.recorded', 'Payment', (string) $payment->id, null, [
                'payment_id' => $paymentId,
                'employee' => $employee->full_name,
                'amount' => $payment->amount,
                'method' => $payment->payment_method,
                'new_due' => $currentDue,
            ], $request->user());

            return response()->json([
                'success' => true,
                'message' => "Payment of ৳{$payment->amount} recorded successfully (ID: {$paymentId}).",
                'data' => $payment->load(['employee', 'recorder']),
            ], 201);
        });
    }

    public function employeePayments($employeeId): JsonResponse
    {
        $employee = Employee::findOrFail($employeeId);
        $payments = Payment::where('employee_id', $employeeId)
            ->orderBy('payment_date', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'message' => "Payments history for {$employee->full_name}.",
            'data' => $payments,
        ]);
    }
}
