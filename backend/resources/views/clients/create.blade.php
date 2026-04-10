@extends('layouts.app')
@section('page_title', 'Novo cliente')
@section('page_subtitle', 'Registar cliente e contacto')
@section('page_actions')
    <a href="{{ route('clients.index') }}" class="desk-btn">Voltar</a>
@endsection
@section('content')
<form method="post" action="{{ route('clients.store') }}" class="desk-card space-y-3">
    @csrf
    <div>
        <label class="block text-sm">Nome</label>
        <input name="name" class="border rounded px-3 py-2 w-full" required>
    </div>
    <div>
        <label class="block text-sm">Email</label>
        <input name="email" type="email" class="border rounded px-3 py-2 w-full">
    </div>
    <div>
        <label class="block text-sm">Telefone</label>
        <input name="phone" class="border rounded px-3 py-2 w-full">
    </div>
    <div>
        <label class="block text-sm">Notas</label>
        <textarea name="notes" class="border rounded px-3 py-2 w-full"></textarea>
    </div>
    <label class="flex items-center gap-2">
        <input type="checkbox" name="marketing_consent" value="1">
        <span>Consentimento marketing</span>
    </label>
    <button class="desk-btn primary">Guardar</button>
</form>
@endsection
