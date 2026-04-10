@extends('layouts.app')
@section('page_title', 'Dossier do evento')
@section('page_subtitle', $event->name . ' · ' . $event->event_date->format('d/m/Y'))
@section('page_actions')
    @if(auth()->user()->hasPermission('uploads.list'))
        <a href="{{ route('uploads.index', $event) }}" class="desk-btn">Upload provas</a>
    @endif
    <a href="{{ route('events.pdf', $event) }}" target="_blank" class="desk-btn">PDF</a>
    <a href="{{ route('events.index') }}" class="desk-btn">Voltar</a>
@endsection
@section('content')

<div class="grid md:grid-cols-4 gap-3 mb-4">
    <div class="bg-white border rounded p-3">
        <div class="text-xs text-gray-500">Total de fotos</div>
        <div class="text-xl font-semibold">{{ $totalPhotos }}</div>
    </div>
    <div class="bg-white border rounded p-3">
        <div class="text-xs text-gray-500">Previews prontas</div>
        <div class="text-xl font-semibold">{{ $previewReady }}</div>
    </div>
    <div class="bg-white border rounded p-3">
        <div class="text-xs text-gray-500">Previews com falha</div>
        <div class="text-xl font-semibold">{{ $previewFailed }}</div>
    </div>
    <div class="bg-white border rounded p-3">
        <div class="text-xs text-gray-500">PIN do evento</div>
        <div class="text-xl font-semibold">{{ $event->access_pin ?? '—' }}</div>
    </div>
</div>

<div class="bg-white border rounded p-4 mb-4">
    <div class="text-sm font-semibold mb-2">QR do Evento</div>
    <div class="text-sm break-all">
        {{ url('/api/public/events/qr/'.$event->qr_token) }}
    </div>
    <div class="text-xs text-gray-500 mt-2">QR ativo: {{ $event->qr_enabled ? 'Sim' : 'Não' }} | Bloqueado: {{ $event->is_locked ? 'Sim' : 'Não' }}</div>
</div>

<div class="bg-white border rounded p-4 mb-4">
    <div class="text-sm font-semibold mb-2">Preços</div>
    <div class="grid md:grid-cols-2 gap-2 text-sm">
        <div><strong>Preço base:</strong> {{ $event->base_price !== null ? number_format($event->base_price, 2).'€' : '—' }}</div>
        <div><strong>Preço por foto:</strong> {{ number_format($event->price_per_photo, 2).'€' }}</div>
    </div>
</div>

@if($event->event_meta)
@php
    $type = $event->event_type ?? '';
    $commonFields = [
        'missa_hora',
        'igreja_local',
        'igreja_localidade',
        'quinta_local',
        'almoco_localidade',
        'numero_convidados',
        'data_entrega',
        'estar_na_loja_as',
    ];
    $casamentoFields = [
        'noivo_nome',
        'noiva_nome',
        'noivo_contacto',
        'noiva_contacto',
        'noivo_profissao',
        'noiva_profissao',
        'noivo_morada',
        'noiva_morada',
        'noivo_instagram',
        'noiva_instagram',
        'noivo_coordenadas',
        'noiva_coordenadas',
        'noivo_filho_de_1',
        'noivo_filho_de_2',
        'noiva_filho_de_1',
        'noiva_filho_de_2',
        'casa_noivo_chegada',
        'casa_noivo_saida',
        'casa_noiva_chegada',
        'casa_noiva_saida',
        'cliente_noivo_num',
        'cliente_noiva_num',
    ];
    $batizadoFields = [
        'bebe_nome',
        'pai_nome',
        'mae_nome',
        'padrinho_nome',
        'madrinha_nome',
        'contacto_pais',
        'instagram_pais',
        'morada',
        'casa_bebe_hora',
        'coordenadas',
        'cliente_batizado_num',
    ];
    $baseFields = $type === 'casamento' ? $casamentoFields : $batizadoFields;
    $serviceFields = collect($event->event_meta)
        ->keys()
        ->filter(fn ($k) => str_starts_with($k, 'servico_'))
        ->values()
        ->all();
    $fields = array_values(array_unique(array_merge($baseFields, $commonFields, $serviceFields)));
