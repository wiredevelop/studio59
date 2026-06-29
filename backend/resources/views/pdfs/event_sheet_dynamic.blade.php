<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: DejaVu Sans, sans-serif; color: #1f2937; font-size: 12px; margin: 28px; }
        .header { margin-bottom: 18px; }
        .title { font-size: 24px; font-weight: 700; color: #8f2d18; }
        .subtitle { margin-top: 4px; color: #6b7280; }
        .sheet-section { margin-top: 18px; }
        .section-title { font-size: 12px; font-weight: 700; text-transform: uppercase; color: #9ca3af; margin-bottom: 8px; border-bottom: 1px solid #e5e7eb; padding-bottom: 4px; }
        .kv-grid { display: block; }
        .kv-row { margin-bottom: 6px; }
        .kv-row strong { display: inline-block; min-width: 170px; }
    </style>
</head>
<body>
    <div class="header">
        <div class="title">Ficha de Serviço — {{ strtoupper($serviceTemplate?->name ?? ($event->event_type ?: 'Evento')) }}</div>
        <div class="subtitle">
            {{ $event->name }}
            @if($dateLabel)
                · {{ $dateLabel }}
            @endif
        </div>
    </div>

    <div class="sheet-section">
        <div class="section-title">Resumo</div>
        <div class="kv-grid">
            <div class="kv-row"><strong>Reportagem:</strong> {{ $event->legacy_report_number ?? '—' }}</div>
            <div class="kv-row"><strong>Data:</strong> {{ $event->event_date?->format('d/m/Y') ?? '—' }}</div>
            <div class="kv-row"><strong>Hora:</strong> {{ $event->event_time ?? '—' }}</div>
            <div class="kv-row"><strong>Preço base:</strong> {{ $event->base_price !== null ? number_format($event->base_price, 2, ',', '.').' €' : '—' }}</div>
            <div class="kv-row"><strong>Preço por foto:</strong> {{ $event->price_per_photo !== null ? number_format($event->price_per_photo, 2, ',', '.').' €' : '—' }}</div>
            <div class="kv-row"><strong>PIN:</strong> {{ $event->access_pin ?? '—' }}</div>
        </div>
    </div>

    @include('events.partials.template-display', [
        'serviceTemplate' => $serviceTemplate,
        'event' => $event,
        'meta' => $meta,
        'forPdf' => true,
    ])

    @if(!empty($event->notes))
        <div class="sheet-section">
            <div class="section-title">Observações</div>
            <div>{{ $event->notes }}</div>
        </div>
    @endif
</body>
</html>
