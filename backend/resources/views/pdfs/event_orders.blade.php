<!doctype html>
<html lang="pt">
<head>
<meta charset="utf-8">
<style>
@page { margin: 12mm 10mm; }
body { font-family: DejaVu Sans, sans-serif; font-size: 10px; color: #1e1e1e; margin: 0; }
h1 { font-size: 15px; color: #b63a2c; margin: 0 0 2px 0; }
h2 { font-size: 10px; color: #555; margin: 0 0 8px 0; font-weight: normal; }
.section-title {
    font-size: 8px; text-transform: uppercase; color: #888; letter-spacing: 0.5px;
    border-bottom: 1px solid #e0e0e0; margin: 10px 0 5px 0; padding-bottom: 2px;
}
table { width: 100%; border-collapse: collapse; }
th { background: #f5f5f5; font-size: 8px; text-align: left; font-weight: 700;
     padding: 3px 4px; border-bottom: 1px solid #ddd; }
td { padding: 3px 4px; vertical-align: top; border-bottom: 1px solid #f5f5f5; font-size: 9px; }
.num { text-align: right; }
.muted { color: #888; }
.red { color: #b63a2c; }
.green { color: #2e7d32; }
.orange { color: #e65100; }
.blue { color: #1565c0; }
.badge { font-weight: 600; }
.settlement { font-weight: 700; }
.photos-cell { font-size: 8px; color: #444; }
.note-cell { font-size: 8px; color: #666; font-style: italic; }
.summary-row td { font-weight: 700; background: #f9f9f9; border-top: 2px solid #ddd; }
.footer { margin-top: 14px; font-size: 8px; color: #bbb; text-align: right; }
</style>
</head>
<body>
@php
    $fmt = fn($v) => number_format((float)$v, 2, ',', '.');
    $totalOrders  = $orders->count();
    $totalPhotos  = $orders->sum(fn($o) => $o->items->sum(fn($i) => $i->quantity ?? 1));
    $grandTotal   = $orders->sum(fn($o) => (float) $o->total_amount);
@endphp

<h1>Pedidos — {{ strtoupper($event->event_type ?: 'Evento') }}</h1>
<h2>
    {{ $event->name }}
    @if($dateLabel) · {{ $dateLabel }} @endif
    @if($event->location) · {{ $event->location }} @endif
    &nbsp;·&nbsp; {{ $totalOrders }} pedido(s) &nbsp;·&nbsp; {{ $totalPhotos }} foto(s)
</h2>

<table>
    <thead>
        <tr>
            <th style="width:8mm;">#</th>
            <th style="width:20mm;">Código</th>
            <th style="width:42mm;">Cliente</th>
            <th style="width:28mm;">Fotos</th>
            <th style="width:14mm;">Pagamento</th>
            <th style="width:10mm; text-align:center;">Estado</th>
            <th style="width:16mm; text-align:right;">Total</th>
            <th>Notas</th>
        </tr>
    </thead>
    <tbody>
    @foreach($orders as $i => $o)
    @php
        $photoList = $o->items->filter(fn($item) => $item->photo)
            ->map(fn($item) => $item->photo->number.' ×'.($item->quantity ?? 1))
            ->implode(', ');
        $photoCount = $o->items->sum(fn($item) => $item->quantity ?? 1);
        $isPaid = in_array($o->status, ['paid', 'delivered']);
        $hasDue = (float) $o->cash_due_amount > 0;
        $hasPendingChange = (float) $o->cash_change_amount > 0 && ! $o->cash_change_given;
        $settlementClass = $hasDue ? 'red' : ($hasPendingChange ? 'orange' : ($isPaid ? 'green' : 'orange'));
        $settlementText = $hasDue
            ? 'DEVE '.$fmt($o->cash_due_amount).' €'
            : ($hasPendingChange
                ? 'TROCO '.$fmt($o->cash_change_amount).' €'
                : ($isPaid ? 'PAGO' : 'PENDENTE'));
        $flags = [];
        if ((float)$o->cash_change_amount > 0 && $o->cash_change_given)
            $flags[] = 'Troco entregue '.$fmt($o->cash_change_amount).' €';
        $noteText = trim(collect(array_filter([$o->notes, implode(' · ', $flags)]))->implode(' · '));
    @endphp
    <tr>
        <td class="muted">{{ $i + 1 }}</td>
        <td>{{ $o->order_code }}</td>
        <td>
            {{ $o->customer_name }}
            @if($o->customer_phone)
                <br><span class="muted">{{ $o->customer_phone }}</span>
            @endif
        </td>
        <td class="photos-cell">
            {{ $photoCount }} foto(s)
            @if($photoList) <br>{{ $photoList }} @endif
        </td>
        <td>
            @if($o->payment_method === 'cash')
                <span class="badge green">Dinheiro</span>
            @elseif($o->payment_method === 'online')
                <span class="badge blue">Online</span>
            @else
                <span class="muted">{{ $o->payment_method ?: '-' }}</span>
            @endif
        </td>
        <td style="text-align:center;">
            <span class="settlement {{ $settlementClass }}">{{ $settlementText }}</span>
        </td>
        <td class="num">{{ $fmt($o->total_amount) }} €</td>
        <td class="note-cell">{{ $noteText }}</td>
    </tr>
    @endforeach
    <tr class="summary-row">
        <td colspan="3">TOTAL</td>
        <td class="photos-cell">{{ $totalPhotos }} fotos</td>
        <td colspan="2"></td>
        <td class="num">{{ $fmt($grandTotal) }} €</td>
        <td></td>
    </tr>
    </tbody>
</table>

<div class="footer">Studio 59 · {{ $event->name }} · Gerado em {{ now()->format('d/m/Y H:i') }}</div>
</body>
</html>
