@extends('layouts.app')
@section('content')
<div class="flex gap-3 mb-4">
    @if(auth()->user()->hasPermission('events.read'))
        <a class="bg-black text-white px-3 py-2 rounded" href="{{ route('events.index') }}">Eventos</a>
    @endif
    @if(auth()->user()->hasPermission('orders.read'))
        <a class="bg-black text-white px-3 py-2 rounded" href="{{ route('orders.index') }}">Pedidos</a>
    @endif
    @if(auth()->user()->hasPermission('users.manage'))
        <a class="bg-black text-white px-3 py-2 rounded" href="{{ route('users.index') }}">Utilizadores</a>
    @endif
</div>
<div class="grid md:grid-cols-2 gap-4">
    @if(auth()->user()->hasPermission('events.read'))
        <div class="bg-white p-4 rounded shadow">
            <h2 class="font-semibold mb-2">Eventos</h2>
            @foreach($events as $event)
                <div class="border-b py-2 flex justify-between items-center">
                    <div>{{ $event->name }} ({{ $event->event_date->format('Y-m-d') }})</div>
                    @if(auth()->user()->hasPermission('uploads.manage'))
                        <a class="text-blue-600" href="{{ route('uploads.index', $event) }}">Upload</a>
                    @endif
                </div>
            @endforeach
        </div>
    @endif
    @if(auth()->user()->hasPermission('orders.read'))
        <div class="bg-white p-4 rounded shadow">
            <h2 class="font-semibold mb-2">Pedidos recentes</h2>
            @foreach($recentOrders as $order)
                <div class="border-b py-2">{{ $order->order_code }} - {{ $order->customer_name }} - {{ strtoupper($order->status) }}</div>
            @endforeach
        </div>
    @endif
</div>
@endsection
