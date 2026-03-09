@extends('layouts.app')
@section('content')
<h1 class="text-xl font-semibold mb-4">Definições</h1>

<form method="post" action="{{ route('settings.update') }}" class="bg-white p-4 rounded shadow max-w-xl space-y-3">
    @csrf
    @method('PUT')
    <input name="name" value="{{ old('name', $user->name) }}" class="w-full border rounded p-2" placeholder="Nome" required>
    <input name="username" value="{{ old('username', $user->username) }}" class="w-full border rounded p-2" placeholder="Username (opcional)">
    <input name="email" value="{{ old('email', $user->email) }}" class="w-full border rounded p-2" placeholder="Email" required>
    <input name="password" type="password" class="w-full border rounded p-2" placeholder="Nova password (opcional)">
    <div class="flex gap-2">
        <button class="bg-black text-white px-4 py-2 rounded">Guardar</button>
        <a href="{{ route('dashboard') }}" class="border px-4 py-2 rounded">Cancelar</a>
    </div>
</form>
@endsection
