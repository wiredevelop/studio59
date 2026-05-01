@extends('layouts.app')
@section('page_title', 'Novo evento')
@section('page_subtitle', 'Criar ficha completa do serviço')
@section('page_actions')
    <a href="{{ route('events.index') }}" class="desk-btn">Voltar</a>
@endsection
@section('content')
<div class="flex items-center gap-3 mb-2">
    <div id="autosave-status" class="text-xs text-gray-500"></div>
    <div class="text-xs px-2 py-1 rounded bg-amber-100 text-amber-800">Rascunho</div>
</div>
@php
    $meta = old('event_meta', []);
@endphp
<form id="event-create-form" method="post" action="{{ route('events.store') }}" class="event-form space-y-6" enctype="multipart/form-data" data-update-url-template="{{ route('events.update', ['event' => '__EVENT__']) }}">
    @csrf
    <div class="event-card space-y-3">
        <div class="font-semibold">Dados base</div>
        <div class="grid md:grid-cols-3 gap-3">
            <div>
                <label class="block text-sm">Tipo de serviço</label>
                <select name="event_type" class="border p-2 rounded w-full" id="event-type">
                    <option value="">—</option>
                    <option value="casamento" {{ old('event_type') === 'casamento' ? 'selected' : '' }}>CASAMENTO</option>
                    <option value="batizado" {{ old('event_type') === 'batizado' ? 'selected' : '' }}>BATIZADO</option>
                </select>
            </div>
            <div>
                <label class="block text-sm">Data (do serviço)</label>
                <input type="date" name="event_date" id="event-date" value="{{ old('event_date') }}" class="border p-2 rounded w-full" required>
            </div>
            <div>
                <label class="block text-sm">Nº reportagem</label>
                <input name="legacy_report_number" value="{{ old('legacy_report_number', $nextReportNumber ?? '') }}" placeholder="Gerado automaticamente" class="border p-2 rounded w-full">
            </div>
        </div>
        <div class="grid md:grid-cols-4 gap-3">
            <div>
                <label class="block text-sm">Hora (do serviço)</label>
                <input type="time" name="event_time" value="{{ old('event_time') }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Preço base</label>
                <input name="base_price" type="number" step="0.01" value="{{ old('base_price') }}" class="border p-2 rounded w-full" required>
            </div>
            <div>
                <label class="block text-sm">Preço por foto</label>
                <input name="price_per_photo" type="number" step="0.01" value="{{ old('price_per_photo', '5.00') }}" class="border p-2 rounded w-full" required>
            </div>
            <div>
                <label class="block text-sm">PIN do evento (4 dígitos)</label>
                <input value="Gerado automaticamente ao guardar" class="border p-2 rounded w-full bg-gray-100" readonly>
            </div>
        </div>
        <input type="hidden" name="event_meta[cliente_noivo_num]" id="cliente-noivo-num" value="{{ $meta['cliente_noivo_num'] ?? '' }}">
        <input type="hidden" name="event_meta[cliente_noiva_num]" id="cliente-noiva-num" value="{{ $meta['cliente_noiva_num'] ?? '' }}">
        <input type="hidden" name="event_meta[cliente_batizado_num]" id="cliente-batizado-num" value="{{ $meta['cliente_batizado_num'] ?? '' }}">
    </div>

    <div id="event-meta-casamento" class="hidden event-card space-y-4">
        <div class="font-semibold">Dados do Casamento</div>
        <div class="grid md:grid-cols-2 gap-4">
            <div class="event-card event-subcard space-y-3">
                <div class="font-semibold text-sm">Noivo</div>
                <div class="grid md:grid-cols-2 gap-3">
                    <div class="md:col-span-2">
                        <label class="block text-sm">Nome do noivo</label>
                        <input name="event_meta[noivo_nome]" value="{{ $meta['noivo_nome'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div>
                        <label class="block text-sm">Instagram</label>
                        <input name="event_meta[noivo_instagram]" value="{{ $meta['noivo_instagram'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div>
                        <label class="block text-sm">Telemóvel</label>
                        <input name="event_meta[noivo_contacto]" value="{{ $meta['noivo_contacto'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div>
                        <label class="block text-sm">Profissão</label>
                        <input name="event_meta[noivo_profissao]" value="{{ $meta['noivo_profissao'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div>
                        <label class="block text-sm">Filho de</label>
                        <input name="event_meta[noivo_filho_de_1]" value="{{ $meta['noivo_filho_de_1'] ?? '' }}" class="border p-2 rounded w-full" placeholder="Pai">
                    </div>
                    <div>
                        <label class="block text-sm">Filho de</label>
                        <input name="event_meta[noivo_filho_de_2]" value="{{ $meta['noivo_filho_de_2'] ?? '' }}" class="border p-2 rounded w-full" placeholder="Mãe">
                    </div>
                    <div class="md:col-span-2">
                        <label class="block text-sm">Morada</label>
                        <input name="event_meta[noivo_morada]" value="{{ $meta['noivo_morada'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div class="md:col-span-2">
                        <label class="block text-sm">Coordenadas</label>
                        <input name="event_meta[noivo_coordenadas]" value="{{ $meta['noivo_coordenadas'] ?? '' }}" class="border p-2 rounded w-full" placeholder="Ex: 41.123,-8.456">
                    </div>
                    <div>
                        <label class="block text-sm">Casa do noivo: hora de chegada</label>
                        <input type="time" name="event_meta[casa_noivo_chegada]" value="{{ $meta['casa_noivo_chegada'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div>
                        <label class="block text-sm">Casa do noivo: hora de saída</label>
                        <input type="time" name="event_meta[casa_noivo_saida]" value="{{ $meta['casa_noivo_saida'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                </div>
            </div>
            <div class="event-card event-subcard space-y-3">
                <div class="font-semibold text-sm">Noiva</div>
                <div class="grid md:grid-cols-2 gap-3">
                    <div class="md:col-span-2">
                        <label class="block text-sm">Nome da noiva</label>
                        <input name="event_meta[noiva_nome]" value="{{ $meta['noiva_nome'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div>
                        <label class="block text-sm">Instagram</label>
                        <input name="event_meta[noiva_instagram]" value="{{ $meta['noiva_instagram'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div>
                        <label class="block text-sm">Telemóvel</label>
                        <input name="event_meta[noiva_contacto]" value="{{ $meta['noiva_contacto'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div>
                        <label class="block text-sm">Profissão</label>
                        <input name="event_meta[noiva_profissao]" value="{{ $meta['noiva_profissao'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div>
                        <label class="block text-sm">Filho de</label>
                        <input name="event_meta[noiva_filho_de_1]" value="{{ $meta['noiva_filho_de_1'] ?? '' }}" class="border p-2 rounded w-full" placeholder="Pai">
                    </div>
                    <div>
                        <label class="block text-sm">Filho de</label>
                        <input name="event_meta[noiva_filho_de_2]" value="{{ $meta['noiva_filho_de_2'] ?? '' }}" class="border p-2 rounded w-full" placeholder="Mãe">
                    </div>
                    <div class="md:col-span-2">
                        <label class="block text-sm">Morada</label>
                        <input name="event_meta[noiva_morada]" value="{{ $meta['noiva_morada'] ?? '' }}" class="border p-2 rounded w-full">
                    </div>
                    <div class="md:col-span-2">
                        <label class="block text-sm">Coordenadas</label>
                        <input name="event_meta[noiva_coordenadas]" value="{{ $meta['noiva_coordenadas'] ?? '' }}" class="border p-2 rounded w-full" placeholder="Ex: 41.123,-8.456">
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
        </div>
    </div>

    <div id="event-meta-batizado" class="hidden event-card space-y-4">
        <div class="font-semibold">Dados do Batizado</div>
        <div class="grid md:grid-cols-2 gap-3">
            <input name="event_meta[bebe_nome]" value="{{ $meta['bebe_nome'] ?? '' }}" placeholder="Nome do bebé" class="border p-2 rounded w-full md:col-span-2">
            <input name="event_meta[pai_nome]" value="{{ $meta['pai_nome'] ?? '' }}" placeholder="Nome do pai" class="border p-2 rounded w-full">
            <input name="event_meta[mae_nome]" value="{{ $meta['mae_nome'] ?? '' }}" placeholder="Nome da mãe" class="border p-2 rounded w-full">
            <input name="event_meta[padrinho_nome]" value="{{ $meta['padrinho_nome'] ?? '' }}" placeholder="Nome do padrinho" class="border p-2 rounded w-full">
            <input name="event_meta[madrinha_nome]" value="{{ $meta['madrinha_nome'] ?? '' }}" placeholder="Nome da madrinha" class="border p-2 rounded w-full">
            <input name="event_meta[contacto_pai]" value="{{ $meta['contacto_pai'] ?? ($meta['contacto_pais'] ?? '') }}" placeholder="Contacto do pai" class="border p-2 rounded w-full">
            <input name="event_meta[contacto_mae]" value="{{ $meta['contacto_mae'] ?? '' }}" placeholder="Contacto da mãe" class="border p-2 rounded w-full">
            <input name="event_meta[morada]" value="{{ $meta['morada'] ?? '' }}" placeholder="Morada" class="border p-2 rounded w-full md:col-span-2">
        </div>
    </div>

    @php
        $igrejaRaw = $meta['igreja_local'] ?? '';
        $igrejaNome = $meta['igreja_localidade'] ?? '';
        $igrejaTipo = '';
        $igrejaLower = function_exists('mb_strtolower') ? mb_strtolower($igrejaRaw) : strtolower($igrejaRaw);
        if (! empty($igrejaRaw)) {
            if (str_contains($igrejaLower, 'civil')) {
                $igrejaTipo = 'Civil';
            } elseif (str_contains($igrejaLower, 'igreja')) {
                $igrejaTipo = 'Igreja';
            } elseif ($igrejaNome === '') {
                $igrejaNome = $igrejaRaw;
            }
        }

        $quintaRaw = $meta['quinta_local'] ?? '';
        $refeicaoNome = $meta['almoco_localidade'] ?? '';
        $refeicaoTipo = '';
        $quintaLower = function_exists('mb_strtolower') ? mb_strtolower($quintaRaw) : strtolower($quintaRaw);
        if (! empty($quintaRaw)) {
            if (str_contains($quintaLower, 'jantar')) {
                $refeicaoTipo = 'Jantar';
            } elseif (str_contains($quintaLower, 'almoço') || str_contains($quintaLower, 'almoco')) {
                $refeicaoTipo = 'Almoço';
            } elseif ($refeicaoNome === '') {
                $refeicaoNome = $quintaRaw;
            }
        }
    @endphp

    <div class="event-card space-y-3">
        <div class="font-semibold">Missa e locais</div>
        <div class="grid md:grid-cols-2 gap-3">
            <div>
                <label class="block text-sm">Missa</label>
                <input type="time" name="event_meta[missa_hora]" value="{{ $meta['missa_hora'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Cerimónia</label>
                <select name="event_meta[igreja_local]" class="border p-2 rounded w-full">
                    <option value="">Selecione</option>
                    <option value="Igreja" {{ $igrejaTipo === 'Igreja' ? 'selected' : '' }}>Igreja</option>
                    <option value="Civil" {{ $igrejaTipo === 'Civil' ? 'selected' : '' }}>Civil</option>
                </select>
            </div>
            <div>
                <label class="block text-sm">Nome da igreja/local</label>
                <input name="event_meta[igreja_localidade]" value="{{ $igrejaNome }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Refeição</label>
                <select name="event_meta[quinta_local]" class="border p-2 rounded w-full">
                    <option value="">Selecione</option>
                    <option value="Almoço" {{ $refeicaoTipo === 'Almoço' ? 'selected' : '' }}>Almoço</option>
                    <option value="Jantar" {{ $refeicaoTipo === 'Jantar' ? 'selected' : '' }}>Jantar</option>
                </select>
            </div>
            <div>
                <label class="block text-sm">Nome da quinta/restaurante</label>
                <input name="event_meta[almoco_localidade]" value="{{ $refeicaoNome }}" class="border p-2 rounded w-full">
            </div>
        </div>
    </div>

    <div class="event-card space-y-3">
        <div class="font-semibold">Entrega e equipa</div>
        <div class="grid md:grid-cols-4 gap-3">
            <div>
                <label class="block text-sm">Nº convidados</label>
                <input type="number" min="0" name="event_meta[numero_convidados]" value="{{ $meta['numero_convidados'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Data de entrega</label>
                <input type="date" name="event_meta[data_entrega]" value="{{ $meta['data_entrega'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">Equipa de trabalho</label>
                <input name="event_meta[equipa_de_trabalho]" value="{{ $meta['equipa_de_trabalho'] ?? '' }}" class="border p-2 rounded w-full" placeholder="Ex: LM não trocar">
                <div id="team-preview" class="text-xs text-gray-600 mt-1"></div>
            </div>
            <div>
                <label class="block text-sm">Nº de profissionais</label>
                <input id="team-count" type="number" min="0" name="event_meta[servico_num_profissionais]" value="{{ $meta['servico_num_profissionais'] ?? '' }}" class="border p-2 rounded w-full bg-gray-100" readonly>
            </div>
        </div>
    </div>

    <div class="event-card space-y-4">
        <div class="font-semibold">Informações do serviço</div>
        <div class="grid md:grid-cols-3 gap-2">
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_save_the_date]" value="0">
                <input type="checkbox" name="event_meta[servico_save_the_date]" value="1" {{ !empty($meta['servico_save_the_date']) ? 'checked' : '' }}>
                <span>Save the date</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_fotos_love_story]" value="0">
                <input type="checkbox" name="event_meta[servico_fotos_love_story]" value="1" {{ !empty($meta['servico_fotos_love_story']) ? 'checked' : '' }}>
                <span>Fotos love story</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_video_love_story]" value="0">
                <input type="checkbox" name="event_meta[servico_video_love_story]" value="1" {{ !empty($meta['servico_video_love_story']) ? 'checked' : '' }}>
                <span>Vídeo love story</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_projectar_love_story]" value="0">
                <input type="checkbox" name="event_meta[servico_projectar_love_story]" value="1" {{ !empty($meta['servico_projectar_love_story']) ? 'checked' : '' }}>
                <span>Projectar love story</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_combo_beleza_love_story]" value="0">
                <input type="checkbox" name="event_meta[servico_combo_beleza_love_story]" value="1" {{ !empty($meta['servico_combo_beleza_love_story']) ? 'checked' : '' }}>
                <span>Combo beleza love story</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_album_digital_30_5]" value="0">
                <input type="checkbox" name="event_meta[servico_album_digital_30_5]" value="1" {{ !empty($meta['servico_album_digital_30_5']) ? 'checked' : '' }}>
                <span>Álbum digital 30+5</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_combo_beleza_ttd]" value="0">
                <input type="checkbox" name="event_meta[servico_combo_beleza_ttd]" value="1" {{ !empty($meta['servico_combo_beleza_ttd']) ? 'checked' : '' }}>
                <span>Combo beleza ttd</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_album_digital]" value="0">
                <input type="checkbox" name="event_meta[servico_album_digital]" value="1" {{ !empty($meta['servico_album_digital']) ? 'checked' : '' }}>
                <span>Álbum digital</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_album_convidados]" value="0">
                <input type="checkbox" name="event_meta[servico_album_convidados]" value="1" {{ !empty($meta['servico_album_convidados']) ? 'checked' : '' }}>
                <span>Álbum de convidados</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_albuns_40_20]" value="0">
                <input type="checkbox" name="event_meta[servico_albuns_40_20]" value="1" {{ !empty($meta['servico_albuns_40_20']) ? 'checked' : '' }}>
                <span>Álbuns 40x20</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_same_day_edit]" value="0">
                <input type="checkbox" name="event_meta[servico_same_day_edit]" value="1" {{ !empty($meta['servico_same_day_edit']) ? 'checked' : '' }}>
                <span>Same day edit</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_projectar_same_day_edit]" value="0">
                <input type="checkbox" name="event_meta[servico_projectar_same_day_edit]" value="1" {{ !empty($meta['servico_projectar_same_day_edit']) ? 'checked' : '' }}>
                <span>Projectar same day edit</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_galeria_digital_convidados]" value="0">
                <input type="checkbox" name="event_meta[servico_galeria_digital_convidados]" value="1" {{ !empty($meta['servico_galeria_digital_convidados']) ? 'checked' : '' }}>
                <span>Galeria digital c/fotos convidados</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_foto_lembranca_qr]" value="0">
                <input type="checkbox" name="event_meta[servico_foto_lembranca_qr]" value="1" {{ !empty($meta['servico_foto_lembranca_qr']) ? 'checked' : '' }}>
                <span>Foto lembrança QR code</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_impressao_100_11x22_7]" value="0">
                <input type="checkbox" name="event_meta[servico_impressao_100_11x22_7]" value="1" {{ !empty($meta['servico_impressao_100_11x22_7']) ? 'checked' : '' }}>
                <span>Impressão 100 fotos 11x22,7</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_video_depois_do_sim]" value="0">
                <input type="checkbox" name="event_meta[servico_video_depois_do_sim]" value="1" {{ !empty($meta['servico_video_depois_do_sim']) ? 'checked' : '' }}>
                <span>Vídeo depois do SIM</span>
            </label>
            <label class="flex items-center gap-2 text-sm">
                <input type="hidden" name="event_meta[servico_drone]" value="0">
                <input type="checkbox" name="event_meta[servico_drone]" value="1" {{ !empty($meta['servico_drone']) ? 'checked' : '' }}>
                <span>Drone</span>
            </label>
        </div>
            <div class="grid md:grid-cols-2 gap-3">
            <div>
                <label class="block text-sm">Tela</label>
                <input name="event_meta[servico_tela]" value="{{ $meta['servico_tela'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
            <div>
                <label class="block text-sm">USB</label>
                <input name="event_meta[servico_usb]" value="{{ $meta['servico_usb'] ?? '' }}" class="border p-2 rounded w-full">
            </div>
        </div>
        <div>
            <label class="block text-sm">Condições mínimas de trabalho</label>
            <textarea name="event_meta[servico_condicoes_minimas]" class="border p-2 rounded w-full" rows="2">{{ $meta['servico_condicoes_minimas'] ?? '' }}</textarea>
        </div>
        <div>
            <label class="block text-sm">Músicas</label>
            <textarea name="event_meta[servico_musicas]" class="border p-2 rounded w-full" rows="2">{{ $meta['servico_musicas'] ?? '' }}</textarea>
        </div>
        <div>
            <label class="block text-sm">Extras</label>
            <textarea name="event_meta[servico_extras]" class="border p-2 rounded w-full" rows="2">{{ $meta['servico_extras'] ?? '' }}</textarea>
        </div>
    </div>

    <div id="event-couple-photo" class="event-card space-y-3">
        <div class="font-semibold">Foto dos noivos</div>
        <div>
            <label class="block text-sm">Tirar na hora (se tiver câmara)</label>
            <input type="file" name="event_meta[foto_noivos]" accept="image/*" capture="environment" class="border p-2 rounded w-full bg-white">
        </div>
    </div>

    <div class="event-card space-y-3">
        <div class="font-semibold">Observações</div>
        <div>
            <label class="block text-sm">OBS</label>
            <textarea name="notes" class="border p-2 rounded w-full" rows="3">{{ old('notes') }}</textarea>
        </div>
    </div>

    <button class="bg-black text-white px-3 py-2 rounded">Guardar</button>
