<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59 - Pedido</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 min-h-screen">
<main class="max-w-2xl mx-auto p-6">
    @if(session('ok'))
        <div class="bg-green-100 border border-green-300 p-3 rounded mb-4">{{ session('ok') }}</div>
    @endif
    <div class="bg-white border rounded p-4 space-y-2">
        <h1 class="text-xl font-semibold">Pedido {{ $order->order_code }}</h1>
        <div class="text-sm">Evento: {{ $order->event->name }}</div>
        <div class="text-sm">Cliente: {{ $order->customer_name }}</div>
        <div class="text-sm">Estado: <span class="font-semibold">{{ strtoupper($order->status) }}</span></div>
        <div class="text-sm">Total: {{ number_format($order->total_amount, 2) }}€</div>
        <div class="pt-2 text-sm">
            Fotos:
            <span class="font-mono">
                {{ $order->items->map(fn($i) => $i->photo?->number)->filter()->implode(', ') }}
            </span>
        </div>
        <a href="{{ route('guest.events') }}" class="inline-block mt-2 border rounded px-3 py-2 bg-white">Voltar aos eventos</a>
    </div>
</main>
</body>
</html>
