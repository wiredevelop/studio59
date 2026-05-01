<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59 - Catálogo</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="/brand.css">
    <style>
        .catalog-shell { height: 100vh; display: grid; grid-template-rows: auto 1fr auto; }
        .catalog-body { min-height: 0; overflow: hidden; display: flex; flex-direction: column; }
        #all-grid { flex: 1 1 auto; min-height: 0; grid-auto-rows: 1fr; }
        .photo-card { background: var(--brand-surface); border: 1px solid rgba(219, 171, 151, 0.45); border-radius: 14px; overflow: hidden; }
        .photo-card { display: flex; flex-direction: column; height: 100%; }
        .photo-thumb { position: relative; overflow: hidden; flex: 1 1 auto; min-height: 0; }
        .photo-thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }
        .photo-footer { flex-shrink: 0; }
        .wm-overlay { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; opacity: 0.15; font-weight: 800; letter-spacing: 2px; color: var(--brand-rose); font-size: 22px; pointer-events: none; }
        .select-badge {
            position: absolute;
            top: 8px;
            right: 8px;
            width: 26px;
            height: 26px;
            border-radius: 999px;
            display: grid;
            place-items: center;
            border: 1px solid rgba(219,171,151,0.8);
            background: rgba(0,0,0,0.55) !important;
            font-size: 14px;
            color: var(--brand-rose) !important;
            opacity: 0;
            transform: scale(0.6);
            transition: opacity 160ms ease, transform 160ms ease;
        }
        .select-badge.selected {
            opacity: 1;
            transform: scale(1);
        }
        .photo-footer { display: flex; align-items: center; justify-content: space-between; padding: 6px 8px; font-size: 12px; }
        .modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.65); display: none; align-items: center; justify-content: center; z-index: 50; }
        .modal-panel { width: min(92vw, 1100px); height: min(82vh, 760px); background: var(--brand-surface); border: 1px solid rgba(219,171,151,0.45); border-radius: 18px; overflow: hidden; display: grid; grid-template-rows: auto 1fr auto; }
        .qr-panel { width: min(92vw, 360px); height: auto; display: block; }
        .qr-panel .modal-body { height: auto; }
        .qr-panel .modal-body img { width: 100%; height: auto; display: block; object-fit: contain; }
        .modal-header { padding: 10px 14px; font-weight: 600; display: flex; justify-content: space-between; align-items: center; }
        .modal-body { position: relative; padding: 8px; }
        .modal-body img { width: 100%; height: 100%; object-fit: contain; background: #000; border-radius: 12px; }
        .modal-watermark { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-size: clamp(32px, 10vw, 120px); font-weight: 800; letter-spacing: 6px; color: var(--brand-rose); opacity: 0.12; pointer-events: none; }
        .modal-actions { padding: 12px 14px; display: flex; gap: 10px; justify-content: flex-end; }
        .bottom-bar { position: sticky; bottom: 12px; margin-top: 16px; display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
        .cart-pulse { animation: cartPulse 420ms ease-out; }
        .card-flash { animation: cardFlash 520ms ease-out; }
        @keyframes cartPulse {
            0% { transform: scale(1); box-shadow: 0 0 0 rgba(219,171,151,0.0); }
            40% { transform: scale(1.02); box-shadow: 0 0 18px rgba(219,171,151,0.35); }
            100% { transform: scale(1); box-shadow: 0 0 0 rgba(219,171,151,0.0); }
        }
        @keyframes cardFlash {
            0% { box-shadow: 0 0 0 rgba(219,171,151,0.0); }
            45% { box-shadow: 0 0 18px rgba(219,171,151,0.45); }
            100% { box-shadow: 0 0 0 rgba(219,171,151,0.0); }
        }
    </style>
</head>
<body class="bg-gray-100 h-screen overflow-hidden">
<main class="mx-auto h-full max-w-6xl p-4 catalog-shell">
    <div class="catalog-top">
        @if($errors->any())
            <div class="bg-red-100 border border-red-300 p-3 rounded mb-4">{{ $errors->first() }}</div>
        @endif

        <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
            <div class="text-sm font-semibold">{{ $event->name }}</div>
            <div class="flex items-center gap-2">
                @if($event->qr_token)
                    <button type="button" id="qr-btn" class="ios-btn ios-btn-secondary">QR Code</button>
                @endif
                <button type="button" id="face-search-btn" class="ios-btn ios-btn-secondary">Pesquisa facial</button>
                <button type="button" id="clear-guest-btn" class="ios-btn ios-btn-secondary">Novo convidado / limpar sessão</button>
                <input id="face-input" type="file" accept="image/*" capture="user" class="hidden">
            </div>
        </div>
        <div class="text-xs text-gray-600 mb-3">Podes tirar a selfie sozinho ou com mais pessoas. As sugestões incluem fotos onde apareca qualquer rosto detetado.</div>

        <form method="get" action="{{ route('guest.catalog', $event) }}" class="mb-3">
            <div class="grid grid-cols-[1fr_auto] gap-2">
                <input name="search" value="{{ $search }}" class="ios-input" placeholder="Pesquisar número">
                <button class="ios-btn ios-btn-primary" type="submit">Pesquisar</button>
            </div>
        </form>
    </div>

    <div class="catalog-body">
        <div id="suggestions-section" class="mb-4 hidden">
            <div class="text-xs uppercase tracking-wider text-gray-600 mb-2">Sugestões</div>
            <div id="suggestions-grid" class="grid grid-cols-3 gap-3"></div>
        </div>

        <div class="text-xs uppercase tracking-wider text-gray-600 mb-2">Todas</div>
        <div id="all-grid" class="grid grid-cols-3 gap-3">
        @foreach($photos as $photo)
            @php $previewUrl = route('preview.image', $photo).'?v='.($photo->updated_at ? $photo->updated_at->timestamp : 0); @endphp
            <div class="photo-card" data-photo-id="{{ $photo->id }}" data-photo-number="{{ $photo->number }}" data-photo-url="{{ $previewUrl }}">
                <div class="photo-thumb">
                    <img src="{{ $previewUrl }}" alt="Foto {{ $photo->number }}" loading="lazy" decoding="async">
                    <div class="wm-overlay">STUDIO 59</div>
                    <button type="button" class="select-badge" data-select-toggle>✓</button>
                </div>
                <div class="photo-footer">
                    <span>#{{ $photo->number }}</span>
                    <button type="button" class="text-xs" data-select-toggle>Selecionar</button>
                </div>
            </div>
        @endforeach
        </div>
    </div>

    <div class="catalog-bottom pt-3 border-t border-white/10">
        <div class="flex flex-wrap items-center justify-between gap-3">
            <div class="min-w-[220px]">{{ $photos->links('pagination.guest') }}</div>
            <a href="{{ route('guest.cart', $event) }}" class="ios-btn ios-btn-primary" id="cart-btn">Carrinho (0)</a>
        </div>
    </div>
</main>

<div id="photo-modal" class="modal-backdrop">
    <div class="modal-panel">
        <div class="modal-header">
            <span id="modal-title">Foto</span>
            <button class="ios-btn ios-btn-secondary" id="modal-close">Fechar</button>
        </div>
        <div class="modal-body">
            <img id="modal-image" src="" alt="Preview">
            <div class="modal-watermark">STUDIO 59</div>
        </div>
        <div class="modal-actions">
            <button class="ios-btn ios-btn-primary" id="modal-toggle">Selecionar</button>
        </div>
    </div>
</div>

@if($event->qr_token)
    @php $qrUrl = url('/api/public/events/qr/'.$event->qr_token); @endphp
    <div id="qr-modal" class="modal-backdrop">
        <div class="modal-panel qr-panel">
            <div class="modal-header">
                <span>QR Code do Evento</span>
                <button class="ios-btn ios-btn-secondary" id="qr-close">Fechar</button>
            </div>
            <div class="modal-body">
                <img src="https://api.qrserver.com/v1/create-qr-code/?size=320x320&data={{ urlencode($qrUrl) }}" alt="QR Code do evento">
            </div>
            <div class="modal-actions">
                <div class="text-xs text-gray-500 break-all">{{ $qrUrl }}</div>
            </div>
        </div>
    </div>
@endif

<script>
const eventId = {{ $event->id }};
const cartKey = `studio59_cart_${eventId}`;
const wantsFilmKey = `studio59_wants_film_${eventId}`;
const previewBase = '{{ url('/preview') }}/';

const readCart = () => {
    try {
        const raw = JSON.parse(localStorage.getItem(cartKey) || '{}');
        return raw && typeof raw === 'object' ? raw : {};
    } catch (_) { return {}; }
};
const writeCart = (cart) => localStorage.setItem(cartKey, JSON.stringify(cart));
const cartCount = (cart) => Object.values(cart).reduce((sum, item) => sum + (item.qty || 1), 0);

const updateCartBadge = () => {
    const cart = readCart();
    const count = cartCount(cart);
    const btn = document.getElementById('cart-btn');
    if (btn) btn.textContent = `Carrinho (${count})`;
};

const setSelectedState = (card, selected) => {
    const badge = card.querySelector('[data-select-toggle]');
    if (selected) badge?.classList.add('selected'); else badge?.classList.remove('selected');
};

const pulseCart = () => {
    const btn = document.getElementById('cart-btn');
    if (!btn) return;
    btn.classList.remove('cart-pulse');
    void btn.offsetWidth;
    btn.classList.add('cart-pulse');
};

const flashCard = (card) => {
    if (!card) return;
    card.classList.remove('card-flash');
    void card.offsetWidth;
    card.classList.add('card-flash');
};

const toggleSelection = (card) => {
    const id = Number(card.dataset.photoId);
    const number = card.dataset.photoNumber;
    const url = card.dataset.photoUrl || `${previewBase}${id}`;
    const cart = readCart();
    if (cart[id]) {
        delete cart[id];
        setSelectedState(card, false);
    } else {
        cart[id] = { id, number, url, qty: 1 };
        setSelectedState(card, true);
        flashCard(card);
        pulseCart();
    }
    writeCart(cart);
    updateCartBadge();
};

const initCards = () => {
    const cart = readCart();
    document.querySelectorAll('.photo-card').forEach((card) => {
        const id = Number(card.dataset.photoId);
        setSelectedState(card, !!cart[id]);
        card.querySelectorAll('[data-select-toggle]').forEach((btn) => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                toggleSelection(card);
                syncModalButton();
            });
        });
        const thumb = card.querySelector('.photo-thumb');
        if (thumb) {
            let clickTimer = null;
            thumb.addEventListener('click', (e) => {
                if (clickTimer) return;
                clickTimer = setTimeout(() => {
                    toggleSelection(card);
                    syncModalButton();
                    clickTimer = null;
                }, 220);
            });
            thumb.addEventListener('dblclick', () => {
                if (clickTimer) {
                    clearTimeout(clickTimer);
                    clickTimer = null;
                }
                openModal(card);
            });
        }
    });
};

