<?php

use App\Http\Controllers\AuditLogController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\CateringPaymentController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\EmployeeController;
use App\Http\Controllers\LedgerController;
use App\Http\Controllers\LunchAttendanceController;
use App\Http\Controllers\LunchScheduleController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\PaymentController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\SettingsController;
use App\Http\Middleware\CheckRolePermission;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| AppiMeal REST API Routes
|--------------------------------------------------------------------------
*/

Route::get('/health', function () {
    return response()->json([
        'success' => true,
        'status' => 'ok',
        'system' => 'AppiMeal REST API',
        'company' => 'Appifly BD Limited',
        'timezone' => config('app.timezone'),
        'timestamp' => now('Asia/Dhaka')->toIso8601String(),
    ]);
});

Route::get('/setup-database', function () {
    try {
        Artisan::call('storage:link');
        Artisan::call('migrate:fresh', ['--seed' => true, '--force' => true]);
        return response()->json([
            'success' => true,
            'message' => 'Supabase Database migrated & seeded successfully!',
            'output' => Artisan::output(),
        ]);
    } catch (\Throwable $e) {
        return response()->json([
            'success' => false,
            'error' => $e->getMessage(),
        ], 500);
    }
});

// Auth Routes (Public)
Route::post('/login', [AuthController::class, 'login'])->name('login');
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('/reset-password', [AuthController::class, 'resetPassword']);

// Protected Routes (Sanctum)
Route::middleware('auth:sanctum')->group(function () {

    // Common Auth & Profile
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/profile/avatar', [AuthController::class, 'uploadAvatar']);
    Route::post('/logout', [AuthController::class, 'logout']);

    // Notifications
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::patch('/notifications/{id}/read', [NotificationController::class, 'markAsRead']);
    Route::get('/notifications/preferences', [NotificationController::class, 'preferences']);
    Route::put('/notifications/preferences', [NotificationController::class, 'updatePreferences']);

    // Employee Dashboards & Features
    Route::get('/dashboard/employee', [DashboardController::class, 'employeeSummary']);
    Route::get('/lunch/today-status', [LunchAttendanceController::class, 'todayStatus']);
    Route::get('/lunch/today-list', [LunchAttendanceController::class, 'todayList']);
    Route::get('/lunch/calendar', [LunchScheduleController::class, 'calendar']);
    Route::post('/lunch/schedule', [LunchScheduleController::class, 'schedule']);
    Route::post('/lunch/cancel', [LunchScheduleController::class, 'cancel']);
    Route::post('/lunch/attend', [LunchAttendanceController::class, 'attend']);
    Route::get('/ledger/me', [LedgerController::class, 'myLedger']);

    // Catering Viewer Dashboard
    Route::middleware(CheckRolePermission::class . ':catering_viewer,admin,super_admin')->group(function () {
        Route::get('/dashboard/catering', [DashboardController::class, 'cateringSummary']);
    });

    // Admin & Super Admin Management Routes
    Route::middleware(CheckRolePermission::class . ':admin,super_admin')->group(function () {
        Route::get('/dashboard/admin', [DashboardController::class, 'adminSummary']);

        // Employee Management
        Route::get('/employees', [EmployeeController::class, 'index']);
        Route::get('/employees/{id}', [EmployeeController::class, 'show']);
        Route::post('/employees', [EmployeeController::class, 'store']);
        Route::put('/employees/{id}', [EmployeeController::class, 'update']);
        Route::patch('/employees/{id}/status', [EmployeeController::class, 'toggleStatus']);
        Route::post('/employees/{id}/reset-password', [EmployeeController::class, 'adminResetPassword']);

        // Payments & Ledger
        Route::get('/payments', [PaymentController::class, 'index']);
        Route::post('/payments', [PaymentController::class, 'store']);
        Route::get('/employees/{id}/payments', [PaymentController::class, 'employeePayments']);
        Route::get('/ledger/employees/{id}', [LedgerController::class, 'employeeLedger']);

        // Catering Payments & Billing (Admin)
        Route::get('/catering/payments', [CateringPaymentController::class, 'index']);
        Route::post('/catering/payments', [CateringPaymentController::class, 'store']);
        Route::get('/catering/employee-breakdown', [CateringPaymentController::class, 'employeeBreakdown']);
        Route::get('/catering/summary', [CateringPaymentController::class, 'summary']);

        // Settings
        Route::get('/settings', [SettingsController::class, 'getSettings']);
        Route::put('/settings', [SettingsController::class, 'updateSettings']);

        // Reports
        Route::get('/reports/daily', [ReportController::class, 'daily']);
        Route::get('/reports/monthly', [ReportController::class, 'monthly']);
        Route::get('/reports/employees', [ReportController::class, 'employeeReport']);
        Route::get('/reports/dues', [ReportController::class, 'dueReport']);
        Route::post('/reports/export', [ReportController::class, 'export']);

        // Audit Logs
        Route::get('/audit-logs', [AuditLogController::class, 'index']);

        // Manual Meal Management (Admin)
        Route::get('/admin/lunch/manage-list', [LunchAttendanceController::class, 'adminManageList']);
        Route::post('/admin/lunch/manual-entry', [LunchAttendanceController::class, 'adminManageMeal']);
    });
});
