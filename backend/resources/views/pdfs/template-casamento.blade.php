<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 10mm; }
        body { font-family: DejaVu Sans, sans-serif; font-size: 10px; color: #2a2a2a; }
        .page { position: relative; width: 190mm; height: 277mm; }
        .red { color: #b63a2c; }
        .title { text-align: center; font-weight: 700; font-size: 20px; }
        .sub { text-align: center; font-size: 12px; margin-top: 2px; }
        .contacts { position: absolute; top: 2mm; right: 0; font-size: 8px; text-align: right; }
        .section { position: absolute; left: 0; right: 0; }
        table { width: 100%; border-collapse: collapse; }
        td { padding: 1px 2px; vertical-align: top; }
        .lbl { font-size: 9px; color: #444; text-transform: uppercase; }
        .val { font-size: 11px; }
        .box { border: 1px solid #999; padding: 6px; text-align: center; width: 40mm; }
        .line { border-bottom: 1px solid #bdbdbd; }
        .sig { border-top: 1px solid #777; text-align: center; padding-top: 4px; }
        .note { font-size: 9px; color: #b63a2c; }
        .shift-left { position: relative; left: -3mm; }
        .info-table td { padding: 1px 1.5px; }
        .split-left { padding-right: 3mm; }
        .split-right { padding-left: 3mm; border-left: 1px solid #bdbdbd; }
        .bottom-red { display: block; margin-top: 2mm; color: #b63a2c; }
        .gap { display: inline-block; margin-left: 4mm; }
    </style>
</head>
<body>
@php
    $type = $event->event_type ?? '';
    $serviceLabel = strtoupper($type ?: 'EVENTO');
    $reportNo = $event->legacy_report_number ?? $event->internal_code ?? $event->id;
    $priceBaseRaw = $event->base_price ?? $meta['preco_base'] ?? null;
    $priceBase = $priceBaseRaw !== null ? number_format((float) $priceBaseRaw, 2, ',', '.').' €' : '';
    $houseLabel = $type === 'casamento' ? 'NA CASA DO NOIVO ÀS:' : 'NA CASA DO BEBÉ ÀS:';
    $serviceLabels = [
        'servico_save_the_date' => 'Save the date',
        'servico_fotos_love_story' => 'Fotos love story',
        'servico_video_love_story' => 'Vídeo love story',
        'servico_projectar_love_story' => 'Projectar love story',
        'servico_combo_beleza_love_story' => 'Combo beleza love story',
        'servico_album_digital_30_5' => 'Álbum digital 30+5',
        'servico_combo_beleza_ttd' => 'Combo beleza ttd',
        'servico_album_digital' => 'Álbum digital',
        'servico_album_convidados' => 'Álbum de convidados',
        'servico_albuns_40_20' => 'Álbuns 40x20',
        'servico_same_day_edit' => 'Same day edit',
        'servico_projectar_same_day_edit' => 'Projectar same day edit',
        'servico_galeria_digital_convidados' => 'Galeria digital c/fotos convidados',
        'servico_foto_lembranca_qr' => 'Foto lembrança QR code',
        'servico_impressao_100_11x22_7' => 'Impressão 100 fotos 11x22,7',
        'servico_video_depois_do_sim' => 'Vídeo depois do SIM',
        'servico_drone' => 'Drone',
    ];
    $serviceList = collect($serviceLabels)
        ->filter(fn ($label, $key) => !empty($meta[$key]))
        ->values()
        ->implode(' • ');
@endphp

<div class="page">
    <div class="contacts">
        <div>Contactos</div>
        <div>935 551 234</div>
        <div>918 685 658</div>
        <div>{{ $meta['contacto_nome_1'] ?? '' }}</div>
        <div>{{ $meta['contacto_nome_2'] ?? '' }}</div>
        <div>{{ $meta['contacto_nome_3'] ?? '' }}</div>
    </div>

    <div class="section" style="top: 4mm;">
        <div class="title red">{{ $serviceLabel }}</div>
        @if($dateLabel)<div class="sub red">{{ $dateLabel }}</div>@endif
        @if(!empty($namesLine))<div class="sub red" style="font-weight:700;">{{ $namesLine }}</div>@endif
        <div class="sub red">{{ $event->event_time ? $event->event_time.'h' : '' }} {{ $event->location ? 'no '.$event->location : '' }}</div>
    </div>

    <div class="section" style="top: 32mm;">
        <table>
            <tr>
                <td class="lbl" style="width:30mm;">Reportagem nº</td>
                <td class="val" style="width:70mm;">{{ $reportNo }}</td>
                <td style="width:40mm;"></td>
                <td style="width:50mm; text-align:right;">
                    <div class="box small" style="margin-bottom:2mm;">
                        <div class="lbl">Preço base</div>
                        <div class="val">{{ $priceBase }}</div>
                    </div>
                </td>
            </tr>
        </table>
        
    </div>

    @if($type === 'casamento')
        <div class="section" style="top: 48mm;">
            <table>
                <tr>
                    <td class="split-left" style="width:50%;">
                        <table class="info-table">
                            <tr>
                                <td class="lbl">Nome</td>
                                <td class="val">{{ $meta['noivo_nome'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td class="lbl">Instagram</td>
                                <td class="val">{{ $meta['noivo_instagram'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td class="lbl">Contacto</td>
                                <td class="val">{{ $meta['noivo_contacto'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td class="lbl">Profissão</td>
                                <td class="val">{{ $meta['noivo_profissao'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td class="lbl">Filho de</td>
                                <td class="val">
                                    {{ $meta['noivo_filho_de_1'] ?? '' }}<br>
                                    {{ $meta['noivo_filho_de_2'] ?? '' }}
                                </td>
                            </tr>
                            <tr>
                                <td class="lbl">Morada</td>
                                <td class="val">{{ $meta['noivo_morada'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td class="lbl">Coordenadas</td>
                                <td class="val">{{ $meta['noivo_coordenadas'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td colspan="2">
                                    <span class="bottom-red">
                                        Casa do noivo às {{ $meta['casa_noivo_chegada'] ?? '' }}
                                        <span class="gap">Casa do noivo saída {{ $meta['casa_noivo_saida'] ?? '' }}</span>
                                    </span>
                                </td>
                            </tr>
                        </table>
                    </td>
                    <td class="split-right" style="width:50%;">
                        <table class="info-table">
                            <tr>
                                <td class="lbl">Nome</td>
                                <td class="val">{{ $meta['noiva_nome'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td class="lbl">Instagram</td>
                                <td class="val">{{ $meta['noiva_instagram'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td class="lbl">Contacto</td>
                                <td class="val">{{ $meta['noiva_contacto'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td class="lbl">Profissão</td>
                                <td class="val">{{ $meta['noiva_profissao'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td class="lbl">Filha de</td>
                                <td class="val">
                                    {{ $meta['noiva_filho_de_1'] ?? '' }}<br>
                                    {{ $meta['noiva_filho_de_2'] ?? '' }}
                                </td>
                            </tr>
                            <tr>
                                <td class="lbl">Morada</td>
                                <td class="val">{{ $meta['noiva_morada'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td class="lbl">Coordenadas</td>
                                <td class="val">{{ $meta['noiva_coordenadas'] ?? '' }}</td>
                            </tr>
                            <tr>
                                <td colspan="2">
                                    <span class="bottom-red">
                                        Casa da noiva às {{ $meta['casa_noiva_chegada'] ?? '' }}
                                        <span class="gap">Casa da noiva saída {{ $meta['casa_noiva_saida'] ?? '' }}</span>
                                    </span>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
            </table>
        </div>
    @else
        <div class="section" style="top: 48mm;">
            <table>
                <tr style="height:6mm;">
                    <td class="lbl red" style="width:40mm;">{{ $houseLabel }}</td>
                    <td class="val red">{{ $meta['casa_bebe_hora'] ?? $meta['casa_noivo_chegada'] ?? '' }}</td>
                </tr>
                <tr style="height:6mm;">
                    <td class="lbl" style="width:20mm;">{{ $type === 'casamento' ? 'Noivo' : 'Bebé' }}</td>
                    <td class="val">{{ $type === 'casamento' ? ($meta['noivo_nome'] ?? '') : ($meta['bebe_nome'] ?? '') }}</td>
                </tr>
                <tr style="height:6mm;">
                    <td class="lbl">{{ $type === 'casamento' ? 'Noiva' : 'Pais bebé' }}</td>
                    <td class="val">{{ $type === 'casamento' ? ($meta['noiva_nome'] ?? '') : trim(($meta['pai_nome'] ?? '').' '.($meta['mae_nome'] ?? '')) }}</td>
                </tr>
                <tr style="height:6mm;">
                    <td class="lbl">Morada</td>
                    <td class="val">{{ $type === 'casamento' ? ($meta['noivo_morada'] ?? '') : ($meta['morada'] ?? '') }}</td>
                </tr>
                <tr style="height:6mm;">
                    <td class="lbl"></td>
                    <td class="val">{{ $type === 'casamento' ? ($meta['noiva_morada'] ?? '') : '' }}</td>
                </tr>
                <tr style="height:6mm;">
                    <td class="lbl">Coordenadas</td>
                    <td class="val">{{ $meta['coordenadas'] ?? '' }}</td>
                </tr>
            </table>
        </div>
    @endif

    <div class="section" style="top: 100mm;">
        <table>
            <tr>
                <td class="lbl" style="width:20mm;">Missa às</td>
                <td class="val" style="width:25mm;">{{ $meta['missa_hora'] ?? '' }}</td>
                <td class="lbl" style="width:18mm;">Igreja</td>
                <td class="val" style="width:45mm;">{{ $meta['igreja_local'] ?? '' }}</td>
                <td class="lbl" style="width:20mm;">Almoço</td>
                <td class="val">{{ $meta['quinta_local'] ?? '' }}</td>
            </tr>
            <tr>
                <td class="lbl">Nº convidados</td>
                <td class="val">{{ $meta['numero_convidados'] ?? '' }}</td>
            </tr>
        </table>
    </div>

    <div class="section" style="top: 118mm;">
        <div class="note">ATENÇÃO</div>
        <div class="note">{{ $meta['atencao'] ?? '' }}</div>
        <div class="note">{{ $event->notes ?? '' }}</div>
        <div class="note">{{ $meta['servico_extras'] ?? '' }}</div>
        <div class="note">{{ $serviceList }}</div>
    </div>

    <div class="section" style="top: 158mm;">
        <table>
            <tr>
                <td class="lbl">Nº Fotos vendidas:</td>
                <td class="lbl">Nº Fotos deve:</td>
                <td class="lbl">€€ Digital:</td>
                <td class="lbl">€€ Físico:</td>
                <td class="lbl shift-left">€€ Extras:</td>
                <td class="lbl">USB Vendidos:</td>
            </tr>
            <tr>
                <td class="val small">Telas Vendidas:</td>
                <td class="val small">Despesas (se existir):</td>
                <td class="val small">Total €€ entregue:</td>
                <td class="val small">Comissão+Gorjeta:</td>
                <td></td>
                <td></td>
            </tr>
            <tr>
                <td class="note" colspan="6">OBS para filme ou fotos: {{ $meta['obs_filme_fotos'] ?? '' }}</td>
            </tr>
        </table>
    </div>

    <div class="section" style="top: 190mm;">
        <table>
            <tr>
                <td class="val small" style="width:65%;">Extras para conta dos noivos: {{ $meta['extras_conta_noivos'] ?? '' }}</td>
                <td style="width:35%;">
                    <table>
                        <tr><td class="lbl" style="text-align:right;">Total de Extras</td><td class="line">&nbsp;</td></tr>
                        <tr><td class="lbl" style="text-align:right;">Avanço</td><td class="line">&nbsp;</td></tr>
                        <tr><td class="lbl" style="text-align:right;">Falta Pagar</td><td class="line">&nbsp;</td></tr>
                    </table>
                </td>
            </tr>
        </table>
    </div>

    <div class="section" style="bottom: 12mm;">
        <table>
            <tr>
                <td class="lbl" style="width:25mm;">Data de entrega</td>
                <td class="val" style="width:40mm;">{{ $meta['data_entrega'] ?? '' }}</td>
                <td style="width:10mm;"></td>
                <td class="sig" style="width:55mm;">O Cliente</td>
                <td class="sig" style="width:55mm;">O Responsável</td>
            </tr>
        </table>
        <div class="val" style="margin-top:3mm;">Entreguei o serviço de Reportagem ao Studio 59 que assume toda a responsabilidade pelo trabalho.</div>
    </div>
</div>
</body>
</html>
