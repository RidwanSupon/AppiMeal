<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::with(['role', 'employee', 'notificationPreference'])
            ->where('email', strtolower(trim($request->email)))
            ->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid email address or password.',
                'errors' => ['credentials' => ['The provided credentials do not match our records.']],
            ], 401);
        }

        if (! $user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Your account has been deactivated. Please contact administrator.',
                'errors' => ['account' => ['Account deactivated.']],
            ], 403);
        }

        // Revoke old tokens if any
        $user->tokens()->delete();

        // Create new token
        $token = $user->createToken('auth_token')->plainTextToken;

        AuditLog::log('user.login', 'User', (string) $user->id, null, ['email' => $user->email], $user);

        return response()->json([
            'success' => true,
            'message' => 'Login successful.',
            'data' => [
                'token' => $token,
                'token_type' => 'Bearer',
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role' => $user->role ? $user->role->slug : 'employee',
                    'role_name' => $user->role ? $user->role->name : 'Employee',
                    'employee_id' => $user->employee ? $user->employee->employee_id : null,
                    'employee' => $user->employee,
                ],
            ],
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        $user = $request->user()->load(['role', 'employee.ledger', 'notificationPreference']);

        return response()->json([
            'success' => true,
            'message' => 'User profile retrieved successfully.',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role' => $user->role ? $user->role->slug : 'employee',
                    'role_name' => $user->role ? $user->role->name : 'Employee',
                    'employee_id' => $user->employee ? $user->employee->employee_id : null,
                    'employee' => $user->employee,
                ],
            ],
        ]);
    }

    public function uploadAvatar(Request $request): JsonResponse
    {
        $request->validate([
            'avatar' => 'required|image|mimes:jpeg,png,jpg,gif,webp|max:5120',
        ]);

        $user = $request->user();

        if (! $request->hasFile('avatar')) {
            return response()->json([
                'success' => false,
                'message' => 'No image file provided.',
            ], 422);
        }

        $file = $request->file('avatar');
        $ext = $file->getClientOriginalExtension() ?: ($file->guessExtension() ?: 'jpg');
        $filename = 'avatar_' . $user->id . '_' . time() . '.' . $ext;
        $path = $file->storeAs('avatars', $filename, 'public');
        $avatarUrl = '/storage/' . $path;

        if ($user->employee) {
            if ($user->employee->avatar_url) {
                $oldPath = str_replace('/storage/', '', $user->employee->avatar_url);
                if (Storage::disk('public')->exists($oldPath)) {
                    Storage::disk('public')->delete($oldPath);
                }
            }
            $user->employee->avatar_url = $avatarUrl;
            $user->employee->save();
        }

        AuditLog::log('user.avatar_uploaded', 'User', (string) $user->id, null, ['avatar_url' => $avatarUrl], $user);

        $freshUser = $user->fresh(['role', 'employee.ledger', 'notificationPreference']);

        return response()->json([
            'success' => true,
            'message' => 'Profile avatar uploaded successfully.',
            'data' => [
                'avatar_url' => $avatarUrl,
                'user' => [
                    'id' => $freshUser->id,
                    'name' => $freshUser->name,
                    'email' => $freshUser->email,
                    'role' => $freshUser->role ? $freshUser->role->slug : 'employee',
                    'role_name' => $freshUser->role ? $freshUser->role->name : 'Employee',
                    'employee_id' => $freshUser->employee ? $freshUser->employee->employee_id : null,
                    'employee' => $freshUser->employee,
                ],
            ],
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user) {
            $user->currentAccessToken()->delete();
            AuditLog::log('user.logout', 'User', (string) $user->id, null, null, $user);
        }

        return response()->json([
            'success' => true,
            'message' => 'Logged out successfully.',
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $request->validate(['email' => 'required|email']);

        $user = User::where('email', strtolower(trim($request->email)))->first();

        if (! $user) {
            return response()->json([
                'success' => true,
                'message' => 'If an account exists with that email, a password reset token has been generated.',
            ]);
        }

        $token = Str::random(60);

        AuditLog::log('user.forgot_password_request', 'User', (string) $user->id, null, ['email' => $user->email]);

        return response()->json([
            'success' => true,
            'message' => 'Password reset instructions have been processed.',
            'data' => [
                'reset_token' => $token,
                'email' => $user->email,
            ],
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $user = User::where('email', strtolower(trim($request->email)))->first();

        if (! $user) {
            return response()->json([
                'success' => false,
                'message' => 'User not found.',
            ], 404);
        }

        $user->password = Hash::make($request->password);
        $user->save();

        AuditLog::log('user.password_reset', 'User', (string) $user->id, null, null, $user);

        return response()->json([
            'success' => true,
            'message' => 'Password reset successfully. You can now login with your new password.',
        ]);
    }
}
