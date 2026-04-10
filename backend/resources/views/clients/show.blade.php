@extends('layouts.app')
@section('page_title', 'Cliente')
@section('page_subtitle', $client->name)
@section('page_actions')
    <a href="{{ route('clients.edit', $client) }}" class="desk-btn">Editar</a>
    <a href="{{ route('clients.index') }}" class="desk-btn">Voltar</a>
@endsection
@section('content')
<div class="desk-card space-y-2">
    <div><strong>Email:</strong> {{ $client->email }}</div>
    <div><strong>Telefone:</strong> {{ $client->phone }}</div>
    <div><strong>Marketing:</strong> {{ $client->marketing_consent ? 'Sim' : 'Não' }}</div>
    <div><strong>Notas:</strong> {{ $client->notes }}</div>
</div>
@endsection