</form>
<script>
    document.addEventListener('DOMContentLoaded', () => {
        const input = document.querySelector('input[name=\"event_meta[equipa_de_trabalho]\"]');
        const preview = document.getElementById('team-preview');
        const countInput = document.getElementById('team-count');
        if (!input || !preview) return;

        const teamUsers = @json($teamUsersPayload);

        const userMap = new Map();
        teamUsers.forEach(u => {
            if (!u.username) return;
            userMap.set(u.username.toLowerCase(), u);
        });

        const splitParts = (raw) => {
            let text = (raw || '').replace(/[\\r\\n]/g, ' ');
            text = text.replace(/\\s*[+,&;\\/]+\\s*/g, ',');
            text = text.replace(/\\s+e\\s+/gi, ',');
            text = text.replace(/\\s+and\\s+/gi, ',');
            return text.split(',').map(s => s.trim()).filter(Boolean);
        };

        const stripDiacritics = (value) => {
            if (!value) return '';
            if (typeof value.normalize === 'function') {
                return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
            }
            return value;
        };

        const escapeRegex = (value) => String(value).replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');

        const normalizeRaw = (raw) => {
            let text = stripDiacritics((raw || '').toLowerCase());
            text = text.replace(/[^a-z0-9]+/g, ' ').trim();
            return ` ${text} `;
        };

        const normalizeToken = (raw) => {
            let text = raw.replace(/\\(.*?\\)/g, '').trim();
            text = text.replace(/['\"]/g, '');
            text = stripDiacritics(text);
            text = text.replace(/[^A-Za-z0-9]+/g, ' ').trim();
            if (!text) return '';
            return text.split(' ')[0].toLowerCase();
        };

        const resolveUsers = (raw) => {
            const tokens = splitParts(raw).map(normalizeToken).filter(Boolean);
            const matched = new Map();
            const unknown = [];
            const rawNormalized = normalizeRaw(raw);
            const matchedByRaw = new Set();

            userMap.forEach((user, username) => {
                const pattern = new RegExp(`(^|[^a-z0-9])${escapeRegex(username)}([^a-z0-9]|$)`);
                if (pattern.test(rawNormalized)) {
                    matched.set(user.id, user);
                    matchedByRaw.add(username);
                }
            });

            tokens.forEach(token => {
                if (userMap.has(token)) {
                    const user = userMap.get(token);
                    matched.set(user.id, user);
                    return;
                }
                if (token.length > 2) {
                    const prefix = token.slice(0, 2);
                    if (userMap.has(prefix)) {
                        const user = userMap.get(prefix);
                        matched.set(user.id, user);
                        return;
                    }
                }
                if (!matchedByRaw.has(token)) {
                    unknown.push(token);
                }
            });

            return {
                matched: Array.from(matched.values()),
                unknown: Array.from(new Set(unknown)),
            };
        };

        const render = () => {
            const { matched, unknown } = resolveUsers(input.value || '');
            const total = matched.length + unknown.length;
            if (countInput) {
                countInput.value = String(total);
            }
            if (!matched.length && !unknown.length) {
                preview.innerHTML = '';
                return;
            }
            const chips = matched.map(u => {
                const label = (u.username || '').toUpperCase();
                const title = u.name ? ` title=\"${u.name}\"` : '';
                return `<span class=\"inline-flex items-center px-2 py-1 rounded bg-gray-100 text-gray-700 mr-1 mb-1\"${title}>${label}</span>`;
            }).join('');
            const unknownText = unknown.length
                ? `<div class=\"text-xs text-gray-400 mt-1\">Sem correspondência: ${unknown.join(', ')}</div>`
                : '';
            preview.innerHTML = `<div class=\"flex flex-wrap\">${chips}</div>${unknownText}`;
        };

        input.addEventListener('input', render);
        render();
    });
</script>
<script>
    document.addEventListener('DOMContentLoaded', () => {
        const form = document.getElementById('event-create-form');
        if (!form) return;
        const statusEl = document.getElementById('autosave-status');
        const updateTemplate = form.dataset.updateUrlTemplate || '';
        const token = form.querySelector('input[name=\"_token\"]')?.value || '';
        let autosaveTimer = null;
        let dirty = false;
        let saving = false;
        let eventId = null;
        let userActive = false;
        if (statusEl) statusEl.textContent = 'Autosave ativo';
        if (statusEl) statusEl.textContent = 'Autosave ativo';

        const activate = () => { userActive = true; };
        form.addEventListener('pointerdown', activate, { once: true, capture: true });
        form.addEventListener('keydown', activate, { once: true, capture: true });

        const markDirty = (event) => {
            if (event && event.isTrusted === false) return;
            if (!userActive) userActive = true;
            dirty = true;
            if (statusEl) statusEl.textContent = 'Alterações detetadas';
            scheduleAutosave();
        };

        const scheduleAutosave = () => {
            clearTimeout(autosaveTimer);
            autosaveTimer = setTimeout(runAutosave, 800);
        };

        const runAutosave = async () => {
            if (!dirty || saving) return;
            saving = true;
            if (statusEl) statusEl.textContent = 'A guardar...';
            const fd = new FormData(form);
            fd.set('autosave', '1');
            fd.set('enforce_required', '0');
            if (!fd.get('event_date')) {
                const today = new Date();
                const y = today.getFullYear().toString().padStart(4, '0');
                const m = (today.getMonth() + 1).toString().padStart(2, '0');
                const d = today.getDate().toString().padStart(2, '0');
                fd.set('event_date', `${y}-${m}-${d}`);
            }
            if (eventId) {
                fd.set('_method', 'PUT');
            }
            if (token && !fd.get('_token')) {
                fd.set('_token', token);
            }
            const url = eventId && updateTemplate
                ? updateTemplate.replace('__EVENT__', String(eventId))
                : form.getAttribute('action');
            try {
                const res = await fetch(url, {
                    method: 'POST',
                    credentials: 'same-origin',
                    headers: {
                        'X-Requested-With': 'XMLHttpRequest',
                        'Accept': 'application/json',
                        'X-CSRF-TOKEN': token,
                    },
                    body: fd,
                });
                if (res.ok) {
                    const data = await res.json().catch(() => ({}));
                    if (!eventId && data.event_id) {
                        eventId = data.event_id;
                        if (updateTemplate) {
                            form.setAttribute('action', updateTemplate.replace('__EVENT__', String(eventId)));
                        }
                        if (!form.querySelector('input[name=\"_method\"]')) {
                            const method = document.createElement('input');
                            method.type = 'hidden';
                            method.name = '_method';
                            method.value = 'PUT';
                            form.appendChild(method);
                        }
                    }
                    dirty = false;
                    if (statusEl) statusEl.textContent = 'Rascunho guardado';
                } else {
                    let message = 'Erro ao guardar';
                    try {
                        const data = await res.json();
                        if (data && data.errors) {
                            const first = Object.values(data.errors)[0];
                            if (Array.isArray(first) && first.length) {
                                message = `Erro ao guardar: ${first[0]}`;
                            }
                        } else if (data && data.message) {
                            message = `Erro ao guardar: ${data.message}`;
                        }
                    } catch (e) {
                        // ignore
                    }
                    if (res.status) {
                        message = `${message} (${res.status})`;
                    }
                    if (statusEl) statusEl.textContent = message;
                }
            } catch (e) {
                if (statusEl) statusEl.textContent = 'Erro ao guardar';
            } finally {
                saving = false;
            }
        };

        form.addEventListener('input', markDirty);
        form.addEventListener('change', markDirty);
        form.querySelectorAll('input, select, textarea').forEach(field => {
            field.addEventListener('input', markDirty);
            field.addEventListener('change', markDirty);
        });
    });
</script>
<script>
    const typeSelect = document.getElementById('event-type');
    const casamento = document.getElementById('event-meta-casamento');
    const batizado = document.getElementById('event-meta-batizado');
    const couplePhoto = document.getElementById('event-couple-photo');
    const dateInput = document.getElementById('event-date');
    const clienteNoivo = document.getElementById('cliente-noivo-num');
    const clienteNoiva = document.getElementById('cliente-noiva-num');
    const clienteBatizado = document.getElementById('cliente-batizado-num');

    function generateClientNumber(suffix) {
        const date = dateInput && dateInput.value ? dateInput.value.replace(/-/g, '') : new Date().toISOString().slice(0, 10).replace(/-/g, '');
        const rand = Math.floor(100 + Math.random() * 900);
        return `${date}${suffix}${rand}`;
    }

    function ensureClientNumbers() {
        const v = typeSelect.value;
        if (v === 'casamento') {
            if (clienteNoivo && !clienteNoivo.value) {
                clienteNoivo.value = generateClientNumber('1');
            }
            if (clienteNoiva && !clienteNoiva.value) {
                clienteNoiva.value = generateClientNumber('2');
            }
            if (clienteNoivo && clienteNoiva && clienteNoivo.value === clienteNoiva.value) {
                clienteNoiva.value = generateClientNumber('2');
            }
        }
        if (v === 'batizado') {
            if (clienteBatizado && !clienteBatizado.value) {
                clienteBatizado.value = generateClientNumber('B');
            }
        }
    }

    function toggleMeta() {
        const v = typeSelect.value;
        casamento.classList.toggle('hidden', v !== 'casamento');
        batizado.classList.toggle('hidden', v !== 'batizado');
        if (couplePhoto) {
            couplePhoto.classList.toggle('hidden', v === 'batizado');
        }
        ensureClientNumbers();
    }

    typeSelect.addEventListener('change', toggleMeta);
    if (dateInput) {
        dateInput.addEventListener('change', ensureClientNumbers);
    }
    toggleMeta();
</script>
@endsection
