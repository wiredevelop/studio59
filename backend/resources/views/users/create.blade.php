@extends('layouts.app')
@section('content')
<h1 class="text-xl font-semibold mb-4">Novo utilizador</h1>

<form method="post" action="{{ route('users.store') }}" class="bg-white p-4 rounded shadow max-w-xl space-y-3">
    @csrf
    <input name="name" value="{{ old('name') }}" class="w-full border rounded p-2" placeholder="Nome" required>
    <input name="username" value="{{ old('username') }}" class="w-full border rounded p-2" placeholder="Username (opcional)">
    <input name="email" value="{{ old('email') }}" class="w-full border rounded p-2" placeholder="Email" required>
    <input name="password" type="password" class="w-full border rounded p-2" placeholder="Password" required>
    <select name="role" class="w-full border rounded p-2" required>
        <option value="staff" {{ old('role') === 'staff' ? 'selected' : '' }}>staff</option>
        <option value="photographer" {{ old('role') === 'photographer' ? 'selected' : '' }}>fotografo</option>
        <option value="admin" {{ old('role') === 'admin' ? 'selected' : '' }}>admin</option>
    </select>
    <div class="border rounded p-3 space-y-2">
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
        <button class="bg-black text-white px-4 py-2 rounded">Guardar</button>
        <a href="{{ route('users.index') }}" class="border px-4 py-2 rounded">Cancelar</a>
    </div>
</form>
@endsection
