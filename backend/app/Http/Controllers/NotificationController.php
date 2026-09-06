<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Notification;
use App\Models\NotificationPreference;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $notifications = Notification::where('user_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 15));

        return response()->json([
            'success' => true,
            'message' => 'Notifications retrieved.',
            'data' => $notifications,
        ]);
    }

    public function markAsRead(Request $request, $id): JsonResponse
    {
        $notification = Notification::where('user_id', $request->user()->id)->findOrFail($id);
        $notification->is_read = true;
        $notification->read_at = now();
        $notification->save();

        return response()->json([
            'success' => true,
            'message' => 'Notification marked as read.',
            'data' => $notification,
        ]);
    }

    public function preferences(Request $request): JsonResponse
    {
        $pref = NotificationPreference::firstOrCreate(
            ['user_id' => $request->user()->id],
            ['email_notifications' => true, 'push_notifications' => true, 'lunch_reminder' => true, 'payment_alerts' => true]
        );

        return response()->json([
            'success' => true,
            'message' => 'Notification preferences retrieved.',
            'data' => $pref,
        ]);
    }

    public function updatePreferences(Request $request): JsonResponse
    {
        $request->validate([
            'email_notifications' => 'required|boolean',
            'push_notifications' => 'required|boolean',
            'lunch_reminder' => 'required|boolean',
            'payment_alerts' => 'required|boolean',
        ]);

        $pref = NotificationPreference::firstOrCreate(['user_id' => $request->user()->id]);
        $pref->update($request->all());

        return response()->json([
            'success' => true,
            'message' => 'Notification preferences updated.',
            'data' => $pref,
        ]);
    }
}
