@extends('layouts.app')
@section('page_title', 'Editar cliente')
@section('page_subtitle', $client->name)
@section('page_actions')
    <a href="{{ route('clients.index') }}" class="desk-btn">Voltar</a>
@endsection
@section('content')
<form method="post" action="{{ route('clients.update', $client) }}" class="desk-card space-y-3">
    @csrf
    @method('PUT')
    <div>
        <label class="block text-sm">Nome</label>
        <input name="name" class="border rounded px-3 py-2 w-full" value="{{ $client->name }}" required>
    </div>
    <div>
        <label class="block text-sm">Email</label>
        <input name="email" type="email" class="border rounded px-3 py-2 w-full" value="{{ $client->email }}">
    </div>
    <div>
        <label class="block text-sm">Telefone</label>
        <input name="phone" class="border rounded px-3 py-2 w-full" value="{{ $client->phone }}">
    </div>
    <div>
        <label class="block text-sm">Notas</label>
        <textarea name="notes" class="border rounded px-3 py-2 w-full">{{ $client->notes }}</textarea>
    </div>
    <label class="flex items-center gap-2">
        <input type="checkbox" name="marketing_consent" value="1" {{ $client->marketing_consent ? 'checked' : '' }}>
        <span>Consentimento marketing</span>
    </label>
    <button class="desk-btn primary">Guardar</button>
</form>
@endsection
