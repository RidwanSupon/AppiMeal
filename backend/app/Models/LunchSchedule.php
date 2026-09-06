<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LunchSchedule extends Model
{
    use HasFactory;

    protected $fillable = [
        'employee_id',
        'lunch_date',
        'status',
        'scheduled_at',
        'cancelled_at',
        'cancellation_reason',
    ];

    protected $casts = [
        'lunch_date' => 'date:Y-m-d',
        'scheduled_at' => 'datetime',
        'cancelled_at' => 'datetime',
    ];

    public function employee()
    {
        return $this->belongsTo(Employee::class);
    }

    public function attendance()
    {
        return $this->hasOne(LunchAttendance::class, 'schedule_id');
    }

    public function charge()
    {
        return $this->hasOne(MealCharge::class, 'schedule_id');
    }
}
