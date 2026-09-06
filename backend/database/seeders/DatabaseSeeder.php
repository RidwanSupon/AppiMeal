<?php

namespace Database\Seeders;

use App\Models\AuditLog;
use App\Models\Department;
use App\Models\Employee;
use App\Models\EmployeeLedger;
use App\Models\LunchAttendance;
use App\Models\LunchSchedule;
use App\Models\MealCharge;
use App\Models\MealPriceHistory;
use App\Models\MealSettings;
use App\Models\Notification;
use App\Models\NotificationPreference;
use App\Models\Payment;
use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Roles
        $superAdminRole = Role::create([
            'name' => 'SUPER ADMIN',
            'slug' => Role::SUPER_ADMIN,
            'description' => 'Full control over system settings, users, pricing, payments and reports.',
        ]);

        $adminRole = Role::create([
            'name' => 'ADMIN',
            'slug' => Role::ADMIN,
            'description' => 'Manages employees, lunch windows, payments, and views all reports.',
        ]);

        $employeeRole = Role::create([
            'name' => 'EMPLOYEE',
            'slug' => Role::EMPLOYEE,
            'description' => 'Can schedule lunch, attend lunch, view personal ledger and history.',
        ]);

        $cateringRole = Role::create([
            'name' => 'CATERING VIEWER',
            'slug' => Role::CATERING_VIEWER,
            'description' => 'Read-only view of daily/monthly meal counts and attendance checklist.',
        ]);

        // 2. Permissions
        $permissionsList = [
            ['name' => 'Manage System Settings', 'slug' => 'settings.manage', 'module' => 'admin'],
            ['name' => 'Manage Employees', 'slug' => 'employees.manage', 'module' => 'admin'],
            ['name' => 'Manage Meal Pricing', 'slug' => 'pricing.manage', 'module' => 'admin'],
            ['name' => 'Record Payments', 'slug' => 'payments.record', 'module' => 'finance'],
            ['name' => 'View Reports', 'slug' => 'reports.view', 'module' => 'reports'],
            ['name' => 'Export Reports', 'slug' => 'reports.export', 'module' => 'reports'],
            ['name' => 'View Audit Logs', 'slug' => 'audit.view', 'module' => 'audit'],
            ['name' => 'Schedule Lunch', 'slug' => 'lunch.schedule', 'module' => 'employee'],
            ['name' => 'Attend Lunch', 'slug' => 'lunch.attend', 'module' => 'employee'],
            ['name' => 'View Catering Dashboard', 'slug' => 'catering.view', 'module' => 'catering'],
        ];

        foreach ($permissionsList as $permData) {
            $perm = Permission::create($permData);
            $superAdminRole->permissions()->attach($perm->id);
            if (in_array($permData['slug'], ['employees.manage', 'pricing.manage', 'payments.record', 'reports.view', 'reports.export', 'catering.view'])) {
                $adminRole->permissions()->attach($perm->id);
            }
            if (in_array($permData['slug'], ['lunch.schedule', 'lunch.attend'])) {
                $employeeRole->permissions()->attach($perm->id);
            }
            if ($permData['slug'] === 'catering.view') {
                $cateringRole->permissions()->attach($perm->id);
            }
        }

        // 3. Departments
        Department::create(['name' => 'Management', 'code' => 'MGMT', 'description' => 'Executive Leadership']);
        Department::create(['name' => 'Business Development', 'code' => 'BD', 'description' => 'Strategic Partnerships & Sales']);
        Department::create(['name' => 'Software Engineering', 'code' => 'SWE', 'description' => 'Core Software Engineering']);
        Department::create(['name' => 'Product & Analysis', 'code' => 'PROD', 'description' => 'Product Management & Analytics']);
        Department::create(['name' => 'UI/UX Design', 'code' => 'DES', 'description' => 'Product Design & User Experience']);
        Department::create(['name' => 'Web Development', 'code' => 'WEB', 'description' => 'Web Development Team']);
        Department::create(['name' => 'App Development', 'code' => 'APP', 'description' => 'Mobile App Development Team']);

        // 4. System Settings
        $settings = MealSettings::create([
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
        ]);

        MealPriceHistory::create([
            'price' => 120.00,
            'effective_date' => Carbon::now()->startOfMonth()->toDateString(),
            'notes' => 'Initial meal price setup for Appifly BD Limited',
        ]);

        // 5. Admin User (info@appiflybd.com / appifly@meal)
        $adminUser = User::create([
            'name' => 'Appifly Admin',
            'email' => 'info@appiflybd.com',
            'password' => Hash::make('appifly@meal'),
            'role_id' => $superAdminRole->id,
            'is_active' => true,
        ]);
        NotificationPreference::create(['user_id' => $adminUser->id]);

        // Catering User
        $cateringUser = User::create([
            'name' => 'Catering Staff',
            'email' => 'catering@appiflybd.com',
            'password' => Hash::make('appifly@meal'),
            'role_id' => $cateringRole->id,
            'is_active' => true,
        ]);
        NotificationPreference::create(['user_id' => $cateringUser->id]);

        // 6. Real Employees
        $employeeData = [
            [
                'name' => 'MD Tusher Akanda',
                'employee_id' => 'AF2026001',
                'email' => 'tusher@appiflybd.com',
                'designation' => 'Managing Director',
                'department' => 'Management',
            ],
            [
                'name' => 'MD Masum Talukder',
                'employee_id' => 'AF2026002',
                'email' => 'masum@appiflybd.com',
                'designation' => 'CEO',
                'department' => 'Management',
            ],
            [
                'name' => 'Ashfakul Alam',
                'employee_id' => 'AF2026003',
                'email' => 'ashfakul@appiflybd.com',
                'designation' => 'Manager, Strategic Partnerships',
                'department' => 'Business Development',
            ],
            [
                'name' => 'Iftekhar Mahmud',
                'employee_id' => 'AF2026004',
                'email' => 'iftekhar@appiflybd.com',
                'designation' => 'Lead Software Engineer',
                'department' => 'Software Engineering',
            ],
            [
                'name' => 'Md Ridwanur Rahman',
                'employee_id' => 'AF2026005',
                'email' => 'ridwan@appiflybd.com',
                'designation' => 'Software Business Analyst',
                'department' => 'Product & Analysis',
            ],
            [
                'name' => 'Amir Hamja Fahim',
                'employee_id' => 'AF2026006',
                'email' => 'amir@appiflybd.com',
                'designation' => 'Lead UI/UX Designer',
                'department' => 'UI/UX Design',
            ],
            [
                'name' => 'Shojib Bhuiyan',
                'employee_id' => 'AF2026007',
                'email' => 'shojib@appiflybd.com',
                'designation' => 'Business Development Manager',
                'department' => 'Business Development',
            ],
            [
                'name' => 'Hridoy Talukder',
                'employee_id' => 'AF2026009',
                'email' => 'hridoy@appiflybd.com',
                'designation' => 'Web Dev (Intern)',
                'department' => 'Web Development',
            ],
            [
                'name' => 'Mohammad Nayem Islam',
                'employee_id' => 'AF2026010',
                'email' => 'nayem@appiflybd.com',
                'designation' => 'Senior Product Manager',
                'department' => 'Product & Analysis',
            ],
            [
                'name' => 'Hasnain Al Ifan',
                'employee_id' => 'AF2026011',
                'email' => 'ifan@appiflybd.com',
                'designation' => 'Web Dev (Intern)',
                'department' => 'Web Development',
            ],
            [
                'name' => 'Dipto Chandra Das',
                'employee_id' => 'AF2026012',
                'email' => 'dipto@appiflybd.com',
                'designation' => 'App Dev (Intern)',
                'department' => 'App Development',
            ],
            [
                'name' => 'Jami Abdullah',
                'employee_id' => 'AF2026013',
                'email' => 'abdullah@appiflybd.com',
                'designation' => 'Web Dev (Intern)',
                'department' => 'Web Development',
            ],
            [
                'name' => 'Marwon Ahmed Sijan',
                'employee_id' => 'AF2026014',
                'email' => 'marwon@appiflybd.com',
                'designation' => 'App Dev (Intern)',
                'department' => 'App Development',
            ],
        ];

        foreach ($employeeData as $data) {
            $user = User::create([
                'name' => $data['name'],
                'email' => strtolower(trim($data['email'])),
                'password' => Hash::make('password'),
                'role_id' => $employeeRole->id,
                'is_active' => true,
            ]);
            NotificationPreference::create(['user_id' => $user->id]);

            $emp = Employee::create([
                'user_id' => $user->id,
                'employee_id' => $data['employee_id'],
                'full_name' => $data['name'],
                'phone' => null,
                'department' => $data['department'],
                'designation' => $data['designation'],
                'joining_date' => '2026-01-01',
                'status' => 'active',
            ]);

            EmployeeLedger::create([
                'employee_id' => $emp->id,
                'opening_balance' => 0.00,
                'total_meal_charges' => 0.00,
                'total_adjustments' => 0.00,
                'total_payments' => 0.00,
                'current_due' => 0.00,
            ]);

            Notification::create([
                'user_id' => $user->id,
                'title' => 'Welcome to AppiMeal',
                'message' => 'Your Appifly BD meal account is now active.',
                'type' => 'info',
                'is_read' => false,
            ]);
        }

        AuditLog::log('system.seed', 'System', '1', null, ['message' => 'Database populated with Appifly BD Limited official employees']);
    }
}
