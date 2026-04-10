<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59</title>
</head>
<body style="font-family: Arial, sans-serif; background:#f6f6f6; padding:20px;">
    <div style="max-width:620px; margin:0 auto; background:#ffffff; border:1px solid #e5e5e5; border-radius:8px; padding:24px;">
        @php
            $title = 'Convite para evento';
            if ($reason === 'updated') {
                $title = 'Atualização de evento';
            } elseif ($reason === 'cancelled') {
                $title = 'Removido do evento';
            }
        @endphp
        <h2 style="margin:0 0 12px;">{{ $title }}</h2>
        <p style="margin:0 0 10px;">Olá {{ $user->name }},</p>
        <p style="margin:0 0 10px;">
            Evento: <strong>{{ $eventLabel ?: 'EVENTO' }}</strong>
        </p>
        @php
            $storeTime = $event->store_time_raw ?? null;
            if (empty($storeTime) && is_array($event->event_meta ?? null)) {
                $storeTime = $event->event_meta['estar_na_loja_as'] ?? null;
            }
            $storeTime = is_string($storeTime) ? trim($storeTime) : '';
            $startTime = $storeTime;
            if (empty($startTime) && !empty($event->event_time)) {
                $startTime = $event->event_time;
            }
        @endphp
        <p style="margin:0 0 10px;">
            Data: <strong>{{ $event->event_date }}</strong>
            @if(!empty($startTime))
                às <strong>{{ $startTime }}</strong> (até <strong>23:59</strong>)
            @endif
        </p>
        @if(!empty($event->location))
            <p style="margin:0 0 10px;">Local: <strong>{{ $event->location }}</strong></p>
        @endif
        @if($reason === 'cancelled')
            <p style="margin:0 0 16px;">
                Foi removido do evento. Em anexo segue o cancelamento (.ics) para remover da sua agenda.
            </p>
        @else
            <p style="margin:0 0 16px;">
                Em anexo segue o convite de calendário (.ics). Abra o anexo para aceitar e adicionar à sua agenda.
            </p>
            <p style="margin:0; font-size:13px; color:#555;">
                Se precisar alterar a duração do evento, pode ajustar no seu calendário depois de aceitar.
            </p>
        @endif
    </div>
</body>
</html>
