<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('meal_settings', function (Blueprint $table) {
            $table->id();
            $table->string('company_name')->default('Appifly BD Limited');
            $table->string('timezone')->default('Asia/Dhaka');
            $table->string('currency')->default('BDT');
            $table->string('currency_symbol')->default('৳');
            $table->decimal('current_meal_price', 10, 2)->default(120.00);
            $table->time('attendance_start_time')->default('12:30:00');
            $table->time('attendance_end_time')->default('14:00:00');
            $table->time('cancellation_cutoff_time')->default('11:00:00');
            $table->boolean('allow_employee_cancellation')->default(true);
            $table->boolean('charge_on_attendance_only')->default(true); // Default: Charge on actual attendance
            $table->integer('max_planning_days')->default(30);
            $table->timestamps();
        });

        Schema::create('meal_price_histories', function (Blueprint $table) {
            $table->id();
            $table->decimal('price', 10, 2);
            $table->date('effective_date');
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->onDelete('set null');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('meal_price_histories');
        Schema::dropIfExists('meal_settings');
    }
};
