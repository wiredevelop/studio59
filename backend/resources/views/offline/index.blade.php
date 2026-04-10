@extends('layouts.app')
@section('page_title', 'Sincronização')
@section('page_subtitle', 'Importação e histórico offline')
@section('content')
<form method="post" action="{{ route('offline.import') }}" enctype="multipart/form-data" class="desk-card space-y-3 mb-6">
    @csrf
    <div>
        <label class="block text-sm">Evento</label>
        <select name="event_id" class="desk-select w-full">
            @foreach($events as $event)
                <option value="{{ $event->id }}">{{ $event->name }} ({{ $event->event_date->format('Y-m-d') }})</option>
            @endforeach
        </select>
    </div>
    <div>
        <label class="block text-sm">Ficheiro JSON</label>
        <input type="file" name="payload" class="desk-input w-full" accept=".json">
    </div>
    <button class="desk-btn primary">Importar</button>
</form>

<div class="desk-card overflow-hidden">
    <table class="desk-table">
        <thead>
            <tr>
                <th class="p-2 text-left">Evento</th>
                <th class="p-2">Estado</th>
                <th class="p-2">Checksum</th>
                <th class="p-2">Data</th>
            </tr>
        </thead>
        <tbody>
        @foreach($syncs as $sync)
            <tr>
                <td class="p-2">{{ $sync->event?->name }}</td>
                <td class="p-2 text-center"><span class="desk-badge {{ $sync->status === 'pending' ? 'warn' : 'success' }}">{{ $sync->status }}</span></td>
                <td class="p-2 text-center text-xs">{{ $sync->checksum }}</td>
                <td class="p-2 text-center">{{ $sync->created_at?->format('Y-m-d H:i') }}</td>
            </tr>
        @endforeach
        </tbody>
    </table>
</div>
@endsection
