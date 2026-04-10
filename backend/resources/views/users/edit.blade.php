@extends('layouts.app')
@section('page_title', 'Editar utilizador')
@section('page_subtitle', $user->name)
@section('page_actions')
    <a href="{{ route('users.index') }}" class="desk-btn">Voltar</a>
@endsection
@section('content')
<form method="post" action="{{ route('users.update', $user) }}" class="desk-card space-y-3">
    @csrf
    @method('PUT')
    <input name="name" value="{{ old('name', $user->name) }}" class="desk-input w-full" placeholder="Nome" required>
    <input name="username" value="{{ old('username', $user->username) }}" class="desk-input w-full" placeholder="Username (opcional)">
    <input name="email" value="{{ old('email', $user->email) }}" class="desk-input w-full" placeholder="Email" required>
    <input name="password" type="password" class="desk-input w-full" placeholder="Nova password (opcional)">
    <select name="role" class="desk-select w-full" required>
        <option value="staff" {{ old('role', $user->role) === 'staff' ? 'selected' : '' }}>staff</option>
        <option value="photographer" {{ old('role', $user->role) === 'photographer' ? 'selected' : '' }}>fotografo</option>
        <option value="admin" {{ old('role', $user->role) === 'admin' ? 'selected' : '' }}>admin</option>
    </select>
    <div class="event-card space-y-2">
        <div class="font-semibold">Permissões</div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
            @foreach($permissions as $key => $label)
                <label class="flex items-center gap-2">
                    <input type="checkbox" name="permissions[]" value="{{ $key }}" {{ in_array($key, old('permissions', $user->permissionsList())) ? 'checked' : '' }}>
                    <span>{{ $label }}</span>
                </label>
            @endforeach
        </div>
    </div>
    <div class="flex gap-2">
        <button class="desk-btn primary">Guardar</button>
        <a href="{{ route('users.index') }}" class="desk-btn">Cancelar</a>
    </div>
</form>
@endsection
