@extends('layouts.app')
@section('page_title', 'QR Code do evento')
@section('page_subtitle', $event->name)
@section('page_actions')
    <a href="{{ route('events.index') }}" class="desk-btn">Voltar</a>
@endsection
@section('content')
<div class="desk-card">
    <div class="flex flex-col items-center gap-4">
        <img
            src="https://api.qrserver.com/v1/create-qr-code/?size=320x320&data={{ urlencode($qrUrl) }}"
            alt="QR Code do evento"
            class="border rounded"
        />
        <div class="w-full max-w-xl">
            <div class="text-sm text-gray-600 mb-1">URL do QR</div>
            <div class="p-2 border rounded bg-gray-50 text-xs break-all">{{ $qrUrl }}</div>
        </div>
    </div>
</div>
@endsection
