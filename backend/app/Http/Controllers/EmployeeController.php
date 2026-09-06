<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Employee;
use App\Models\EmployeeLedger;
use App\Models\NotificationPreference;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class EmployeeController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Employee::with(['user.role', 'ledger']);

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('full_name', 'like', "%{$search}%")
                    ->orWhere('employee_id', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($u) use ($search) {
                        $u->where('email', 'like', "%{$search}%");
                    });
            });
        }

        if ($request->filled('department')) {
            $query->where('department', $request->department);
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        $employees = $query->orderBy('full_name')->paginate($request->get('per_page', 15));

        return response()->json([
            'success' => true,
            'message' => 'Employees fetched successfully.',
            'data' => $employees,
        ]);
    }

    public function show($id): JsonResponse
    {
        $employee = Employee::with(['user.role', 'ledger', 'schedules' => function ($q) {
            $q->orderBy('lunch_date', 'desc')->take(10);
        }, 'payments' => function ($q) {
            $q->orderBy('payment_date', 'desc')->take(10);
        }])->findOrFail($id);

        return response()->json([
            'success' => true,
            'message' => 'Employee details fetched.',
            'data' => $employee,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'full_name' => 'required|string|max:255',
            'employee_id' => 'required|string|unique:employees,employee_id',
            'email' => 'required|email|unique:users,email',
            'phone' => 'nullable|string|max:20',
            'department' => 'required|string',
            'designation' => 'required|string',
            'joining_date' => 'nullable|date',
            'password' => 'required|string|min:8',
            'role' => 'nullable|string|exists:roles,slug',
        ]);

        return DB::transaction(function () use ($request) {
            $roleSlug = $request->get('role', Role::EMPLOYEE);
            $role = Role::where('slug', $roleSlug)->firstOrFail();

            $user = User::create([
                'name' => $request->full_name,
                'email' => strtolower(trim($request->email)),
                'password' => Hash::make($request->password),
                'role_id' => $role->id,
                'is_active' => true,
            ]);

            NotificationPreference::create(['user_id' => $user->id]);

            $employee = Employee::create([
                'user_id' => $user->id,
                'employee_id' => strtoupper(trim($request->employee_id)),
                'full_name' => $request->full_name,
                'phone' => $request->phone,
                'department' => $request->department,
                'designation' => $request->designation,
                'joining_date' => $request->joining_date ?? now()->toDateString(),
                'status' => 'active',
            ]);

            EmployeeLedger::create([
                'employee_id' => $employee->id,
                'opening_balance' => 0.00,
                'total_meal_charges' => 0.00,
                'total_adjustments' => 0.00,
                'total_payments' => 0.00,
                'current_due' => 0.00,
            ]);

            AuditLog::log('employee.created', 'Employee', (string) $employee->id, null, [
                'employee_id' => $employee->employee_id,
                'name' => $employee->full_name,
                'email' => $user->email,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Employee created successfully.',
                'data' => $employee->load(['user.role', 'ledger']),
            ], 201);
        });
    }

    public function update(Request $request, $id): JsonResponse
    {
        $employee = Employee::with('user')->findOrFail($id);

        $request->validate([
            'full_name' => 'required|string|max:255',
            'phone' => 'nullable|string|max:20',
            'department' => 'required|string',
            'designation' => 'required|string',
            'joining_date' => 'nullable|date',
        ]);

        $oldVal = $employee->toArray();

        $employee->update([
            'full_name' => $request->full_name,
            'phone' => $request->phone,
            'department' => $request->department,
            'designation' => $request->designation,
            'joining_date' => $request->joining_date,
        ]);

        $employee->user->update([
            'name' => $request->full_name,
        ]);

        AuditLog::log('employee.updated', 'Employee', (string) $employee->id, $oldVal, $employee->toArray());

        return response()->json([
            'success' => true,
            'message' => 'Employee updated successfully.',
            'data' => $employee->fresh(['user.role', 'ledger']),
        ]);
    }

    public function toggleStatus($id): JsonResponse
    {
        $employee = Employee::with('user')->findOrFail($id);
        $newStatus = $employee->status === 'active' ? 'inactive' : 'active';

        $employee->status = $newStatus;
        $employee->save();

        $employee->user->is_active = ($newStatus === 'active');
        $employee->user->save();

        AuditLog::log('employee.status_changed', 'Employee', (string) $employee->id, null, ['status' => $newStatus]);

        return response()->json([
            'success' => true,
            'message' => "Employee status changed to {$newStatus}.",
            'data' => $employee,
        ]);
    }

    public function adminResetPassword(Request $request, $id): JsonResponse
    {
        $request->validate([
            'password' => 'required|string|min:8',
        ]);

        $employee = Employee::with('user')->findOrFail($id);
        $employee->user->password = Hash::make($request->password);
        $employee->user->save();

        AuditLog::log('employee.password_reset_by_admin', 'Employee', (string) $employee->id, null, ['email' => $employee->user->email]);

        return response()->json([
            'success' => true,
            'message' => "Password reset successfully for {$employee->full_name}.",
        ]);
    }
}
