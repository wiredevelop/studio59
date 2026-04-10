@extends('layouts.app')
@section('page_title', 'Definições')
@section('page_subtitle', 'Perfil e credenciais')
@section('content')
<form method="post" action="{{ route('settings.update') }}" class="desk-card space-y-3">
    @csrf
    @method('PUT')
    <input name="name" value="{{ old('name', $user->name) }}" class="desk-input w-full" placeholder="Nome" required>
    <input name="username" value="{{ old('username', $user->username) }}" class="desk-input w-full" placeholder="Username (opcional)">
    <input name="email" value="{{ old('email', $user->email) }}" class="desk-input w-full" placeholder="Email" required>
    <input name="password" type="password" class="desk-input w-full" placeholder="Nova password (opcional)">
    <div class="flex gap-2">
        <button class="desk-btn primary">Guardar</button>
        <a href="{{ route('dashboard') }}" class="desk-btn">Cancelar</a>
    </div>
</form>
@endsection