@endphp
<div class="bg-white border rounded p-4 mb-4">
    <div class="text-sm font-semibold mb-2">Detalhes do Evento</div>
    <div class="grid md:grid-cols-2 gap-2 text-sm">
        @foreach($fields as $k)
            @if(array_key_exists($k, $event->event_meta))
                <div><strong>{{ ucfirst(str_replace('_', ' ', $k)) }}:</strong> {{ $event->event_meta[$k] }}</div>
            @endif
        @endforeach
    </div>
</div>
@endif

<div class="bg-white border rounded p-4 mb-4">
    <div class="text-sm font-semibold mb-3">Staff associado</div>
    @if(auth()->user()->hasPermission('events.update'))
        <form method="post" action="{{ route('events.staff.assign', $event) }}" class="flex flex-wrap gap-2 mb-3">
            @csrf
            <select name="user_id" class="border rounded px-3 py-2">
                @foreach($users as $user)
                    <option value="{{ $user->id }}">{{ $user->name }} ({{ $user->role }})</option>
                @endforeach
            </select>
            <select name="role" class="border rounded px-3 py-2">
                <option value="photographer">Fotógrafo</option>
                <option value="assistant">Assistente</option>
                <option value="sales">Vendas</option>
            </select>
            <button class="bg-black text-white px-3 py-2 rounded">Associar</button>
        </form>
    @endif
    <div class="space-y-2">
        @forelse($staff as $member)
            <div class="flex items-center justify-between border rounded p-2">
                <div class="text-sm">{{ $member->user->name }} — {{ $member->role }}</div>
                @if(auth()->user()->hasPermission('events.update'))
                    <form method="post" action="{{ route('events.staff.remove', [$event, $member->user]) }}" onsubmit="return confirm('Remover staff?');">
                        @csrf
                        @method('DELETE')
                        <button class="text-red-600 text-sm">Remover</button>
                    </form>
                @endif
            </div>
        @empty
            <div class="text-sm text-gray-500">Sem staff associado.</div>
        @endforelse
    </div>
</div>

<div class="bg-white border rounded p-4 mb-4">
    <div class="text-sm font-semibold mb-3">Pastas</div>
    <div class="grid md:grid-cols-2 gap-3">
        <a href="{{ route('events.show', ['event' => $event->id, 'folder' => 'previews']) }}"
           class="border rounded p-4 {{ $folder === 'previews' ? 'border-blue-500 bg-blue-50' : '' }}">
            <div class="text-lg">[DIR] PREVIEWS</div>
            <div class="text-xs text-gray-500 mt-1">Catalogo para convidados (watermark)</div>
        </a>
        <a href="{{ route('events.show', ['event' => $event->id, 'folder' => 'provas']) }}"
           class="border rounded p-4 {{ $folder === 'provas' ? 'border-blue-500 bg-blue-50' : '' }}">
            <div class="text-lg">[DIR] PROVAS</div>
            <div class="text-xs text-gray-500 mt-1">JPEG originais carregados pelo fotografo</div>
        </a>
    </div>
</div>

<form class="bg-white border rounded p-3 mb-4 flex gap-2">
    <input type="hidden" name="folder" value="{{ $folder }}">
    <input name="search" value="{{ $search }}" class="border rounded p-2 w-full" placeholder="Pesquisar por numero (ex: 0007)">
    <button class="bg-black text-white px-4 rounded">Pesquisar</button>
</form>

