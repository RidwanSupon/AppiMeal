<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employees', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->string('employee_id')->unique();
            $table->string('full_name');
            $table->string('phone')->nullable();
            $table->string('department');
            $table->string('designation');
            $table->date('joining_date')->nullable();
            $table->string('avatar_url')->nullable();
            $table->string('status')->default('active'); // active, inactive
            $table->softDeletes();
            $table->timestamps();

            $table->index('department');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employees');
    }
};
