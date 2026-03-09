@extends('layouts.app')
@section('content')
<h1 class="text-xl font-semibold mb-4">Sincronização Offline</h1>

<form method="post" action="{{ route('offline.import') }}" enctype="multipart/form-data" class="bg-white rounded shadow p-4 space-y-3 mb-6">
    @csrf
    <div>
        <label class="block text-sm">Evento</label>
        <select name="event_id" class="border rounded px-3 py-2 w-full">
            @foreach($events as $event)
                <option value="{{ $event->id }}">{{ $event->name }} ({{ $event->event_date->format('Y-m-d') }})</option>
            @endforeach
        </select>
    </div>
    <div>
        <label class="block text-sm">Ficheiro JSON</label>
        <input type="file" name="payload" class="border rounded px-3 py-2 w-full" accept=".json">
    </div>
    <button class="bg-black text-white px-3 py-2 rounded">Importar</button>
</form>

<div class="bg-white rounded shadow overflow-hidden">
    <table class="w-full text-sm">
        <thead class="bg-gray-100">
            <tr>
                <th class="p-2 text-left">Evento</th>
                <th class="p-2">Estado</th>
                <th class="p-2">Checksum</th>
                <th class="p-2">Data</th>
            </tr>
        </thead>
        <tbody>
        @foreach($syncs as $sync)
            <tr class="border-t">
                <td class="p-2">{{ $sync->event?->name }}</td>
                <td class="p-2 text-center">{{ $sync->status }}</td>
                <td class="p-2 text-center text-xs">{{ $sync->checksum }}</td>
                <td class="p-2 text-center">{{ $sync->created_at?->format('Y-m-d H:i') }}</td>
            </tr>
        @endforeach
        </tbody>
    </table>
</div>
@endsection
