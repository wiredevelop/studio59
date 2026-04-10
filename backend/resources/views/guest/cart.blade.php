<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59 - Carrinho</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="/brand.css">
    <style>
        .cart-card { background: var(--brand-surface); border: 1px solid rgba(219,171,151,0.45); border-radius: 14px; padding: 12px; }
        .item-row { display: grid; grid-template-columns: 64px 1fr auto; gap: 12px; align-items: center; }
        .qty-btn { width: 28px; height: 28px; border-radius: 999px; border: 1px solid rgba(219,171,151,0.8); display: grid; place-items: center; }
    </style>
</head>
<body class="bg-gray-100 min-h-screen">
<main class="max-w-4xl mx-auto p-4">
    <div class="flex items-center justify-between mb-4">
        <div class="text-lg font-semibold">Carrinho</div>
        <a href="{{ route('guest.catalog', $event) }}" class="ios-btn ios-btn-secondary">Voltar ao catálogo</a>
    </div>

    <div id="cart-empty" class="text-sm text-gray-600 hidden">Carrinho vazio</div>

    <div id="cart-list" class="space-y-3"></div>

    <div id="film-section" class="mt-4 hidden">
        <label class="flex items-center gap-2">
            <input type="checkbox" id="wants-film" class="h-4 w-4">
            <span>Adicionar filme (+30€)</span>
        </label>
    </div>

    <div id="cart-actions" class="mt-4 flex items-center justify-between">
        <div class="text-sm font-semibold" id="cart-total">Total: €0.00</div>
        <a href="{{ route('guest.checkout', $event) }}" class="ios-btn ios-btn-primary">Ir para checkout</a>
    </div>
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
const writeCart = (cart) => localStorage.setItem(cartKey, JSON.stringify(cart));

const render = () => {
    const list = document.getElementById('cart-list');
    const empty = document.getElementById('cart-empty');
    const actions = document.getElementById('cart-actions');
    const cart = readCart();
    const items = Object.values(cart);
    list.innerHTML = '';
    if (!items.length) {
        empty.classList.remove('hidden');
        filmSection?.classList.add('hidden');
        actions?.classList.add('hidden');
    } else {
        empty.classList.add('hidden');
        actions?.classList.remove('hidden');
        if (filmEligible) {
            filmSection?.classList.remove('hidden');
        }
        items.forEach((item) => {
            const row = document.createElement('div');
            row.className = 'cart-card';
            row.innerHTML = `
                <div class="item-row">
                    <img src="${item.url}" alt="Foto ${item.number}" class="w-16 h-16 object-cover rounded">
                    <div>
                        <div class="text-sm font-semibold">Foto ${item.number}</div>
                        <div class="text-xs text-gray-600">Quantidade: <span data-qty>${item.qty}</span></div>
                    </div>
                    <div class="flex items-center gap-2">
                        <button class="qty-btn" data-action="dec">-</button>
                        <button class="qty-btn" data-action="inc">+</button>
                        <button class="qty-btn" data-action="del">x</button>
                    </div>
                </div>
            `;
            row.querySelector('[data-action="dec"]').addEventListener('click', () => updateQty(item.id, -1));
            row.querySelector('[data-action="inc"]').addEventListener('click', () => updateQty(item.id, 1));
            row.querySelector('[data-action="del"]').addEventListener('click', () => removeItem(item.id));
            list.appendChild(row);
        });
    }
    updateTotals();
};

const updateQty = (id, delta) => {
    const cart = readCart();
    if (!cart[id]) return;
    const next = (cart[id].qty || 1) + delta;
    if (next <= 0) {
        delete cart[id];
    } else {
        cart[id].qty = next;
    }
    writeCart(cart);
    render();
};

const removeItem = (id) => {
    const cart = readCart();
    delete cart[id];
    writeCart(cart);
    render();
};

const updateTotals = () => {
    const cart = readCart();
    const items = Object.values(cart);
    const itemsTotal = items.reduce((sum, item) => sum + (item.qty || 1) * pricePerPhoto, 0);
    const wantsFilm = document.getElementById('wants-film')?.checked === true;
    const filmFee = wantsFilm ? 30 : 0;
    const total = itemsTotal + filmFee;
    document.getElementById('cart-total').textContent = `Total: €${total.toFixed(2)}`;
};

const filmEligible = eventType === 'casamento' || eventType === 'batizado';
const filmSection = document.getElementById('film-section');
const wantsFilmInput = document.getElementById('wants-film');
if (filmEligible && filmSection && wantsFilmInput) {
    filmSection.classList.remove('hidden');
    wantsFilmInput.checked = localStorage.getItem(wantsFilmKey) === '1';
    wantsFilmInput.addEventListener('change', () => {
        localStorage.setItem(wantsFilmKey, wantsFilmInput.checked ? '1' : '0');
        updateTotals();
    });
} else if (!filmEligible) {
    localStorage.removeItem(wantsFilmKey);
}

render();
</script>
</body>
</html>
