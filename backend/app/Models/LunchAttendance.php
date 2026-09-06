<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LunchAttendance extends Model
{
    use HasFactory;

    protected $fillable = [
        'employee_id',
        'schedule_id',
        'lunch_date',
        'attended_at',
        'status',
        'ip_address',
    ];

    protected $casts = [
        'lunch_date' => 'date:Y-m-d',
        'attended_at' => 'datetime',
    ];

    public function employee()
    {
        return $this->belongsTo(Employee::class);
    }

    public function schedule()
    {
        return $this->belongsTo(LunchSchedule::class, 'schedule_id');
    }

    public function charge()
    {
        return $this->hasOne(MealCharge::class, 'attendance_id');
    }
}
