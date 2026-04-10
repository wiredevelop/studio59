<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StaffLoginRequest;
use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;

class StaffAuthController extends Controller
{
    public function login(StaffLoginRequest $request)
    {
        $login = $request->input('login', $request->input('email'));
        $password = (string) $request->input('password');

        $authenticated = Auth::attempt(['email' => $login, 'password' => $password])
            || Auth::attempt(['username' => $login, 'password' => $password]);

        if (! $authenticated) {
            Audit::log('api.auth.login.failed', null, null, ['login' => $login]);
            return response()->json(['message' => 'Invalid credentials'], 422);
        }

        $user = Auth::user();
        if (! $user) {
            return response()->json(['message' => 'Unable to resolve authenticated user'], 500);
        }

        if (! in_array($user->role, ['admin', 'staff', 'photographer'], true)) {
            Auth::logout();
            return response()->json(['message' => 'User role not allowed'], 403);
        }

        $token = $user->createToken('staff-mobile')->plainTextToken;
        Audit::log('api.auth.login.success', null, null, ['user_id' => $user->id]);

        return response()->json([
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $user->username,
                'email' => $user->email,
                'role' => $user->role,
                'permissions' => $user->permissionsList(),
            ],
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();
        Audit::log('api.auth.logout');

        return response()->json(['message' => 'Logged out']);
    }

    public function me(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'role' => $user->role,
            'permissions' => $user->permissionsList(),
        ]);
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'username' => ['nullable', 'string', 'max:60', 'regex:/^[A-Za-z0-9._-]+$/', Rule::unique('users', 'username')->ignore($user->id)],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'password' => ['nullable', 'string', 'min:6'],
        ]);

        if (empty($validated['password'])) {
            unset($validated['password']);
        }

        $user->update($validated);
        Audit::log('api.auth.profile.updated', null, null, ['user_id' => $user->id]);

        return response()->json([
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'role' => $user->role,
            'permissions' => $user->permissionsList(),
        ]);
    }
}