const modal = document.getElementById('photo-modal');
const modalTitle = document.getElementById('modal-title');
const modalImage = document.getElementById('modal-image');
const modalToggle = document.getElementById('modal-toggle');
let modalCard = null;

const openModal = (card) => {
    modalCard = card;
    modalTitle.textContent = `Foto ${card.dataset.photoNumber}`;
    modalImage.src = card.dataset.photoUrl || `${previewBase}${card.dataset.photoId}`;
    syncModalButton();
    modal.style.display = 'flex';
};

const closeModal = () => {
    modal.style.display = 'none';
    modalCard = null;
};

const syncModalButton = () => {
    if (!modalCard) return;
    const id = Number(modalCard.dataset.photoId);
    const selected = !!readCart()[id];
    modalToggle.textContent = selected ? 'Remover' : 'Selecionar';
};

modalToggle?.addEventListener('click', () => {
    if (!modalCard) return;
    toggleSelection(modalCard);
    syncModalButton();
});

document.getElementById('modal-close')?.addEventListener('click', closeModal);
modal?.addEventListener('click', (e) => { if (e.target === modal) closeModal(); });

updateCartBadge();
initCards();

const clearGuestBtn = document.getElementById('clear-guest-btn');
clearGuestBtn?.addEventListener('click', () => {
    localStorage.removeItem(cartKey);
    localStorage.removeItem(wantsFilmKey);
    document.querySelectorAll('.photo-card').forEach((card) => setSelectedState(card, false));
    if (modalCard) syncModalButton();
    updateCartBadge();
    alert('Novo convidado pronto. Carrinho limpo.');
});

