@extends('layouts.app')
@section('content')
<h1 class="text-xl font-semibold mb-4">Editar evento</h1>
<form method="post" action="{{ route('events.update', $event) }}" class="bg-white p-4 rounded shadow space-y-3">
    @csrf
    @method('PUT')
    <div>
        <label class="block text-sm">Nome</label>
        <input name="name" value="{{ $event->name }}" class="border p-2 rounded w-full" required>
    </div>
    <div>
        <label class="block text-sm">Tipo Evento</label>
        <select name="event_type" class="border p-2 rounded w-full" id="event-type">
            <option value="">—</option>
            <option value="casamento" {{ $event->event_type === 'casamento' ? 'selected' : '' }}>CASAMENTO</option>
            <option value="batizado" {{ $event->event_type === 'batizado' ? 'selected' : '' }}>BATIZADO</option>
        </select>
    </div>
    <div class="grid md:grid-cols-2 gap-3">
        <div>
            <label class="block text-sm">Data</label>
            <input type="date" name="event_date" value="{{ $event->event_date->format('Y-m-d') }}" class="border p-2 rounded w-full" required>
        </div>
        <div>
            <label class="block text-sm">Hora</label>
            <input type="time" name="event_time" value="{{ $event->event_time }}" class="border p-2 rounded w-full">
        </div>
    </div>
    <div class="grid md:grid-cols-2 gap-3">
        <div>
            <label class="block text-sm">Preço por foto</label>
            <input name="price_per_photo" type="number" step="0.01" value="{{ $event->price_per_photo }}" class="border p-2 rounded w-full" required>
        </div>
        <div>
            <label class="block text-sm">PIN do evento (4 dígitos)</label>
            <input value="{{ $event->access_pin ?? 'Gerado automaticamente' }}" class="border p-2 rounded w-full bg-gray-100" readonly>
        </div>
    </div>
    <div>
        <label class="block text-sm">Notas internas</label>
        <textarea name="notes" class="border p-2 rounded w-full">{{ $event->notes }}</textarea>
    </div>
    @php($meta = $event->event_meta ?? [])
    <div class="border rounded p-3 space-y-3">
        <div class="font-semibold">Detalhes adicionais</div>
        <div class="grid md:grid-cols-2 gap-3">
            <div>
                <label class="block text-sm">A que horas é a missa</label>
                <input type="time" name="event_meta[missa_hora]" value="{{ $meta['missa_hora'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Onde é a igreja</label>
                <input name="event_meta[igreja_local]" value="{{ $meta['igreja_local'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Onde é a quinta</label>
                <input name="event_meta[quinta_local]" value="{{ $meta['quinta_local'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Número de convidados</label>
                <input type="number" min="0" name="event_meta[numero_convidados]" value="{{ $meta['numero_convidados'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div class="md:col-span-2">
                <label class="block text-sm">Tipo de pacote (informativo)</label>
                <input name="event_meta[tipo_pacote]" value="{{ $meta['tipo_pacote'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
        </div>
    </div>
    <div id="event-meta-casamento" class="hidden border rounded p-3">
        <div class="font-semibold mb-2">Dados do Casamento</div>
        <div class="grid md:grid-cols-2 gap-3">
            <input name="event_meta[noivo_nome]" value="{{ $meta['noivo_nome'] ?? '' }}" placeholder="Nome do noivo" class="border p-2 rounded w-full">
            <input name="event_meta[noiva_nome]" value="{{ $meta['noiva_nome'] ?? '' }}" placeholder="Nome da noiva" class="border p-2 rounded w-full">
            <input name="event_meta[noivo_contacto]" value="{{ $meta['noivo_contacto'] ?? '' }}" placeholder="Contacto do noivo" class="border p-2 rounded w-full">
            <input name="event_meta[noiva_contacto]" value="{{ $meta['noiva_contacto'] ?? '' }}" placeholder="Contacto da noiva" class="border p-2 rounded w-full">
            <input name="event_meta[noivo_profissao]" value="{{ $meta['noivo_profissao'] ?? '' }}" placeholder="Profissão do noivo" class="border p-2 rounded w-full">
            <input name="event_meta[noiva_profissao]" value="{{ $meta['noiva_profissao'] ?? '' }}" placeholder="Profissão da noiva" class="border p-2 rounded w-full">
            <input name="event_meta[noivo_morada]" value="{{ $meta['noivo_morada'] ?? '' }}" placeholder="Morada do noivo" class="border p-2 rounded w-full">
            <input name="event_meta[noiva_morada]" value="{{ $meta['noiva_morada'] ?? '' }}" placeholder="Morada da noiva" class="border p-2 rounded w-full">
            <input name="event_meta[instagram_noivos]" value="{{ $meta['instagram_noivos'] ?? '' }}" placeholder="Instagram dos noivos" class="border p-2 rounded w-full md:col-span-2">
            <div>
                <label class="block text-sm">Casa do noivo: hora de chegada</label>
                <input type="time" name="event_meta[casa_noivo_chegada]" value="{{ $meta['casa_noivo_chegada'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Casa do noivo: hora de saída</label>
                <input type="time" name="event_meta[casa_noivo_saida]" value="{{ $meta['casa_noivo_saida'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Casa da noiva: hora de chegada</label>
                <input type="time" name="event_meta[casa_noiva_chegada]" value="{{ $meta['casa_noiva_chegada'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Casa da noiva: hora de saída</label>
                <input type="time" name="event_meta[casa_noiva_saida]" value="{{ $meta['casa_noiva_saida'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
        </div>
    </div>
    <div id="event-meta-batizado" class="hidden border rounded p-3">
        <div class="font-semibold mb-2">Dados do Batizado</div>
        <div class="grid md:grid-cols-2 gap-3">
            <input name="event_meta[bebe_nome]" value="{{ $meta['bebe_nome'] ?? '' }}" placeholder="Nome do bebé" class="border p-2 rounded w-full">
            <input name="event_meta[pai_nome]" value="{{ $meta['pai_nome'] ?? '' }}" placeholder="Nome do pai" class="border p-2 rounded w-full">
            <input name="event_meta[mae_nome]" value="{{ $meta['mae_nome'] ?? '' }}" placeholder="Nome da mãe" class="border p-2 rounded w-full">
            <input name="event_meta[padrinho_nome]" value="{{ $meta['padrinho_nome'] ?? '' }}" placeholder="Nome do padrinho" class="border p-2 rounded w-full">
            <input name="event_meta[madrinha_nome]" value="{{ $meta['madrinha_nome'] ?? '' }}" placeholder="Nome da madrinha" class="border p-2 rounded w-full">
            <input name="event_meta[contacto_pais]" value="{{ $meta['contacto_pais'] ?? '' }}" placeholder="Contacto dos pais" class="border p-2 rounded w-full">
            <input name="event_meta[morada]" value="{{ $meta['morada'] ?? '' }}" placeholder="Morada" class="border p-2 rounded w-full md:col-span-2">
            <input name="event_meta[instagram_pais]" value="{{ $meta['instagram_pais'] ?? '' }}" placeholder="Instagram dos pais" class="border p-2 rounded w-full md:col-span-2">
        </div>
    </div>
    <div class="flex items-center gap-4">
        @if($event->event_date->isSameDay(\Illuminate\Support\Carbon::today('Europe/Lisbon')) || $event->event_date->isPast())
            <label class="flex items-center gap-2">
                <input type="checkbox" name="is_locked" value="1" {{ $event->is_locked ? 'checked' : '' }}>
                <span>Bloqueado</span>
            </label>
        @endif
    </div>
    <button class="bg-black text-white px-3 py-2 rounded">Atualizar</button>
</form>
<script>
    const typeSelect = document.getElementById('event-type');
    const casamento = document.getElementById('event-meta-casamento');
    const batizado = document.getElementById('event-meta-batizado');
    function toggleMeta() {
        const v = typeSelect.value;
        casamento.classList.toggle('hidden', v !== 'casamento');
        batizado.classList.toggle('hidden', v !== 'batizado');
    }
    typeSelect.addEventListener('change', toggleMeta);
    toggleMeta();
</script>
@endsection
