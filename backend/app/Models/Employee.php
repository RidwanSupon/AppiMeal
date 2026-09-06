<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Employee extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'user_id',
        'employee_id',
        'full_name',
        'phone',
        'department',
        'designation',
        'joining_date',
        'avatar_url',
        'status',
    ];

    protected $casts = [
        'joining_date' => 'date',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function schedules()
    {
        return $this->hasMany(LunchSchedule::class);
    }

    public function attendances()
    {
        return $this->hasMany(LunchAttendance::class);
    }

    public function charges()
    {
        return $this->hasMany(MealCharge::class);
    }

    public function payments()
    {
        return $this->hasMany(Payment::class);
    }

    public function ledger()
    {
        return $this->hasOne(EmployeeLedger::class);
    }
}
