<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59 - Catálogo</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 min-h-screen">
<main class="max-w-6xl mx-auto p-4">
    @if(session('ok'))
        <div class="bg-green-100 border border-green-300 p-3 rounded mb-4">{{ session('ok') }}</div>
    @endif
    @if($errors->any())
        <div class="bg-red-100 border border-red-300 p-3 rounded mb-4">{{ $errors->first() }}</div>
    @endif

    <div class="bg-white border rounded p-3 mb-3 flex flex-wrap items-center justify-between gap-2">
        <div>
            <div class="font-semibold">{{ $event->name }}</div>
            <div class="text-xs text-gray-600">Senha: {{ $event->access_password }} • Preço/foto: {{ number_format($event->price_per_photo, 2) }}€</div>
        </div>
        <div class="flex items-center gap-2">
            <button type="button" id="face-search-btn" class="border rounded px-3 py-2 bg-white">Pesquisa facial</button>
            <form method="post" action="{{ route('guest.reset', $event) }}">
                @csrf
                <button class="border rounded px-3 py-2 bg-white">Novo convidado / limpar sessão</button>
            </form>
            <input id="face-input" type="file" accept="image/*" capture="user" class="hidden">
        </div>
    </div>

    @if($event->event_meta)
        <div class="bg-white border rounded p-3 mb-3">
            <div class="text-sm font-semibold mb-2">Detalhes do Evento</div>
            <div class="grid md:grid-cols-2 gap-2 text-sm">
                @foreach($event->event_meta as $k => $v)
                    <div><strong>{{ ucfirst(str_replace('_', ' ', $k)) }}:</strong> {{ $v }}</div>
                @endforeach
            </div>
        </div>
    @endif

    <form class="bg-white border rounded p-3 mb-3 flex gap-2">
        <input name="search" value="{{ $search }}" class="border rounded p-2 w-full" placeholder="Pesquisar por número">
        <button class="bg-black text-white px-4 rounded">Pesquisar</button>
    </form>

    <form id="order-form" method="post" action="{{ route('guest.order.store', $event) }}" class="bg-white border rounded p-3 mb-4 space-y-2">
        @csrf
        <div class="grid md:grid-cols-4 gap-2">
            <input name="customer_name" class="border rounded p-2" placeholder="Nome" required>
            <input name="customer_phone" class="border rounded p-2" placeholder="Telefone (opcional)">
            <input name="customer_email" type="email" class="border rounded p-2" placeholder="Email (opcional)">
            <select name="payment_method" class="border rounded p-2">
                <option value="cash">cash</option>
                <option value="online">online (placeholder)</option>
            </select>
        </div>
        <div class="flex items-center justify-between">
            <div class="text-sm">Selecionadas: <span id="selected-count">0</span> • Total: <span id="selected-total">0.00€</span></div>
            <button class="bg-black text-white px-4 py-2 rounded">Criar pedido</button>
        </div>
    </form>

    <div id="suggestions-section" class="mb-4 hidden">
        <div class="text-xs uppercase tracking-wider text-gray-600 mb-2">Sugestões</div>
        <div id="suggestions-grid" class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-3"></div>
    </div>

    <div class="text-xs uppercase tracking-wider text-gray-600 mb-2">Todas</div>
    <div id="all-grid" class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-3">
        @foreach($photos as $photo)
            <label class="bg-white border rounded p-2 cursor-pointer" data-photo-id="{{ $photo->id }}">
                <input type="checkbox" class="photo-select mb-1" value="{{ $photo->id }}" data-price="{{ (float) $event->price_per_photo }}">
                <div class="text-xs font-semibold mb-1">#{{ $photo->number }}</div>
                <img src="{{ route('preview.image', $photo) }}" class="w-full h-24 object-cover rounded">
            </label>
        @endforeach
    </div>

    <div class="mt-4">{{ $photos->links() }}</div>
</main>

<script>
const selectedCount = document.getElementById('selected-count');
const selectedTotal = document.getElementById('selected-total');
const form = document.getElementById('order-form');
const storageKey = 'studio59_guest_cart_{{ $event->id }}';
const shouldClearOnLoad = {{ session('clear_guest_cart') ? 'true' : 'false' }};
const pricePerPhoto = {{ (float) $event->price_per_photo }};
const faceBtn = document.getElementById('face-search-btn');
const faceInput = document.getElementById('face-input');
const suggestionsSection = document.getElementById('suggestions-section');
const suggestionsGrid = document.getElementById('suggestions-grid');
const allGrid = document.getElementById('all-grid');
const csrfToken = '{{ csrf_token() }}';

const readCart = () => {
    try { return JSON.parse(localStorage.getItem(storageKey) || '[]'); } catch (_) { return []; }
};
const writeCart = (ids) => localStorage.setItem(storageKey, JSON.stringify(ids));

const bindCheckbox = (checkbox) => {
    checkbox.addEventListener('change', () => {
        const ids = new Set(readCart());
        const id = Number(checkbox.value);
        if (checkbox.checked) ids.add(id); else ids.delete(id);
        writeCart(Array.from(ids));
        syncUi();
    });
};

const syncUi = () => {
    const ids = readCart();
    document.querySelectorAll('.photo-select').forEach((el) => {
        el.checked = ids.includes(Number(el.value));
    });
    selectedCount.textContent = String(ids.length);
    selectedTotal.textContent = (ids.length * pricePerPhoto).toFixed(2) + '€';
};

if (shouldClearOnLoad) {
    localStorage.removeItem(storageKey);
}

document.querySelectorAll('.photo-select').forEach((checkbox) => bindCheckbox(checkbox));

form.addEventListener('submit', (e) => {
    const ids = readCart();
    if (!ids.length) {
        e.preventDefault();
        alert('Seleciona pelo menos 1 foto.');
        return;
    }

    ids.forEach((id) => {
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = 'photo_ids[]';
        input.value = id;
        form.appendChild(input);
    });
});

syncUi();

const renderSuggestions = (photos) => {
    suggestionsGrid.innerHTML = '';
    if (!photos.length) {
        suggestionsSection.classList.add('hidden');
        return;
    }
    photos.forEach((p) => {
        const existing = allGrid.querySelector(`[data-photo-id=\"${p.id}\"]`);
        if (existing) existing.remove();

        const label = document.createElement('label');
        label.className = 'bg-white border rounded p-2 cursor-pointer';
        label.dataset.photoId = String(p.id);
        label.innerHTML = `
            <input type=\"checkbox\" class=\"photo-select mb-1\" value=\"${p.id}\" data-price=\"${pricePerPhoto}\">
            <div class=\"text-xs font-semibold mb-1\">#${p.number}</div>
            <img src=\"${p.preview_url}\" class=\"w-full h-24 object-cover rounded\">
        `;
        suggestionsGrid.appendChild(label);
        const checkbox = label.querySelector('.photo-select');
        bindCheckbox(checkbox);
    });
    suggestionsSection.classList.remove('hidden');
    syncUi();
};

faceBtn?.addEventListener('click', () => {
    faceInput?.click();
});

faceInput?.addEventListener('change', async () => {
    const file = faceInput.files?.[0];
    if (!file) return;

    if (!confirm('Ao usar pesquisa facial, autorizas a análise da tua selfie para sugerir as fotos.')) {
        faceInput.value = '';
        return;
    }

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
