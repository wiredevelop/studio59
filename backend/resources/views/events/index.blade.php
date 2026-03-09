@extends('layouts.app')
@section('content')
<div class="flex justify-between mb-4">
<h1 class="text-xl font-semibold">Eventos</h1>
@if(auth()->user()->hasPermission('events.write'))
    <a href="{{ route('events.create') }}" class="bg-black text-white px-3 py-2 rounded">Novo</a>
@endif
</div>
<div class="bg-white rounded shadow overflow-hidden">
    <table class="w-full text-sm">
        <thead class="bg-gray-100"><tr><th class="p-2 text-left">Nome</th><th class="p-2">Data</th><th class="p-2">Estado</th><th class="p-2">Código</th><th class="p-2">Fotos</th><th class="p-2">Preço</th><th class="p-2">Ações</th></tr></thead>
        <tbody>
        @foreach($events as $event)
            <tr class="border-t">
                <td class="p-2">{{ $event->name }}</td>
                <td class="p-2 text-center">{{ $event->event_date->format('Y-m-d') }}</td>
                <td class="p-2 text-center">{{ $event->status }}</td>
                <td class="p-2 text-center">{{ $event->internal_code }}</td>
                <td class="p-2 text-center">{{ $event->photos_count }}</td>
                <td class="p-2 text-center">{{ number_format($event->price_per_photo, 2) }}€</td>
                <td class="p-2 text-center">
                    <div class="flex items-center justify-center gap-2">
                    @if(auth()->user()->hasPermission('events.read'))
                        <a class="text-blue-600" href="{{ route('events.show', $event) }}">Dossier</a>
                        <a class="text-blue-600" href="{{ route('events.qr', $event) }}">QR</a>
                    @endif
                    @if(auth()->user()->hasPermission('events.write'))
                        <a class="text-blue-600" href="{{ route('events.edit', $event) }}">Editar</a>
                        <form method="post" action="{{ route('events.destroy', $event) }}" onsubmit="return confirm('Remover evento e todas as fotos?');">
                            @csrf
                            @method('DELETE')
                            <button class="text-red-600">Apagar</button>
                        </form>
                    @endif
                    @if(auth()->user()->hasPermission('uploads.manage'))
                        <a class="text-blue-600" href="{{ route('uploads.index', $event) }}">Upload</a>
                    @endif
                    @if(auth()->user()->hasPermission('orders.export'))
                        <a class="text-blue-600" href="{{ route('orders.export', $event) }}">CSV</a>
                    @endif
                    </div>
                </td>
            </tr>
        @endforeach
        </tbody>
    </table>
</div>
<div class="mt-3">{{ $events->links() }}</div>
@endsection
