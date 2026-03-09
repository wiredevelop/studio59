<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59 - Downloads</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 min-h-screen">
<main class="max-w-5xl mx-auto p-6">
    <div class="bg-white border rounded p-4 mb-4">
        <h1 class="text-xl font-semibold">Downloads - Pedido {{ $order->order_code }}</h1>
        <p class="text-sm text-gray-600">Evento: {{ $order->event->name }} - Cliente: {{ $order->customer_name }}</p>
        <p class="text-sm text-gray-600">Estado: {{ strtoupper($order->status) }}</p>
    </div>

    <form method="post" action="{{ route('downloads.bulk', ['token' => $token]) }}" id="bulk-download-form">
        @csrf
        <div class="mb-4 bg-white border rounded p-3 flex flex-wrap items-center gap-2">
            <button type="button" id="select-all" class="border rounded px-3 py-2 bg-white text-sm">Selecionar tudo</button>
            <button type="button" id="clear-all" class="border rounded px-3 py-2 bg-white text-sm">Limpar seleção</button>
            <button class="bg-black text-white rounded px-3 py-2 text-sm">Download selecionadas (ZIP)</button>
            <button name="all" value="1" class="border rounded px-3 py-2 bg-white text-sm">Download de todas (ZIP)</button>
        </div>

        <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-3">
            @foreach($order->items as $item)
                @php($photo = $item->photo)
                @if($photo)
                    <div class="bg-white border rounded p-2">
                        <label class="text-xs flex items-center gap-1 mb-1">
                            <input type="checkbox" class="photo-check" name="photo_ids[]" value="{{ $photo->id }}">
                            <span>#{{ $photo->number }}</span>
                        </label>
                        @if($photo->preview_path)
                            <img src="{{ route('preview.image', $photo) }}" class="w-full h-24 object-cover rounded">
                        @endif
                        <a class="text-blue-600 text-xs mt-2 inline-block" href="{{ route('downloads.photo', ['token' => $token, 'photoId' => $photo->id]) }}">
                            Download original
                        </a>
                    </div>
                @endif
            @endforeach
        </div>
    </form>
</main>

<script>
const checks = () => Array.from(document.querySelectorAll('.photo-check'));
document.getElementById('select-all')?.addEventListener('click', () => checks().forEach((c) => c.checked = true));
document.getElementById('clear-all')?.addEventListener('click', () => checks().forEach((c) => c.checked = false));

document.getElementById('bulk-download-form')?.addEventListener('submit', (e) => {
    if (e.submitter && e.submitter.name === 'all') {
        checks().forEach((c) => c.checked = false);
        return;
    }

    const any = checks().some((c) => c.checked);
    if (!any) {
        e.preventDefault();
        alert('Seleciona pelo menos 1 foto.');
    }
});
</script>
</body>
</html>
