@extends('layouts.app')
@section('page_title', 'Novo utilizador')
@section('page_subtitle', 'Adicionar membro da equipa')
@section('page_actions')
    <a href="{{ route('users.index') }}" class="desk-btn">Voltar</a>
@endsection
@section('content')
<form method="post" action="{{ route('users.store') }}" class="desk-card space-y-3">
    @csrf
    <input name="name" value="{{ old('name') }}" class="desk-input w-full" placeholder="Nome" required>
    <input name="username" value="{{ old('username') }}" class="desk-input w-full" placeholder="Username (opcional)">
    <input name="email" value="{{ old('email') }}" class="desk-input w-full" placeholder="Email" required>
    <input name="password" type="password" class="desk-input w-full" placeholder="Password" required>
    <select name="role" class="desk-select w-full" required>
        <option value="staff" {{ old('role') === 'staff' ? 'selected' : '' }}>staff</option>
        <option value="photographer" {{ old('role') === 'photographer' ? 'selected' : '' }}>fotografo</option>
        <option value="admin" {{ old('role') === 'admin' ? 'selected' : '' }}>admin</option>
    </select>
    <div class="event-card space-y-2">
        <div class="font-semibold">Permissões</div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
            @foreach($permissions as $key => $label)
                <label class="flex items-center gap-2">
                    <input type="checkbox" name="permissions[]" value="{{ $key }}" {{ in_array($key, old('permissions', [])) ? 'checked' : '' }}>
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
