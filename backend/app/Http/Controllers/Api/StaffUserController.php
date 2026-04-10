<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\Audit;
use App\Support\UserEventAssignment;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class StaffUserController extends Controller
{
    public function index()
    {
        return response()->json(User::orderBy('name')->paginate(20));
    }

    public function show(User $user)
    {
        return response()->json([
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'role' => $user->role,
            'permissions' => $user->permissionsList(),
        ]);
    }

    public function store(Request $request)
    {
        $permissionKeys = array_keys(config('permissions'));
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'username' => ['nullable', 'string', 'max:60', 'regex:/^[A-Za-z0-9._-]+$/', 'unique:users,username'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:6'],
            'role' => ['required', Rule::in(['admin', 'staff', 'photographer'])],
            'permissions' => ['nullable', 'array'],
            'permissions.*' => ['string', Rule::in($permissionKeys)],
        ]);

        $validated['permissions'] = $validated['permissions'] ?? [];
        $user = User::create($validated);
        UserEventAssignment::attachUserToExistingEvents($user);
        Audit::log('api.user.created', User::class, $user->id, [
            'email' => $user->email,
            'role' => $user->role,
        ]);

        return response()->json([
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'role' => $user->role,
            'permissions' => $user->permissionsList(),
        ], 201);
    }

    public function update(Request $request, User $user)
    {
        $permissionKeys = array_keys(config('permissions'));
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'username' => ['nullable', 'string', 'max:60', 'regex:/^[A-Za-z0-9._-]+$/', Rule::unique('users', 'username')->ignore($user->id)],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'password' => ['nullable', 'string', 'min:6'],
            'role' => ['required', Rule::in(['admin', 'staff', 'photographer'])],
            'permissions' => ['nullable', 'array'],
            'permissions.*' => ['string', Rule::in($permissionKeys)],
        ]);

        if (empty($validated['password'])) {
            unset($validated['password']);
        }

        $validated['permissions'] = $validated['permissions'] ?? [];
        $user->update($validated);
        Audit::log('api.user.updated', User::class, $user->id, [
            'email' => $user->email,
            'role' => $user->role,
        ]);

        return response()->json([
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'role' => $user->role,
            'permissions' => $user->permissionsList(),
        ]);
    }

    public function destroy(Request $request, User $user)
    {
        if ((int) $user->id === (int) $request->user()->id) {
            return response()->json(['message' => 'Não podes apagar o teu próprio utilizador.'], 422);
        }

        $deletedId = $user->id;
        $user->delete();
        Audit::log('api.user.deleted', User::class, $deletedId);

        return response()->json(['message' => 'Deleted']);
    }
}
