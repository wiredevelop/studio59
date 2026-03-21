<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59 - Checkout</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="/brand.css">
    <style>
        .section-card { background: var(--brand-surface); border: 1px solid rgba(219,171,151,0.45); border-radius: 16px; padding: 16px; }
        .option { border: 1px solid rgba(219,171,151,0.45); border-radius: 12px; padding: 10px 12px; display: flex; align-items: center; gap: 8px; cursor: pointer; }
        .option input { accent-color: var(--brand-rose); }
    </style>
</head>
<body class="bg-gray-100 min-h-screen">
<main class="max-w-3xl mx-auto p-4">
    <div class="flex items-center justify-between mb-4">
        <div class="text-lg font-semibold">Checkout</div>
        <a href="{{ route('guest.cart', $event) }}" class="ios-btn ios-btn-secondary">Voltar ao carrinho</a>
    </div>

    <form id="checkout-form" method="post" action="{{ route('guest.order.store', $event) }}" class="space-y-4">
        @csrf
        <div class="text-sm" id="selected-count">Fotos selecionadas: 0</div>
        <div class="section-card space-y-3">
            <div class="text-sm font-semibold">Dados do cliente</div>
            <input name="customer_name" class="ios-input" placeholder="Nome" required>
            <input name="customer_phone" class="ios-input" placeholder="Telemóvel" required>
            <input name="customer_email" class="ios-input" placeholder="Email" type="email" required>
        </div>

        <div class="section-card space-y-3">
            <div class="text-sm font-semibold">Produto</div>
            <label class="option"><input type="radio" name="product_type" value="digital" checked> <span>Digital</span></label>
            <label class="option"><input type="radio" name="product_type" value="paper"> <span>Papel</span></label>
            <label class="option"><input type="radio" name="product_type" value="both"> <span>Ambos</span></label>
        </div>

        <div class="section-card space-y-3" id="delivery-section" style="display:none;">
            <div class="text-sm font-semibold">Entrega</div>
            <label class="option"><input type="radio" name="delivery_type" value="pickup"> <span id="delivery-pickup-label">Entregar aos noivos</span></label>
            <label class="option"><input type="radio" name="delivery_type" value="shipping"> <span>Enviar por correio (+5€)</span></label>
            <input name="delivery_address" id="delivery-address" class="ios-input" placeholder="Morada para envio" style="display:none;">
        </div>

        <div class="section-card space-y-3" id="film-section" style="display:none;">
            <div class="text-sm font-semibold">Filme</div>
            <div id="film-info" class="text-sm">Filme: Não</div>
        </div>

        <div class="section-card space-y-3">
            <div class="text-sm font-semibold">Pagamento</div>
            <label class="option"><input type="radio" name="payment_method" value="cash" checked> <span>Dinheiro (com fotógrafo)</span></label>
            <label class="option"><input type="radio" name="payment_method" value="mbway"> <span>MB Way</span></label>
        </div>

        <div class="section-card space-y-3">
            <div class="text-sm font-semibold" id="total-line">Total: €0.00 (Extras: €0.00)</div>
            <button class="ios-btn ios-btn-primary" type="submit">Submeter pedido</button>
        </div>
    </form>
</main>

<script>
const eventId = {{ $event->id }};
const eventType = '{{ $event->event_type ?? '' }}';
const pricePerPhoto = {{ (float) $event->price_per_photo }};
const cartKey = `studio59_cart_${eventId}`;
const wantsFilmKey = `studio59_wants_film_${eventId}`;

const readCart = () => {
    try {
        const raw = JSON.parse(localStorage.getItem(cartKey) || '{}');
        return raw && typeof raw === 'object' ? raw : {};
    } catch (_) { return {}; }
};

const totalLine = document.getElementById('total-line');
const selectedCount = document.getElementById('selected-count');
const deliverySection = document.getElementById('delivery-section');
const deliveryAddress = document.getElementById('delivery-address');
const pickupLabel = document.getElementById('delivery-pickup-label');

