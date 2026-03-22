@extends('layouts.app')
@section('content')
<div class="flex justify-between mb-4">
    <h1 class="text-xl font-semibold">Eventos</h1>
    @if(auth()->user()->hasPermission('events.write'))
        <a href="{{ route('events.create') }}" class="bg-black text-white px-3 py-2 rounded">Novo</a>
    @endif
</div>

<div class="flex gap-2 mb-4">
    <a href="{{ route('events.index', ['type' => 'casamento']) }}" class="px-3 py-2 rounded border {{ ($type ?? null) === 'casamento' ? 'bg-black text-white border-black' : 'bg-white' }}">CASAMENTO</a>
    <a href="{{ route('events.index', ['type' => 'batizado']) }}" class="px-3 py-2 rounded border {{ ($type ?? null) === 'batizado' ? 'bg-black text-white border-black' : 'bg-white' }}">BATIZADO</a>
</div>

@if(!in_array($type ?? '', ['casamento', 'batizado'], true))
    <div class="text-sm text-gray-500">Escolhe o tipo de serviço para abrir o formulário.</div>
@else
    @php
        $event = $currentEvent ?? null;
        $meta = $meta ?? [];
        $metaRequest = request('event_meta', []);
        $metaValue = function ($key) use ($event, $meta, $metaRequest) {
            if ($event) {
                return $meta[$key] ?? '';
            }
            return $metaRequest[$key] ?? '';
        };
        $baseValue = function ($key, $default = '') use ($event) {
            if ($event) {
                if ($key === 'event_date') {
                    return optional($event->event_date)->format('Y-m-d');
                }
                if ($key === 'event_time' && is_string($event->event_time)) {
                    return strlen($event->event_time) >= 5 ? substr($event->event_time, 0, 5) : $event->event_time;
                }
                if ($key === 'legacy_report_number') {
                    return $event->legacy_report_number ?? $default;
                }
                return data_get($event, $key, $default);
            }
            return request($key, $default);
        };
    @endphp

    <div class="flex items-center gap-3 mb-2">
        <div id="autosave-status" class="text-xs text-gray-500"></div>
        @if($event && $event->status === 'rascunho')
            <div class="text-xs px-2 py-1 rounded bg-amber-100 text-amber-800">Rascunho</div>
        @endif
    </div>
    <div class="flex items-center gap-2 mb-4">
        <button id="search-btn" class="bg-black text-white px-3 py-2 rounded" type="submit" form="event-search-form" formaction="{{ route('events.index') }}" formmethod="get">Procurar</button>
        @if($event && auth()->user()->hasPermission('uploads.manage'))
            <a href="{{ route('uploads.index', $event) }}" class="bg-white px-3 py-2 rounded border">Upload</a>
        @endif
        @if($event)
            <button class="bg-emerald-700 text-white px-3 py-2 rounded" type="submit" form="event-search-form" formaction="{{ route('events.update', $event) }}" formmethod="post">Guardar</button>
            @if(($type ?? null) === 'casamento')
                <button class="bg-white px-3 py-2 rounded border" type="submit" form="event-search-form" formaction="{{ route('events.update', $event) }}" formmethod="post" formtarget="_blank" name="print_pdf" value="1">IMPRIMIR</button>
            @endif
        @endif
        @if($firstUrl)
            <a href="{{ $firstUrl }}" class="px-3 py-2 rounded border">&laquo;&laquo;</a>
        @else
            <span class="px-3 py-2 rounded border text-gray-300 cursor-not-allowed">&laquo;&laquo;</span>
        @endif
        @if($prevUrl)
            <a href="{{ $prevUrl }}" class="px-3 py-2 rounded border">&lsaquo;</a>
        @else
            <span class="px-3 py-2 rounded border text-gray-300 cursor-not-allowed">&lsaquo;</span>
        @endif
        @if($nextUrl)
            <a href="{{ $nextUrl }}" class="px-3 py-2 rounded border">&rsaquo;</a>
        @else
            <span class="px-3 py-2 rounded border text-gray-300 cursor-not-allowed">&rsaquo;</span>
        @endif
        @if($lastUrl)
            <a href="{{ $lastUrl }}" class="px-3 py-2 rounded border">&raquo;&raquo;</a>
        @else
            <span class="px-3 py-2 rounded border text-gray-300 cursor-not-allowed">&raquo;&raquo;</span>
        @endif
        <div class="text-xs text-gray-500 ml-2">
            @if($totalResults)
                Resultado {{ ($currentIndex ?? 0) + 1 }} de {{ $totalResults }}
            @else
                Sem resultados
            @endif
        </div>
    </div>

    <form id="event-search-form" method="get" action="{{ $event ? route('events.update', $event) : route('events.index') }}" class="bg-white p-4 rounded shadow space-y-6">
        <input type="hidden" name="type" value="{{ $type }}">
        <input type="hidden" name="search_mode" value="{{ $searchMode ? 1 : 0 }}">
        @if($event)
            @csrf
            @method('PUT')
            <input type="hidden" name="return_url" value="{{ url()->full() }}">
        @endif

        <div class="border rounded p-4 space-y-3">
            <div class="font-semibold">Dados base</div>
            <div class="grid md:grid-cols-3 gap-3">
                <div>
                    <label class="block text-sm">Tipo de serviço</label>
                    <input value="{{ strtoupper($type) }}" class="border p-2 rounded w-full bg-gray-100" readonly>
                </div>
                <div>
                    <label class="block text-sm">Data (do serviço)</label>
                    <input type="date" name="event_date" value="{{ $baseValue('event_date') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Nº reportagem</label>
                    <input name="legacy_report_number" value="{{ $baseValue('legacy_report_number') }}" class="border p-2 rounded w-full">
                </div>
            </div>
            <div class="grid md:grid-cols-4 gap-3">
                <div>
                    <label class="block text-sm">Hora (do serviço)</label>
                    <input type="time" name="event_time" value="{{ $baseValue('event_time') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Preço base</label>
                    <input name="base_price" type="number" step="0.01" value="{{ $baseValue('base_price') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Preço por foto</label>
                    <input name="price_per_photo" type="number" step="0.01" value="{{ $baseValue('price_per_photo') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Código do evento (PIN)</label>
                    <input name="access_pin" value="{{ $baseValue('access_pin') }}" class="border p-2 rounded w-full {{ $searchMode ? '' : 'bg-gray-100' }}" {{ $searchMode ? '' : 'readonly' }}>
                </div>
            </div>
            <div class="grid md:grid-cols-3 gap-3"></div>
        </div>

        @if($type === 'casamento')
            <div class="border rounded p-4 space-y-4">
                <div class="font-semibold">Dados do Casamento</div>
                <div class="grid md:grid-cols-2 gap-4">
                    <div class="border rounded p-3 space-y-3">
                        <div class="font-semibold text-sm">Noivo</div>
                        <div class="grid md:grid-cols-2 gap-3">
                            <div class="md:col-span-2">
                                <label class="block text-sm">Nome do noivo</label>
                                <input name="event_meta[noivo_nome]" value="{{ $metaValue('noivo_nome') }}" class="border p-2 rounded w-full">
                            </div>
                            <div>
                                <label class="block text-sm">Instagram</label>
                                <input name="event_meta[noivo_instagram]" value="{{ $metaValue('noivo_instagram') }}" class="border p-2 rounded w-full">
                            </div>
                            <div>
                                <label class="block text-sm">Telemóvel</label>
                                <input name="event_meta[noivo_contacto]" value="{{ $metaValue('noivo_contacto') }}" class="border p-2 rounded w-full">
                            </div>
                            <div>
                                <label class="block text-sm">Profissão</label>
                                <input name="event_meta[noivo_profissao]" value="{{ $metaValue('noivo_profissao') }}" class="border p-2 rounded w-full">
                            </div>
                            <div>
                                <label class="block text-sm">Filho de</label>
                                <input name="event_meta[noivo_filho_de_1]" value="{{ $metaValue('noivo_filho_de_1') }}" class="border p-2 rounded w-full" placeholder="Pai">
                            </div>
                            <div>
                                <label class="block text-sm">Filho de</label>
                                <input name="event_meta[noivo_filho_de_2]" value="{{ $metaValue('noivo_filho_de_2') }}" class="border p-2 rounded w-full" placeholder="Mãe">
                            </div>
                            <div class="md:col-span-2">
                                <label class="block text-sm">Morada</label>
                                <input name="event_meta[noivo_morada]" value="{{ $metaValue('noivo_morada') }}" class="border p-2 rounded w-full">
                            </div>
                            <div class="md:col-span-2">
                                <label class="block text-sm">Coordenadas</label>
                                <input name="event_meta[noivo_coordenadas]" value="{{ $metaValue('noivo_coordenadas') }}" class="border p-2 rounded w-full" placeholder="Ex: 41.123,-8.456">
                            </div>
                            <div>
                                <label class="block text-sm">Casa do noivo: hora de chegada</label>
                                <input type="time" name="event_meta[casa_noivo_chegada]" value="{{ $metaValue('casa_noivo_chegada') }}" class="border p-2 rounded w-full">
                            </div>
                            <div>
                                <label class="block text-sm">Casa do noivo: hora de saída</label>
                                <input type="time" name="event_meta[casa_noivo_saida]" value="{{ $metaValue('casa_noivo_saida') }}" class="border p-2 rounded w-full">
                            </div>
                        </div>
                    </div>
                    <div class="border rounded p-3 space-y-3">
                        <div class="font-semibold text-sm">Noiva</div>
                        <div class="grid md:grid-cols-2 gap-3">
                            <div class="md:col-span-2">
                                <label class="block text-sm">Nome da noiva</label>
                                <input name="event_meta[noiva_nome]" value="{{ $metaValue('noiva_nome') }}" class="border p-2 rounded w-full">
                            </div>
                            <div>
                                <label class="block text-sm">Instagram</label>
                                <input name="event_meta[noiva_instagram]" value="{{ $metaValue('noiva_instagram') }}" class="border p-2 rounded w-full">
                            </div>
                            <div>
                                <label class="block text-sm">Telemóvel</label>
                                <input name="event_meta[noiva_contacto]" value="{{ $metaValue('noiva_contacto') }}" class="border p-2 rounded w-full">
                            </div>
                            <div>
                                <label class="block text-sm">Profissão</label>
                                <input name="event_meta[noiva_profissao]" value="{{ $metaValue('noiva_profissao') }}" class="border p-2 rounded w-full">
                            </div>
                            <div>
                                <label class="block text-sm">Filho de</label>
                                <input name="event_meta[noiva_filho_de_1]" value="{{ $metaValue('noiva_filho_de_1') }}" class="border p-2 rounded w-full" placeholder="Pai">
                            </div>
                            <div>
                                <label class="block text-sm">Filho de</label>
                                <input name="event_meta[noiva_filho_de_2]" value="{{ $metaValue('noiva_filho_de_2') }}" class="border p-2 rounded w-full" placeholder="Mãe">
                            </div>
                            <div class="md:col-span-2">
                                <label class="block text-sm">Morada</label>
                                <input name="event_meta[noiva_morada]" value="{{ $metaValue('noiva_morada') }}" class="border p-2 rounded w-full">
                            </div>
                            <div class="md:col-span-2">
                                <label class="block text-sm">Coordenadas</label>
                                <input name="event_meta[noiva_coordenadas]" value="{{ $metaValue('noiva_coordenadas') }}" class="border p-2 rounded w-full" placeholder="Ex: 41.123,-8.456">
                            </div>
                            <div>
                                <label class="block text-sm">Casa da noiva: hora de chegada</label>
                                <input type="time" name="event_meta[casa_noiva_chegada]" value="{{ $metaValue('casa_noiva_chegada') }}" class="border p-2 rounded w-full">
                            </div>
                            <div>
                                <label class="block text-sm">Casa da noiva: hora de saída</label>
                                <input type="time" name="event_meta[casa_noiva_saida]" value="{{ $metaValue('casa_noiva_saida') }}" class="border p-2 rounded w-full">
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        @endif

        @if($type === 'batizado')
            <div class="border rounded p-4 space-y-4">
                <div class="font-semibold">Dados do Batizado</div>
                <div class="grid md:grid-cols-2 gap-3">
                    <input name="event_meta[bebe_nome]" value="{{ $metaValue('bebe_nome') }}" placeholder="Nome do bebé" class="border p-2 rounded w-full">
                    <input name="event_meta[pai_nome]" value="{{ $metaValue('pai_nome') }}" placeholder="Nome do pai" class="border p-2 rounded w-full">
                    <input name="event_meta[mae_nome]" value="{{ $metaValue('mae_nome') }}" placeholder="Nome da mãe" class="border p-2 rounded w-full">
                    <input name="event_meta[padrinho_nome]" value="{{ $metaValue('padrinho_nome') }}" placeholder="Nome do padrinho" class="border p-2 rounded w-full">
                    <input name="event_meta[madrinha_nome]" value="{{ $metaValue('madrinha_nome') }}" placeholder="Nome da madrinha" class="border p-2 rounded w-full">
                    <input name="event_meta[contacto_pais]" value="{{ $metaValue('contacto_pais') }}" placeholder="Contacto dos pais" class="border p-2 rounded w-full">
                    <input name="event_meta[morada]" value="{{ $metaValue('morada') }}" placeholder="Morada" class="border p-2 rounded w-full md:col-span-2">
                    <input name="event_meta[instagram_pais]" value="{{ $metaValue('instagram_pais') }}" placeholder="Instagram dos pais" class="border p-2 rounded w-full md:col-span-2">
                </div>
            </div>
        @endif

        <div class="border rounded p-4 space-y-3">
            <div class="font-semibold">Missa e locais</div>
            <div class="grid md:grid-cols-2 gap-3">
                <div>
                    <label class="block text-sm">Missa</label>
                    <input type="time" name="event_meta[missa_hora]" value="{{ $metaValue('missa_hora') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Local da igreja</label>
                    <input name="event_meta[igreja_local]" value="{{ $metaValue('igreja_local') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Localidade (igreja)</label>
                    <input name="event_meta[igreja_localidade]" value="{{ $metaValue('igreja_localidade') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Local do almoço</label>
                    <input name="event_meta[quinta_local]" value="{{ $metaValue('quinta_local') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Localidade do almoço</label>
                    <input name="event_meta[almoco_localidade]" value="{{ $metaValue('almoco_localidade') }}" class="border p-2 rounded w-full">
                </div>
            </div>
        </div>

        <div class="border rounded p-4 space-y-3">
            <div class="font-semibold">Entrega e equipa</div>
            <div class="grid md:grid-cols-3 gap-3">
                <div>
                    <label class="block text-sm">Nº convidados</label>
                    <input type="number" min="0" name="event_meta[numero_convidados]" value="{{ $metaValue('numero_convidados') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Data de entrega</label>
                    <input type="date" name="event_meta[data_entrega]" value="{{ $metaValue('data_entrega') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Equipa de trabalho</label>
                    <input name="event_meta[equipa_de_trabalho]" value="{{ $metaValue('equipa_de_trabalho') }}" class="border p-2 rounded w-full" placeholder="Ex: LM não trocar">
                    <div id="team-preview" class="text-xs text-gray-600 mt-1"></div>
                </div>
            </div>
        </div>

        <div class="border rounded p-4 space-y-4">
            <div class="font-semibold">Informações do serviço</div>
            <div class="grid md:grid-cols-3 gap-2">
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_save_the_date]" value="1" {{ $metaValue('servico_save_the_date') ? 'checked' : '' }}> <span>Save the date</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_fotos_love_story]" value="1" {{ $metaValue('servico_fotos_love_story') ? 'checked' : '' }}> <span>Fotos love story</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_video_love_story]" value="1" {{ $metaValue('servico_video_love_story') ? 'checked' : '' }}> <span>Vídeo love story</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_projectar_love_story]" value="1" {{ $metaValue('servico_projectar_love_story') ? 'checked' : '' }}> <span>Projectar love story</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_combo_beleza_love_story]" value="1" {{ $metaValue('servico_combo_beleza_love_story') ? 'checked' : '' }}> <span>Combo beleza love story</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_album_digital_30_5]" value="1" {{ $metaValue('servico_album_digital_30_5') ? 'checked' : '' }}> <span>Álbum digital 30+5</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_combo_beleza_ttd]" value="1" {{ $metaValue('servico_combo_beleza_ttd') ? 'checked' : '' }}> <span>Combo beleza ttd</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_album_digital]" value="1" {{ $metaValue('servico_album_digital') ? 'checked' : '' }}> <span>Álbum digital</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_album_convidados]" value="1" {{ $metaValue('servico_album_convidados') ? 'checked' : '' }}> <span>Álbum de convidados</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_albuns_40_20]" value="1" {{ $metaValue('servico_albuns_40_20') ? 'checked' : '' }}> <span>Álbuns 40x20</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_same_day_edit]" value="1" {{ $metaValue('servico_same_day_edit') ? 'checked' : '' }}> <span>Same day edit</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_projectar_same_day_edit]" value="1" {{ $metaValue('servico_projectar_same_day_edit') ? 'checked' : '' }}> <span>Projectar same day edit</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_galeria_digital_convidados]" value="1" {{ $metaValue('servico_galeria_digital_convidados') ? 'checked' : '' }}> <span>Galeria digital c/fotos convidados</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_foto_lembranca_qr]" value="1" {{ $metaValue('servico_foto_lembranca_qr') ? 'checked' : '' }}> <span>Foto lembrança QR code</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_impressao_100_11x22_7]" value="1" {{ $metaValue('servico_impressao_100_11x22_7') ? 'checked' : '' }}> <span>Impressão 100 fotos 11x22,7</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_video_depois_do_sim]" value="1" {{ $metaValue('servico_video_depois_do_sim') ? 'checked' : '' }}> <span>Vídeo depois do SIM</span></label>
                <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="event_meta[servico_drone]" value="1" {{ $metaValue('servico_drone') ? 'checked' : '' }}> <span>Drone</span></label>
            </div>
            <div class="grid md:grid-cols-2 gap-3">
                <div>
                    <label class="block text-sm">Nº de profissionais</label>
                    <input type="number" min="0" name="event_meta[servico_num_profissionais]" value="{{ $metaValue('servico_num_profissionais') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Prazo de entrega</label>
                    <input name="event_meta[servico_prazo_entrega]" value="{{ $metaValue('servico_prazo_entrega') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">Tela</label>
                    <input name="event_meta[servico_tela]" value="{{ $metaValue('servico_tela') }}" class="border p-2 rounded w-full">
                </div>
                <div>
                    <label class="block text-sm">USB</label>
                    <input name="event_meta[servico_usb]" value="{{ $metaValue('servico_usb') }}" class="border p-2 rounded w-full">
                </div>
            </div>
            <div>
                <label class="block text-sm">Condições mínimas de trabalho</label>
                <textarea name="event_meta[servico_condicoes_minimas]" class="border p-2 rounded w-full" rows="2">{{ $metaValue('servico_condicoes_minimas') }}</textarea>
            </div>
            <div>
                <label class="block text-sm">Músicas</label>
                <textarea name="event_meta[servico_musicas]" class="border p-2 rounded w-full" rows="2">{{ $metaValue('servico_musicas') }}</textarea>
            </div>
            <div>
                <label class="block text-sm">Extras</label>
                <textarea name="event_meta[servico_extras]" class="border p-2 rounded w-full" rows="2">{{ $metaValue('servico_extras') }}</textarea>
            </div>
        </div>

        <div class="border rounded p-4 space-y-3">
            <div class="font-semibold">Loja e observações</div>
            <div class="grid md:grid-cols-2 gap-3">
                <div>
                    <label class="block text-sm">Estar na loja às</label>
                    <input type="time" name="event_meta[estar_na_loja_as]" value="{{ $metaValue('estar_na_loja_as') }}" class="border p-2 rounded w-full">
                </div>
            </div>
            <div>
                <label class="block text-sm">OBS</label>
                <textarea name="notes" class="border p-2 rounded w-full" rows="3">{{ $baseValue('notes') }}</textarea>
            </div>
        </div>

        
    </form>
    @php
        $teamUsersPayload = $teamUsers->map(function ($u) {
            return [
                'id' => $u->id,
                'name' => $u->name,
                'username' => $u->username,
            ];
        })->values();
    @endphp
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            const input = document.querySelector('input[name=\"event_meta[equipa_de_trabalho]\"]');
            const preview = document.getElementById('team-preview');
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
            const form = document.getElementById('event-search-form');
            if (!form) return;
            const method = form.querySelector('input[name=\"_method\"]');
            if (!method || method.value !== 'PUT') return;
            const searchMode = form.querySelector('input[name=\"search_mode\"]');
            if (searchMode && searchMode.value === '1') return;
            const statusEl = document.getElementById('autosave-status');
            const token = form.querySelector('input[name=\"_token\"]')?.value || '';
            let autosaveTimer = null;
            let dirty = false;
            let saving = false;
            let userActive = false;
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
                if (token && !fd.get('_token')) {
                    fd.set('_token', token);
                }
                const url = form.getAttribute('action');
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
        document.addEventListener('DOMContentLoaded', () => {
            const searchBtn = document.getElementById('search-btn');
            if (!searchBtn) return;
            const form = document.getElementById('event-search-form');
            const modeInput = form ? form.querySelector('input[name=\"search_mode\"]') : null;
            if (!form || !modeInput) return;

            searchBtn.addEventListener('click', () => {
                if (modeInput.value !== '0') return;
                const fields = form.querySelectorAll('input, select, textarea');
                fields.forEach(field => {
                    const name = field.getAttribute('name');
                    if (!name || name === 'type' || name === 'search_mode') return;
                    if (field.type === 'hidden' || field.type === 'submit' || field.type === 'button') return;
                    if (field.type === 'checkbox' || field.type === 'radio') {
                        field.checked = false;
                        return;
                    }
                    if (field.tagName === 'SELECT') {
                        if (field.multiple) {
                            Array.from(field.options).forEach(option => { option.selected = false; });
                        } else {
                            field.selectedIndex = 0;
                        }
                        return;
                    }
                    field.value = '';
                });
                modeInput.value = '1';
            });
        });
    </script>
@endif
@endsection
