<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class EmployeeLedger extends Model
{
    use HasFactory;

    protected $fillable = [
        'employee_id',
        'opening_balance',
        'total_meal_charges',
        'total_adjustments',
        'total_payments',
        'current_due',
    ];

    protected $casts = [
        'opening_balance' => 'decimal:2',
        'total_meal_charges' => 'decimal:2',
        'total_adjustments' => 'decimal:2',
        'total_payments' => 'decimal:2',
        'current_due' => 'decimal:2',
    ];

    public function employee()
    {
        return $this->belongsTo(Employee::class);
    }

    public function recalculateDue(): float
    {
        $due = (float) $this->opening_balance + (float) $this->total_meal_charges + (float) $this->total_adjustments - (float) $this->total_payments;
        $this->current_due = max(0, $due);
        $this->save();
        return (float) $this->current_due;
    }
}
