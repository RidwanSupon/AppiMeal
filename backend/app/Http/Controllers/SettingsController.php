<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\MealPriceHistory;
use App\Models\MealSettings;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SettingsController extends Controller
{
    public function getSettings(): JsonResponse
    {
        $settings = MealSettings::first();
        if (! $settings) {
            $settings = MealSettings::create([
                'company_name' => 'Appifly BD Limited',
                'timezone' => 'Asia/Dhaka',
                'currency' => 'BDT',
                'currency_symbol' => '৳',
                'current_meal_price' => 120.00,
                'attendance_start_time' => '12:30:00',
                'attendance_end_time' => '14:00:00',
                'cancellation_cutoff_time' => '11:00:00',
                'allow_employee_cancellation' => true,
                'charge_on_attendance_only' => true,
                'max_planning_days' => 30,
                'weekend_days' => ['Friday', 'Saturday'],
            ]);
        }

        if (empty($settings->weekend_days)) {
            $settings->weekend_days = ['Friday', 'Saturday'];
            $settings->save();
        }

        $priceHistories = MealPriceHistory::with('creator')->orderBy('effective_date', 'desc')->get();

        return response()->json([
            'success' => true,
            'message' => 'System settings retrieved.',
            'data' => [
                'settings' => $settings,
                'price_history' => $priceHistories,
            ],
        ]);
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $request->validate([
            'company_name' => 'required|string|max:255',
            'timezone' => 'required|string',
            'currency' => 'required|string',
            'currency_symbol' => 'required|string',
            'current_meal_price' => 'required|numeric|gt:0',
            'attendance_start_time' => 'required|date_format:H:i:s',
            'attendance_end_time' => 'required|date_format:H:i:s|after:attendance_start_time',
            'cancellation_cutoff_time' => 'required|date_format:H:i:s',
            'allow_employee_cancellation' => 'required|boolean',
            'charge_on_attendance_only' => 'required|boolean',
            'max_planning_days' => 'required|integer|min:1|max:365',
            'weekend_days' => 'nullable|array',
            'weekend_days.*' => 'string|in:Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
        ]);

        $settings = MealSettings::first();
        $oldSettings = $settings ? $settings->toArray() : [];
        $oldPrice = $settings ? (float) $settings->current_meal_price : 0;
        $newPrice = (float) $request->current_meal_price;

        if (! $settings) {
            $settings = new MealSettings;
        }

        $settings->fill($request->all());
        $settings->save();

        // Track price history if price changed
        if (abs($oldPrice - $newPrice) > 0.001) {
            MealPriceHistory::create([
                'price' => $newPrice,
                'effective_date' => now('Asia/Dhaka')->toDateString(),
                'notes' => "Meal price updated from ৳{$oldPrice} to ৳{$newPrice} by " . ($request->user()?->name ?? 'Admin'),
                'created_by' => $request->user()?->id,
            ]);
        }

        AuditLog::log('settings.updated', 'MealSettings', (string) $settings->id, $oldSettings, $settings->toArray(), $request->user());

        return response()->json([
            'success' => true,
            'message' => 'System settings updated successfully.',
            'data' => $settings,
        ]);
    }
}