if (eventType === 'batizado') {
    pickupLabel.textContent = 'Entregar aos pais do bebé';
}

const filmSection = document.getElementById('film-section');
const filmInfo = document.getElementById('film-info');
const filmEligible = eventType === 'casamento' || eventType === 'batizado';
const wantsFilm = filmEligible && localStorage.getItem(wantsFilmKey) === '1';
if (filmEligible) {
    filmSection.style.display = 'block';
    filmInfo.textContent = wantsFilm ? 'Filme: Sim (+30€)' : 'Filme: Não';
} else {
    localStorage.removeItem(wantsFilmKey);
}

const updateTotals = () => {
    const cart = readCart();
    const items = Object.values(cart);
    if (selectedCount) {
        selectedCount.textContent = `Fotos selecionadas: ${items.length}`;
    }
    const itemsTotal = items.reduce((sum, item) => sum + (item.qty || 1) * pricePerPhoto, 0);
    const filmFee = wantsFilm ? 30 : 0;
    const deliveryType = document.querySelector('input[name="delivery_type"]:checked')?.value;
    const shippingFee = deliveryType === 'shipping' ? 5 : 0;
    const extras = filmFee + shippingFee;
    const total = itemsTotal + extras;
    totalLine.textContent = `Total: €${total.toFixed(2)} (Extras: €${extras.toFixed(2)})`;
};

const productRadios = document.querySelectorAll('input[name="product_type"]');
const toggleDelivery = () => {
    const productType = document.querySelector('input[name="product_type"]:checked')?.value;
    if (productType && productType !== 'digital') {
        deliverySection.style.display = 'block';
    } else {
        deliverySection.style.display = 'none';
        document.querySelectorAll('input[name="delivery_type"]').forEach((el) => el.checked = false);
        deliveryAddress.style.display = 'none';
        deliveryAddress.value = '';
    }
    updateTotals();
};
productRadios.forEach((r) => r.addEventListener('change', toggleDelivery));

const deliveryRadios = document.querySelectorAll('input[name="delivery_type"]');
deliveryRadios.forEach((r) => r.addEventListener('change', () => {
    if (r.value === 'shipping' && r.checked) {
        deliveryAddress.style.display = 'block';
    } else if (r.value === 'pickup' && r.checked) {
        deliveryAddress.style.display = 'none';
        deliveryAddress.value = '';
    }
    updateTotals();
}));

const form = document.getElementById('checkout-form');
form.addEventListener('submit', (e) => {
    const cart = readCart();
    const items = Object.values(cart);
    if (!items.length) {
        e.preventDefault();
        alert('Seleciona pelo menos 1 foto.');
        return;
    }
    const productType = document.querySelector('input[name="product_type"]:checked')?.value;
    const deliveryType = document.querySelector('input[name="delivery_type"]:checked')?.value || '';
    if (productType !== 'digital' && !deliveryType) {
        e.preventDefault();
        alert('Escolhe o tipo de entrega.');
        return;
    }
    if (deliveryType === 'shipping' && deliveryAddress.value.trim() === '') {
        e.preventDefault();
        alert('Morada obrigatória para envio.');
        return;
    }

    document.querySelectorAll('input[name^="photo_items"]')?.forEach((el) => el.remove());
    items.forEach((item, idx) => {
        const idInput = document.createElement('input');
        idInput.type = 'hidden';
        idInput.name = `photo_items[${idx}][photo_id]`;
        idInput.value = item.id;
        form.appendChild(idInput);

        const qtyInput = document.createElement('input');
        qtyInput.type = 'hidden';
        qtyInput.name = `photo_items[${idx}][quantity]`;
        qtyInput.value = item.qty || 1;
        form.appendChild(qtyInput);
    });

    const filmInput = document.createElement('input');
    filmInput.type = 'hidden';
    filmInput.name = 'wants_film';
    filmInput.value = wantsFilm ? '1' : '0';
    form.appendChild(filmInput);
});

toggleDelivery();
updateTotals();
</script>
</body>
</html>
