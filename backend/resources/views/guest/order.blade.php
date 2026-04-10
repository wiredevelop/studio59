<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59 - Pedido</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="/brand.css">
</head>
<body class="bg-gray-100 min-h-screen">
<main class="max-w-2xl mx-auto p-6">
    @if(session('ok'))
        <div class="bg-green-100 border border-green-300 p-3 rounded mb-4">{{ session('ok') }}</div>
    @endif
    <div class="bg-white border rounded p-4 space-y-2">
        <div id="pending-note" class="{{ $order->status === 'pending' ? '' : 'hidden' }}">
            <div class="bg-amber-100 border border-amber-300 text-amber-900 p-3 rounded text-sm font-semibold">
                @if($order->payment_method === 'online')
                    Estamos a confirmar o pagamento online.
                @else
                    Dirija-se ao fotografo, e obrigado.
                @endif
            </div>
            <div class="text-xs text-gray-500">A aguardar confirmação de pagamento.</div>
        </div>
        <h1 class="text-xl font-semibold">Pedido {{ $order->order_code }}</h1>
        <div class="text-sm">Evento: {{ $order->event->name }}</div>
        <div class="text-sm">Cliente: {{ $order->customer_name }}</div>
        <div class="text-sm">Pagamento: {{ $order->payment_method === 'online' ? 'Online (Stripe)' : 'Dinheiro' }}</div>
        <div class="text-sm">Estado: <span id="order-status" class="font-semibold">{{ strtoupper($order->status) }}</span></div>
        <div class="text-sm">Total: {{ number_format($order->total_amount, 2) }}€</div>
        <div class="pt-2 text-sm">
            Fotos:
            <span class="font-mono">
                {{ $order->items->map(fn($i) => $i->photo?->number)->filter()->implode(', ') }}
            </span>
        </div>
        <div id="download-area">
            @if(!empty($downloadUrl))
                <a href="{{ $downloadUrl }}" class="inline-block mt-2 border rounded px-3 py-2 bg-white">Download das fotos</a>
                @if(!empty($downloadExpiresAt))
                    <div class="text-xs text-gray-500">Link válido até {{ $downloadExpiresAt->format('d/m/Y H:i') }}</div>
                @endif
            @elseif($order->status === 'paid')
                <div class="text-sm text-gray-600">Link expirado. Pede ao fotografo para enviar novamente.</div>
            @endif
        </div>
        <a href="{{ route('guest.catalog', $order->event) }}" class="inline-block mt-2 border rounded px-3 py-2 bg-white">Voltar ao catalogo</a>
    </div>
</main>
<script>
const ordersKey = 'studio59_orders';
const eventId = {{ $order->event_id }};
const cartKey = `studio59_cart_${eventId}`;
const wantsFilmKey = `studio59_wants_film_${eventId}`;
const orderCode = '{{ $order->order_code }}';

const readOrders = () => {
    try { return JSON.parse(localStorage.getItem(ordersKey) || '[]'); } catch (_) { return []; }
};
const writeOrders = (codes) => localStorage.setItem(ordersKey, JSON.stringify(codes));

const codes = readOrders();
if (!codes.includes(orderCode)) {
    codes.unshift(orderCode);
    writeOrders(codes);
}
localStorage.removeItem(cartKey);
localStorage.removeItem(wantsFilmKey);
</script>
<script>
const statusEl = document.getElementById('order-status');
const pendingNote = document.getElementById('pending-note');
const downloadArea = document.getElementById('download-area');

const renderDownload = (payload) => {
    if (!downloadArea) return;
    if (!payload.download_url) {
        if (payload.status === 'paid') {
            downloadArea.innerHTML = '<div class="text-sm text-gray-600">Link expirado. Pede ao fotografo para enviar novamente.</div>';
        } else {
            downloadArea.innerHTML = '';
        }
        return;
    }
    const expires = payload.download_expires_label ? `<div class="text-xs text-gray-500">Link válido até ${payload.download_expires_label}</div>` : '';
    downloadArea.innerHTML = `<a href="${payload.download_url}" class="inline-block mt-2 border rounded px-3 py-2 bg-white">Download das fotos</a>${expires}`;
};

const pollStatus = async () => {
    try {
        const res = await fetch('{{ route('guest.order.status', $order->order_code) }}', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        if (statusEl && data.status) statusEl.textContent = String(data.status).toUpperCase();
        if (pendingNote) pendingNote.classList.toggle('hidden', data.status !== 'pending');
        renderDownload(data);
    } catch (_) {}
};

setInterval(pollStatus, 5000);
pollStatus();
</script>
</body>
</html>
