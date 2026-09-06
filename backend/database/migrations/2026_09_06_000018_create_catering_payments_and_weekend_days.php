<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('catering_payments', function (Blueprint $table) {
            $table->id();
            $table->string('payment_id')->unique(); // e.g. CATPAY-20260906-0001
            $table->decimal('amount', 10, 2);
            $table->date('payment_date');
            $table->string('payment_method')->default('Bank Transfer'); // Cash, Bank Transfer, bKash, Nagad, Check, Other
            $table->string('reference')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('recorded_by')->nullable()->constrained('users')->onDelete('set null');
            $table->timestamps();

            $table->index('payment_date');
        });

        if (Schema::hasTable('meal_settings') && ! Schema::hasColumn('meal_settings', 'weekend_days')) {
            Schema::table('meal_settings', function (Blueprint $table) {
                $table->json('weekend_days')->nullable()->after('max_planning_days');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('catering_payments');

        if (Schema::hasTable('meal_settings') && Schema::hasColumn('meal_settings', 'weekend_days')) {
            Schema::table('meal_settings', function (Blueprint $table) {
                $table->dropColumn('weekend_days');
            });
        }
    }
};
