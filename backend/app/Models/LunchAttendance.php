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

    public static function processAutoAttendanceForDate(?string $dateStr = null): void
    {
        $now = \Carbon\Carbon::now('Asia/Dhaka');
        $targetDate = $dateStr ?? $now->toDateString();
        $todayStr = $now->toDateString();

        if ($targetDate > $todayStr) {
            return;
        }

        $settings = MealSettings::first();
        if (! $settings) {
            return;
        }

        if ($targetDate === $todayStr && $now->format('H:i:s') < $settings->attendance_start_time) {
            return;
        }

        $schedules = LunchSchedule::where('lunch_date', $targetDate)
            ->whereIn('status', ['PLANNED', 'CONFIRMED'])
            ->get();

        foreach ($schedules as $schedule) {
            \Illuminate\Support\Facades\DB::transaction(function () use ($schedule, $targetDate, $now, $settings) {
                $existing = static::where('employee_id', $schedule->employee_id)
                    ->where('lunch_date', $targetDate)
                    ->first();

                if ($existing) {
                    if ($schedule->status !== 'ATTENDED') {
                        $schedule->status = 'ATTENDED';
                        $schedule->save();
                    }
                    return;
                }

                $attendance = static::create([
                    'employee_id' => $schedule->employee_id,
                    'schedule_id' => $schedule->id,
                    'lunch_date' => $targetDate,
                    'attended_at' => $now,
                    'status' => 'ATTENDED',
                    'ip_address' => 'auto-satisfied',
                ]);

                $schedule->status = 'ATTENDED';
                $schedule->save();

                $priceSnapshot = (float) $settings->current_meal_price;
                MealCharge::create([
                    'employee_id' => $schedule->employee_id,
                    'attendance_id' => $attendance->id,
                    'schedule_id' => $schedule->id,
                    'charge_date' => $targetDate,
                    'amount' => $priceSnapshot,
                    'price_snapshot' => $priceSnapshot,
                    'status' => 'BILLED',
                ]);

                $ledger = EmployeeLedger::firstOrCreate(
                    ['employee_id' => $schedule->employee_id],
                    ['opening_balance' => 0.00, 'total_meal_charges' => 0.00, 'total_adjustments' => 0.00, 'total_payments' => 0.00, 'current_due' => 0.00]
                );
                $ledger->total_meal_charges += $priceSnapshot;
                $ledger->recalculateDue();

                $emp = Employee::find($schedule->employee_id);
                AuditLog::log('lunch.auto_attended', 'LunchAttendance', (string) $attendance->id, null, [
                    'employee' => $emp ? $emp->full_name : "ID {$schedule->employee_id}",
                    'date' => $targetDate,
                    'time' => $now->format('h:i A'),
                    'amount' => $priceSnapshot,
                    'note' => 'Auto satisfied from planned lunch',
                ], null);
            });
        }
    }
}
