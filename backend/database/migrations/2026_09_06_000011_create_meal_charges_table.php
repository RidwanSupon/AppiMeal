<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('meal_charges', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained('employees')->onDelete('cascade');
            $table->foreignId('attendance_id')->nullable()->constrained('lunch_attendances')->onDelete('set null');
            $table->foreignId('schedule_id')->nullable()->constrained('lunch_schedules')->onDelete('set null');
            $table->date('charge_date');
            $table->decimal('amount', 10, 2);
            $table->decimal('price_snapshot', 10, 2);
            $table->enum('status', ['PENDING', 'BILLED', 'CANCELLED'])->default('BILLED');
            $table->timestamps();

            $table->unique(['employee_id', 'charge_date']);
            $table->index('charge_date');
        });

        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->string('payment_id')->unique(); // e.g. PAY-20260906-0001
            $table->foreignId('employee_id')->constrained('employees')->onDelete('cascade');
            $table->decimal('amount', 10, 2);
            $table->date('payment_date');
            $table->string('payment_method')->default('Cash'); // Cash, Bank Transfer, bKash, Nagad, Other
            $table->string('reference')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('recorded_by')->nullable()->constrained('users')->onDelete('set null');
            $table->timestamps();

            $table->index(['employee_id', 'payment_date']);
        });

        Schema::create('employee_ledgers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->unique()->constrained('employees')->onDelete('cascade');
            $table->decimal('opening_balance', 10, 2)->default(0.00);
            $table->decimal('total_meal_charges', 10, 2)->default(0.00);
            $table->decimal('total_adjustments', 10, 2)->default(0.00);
            $table->decimal('total_payments', 10, 2)->default(0.00);
            $table->decimal('current_due', 10, 2)->default(0.00); // Opening + Charges + Adjustments - Payments
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_ledgers');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('meal_charges');
    }
};
