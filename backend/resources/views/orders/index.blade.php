@extends('layouts.app')
@section('page_title', 'Pedidos')
@section('page_subtitle', 'Gestão de pedidos e pagamentos')
@section('page_actions')
    <a href="{{ route('orders.index') }}" class="desk-btn">Atualizar</a>
@endsection
@section('content')
@php($isPhotographer = auth()->user()?->role === 'photographer')
<form class="desk-card desk-toolbar" method="get">
    <select name="event_id" class="desk-select">
        <option value="">Todos os eventos</option>
        @foreach($events as $ev)
        <option value="{{ $ev->id }}" {{ request('event_id') == $ev->id ? 'selected' : '' }}>{{ $ev->name }}</option>
        @endforeach
    </select>
    <select name="status" class="desk-select">
        <option value="">Todos status</option>
        <option value="pending" {{ request('status')==='pending'?'selected':'' }}>pending</option>
        <option value="paid" {{ request('status')==='paid'?'selected':'' }}>paid</option>
    </select>
    <input name="q" value="{{ request('q') }}" class="desk-input" placeholder="nome, codigo, telefone, email">
    <button class="desk-btn primary">Filtrar</button>
</form>

<div class="desk-card overflow-x-auto">
<table class="desk-table">
<thead>
<tr>
    <th class="p-2">
        @if(auth()->user()->hasPermission('orders.bulk') && ! $isPhotographer)
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
<tr>
<td>
    @if(auth()->user()->hasPermission('orders.bulk') && ! $isPhotographer)
        <input type="checkbox" value="{{ $order->id }}" class="order-check">
    @endif
</td>
<td>{{ $order->order_code }}</td>
<td>{{ $order->customer_name }}</td>
<td>{{ $order->customer_phone ?: '-' }}</td>
<td>{{ $order->customer_email ?: '-' }}</td>
<td>{{ $order->product_type ?: '-' }}</td>
<td>
    @if($order->delivery_type === 'shipping')
        Envio ({{ number_format($order->shipping_fee ?? 0, 2) }}€)
    @elseif($order->delivery_type === 'pickup')
        Entregar
    @else
        -
    @endif
</td>
<td>{{ $order->wants_film ? 'Sim (+'.number_format($order->film_fee ?? 0,2).'€)' : 'Não' }}</td>
<td>
    <span class="desk-badge {{ $order->status === 'paid' ? 'success' : 'warn' }}">{{ $order->status }}</span>
</td>
<td>
    {{ $order->items->map(function($i){
        $num = $i->photo?->number;
        if (!$num) return null;
        $qty = $i->quantity ?? 1;
        return $qty > 1 ? $num.' x'.$qty : $num;
    })->filter()->implode(', ') }}
</td>
<td>{{ number_format($order->items_total ?? 0,2) }}€</td>
<td>{{ number_format($order->extras_total ?? 0,2) }}€</td>
<td>{{ number_format($order->total_amount,2) }}EUR</td>
<td class="space-x-2">
    @if(auth()->user()->hasPermission('orders.update'))
        <form method="post" action="{{ route('orders.markPaid', $order) }}" class="inline">@csrf<button class="desk-btn">Marcar pago</button></form>
    @endif
    @if(auth()->user()->hasPermission('orders.download') && ! $isPhotographer)
        @if($order->status === 'paid')
            <form method="post" action="{{ route('orders.sendDownloadLink', $order) }}" class="inline">
                @csrf
                <input type="hidden" name="customer_email" value="">
                <button type="submit" class="desk-btn" data-send-link data-has-email="{{ $order->customer_email ? '1' : '0' }}">Enviar</button>
            </form>
        @endif
        @if($order->status !== 'pending')
            <a class="desk-btn" href="{{ route('orders.downloadAll', $order) }}">Download ZIP</a>
        @endif
    @endif
</td>
</tr>
@endforeach
</tbody>
</table>
</div>

@if(auth()->user()->hasPermission('orders.bulk') && ! $isPhotographer)
    <form method="post" action="{{ route('orders.bulkStatus') }}" id="bulk-form" class="desk-toolbar">
        @csrf
        <select name="status" class="desk-select" required>
            <option value="">Bulk status</option>
            <option value="pending">pending</option>
            <option value="paid">paid</option>
        </select>
        <button class="desk-btn">Aplicar aos selecionados</button>
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

document.querySelectorAll('[data-send-link]').forEach((btn) => {
  btn.addEventListener('click', (e) => {
    if (btn.dataset.hasEmail === '1') return;
    e.preventDefault();
    const email = prompt('Email do cliente para enviar o link de download:');
    if (!email) return;
    const form = btn.closest('form');
    const input = form?.querySelector('input[name="customer_email"]');
    if (!input) return;
    input.value = email.trim();
    form.submit();
  });
});
</script>
@endsection
