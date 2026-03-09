@extends('layouts.app')
@section('content')
<h1 class="text-xl font-semibold mb-4">{{ $client->name }}</h1>
<div class="bg-white rounded shadow p-4 space-y-2">
    <div><strong>Email:</strong> {{ $client->email }}</div>
    <div><strong>Telefone:</strong> {{ $client->phone }}</div>
    <div><strong>Marketing:</strong> {{ $client->marketing_consent ? 'Sim' : 'Não' }}</div>
    <div><strong>Notas:</strong> {{ $client->notes }}</div>
</div>
@endsection
