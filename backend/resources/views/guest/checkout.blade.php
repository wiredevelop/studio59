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
        .payment-options { display: grid; gap: 10px; }
        .payment-option { border: 1px solid rgba(219,171,151,0.45); border-radius: 14px; padding: 12px 14px; display: flex; align-items: center; justify-content: space-between; gap: 12px; background: rgba(219,171,151,0.04); cursor: pointer; }
        .payment-option input { accent-color: var(--brand-rose); }
        .payment-option-main { display: flex; align-items: center; gap: 12px; flex: 1; }
        .payment-option-text { display: grid; gap: 2px; }
        .payment-option-title { font-weight: 600; font-size: 14px; }
        .payment-option-sub { font-size: 12px; color: rgba(219,171,151,0.7); }
        .payment-badges { display: flex; flex-wrap: wrap; gap: 6px; justify-content: flex-end; }
        .payment-badge { font-size: 10px; letter-spacing: 0.08em; text-transform: uppercase; padding: 2px 6px; border-radius: 999px; border: 1px solid rgba(219,171,151,0.5); color: rgba(219,171,151,0.85); }
        .payment-note { font-size: 12px; color: rgba(219,171,151,0.7); }
        .stripe-section { display: none; }
        .stripe-section.active { display: block; }
        #payment-element { padding: 10px 12px; border-radius: 12px; border: 1px solid rgba(219,171,151,0.45); background: rgba(219,171,151,0.04); }
        .payment-error { color: #f5b4a4; font-size: 12px; }
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
        @if($errors->any())
            <div class="bg-amber-100 border border-amber-300 text-amber-900 p-3 rounded text-sm font-semibold">
                {{ $errors->first() }}
            </div>
        @endif
        @if(request()->boolean('stripe_canceled'))
            <div class="bg-amber-100 border border-amber-300 text-amber-900 p-3 rounded text-sm font-semibold">
                Pagamento cancelado. Podes tentar novamente quando quiseres.
            </div>
        @endif
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
            <div class="payment-options">
                <label class="payment-option">
                    <div class="payment-option-main">
                        <input type="radio" name="payment_method" value="cash" checked>
                        <div class="payment-option-text">
                            <span class="payment-option-title">Dinheiro</span>
                            <span class="payment-option-sub">Pagamento direto com o fotógrafo</span>
                        </div>
                    </div>
                </label>
                <label class="payment-option">
                    <div class="payment-option-main">
                        <input type="radio" name="payment_method" value="online">
                        <div class="payment-option-text">
                            <span class="payment-option-title">Pagamento online (Stripe)</span>
                            <span class="payment-option-sub">Cartão e métodos locais — pagamento seguro</span>
                        </div>
                    </div>
                    <div class="payment-badges" aria-hidden="true">
                        <span class="payment-badge">Visa</span>
                        <span class="payment-badge">Mastercard</span>
                        <span class="payment-badge">MB Way</span>
                        <span class="payment-badge">Klarna</span>
                        <span class="payment-badge">Bancontact</span>
                        <span class="payment-badge">EPS</span>
                    </div>
                </label>
            </div>
            <div class="payment-note">As opções disponíveis podem variar conforme o país, moeda e configuração da Stripe.</div>
        </div>

        <div class="section-card space-y-3 stripe-section" id="stripe-section">
            <div class="text-sm font-semibold">Pagamento online</div>
            <div id="payment-element"></div>
            <div id="payment-error" class="payment-error"></div>
        </div>

        <div class="section-card space-y-3">
            <div class="text-sm font-semibold" id="total-line">Total: €0.00 (Extras: €0.00)</div>
            <button class="ios-btn ios-btn-primary" type="submit" id="submit-btn">Submeter pedido</button>
        </div>
    </form>
</main>

<script src="https://js.stripe.com/v3/"></script>
<script>
const eventId = {{ $event->id }};
const eventType = '{{ $event->event_type ?? '' }}';
const pricePerPhoto = {{ (float) $event->price_per_photo }};
const cartKey = `studio59_cart_${eventId}`;
const wantsFilmKey = `studio59_wants_film_${eventId}`;
const stripePublishableKey = '{{ config('services.stripe.publishable') }}';
const paymentIntentUrl = '{{ route('guest.payment.intent', $event) }}';
const orderBaseUrl = '{{ route('guest.order.show', 'ORDER_CODE') }}'.replace('ORDER_CODE', '');

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
const stripeSection = document.getElementById('stripe-section');
const submitBtn = document.getElementById('submit-btn');
const paymentError = document.getElementById('payment-error');
const paymentElementContainer = document.getElementById('payment-element');

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
const paymentRadios = document.querySelectorAll('input[name="payment_method"]');
let stripe = null;
let elements = null;
let clientSecret = '';
let orderCode = '';

const setPaymentError = (message) => {
    if (!paymentError) return;
    paymentError.textContent = message || '';
};

const toggleStripeSection = () => {
    const method = document.querySelector('input[name="payment_method"]:checked')?.value;
    if (method === 'online') {
        stripeSection?.classList.add('active');
        submitBtn.textContent = clientSecret ? 'Pagar agora' : 'Continuar para pagamento';
    } else {
        stripeSection?.classList.remove('active');
        submitBtn.textContent = 'Submeter pedido';
    }
};
paymentRadios.forEach((r) => r.addEventListener('change', toggleStripeSection));
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

    const method = document.querySelector('input[name="payment_method"]:checked')?.value || 'cash';
    if (method !== 'online') {
        return;
    }

    e.preventDefault();
    if (!stripePublishableKey) {
        setPaymentError('Pagamento online indisponível de momento.');
        return;
    }

    setPaymentError('');
    submitBtn.disabled = true;
    submitBtn.textContent = clientSecret ? 'A processar...' : 'A preparar pagamento...';

    const runOnlinePayment = async () => {
        try {
            if (!clientSecret) {
                const formData = new FormData(form);
                const res = await fetch(paymentIntentUrl, {
                    method: 'POST',
                    headers: { 'X-CSRF-TOKEN': formData.get('_token') },
                    body: formData,
                });
                const data = await res.json();
                if (!res.ok) {
                    throw new Error(data?.message || 'Falha ao iniciar pagamento.');
                }
                clientSecret = data.client_secret;
                orderCode = data.order_code;
                stripe = Stripe(stripePublishableKey);
                elements = stripe.elements({ clientSecret });
                const paymentElement = elements.create('payment');
                paymentElement.mount(paymentElementContainer);
                submitBtn.textContent = 'Pagar agora';
                submitBtn.disabled = false;
                paymentElementContainer.scrollIntoView({ behavior: 'smooth', block: 'center' });
                return;
            }

            const { error, paymentIntent } = await stripe.confirmPayment({
                elements,
                confirmParams: {
                    return_url: `${orderBaseUrl}${orderCode}`,
                },
                redirect: 'if_required',
            });

            if (error) {
                throw new Error(error.message || 'Falha ao confirmar pagamento.');
            }

            if (paymentIntent && ['succeeded', 'processing', 'requires_capture'].includes(paymentIntent.status)) {
                window.location.href = `${orderBaseUrl}${orderCode}`;
            } else {
                window.location.href = `${orderBaseUrl}${orderCode}`;
            }
        } catch (err) {
            setPaymentError(err?.message || 'Falha ao iniciar pagamento.');
            submitBtn.disabled = false;
            submitBtn.textContent = clientSecret ? 'Pagar agora' : 'Continuar para pagamento';
        }
    };

    runOnlinePayment();
});

toggleDelivery();
updateTotals();
toggleStripeSection();
</script>
</body>
</html>
