@extends('layouts.app')
@section('content')
@php($isPhotographer = auth()->user()?->role === 'photographer')
<h1 class="text-xl font-semibold mb-4">Pedidos</h1>
<form class="bg-white p-3 rounded shadow mb-4 flex flex-wrap gap-2">
    <select name="event_id" class="border p-2 rounded">
        <option value="">Todos os eventos</option>
        @foreach($events as $ev)
        <option value="{{ $ev->id }}" {{ request('event_id') == $ev->id ? 'selected' : '' }}>{{ $ev->name }}</option>
        @endforeach
    </select>
    <select name="status" class="border p-2 rounded">
        <option value="">Todos status</option>
        <option value="pending" {{ request('status')==='pending'?'selected':'' }}>pending</option>
        <option value="paid" {{ request('status')==='paid'?'selected':'' }}>paid</option>
        <option value="delivered" {{ request('status')==='delivered'?'selected':'' }}>delivered</option>
    </select>
    <input name="q" value="{{ request('q') }}" class="border p-2 rounded" placeholder="nome, codigo, telefone, email">
    <button class="bg-black text-white px-3 py-2 rounded">Filtrar</button>
</form>

<div class="bg-white rounded shadow overflow-x-auto">
<table class="w-full text-sm">
<thead class="bg-gray-100">
<tr>
    <th class="p-2">
        @if(auth()->user()->hasPermission('orders.write') && ! $isPhotographer)
            <input type="checkbox" id="check-all">
        @endif
    </th>
    <th class="p-2">Codigo</th>
    <th class="p-2">Nome</th>
    <th class="p-2">Telemovel</th>
    <th class="p-2">Email</th>
    <th class="p-2">Produto</th>
    <th class="p-2">Entrega</th>
    <th class="p-2">Filme</th>
    <th class="p-2">Status</th>
    <th class="p-2">Fotos</th>
    <th class="p-2">Fotos €</th>
    <th class="p-2">Extras €</th>
    <th class="p-2">Total</th>
    <th class="p-2">Acoes</th>
</tr>
</thead>
<tbody>
@foreach($orders as $order)
<tr class="border-t">
<td class="p-2">
    @if(auth()->user()->hasPermission('orders.write') && ! $isPhotographer)
        <input type="checkbox" value="{{ $order->id }}" class="order-check">
    @endif
</td>
<td class="p-2">{{ $order->order_code }}</td>
<td class="p-2">{{ $order->customer_name }}</td>
<td class="p-2">{{ $order->customer_phone ?: '-' }}</td>
<td class="p-2">{{ $order->customer_email ?: '-' }}</td>
<td class="p-2">{{ $order->product_type ?: '-' }}</td>
<td class="p-2">
    @if($order->delivery_type === 'shipping')
        Envio ({{ number_format($order->shipping_fee ?? 0, 2) }}€)
    @elseif($order->delivery_type === 'pickup')
        Entregar
    @else
        -
    @endif
</td>
<td class="p-2">{{ $order->wants_film ? 'Sim (+'.number_format($order->film_fee ?? 0,2).'€)' : 'Não' }}</td>
<td class="p-2">{{ $order->status }}</td>
<td class="p-2">
    {{ $order->items->map(function($i){
        $num = $i->photo?->number;
        if (!$num) return null;
        $qty = $i->quantity ?? 1;
        return $qty > 1 ? $num.' x'.$qty : $num;
    })->filter()->implode(', ') }}
</td>
<td class="p-2">{{ number_format($order->items_total ?? 0,2) }}€</td>
<td class="p-2">{{ number_format($order->extras_total ?? 0,2) }}€</td>
<td class="p-2">{{ number_format($order->total_amount,2) }}EUR</td>
<td class="p-2 space-x-2">
    @if(auth()->user()->hasPermission('orders.write'))
        <form method="post" action="{{ route('orders.markPaid', $order) }}" class="inline">@csrf<button class="text-blue-600">Marcar pago</button></form>
        @if(! $isPhotographer)
            <form method="post" action="{{ route('orders.markDelivered', $order) }}" class="inline">@csrf<button class="text-green-600">Entregar</button></form>
        @endif
    @endif
    @if(auth()->user()->hasPermission('orders.download') && ! $isPhotographer)
        @if($order->status === 'paid')
            <form method="post" action="{{ route('orders.sendDownloadLink', $order) }}" class="inline">@csrf<button class="text-purple-700">Enviar link</button></form>
        @endif
        @if($order->status !== 'pending')
            <a class="text-black" href="{{ route('orders.downloadAll', $order) }}">Download ZIP</a>
        @endif
    @endif
</td>
</tr>
@endforeach
</tbody>
</table>
</div>

@if(auth()->user()->hasPermission('orders.write') && ! $isPhotographer)
    <form method="post" action="{{ route('orders.bulkStatus') }}" id="bulk-form" class="mt-3 flex gap-2 items-center">
        @csrf
        <select name="status" class="border p-2 rounded" required>
            <option value="">Bulk status</option>
            <option value="pending">pending</option>
            <option value="paid">paid</option>
            <option value="delivered">delivered</option>
        </select>
        <button class="border px-3 py-2 rounded bg-white">Aplicar aos selecionados</button>
    </form>
@endif

<div class="mt-3">{{ $orders->links() }}</div>

<script>
const all = document.getElementById('check-all');
all?.addEventListener('change', (e) => {
  document.querySelectorAll('.order-check').forEach((c) => c.checked = e.target.checked);
});

document.getElementById('bulk-form')?.addEventListener('submit', (e) => {
  const ids = Array.from(document.querySelectorAll('.order-check'))
    .filter((c) => c.checked)
    .map((c) => c.value);

  if (!ids.length) {
    e.preventDefault();
    alert('Seleciona pelo menos 1 pedido.');
    return;
  }

  ids.forEach((id) => {
    const input = document.createElement('input');
    input.type = 'hidden';
    input.name = 'order_ids[]';
    input.value = id;
    e.target.appendChild(input);
  });
});
</script>
@endsection
