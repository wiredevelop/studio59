<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index()
    {
        return view('users.index', [
            'users' => User::orderBy('name')->paginate(20),
        ]);
    }

    public function create()
    {
        return view('users.create', [
            'permissions' => config('permissions'),
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
        Audit::log('user.created', User::class, $user->id, [
            'email' => $user->email,
            'role' => $user->role,
        ]);

        return redirect()->route('users.index')->with('ok', 'Utilizador criado');
    }

    public function edit(User $user)
    {
        return view('users.edit', [
            'user' => $user,
            'permissions' => config('permissions'),
        ]);
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
        Audit::log('user.updated', User::class, $user->id, [
            'email' => $user->email,
            'role' => $user->role,
        ]);

        return redirect()->route('users.index')->with('ok', 'Utilizador atualizado');
    }

    public function destroy(User $user)
    {
        if ((int) $user->id === (int) auth()->id()) {
            return back()->withErrors(['Não podes apagar o teu próprio utilizador.']);
        }

        $deletedId = $user->id;
        $user->delete();
        Audit::log('user.deleted', User::class, $deletedId);

        return redirect()->route('users.index')->with('ok', 'Utilizador apagado');
    }
}