<div class="bg-white border rounded p-3 mb-2">
    <div class="text-sm font-semibold mb-2">
        {{ $folder === 'previews' ? 'Conteudo da pasta PREVIEWS' : 'Conteudo da pasta PROVAS' }}
    </div>

    @if(auth()->user()->hasPermission('photos.bulk_delete'))
        <div class="mb-3 flex flex-wrap gap-2">
            <button type="button" id="select-all-photos" class="border rounded px-3 py-2 bg-white text-sm">Selecionar tudo</button>
            <button type="button" id="clear-all-photos" class="border rounded px-3 py-2 bg-white text-sm">Limpar selecao</button>
            <button type="button" id="bulk-delete-submit" class="bg-red-700 text-white rounded px-3 py-2 text-sm">Apagar selecionadas</button>
        </div>
    @endif

    <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-3">
        @forelse($photos as $photo)
            <div class="border rounded p-2 bg-gray-50">
                <label class="text-xs flex items-center gap-1 mb-1">
                    @if(auth()->user()->hasPermission('photos.delete') || auth()->user()->hasPermission('photos.bulk_delete'))
                        <input type="checkbox" class="photo-check" name="photo_ids[]" value="{{ $photo->id }}">
                    @endif
                    <span>#{{ $photo->number }}</span>
                </label>

                @if($photo->preview_path)
                    <img src="{{ route('preview.image', $photo) }}" class="w-full h-24 object-cover rounded bg-white">
                @else
                    <div class="w-full h-24 rounded bg-gray-200 flex items-center justify-center text-xs text-gray-500">Sem preview</div>
                @endif
                <div class="mt-2 text-[11px] text-gray-600">preview: {{ $photo->preview_status ?? 'n/a' }}</div>
                @if($photo->preview_error)
                    <div class="text-[11px] text-red-600 mt-1">erro: {{ \Illuminate\Support\Str::limit($photo->preview_error, 40) }}</div>
                @endif
                <div class="mt-2 text-xs flex flex-col gap-1">
                    @if($folder === 'previews')
                        <a class="text-blue-600" target="_blank" href="{{ route('preview.image', $photo) }}">Ver preview</a>
                    @else
                        @if(auth()->user()->hasPermission('photos.original'))
                            <a class="text-blue-600" target="_blank" href="{{ route('events.photos.original', [$event, $photo]) }}">Ver original</a>
                        @endif
                    @endif
                    @if(auth()->user()->hasPermission('photos.original'))
                        <a class="text-blue-600" href="{{ route('events.photos.original', [$event, $photo]) }}" download>Download JPEG</a>
                    @endif
                    @if(auth()->user()->hasPermission('photos.update'))
                        <form method="post" action="{{ route('events.photos.retry-preview', [$event, $photo]) }}">
                            @csrf
                            <button class="text-amber-700 text-left">Regerar preview</button>
                        </form>
                    @endif
                    @if(auth()->user()->hasPermission('photos.delete'))
                        <form method="post" action="{{ route('events.photos.destroy', [$event, $photo]) }}" onsubmit="return confirm('Apagar foto #{{ $photo->number }}?');">
                            @csrf
                            @method('DELETE')
                            <button class="text-red-600 text-left">Apagar foto</button>
                        </form>
                    @endif
                </div>
            </div>
        @empty
            <div class="col-span-full text-sm text-gray-500">Sem fotos para mostrar.</div>
        @endforelse
    </div>
</div>

<form method="post" action="{{ route('events.photos.bulk-delete', $event) }}" id="bulk-delete-form" class="hidden">
    @csrf
</form>

<div>{{ $photos->links() }}</div>

<script>
const checks = () => Array.from(document.querySelectorAll('.photo-check'));
document.getElementById('select-all-photos')?.addEventListener('click', () => checks().forEach((c) => c.checked = true));
document.getElementById('clear-all-photos')?.addEventListener('click', () => checks().forEach((c) => c.checked = false));
document.getElementById('bulk-delete-submit')?.addEventListener('click', () => {
    const any = checks().some((c) => c.checked);
    if (!any) {
        alert('Seleciona pelo menos 1 foto.');
        return;
    }

    if (!confirm('Apagar fotos selecionadas?')) {
        return;
    }

    const form = document.getElementById('bulk-delete-form');
    if (!form) return;
    form.querySelectorAll('input[name=\"photo_ids[]\"]').forEach((el) => el.remove());

    checks().filter((c) => c.checked).forEach((c) => {
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = 'photo_ids[]';
        input.value = c.value;
        form.appendChild(input);
    });
    form.submit();
});
</script>
@endsection
