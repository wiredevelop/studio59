@extends('layouts.app')
@section('content')
<div class="flex items-center justify-between mb-4">
    <div>
        <h1 class="text-xl font-semibold">QR Code do Evento</h1>
        <p class="text-sm text-gray-600">{{ $event->name }}</p>
    </div>
    <a href="{{ route('events.index') }}" class="text-blue-600">Voltar</a>
</div>
<div class="bg-white rounded shadow p-6">
    <div class="flex flex-col items-center gap-4">
        <img
            src="https://api.qrserver.com/v1/create-qr-code/?size=320x320&data={{ urlencode($qrUrl) }}"
            alt="QR Code do evento"
            class="border"
        />
        <div class="w-full max-w-xl">
            <div class="text-sm text-gray-600 mb-1">URL do QR</div>
            <div class="p-2 border rounded bg-gray-50 text-xs break-all">{{ $qrUrl }}</div>
        </div>
    </div>
</div>
@endsection
