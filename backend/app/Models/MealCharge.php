<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MealCharge extends Model
{
    use HasFactory;

    protected $fillable = [
        'employee_id',
        'attendance_id',
        'schedule_id',
        'charge_date',
        'amount',
        'price_snapshot',
        'status',
    ];

    protected $casts = [
        'charge_date' => 'date:Y-m-d',
        'amount' => 'decimal:2',
        'price_snapshot' => 'decimal:2',
    ];

    public function employee()
    {
        return $this->belongsTo(Employee::class);
    }

    public function attendance()
    {
        return $this->belongsTo(LunchAttendance::class, 'attendance_id');
    }

    public function schedule()
    {
        return $this->belongsTo(LunchSchedule::class, 'schedule_id');
    }
}
