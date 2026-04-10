<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59 - Eventos</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="/brand.css">
</head>
<body class="bg-gray-100 min-h-screen">
<main class="max-w-5xl mx-auto p-6">
    <h1 class="text-2xl font-bold mb-4">Eventos de hoje</h1>
    <div class="grid md:grid-cols-2 gap-4">
        @forelse($events as $event)
            <a href="{{ route('guest.enter.form', $event) }}" class="block bg-white rounded border p-4 hover:border-black">
                <div class="font-semibold">{{ $event->name }}</div>
                <div class="text-sm text-gray-600">{{ $event->event_date->format('Y-m-d') }} {{ $event->location ? '• '.$event->location : '' }}</div>
            </a>
        @empty
            <div class="bg-white border rounded p-4 text-gray-600">Sem eventos ativos hoje.</div>
        @endforelse
    </div>
</main>
</body>
</html>
