<?php

namespace App\Http\Controllers;

use App\Models\Employee;
use App\Models\EmployeeLedger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LedgerController extends Controller
{
    public function myLedger(Request $request): JsonResponse
    {
        $employee = $request->user()->employee;

        if (! $employee) {
            return response()->json(['success' => false, 'message' => 'Employee profile not found.'], 404);
        }

        $ledger = EmployeeLedger::where('employee_id', $employee->id)->first();
        if (! $ledger) {
            $ledger = EmployeeLedger::create([
                'employee_id' => $employee->id,
                'opening_balance' => 0.00,
                'total_meal_charges' => 0.00,
                'total_adjustments' => 0.00,
                'total_payments' => 0.00,
                'current_due' => 0.00,
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Ledger retrieved.',
            'data' => [
                'employee_id' => $employee->employee_id,
                'full_name' => $employee->full_name,
                'opening_balance' => (float) $ledger->opening_balance,
                'total_meal_charges' => (float) $ledger->total_meal_charges,
                'total_adjustments' => (float) $ledger->total_adjustments,
                'total_payments' => (float) $ledger->total_payments,
                'current_due' => (float) $ledger->current_due,
            ],
        ]);
    }

    public function employeeLedger($id): JsonResponse
    {
        $employee = Employee::with('ledger')->findOrFail($id);

        return response()->json([
            'success' => true,
            'message' => "Ledger for {$employee->full_name}.",
            'data' => $employee->ledger,
        ]);
    }
}
