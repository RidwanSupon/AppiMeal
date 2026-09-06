<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('lunch_schedules', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained('employees')->onDelete('cascade');
            $table->date('lunch_date');
            $table->enum('status', ['PLANNED', 'CONFIRMED', 'ATTENDED', 'CANCELLED', 'MISSED', 'LOCKED'])->default('PLANNED');
            $table->timestamp('scheduled_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->text('cancellation_reason')->nullable();
            $table->timestamps();

            $table->unique(['employee_id', 'lunch_date']);
            $table->index(['lunch_date', 'status']);
        });

        Schema::create('lunch_attendances', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained('employees')->onDelete('cascade');
            $table->foreignId('schedule_id')->nullable()->constrained('lunch_schedules')->onDelete('set null');
            $table->date('lunch_date');
            $table->timestamp('attended_at');
            $table->enum('status', ['ATTENDED', 'MISSED'])->default('ATTENDED');
            $table->string('ip_address')->nullable();
            $table->timestamps();

            $table->unique(['employee_id', 'lunch_date']);
            $table->index('lunch_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lunch_attendances');
        Schema::dropIfExists('lunch_schedules');
    }
};