const faceBtn = document.getElementById('face-search-btn');
const faceInput = document.getElementById('face-input');
const qrBtn = document.getElementById('qr-btn');
const qrModal = document.getElementById('qr-modal');
const qrClose = document.getElementById('qr-close');
const suggestionsSection = document.getElementById('suggestions-section');
const suggestionsGrid = document.getElementById('suggestions-grid');
const allGrid = document.getElementById('all-grid');
const csrfToken = '{{ csrf_token() }}';

qrBtn?.addEventListener('click', () => {
    if (qrModal) qrModal.style.display = 'flex';
});
qrClose?.addEventListener('click', () => {
    if (qrModal) qrModal.style.display = 'none';
});
qrModal?.addEventListener('click', (e) => {
    if (e.target === qrModal) qrModal.style.display = 'none';
});

const renderSuggestions = (photos) => {
    suggestionsGrid.innerHTML = '';
    if (!photos.length) {
        suggestionsSection.classList.add('hidden');
        return;
    }
    photos.forEach((p) => {
        const existing = allGrid.querySelector(`[data-photo-id="${p.id}"]`);
        if (existing) existing.remove();

        const card = document.createElement('div');
        card.className = 'photo-card';
        card.dataset.photoId = String(p.id);
        card.dataset.photoNumber = String(p.number);
        card.dataset.photoUrl = p.preview_url || `${previewBase}${p.id}`;
        card.innerHTML = `
            <div class="photo-thumb">
                <img src="${card.dataset.photoUrl}" alt="Foto ${p.number}" loading="lazy">
                <div class="wm-overlay">STUDIO 59</div>
                <button type="button" class="select-badge" data-select-toggle>✓</button>
            </div>
            <div class="photo-footer">
                <span>#${p.number}</span>
                <button type="button" class="text-xs" data-select-toggle>Selecionar</button>
            </div>
        `;
        suggestionsGrid.appendChild(card);
    });
    suggestionsSection.classList.remove('hidden');
    initCards();
};

faceBtn?.addEventListener('click', () => faceInput?.click());
faceInput?.addEventListener('change', async () => {
    const file = faceInput.files?.[0];
    if (!file) return;
    faceBtn.disabled = true;
    faceBtn.textContent = 'A analisar...';
    try {
        const formData = new FormData();
        formData.append('selfie', file);
        const res = await fetch('{{ route('guest.catalog.faceSearch', $event) }}', {
            method: 'POST',
            headers: { 'X-CSRF-TOKEN': csrfToken },
            body: formData,
        });
        const data = await res.json();
        if (!res.ok) {
            alert(data.message || 'Falha na pesquisa facial.');
        } else {
            renderSuggestions(data.suggested || []);
        }
    } catch (e) {
        alert('Falha na pesquisa facial.');
    } finally {
        faceBtn.disabled = false;
        faceBtn.textContent = 'Pesquisa facial';
        faceInput.value = '';
    }
});

</script>
</body>
</html>
