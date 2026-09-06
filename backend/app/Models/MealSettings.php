<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MealSettings extends Model
{
    use HasFactory;

    protected $fillable = [
        'company_name',
        'timezone',
        'currency',
        'currency_symbol',
        'current_meal_price',
        'attendance_start_time',
        'attendance_end_time',
        'cancellation_cutoff_time',
        'allow_employee_cancellation',
        'charge_on_attendance_only',
        'max_planning_days',
        'weekend_days',
    ];

    protected $casts = [
        'current_meal_price' => 'decimal:2',
        'allow_employee_cancellation' => 'boolean',
        'charge_on_attendance_only' => 'boolean',
        'max_planning_days' => 'integer',
        'weekend_days' => 'array',
    ];
}
