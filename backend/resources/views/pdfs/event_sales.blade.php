<!doctype html>
<html lang="pt">
<head>
<meta charset="utf-8">
<style>
@page { margin: 12mm 10mm; }
body { font-family: DejaVu Sans, sans-serif; font-size: 10px; color: #1e1e1e; margin: 0; }
h1 { font-size: 16px; color: #b63a2c; margin: 0 0 2px 0; }
h2 { font-size: 11px; color: #444; margin: 0 0 6px 0; font-weight: normal; }
.red { color: #b63a2c; }
.section-title {
    font-size: 9px; text-transform: uppercase; color: #888;
    border-bottom: 1px solid #ddd; margin: 10px 0 5px 0; padding-bottom: 2px;
}
table { width: 100%; border-collapse: collapse; }
td, th { padding: 3px 4px; vertical-align: top; }
th { background: #f2f2f2; font-size: 9px; text-align: left; font-weight: 600; }
.num { text-align: right; }
.summary-grid { width: 100%; }
.summary-grid td { padding: 4px 6px; width: 25%; }
.kpi-label { font-size: 8px; color: #888; text-transform: uppercase; }
.kpi-val { font-size: 14px; font-weight: 700; color: #1e1e1e; }
.kpi-val.red { color: #b63a2c; }
.kpi-box { border: 1px solid #e0e0e0; padding: 5px; text-align: center; }
.commission-table td { padding: 3px 4px; border-bottom: 1px solid #f0f0f0; }
.note-text { font-size: 9px; color: #555; font-style: italic; }
.footer { margin-top: 12px; font-size: 8px; color: #aaa; text-align: right; }
.orders-table td { border-bottom: 1px solid #f5f5f5; font-size: 9px; }
.badge-cash { color: #2e7d32; font-weight: 600; }
.badge-online { color: #1565c0; font-weight: 600; }
.badge-pending { color: #e65100; }
.badge-paid { color: #2e7d32; }
</style>
</head>
<body>
@php
    $fmt = fn($v) => number_format((float)$v, 2, ',', '.');
@endphp

<h1>Resumo de Vendas — {{ strtoupper($event->event_type ?: 'Evento') }}</h1>
<h2>
    {{ $event->name }}
    @if($dateLabel) · {{ $dateLabel }} @endif
    @if($event->location) · {{ $event->location }} @endif
</h2>
@if($staffMembers->count())
<h2 style="color:#b63a2c;">Equipa: {{ $staffMembers->implode(' · ') }}</h2>
@endif

{{-- KPI summary --}}
<div class="section-title">Resumo Financeiro</div>
<table class="summary-grid">
    <tr>
        <td><div class="kpi-box">
            <div class="kpi-label">Total Geral</div>
            <div class="kpi-val red">{{ $fmt($grandTotal) }} €</div>
        </div></td>
        <td><div class="kpi-box">
            <div class="kpi-label">Dinheiro Físico</div>
            <div class="kpi-val">{{ $fmt($cashTotal) }} €</div>
        </div></td>
        <td><div class="kpi-box">
            <div class="kpi-label">Digital / Online</div>
            <div class="kpi-val">{{ $fmt($digitalTotal) }} €</div>
        </div></td>
        <td><div class="kpi-box">
            <div class="kpi-label">Fotos Vendidas</div>
            <div class="kpi-val">{{ $photosSold }}</div>
        </div></td>
    </tr>
    @if($changeOwed > 0 || $photosOwed > 0)
    <tr>
        @if($changeOwed > 0)
        <td><div class="kpi-box">
            <div class="kpi-label">Trocos a Devolver</div>
            <div class="kpi-val red">{{ $fmt($changeOwed) }} €</div>
        </div></td>
        @endif
        @if($photosOwed > 0)
        <td><div class="kpi-box">
            <div class="kpi-label">Fotos em Dívida</div>
            <div class="kpi-val red">{{ $fmt($photosOwed) }} €</div>
        </div></td>
        @endif
    </tr>
    @endif
</table>

{{-- Commission --}}
<div class="section-title">Comissão de Equipa ({{ number_format($commissionRate, 1, ',', '.') }}%)</div>
<p style="font-size:9px; color:#555; margin: 0 0 5px 0;">
    {{ $fmt($grandTotal) }} ÷ {{ $memberCount }} membro(s) × {{ number_format($commissionRate, 1, ',', '.') }}% =
    <strong>{{ $fmt($commissionPerMember) }} € por pessoa</strong>
</p>
<table class="commission-table" style="width: auto;">
    <tr>
        <th style="width:80mm;">Membro</th>
        <th style="width:40mm; text-align:right;">Comissão</th>
    </tr>
    @foreach($staffMembers as $name)
    <tr>
        <td>{{ $name }}</td>
        <td class="num">{{ $fmt($commissionPerMember) }} €</td>
    </tr>
    @endforeach
    @if($staffMembers->isEmpty())
    <tr><td colspan="2" style="color:#aaa;">Sem membros registados neste evento.</td></tr>
    @endif
</table>

{{-- Orders list --}}
<div class="section-title">Pedidos ({{ $orders->count() }} total)</div>
<table class="orders-table">
    <tr>
        <th style="width:22mm;">Código</th>
        <th style="width:50mm;">Cliente</th>
        <th style="width:12mm; text-align:center;">Fotos</th>
        <th style="width:14mm;">Pagamento</th>
        <th style="width:12mm; text-align:center;">Estado</th>
        <th style="width:18mm; text-align:right;">Total</th>
        <th>Notas</th>
    </tr>
    @foreach($orders as $o)
    @php
        $photoNums = $o->items->filter(fn($i) => $i->photo)->map(fn($i) => $i->photo->number.'×'.($i->quantity ?? 1))->implode(', ');
        $photoCount = $o->items->sum(fn($i) => $i->quantity ?? 1);
    @endphp
    <tr>
        <td>{{ $o->order_code }}</td>
        <td>{{ $o->customer_name }}</td>
        <td style="text-align:center;">{{ $photoCount }}</td>
        <td>
            @if($o->payment_method === 'cash')
                <span class="badge-cash">Dinheiro</span>
            @elseif($o->payment_method === 'online')
                <span class="badge-online">Online</span>
            @else
                {{ $o->payment_method }}
            @endif
        </td>
        <td style="text-align:center;">
            @if($o->status === 'paid' || $o->status === 'delivered')
                <span class="badge-paid">Pago</span>
            @else
                <span class="badge-pending">Pendente</span>
            @endif
        </td>
        <td class="num">{{ $fmt($o->total_amount) }} €</td>
        <td class="note-text">
            {{ $o->notes ?? '' }}
            @if((float)$o->cash_change_amount > 0)
                @if($o->notes) · @endif
                Troco {{ $fmt($o->cash_change_amount) }} €
            @endif
            @if((float)$o->cash_due_amount > 0)
                @if($o->notes || (float)$o->cash_change_amount > 0) · @endif
                Deve {{ $fmt($o->cash_due_amount) }} €
            @endif
        </td>
    </tr>
    @endforeach
</table>

@if(count($notesList))
<div class="section-title">Notas dos Pedidos</div>
@foreach($notesList as $n)
<p style="font-size:9px; margin: 2px 0;"><strong>{{ $n['code'] }}</strong>: {{ $n['text'] }}</p>
@endforeach
@endif

<div class="footer">Studio 59 · Gerado em {{ now()->format('d/m/Y H:i') }}</div>
</body>
</html>
