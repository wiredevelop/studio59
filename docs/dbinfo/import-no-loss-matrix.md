# Matriz de Importacao Sem Perda

## Fontes analisadas

- `docs/dbinfo/batizados.xlsx`
- `docs/dbinfo/comunhao.xlsx`
- `docs/dbinfo/todos.xlsx`
- `docs/dbinfo/tudo.xlsx`
- `docs/dbinfo/1.pdf`
- `docs/dbinfo/2.pdf`
- `docs/dbinfo/3.pdf`

## Regra base

Para importar sem perder dados:

1. mapear tudo o que ja existe para colunas atuais ou `event_meta`
2. criar campos novos apenas quando o valor tem uso funcional claro
3. guardar sempre a linha legacy completa, com nomes originais das colunas

## Estrategia obrigatoria

Mesmo depois do mapeamento, o importador deve guardar:

- `legacy_payload`: JSON com a linha original completa
- `legacy_source_file`: nome do Excel de origem
- `legacy_source_sheet`: folha de origem
- `legacy_source_row`: numero da linha original

Sem isto, qualquer coluna ainda nao modelada fica em risco.

## Estado atual do sistema

Ja existem destinos estaveis para:

- `events.legacy_report_number`
- `events.legacy_client_number`
- `events.service_raw`
- `events.bride_name`
- `events.groom_name`
- `events.bride_email`
- `events.groom_email`
- `events.bride_phone`
- `events.groom_phone`
- `events.event_date`
- `events.delivery_date`
- `events.event_time`
- `events.guest_count`
- `events.location`
- `events.city`
- `events.address`
- `events.address2`
- `events.mass_time_raw`
- `events.store_time_raw`
- `events.bride_departure_time_raw`
- `events.groom_departure_time_raw`
- `events.price_per_photo`
- `events.base_price`
- `events.total_price`
- `events.notes`
- `events.event_meta.*`

Ja existem inputs/validacao para muitos campos de casamento, batizado e servicos dentro de `event_meta`.

## Campos novos recomendados

Estes ainda nao estao claramente cobertos e devem ganhar destino explicito em `event_meta` e na ficha:

- `event_meta.avos_maternos`
- `event_meta.avos_paternos`
- `event_meta.padrinhos_raw`
- `event_meta.email_pais`
- `event_meta.residencia_apos_casamento`
- `event_meta.facebook`
- `event_meta.telemovel_noiva_2`
- `event_meta.telemovel_noivo_2`
- `event_meta.telemovel_mae`
- `event_meta.telemovel_pai`
- `event_meta.pais_bebe_raw`
- `event_meta.nome_livre`

Estes devem existir pelo menos para preservacao bruta, mesmo que a UX final venha depois.

## Campos comerciais legados

Este bloco nao cabe bem no modelo atual e deve ser preservado primeiro, antes de normalizar:

- `ALBUM`
- `ALBUM DIGITAL`
- `AUTOCOLANTES`
- `BlueRay`
- `CD_fotos`
- `CONVITES`
- `CONVITES1`
- `DVD`
- `FILME`
- `FOTOS`
- `FOTOS EXTRA`
- `LEMBRANÇAS`
- `LEMBRANÇAS1`
- `MALA`
- `Passaconta`
- `PREÇO CONVITES`
- `PREÇO FILME`
- `PREÇO FOTOS`
- `PREÇO LEMB.`
- `QUANT.CONVITES`
- `QUANT.FOTOS`
- `QUANT.FOTOS1`
- `QUANT.FOTOS2`
- `QUANT.LEMB.`
- `SUBTOTAL`
- `SUBTOTAL1`
- `TOTAL`
- `TOTAL1`
- `VALOR`
- `VALOR1`
- `VALOR CONTRATO`
- `DÉBITO`
- `SOMA DÉBITO`

Recomendacao:

- guardar tudo em `legacy_payload`
- criar depois um bloco proprio, por exemplo `event_meta.comercial_legacy`
- nao tentar converter isto ja para `orders`, porque mistura contrato, extras e producao antiga

## Matriz de mapeamento

### Identificacao e agenda

| Coluna legacy | Destino atual | Estado | Acao |
| --- | --- | --- | --- |
| `SERVIÇO DE:` | `events.service_raw` + `events.event_type` normalizado | Coberto | Importar os dois |
| `DATA` | `events.event_date` | Coberto | Importar |
| `REPORTAGEM Nº` | `events.legacy_report_number` | Coberto | Importar string original |
| `CLIENTE Nº` | `events.legacy_client_number` | Parcial | Importar coluna e manter tambem em `legacy_payload` |
| `OBS` | `events.notes` | Coberto | Importar |
| `NOME` | `event_meta.nome_livre` | Falta | Novo campo + `legacy_payload` |

### Financeiro principal

| Coluna legacy | Destino atual | Estado | Acao |
| --- | --- | --- | --- |
| `PREÇO` | `events.price_per_photo` ou `events.total_price` consoante contexto | Parcial | Guardar original e definir regra por tipo |
| `Preço Base` | `events.base_price` | Coberto | Importar |
| `VALOR CONTRATO` | sem destino | Falta | Guardar bruto; provavelmente novo campo |
| `DÉBITO` | sem destino | Falta | Guardar bruto |
| `SOMA DÉBITO` | sem destino | Falta | Guardar bruto |
| `SUBTOTAL` | sem destino | Falta | Guardar bruto |
| `SUBTOTAL1` | sem destino | Falta | Guardar bruto |
| `TOTAL` | sem destino | Falta | Guardar bruto |
| `TOTAL1` | sem destino | Falta | Guardar bruto |
| `VALOR` | sem destino | Falta | Guardar bruto |
| `VALOR1` | sem destino | Falta | Guardar bruto |

### Pessoas e contactos de casamento/comunhao

| Coluna legacy | Destino atual | Estado | Acao |
| --- | --- | --- | --- |
| `NOIVO` | `events.groom_name` + `event_meta.noivo_nome` | Coberto | Importar ambos |
| `NOIVA` | `events.bride_name` + `event_meta.noiva_nome` | Coberto | Importar ambos |
| `FILHO DE` | `event_meta.noivo_filho_de_1` | Coberto | Importar |
| `FILHA DE` | `event_meta.noiva_filho_de_1` | Coberto | Importar |
| `Profissão do Noivo` | `event_meta.noivo_profissao` | Coberto | Importar |
| `Profissão da Noiva` | `event_meta.noiva_profissao` | Coberto | Importar |
| `Email noivo` | `events.groom_email` | Coberto | Importar |
| `Email noiva` | `events.bride_email` | Coberto | Importar |
| `Telemovel noivo` | `events.groom_phone` + `event_meta.noivo_contacto` | Coberto | Importar ambos |
| `Telemovel noiva` | `events.bride_phone` + `event_meta.noiva_contacto` | Coberto | Importar ambos |
| `telemóvel noivo 2` | `event_meta.telemovel_noivo_2` | Falta | Novo campo |
| `telemóvel noiva 2` | `event_meta.telemovel_noiva_2` | Falta | Novo campo |
| `TELEF.` | `events.groom_phone` ou contacto principal fallback | Parcial | Preservar bruto e mapear por tipo |
| `TELEF2` | `events.bride_phone` ou contacto secundario fallback | Parcial | Preservar bruto e mapear por tipo |
| `Instagram` | `event_meta.noivo_instagram` ou `event_meta.instagram_pais` | Parcial | Regra depende do tipo |
| `Instagram2` | `event_meta.noiva_instagram` ou `event_meta.instagram_pais` | Parcial | Regra depende do tipo |
| `Facebook` | `event_meta.facebook` | Falta | Novo campo |
| `MORADA` | `events.address` + `event_meta.noivo_morada` ou `event_meta.morada` | Parcial | Regra depende do tipo |
| `MORADA2` | `events.address2` + `event_meta.noiva_morada` | Coberto | Importar |
| `RESIDÊNCIA APÓS CASAMENTO` | `event_meta.residencia_apos_casamento` | Falta | Novo campo |

### Batizado

| Coluna legacy | Destino atual | Estado | Acao |
| --- | --- | --- | --- |
| `BEBÉ` / `BEBE` | `event_meta.bebe_nome` | Coberto | Importar |
| `PAIS BEBE` | `event_meta.pais_bebe_raw` | Falta | Novo campo bruto |
| `PADRINHOS` | `event_meta.padrinhos_raw` | Falta | Novo campo bruto; pode continuar a alimentar padrinho/madrinha quando parseavel |
| `Telemovel Mãe` | `event_meta.contacto_mae` / `event_meta.telemovel_mae` | Parcial | Criar campo bruto dedicado e manter `contacto_mae` |
| `Telemovel Pai` | `event_meta.contacto_pai` / `event_meta.telemovel_pai` | Parcial | Criar campo bruto dedicado e manter `contacto_pai` |
| `Email Pais` | `event_meta.email_pais` | Falta | Novo campo |
| `AVÓS MATERNOS` | `event_meta.avos_maternos` | Falta | Novo campo |
| `AVÓS PATERNOS` | `event_meta.avos_paternos` | Falta | Novo campo |

### Horarios, local e logistica

| Coluna legacy | Destino atual | Estado | Acao |
| --- | --- | --- | --- |
| `HORAS` | `events.event_time` ou `event_meta.casa_noivo_chegada` ou `event_meta.casa_bebe_hora` | Parcial | Regra por tipo; guardar bruto sempre |
| `HORAS2` | `event_meta.casa_noiva_chegada` | Coberto | Importar |
| `MISSA ÀS` | `events.mass_time_raw` + `event_meta.missa_hora` | Coberto | Importar ambos |
| `LOCAL` | `events.location` + `event_meta.igreja_local` | Coberto | Importar ambos |
| `LOCALIDADE` | `events.city` + `event_meta.igreja_localidade` | Coberto | Importar ambos |
| `ALMOÇO` | `event_meta.quinta_local` | Coberto | Importar |
| `Almoço 1` | `event_meta.quinta_local` | Coberto | Importar fallback |
| `Estar na Loja ás:` | `events.store_time_raw` + `event_meta.estar_na_loja_as` | Coberto | Importar ambos |
| `DATA ENTREGA` | `events.delivery_date` + `event_meta.data_entrega` | Coberto | Importar ambos |
| `Nº CONVIDADOS` | `events.guest_count` + `event_meta.numero_convidados` | Coberto | Importar ambos |
| `sair noivo` | `events.groom_departure_time_raw` + `event_meta.casa_noivo_saida` | Coberto | Importar ambos |
| `sair noiva` | `events.bride_departure_time_raw` + `event_meta.casa_noiva_saida` | Coberto | Importar ambos |
| `Mesa de Apoio aos fotografos` | `event_meta.mesa_apoio_fotografos` | Falta | Novo campo |
| `fotografos almoçam na quinta` | `event_meta.fotografos_almocam_na_quinta` | Falta | Novo campo boolean/texto |

### Equipa e producao

| Coluna legacy | Destino atual | Estado | Acao |
| --- | --- | --- | --- |
| `EQUIPA DE TRABALHO` | `event_meta.equipa_de_trabalho` | Coberto | Importar |
| `Nº de Profissionais` | `event_meta.servico_num_profissionais` | Coberto | Importar |
| `condições minimas de trabalho` | `event_meta.servico_condicoes_minimas` | Coberto | Importar |
| `prazo de entrega` | `event_meta.servico_prazo_entrega` | Coberto | Importar |
| `Musicas` | `event_meta.servico_musicas` | Coberto | Importar |
| `Musicas2` | `event_meta.servico_musicas` | Coberto | Fallback |
| `Tela` | `event_meta.servico_tela` | Coberto | Importar |
| `Pen` | `event_meta.servico_usb` | Coberto | Importar |
| `Paginas` | sem destino | Falta | Guardar bruto |
| `Books_noivos` | sem destino | Falta | Guardar bruto |
| `Capa` | sem destino | Falta | Guardar bruto |
| `nº fotos_pag` | sem destino | Falta | Guardar bruto |

### Servicos e extras ja relativamente cobertos

| Coluna legacy | Destino atual | Estado | Acao |
| --- | --- | --- | --- |
| `Save the Date 1` | `event_meta.servico_save_the_date` | Coberto | Importar |
| `projectar love story` | `event_meta.servico_projectar_love_story` | Coberto | Importar |
| `Combo Beleza Love Story` | `event_meta.servico_combo_beleza_love_story` | Coberto | Importar |
| `Combo Beleza TTD` | `event_meta.servico_combo_beleza_ttd` | Coberto | Importar |
| `Same Day Edit` | `event_meta.servico_same_day_edit` | Coberto | Importar |
| `projectar same day edite` | `event_meta.servico_projectar_same_day_edit` | Coberto | Importar |
| `galeria digital com fotos de convidados` | `event_meta.servico_galeria_digital_convidados` | Coberto | Importar |
| `Foto Lembrança QR Code` | `event_meta.servico_foto_lembranca_qr` | Coberto | Importar |
| `Impressão de 100 fotos 15x22,7` | `event_meta.servico_impressao_100_11x22_7` | Coberto | Importar |
| `Video depois do Sim` | `event_meta.servico_video_depois_do_sim` | Coberto | Importar |
| `Drone` | `event_meta.servico_drone` | Coberto | Importar |
| `Album dos Convidados:` | `event_meta.servico_album_convidados` | Coberto | Importar |
| `Album dos noivos:` | `event_meta.servico_album_digital` | Coberto | Importar |
| `albuns_pais` | `event_meta.servico_albuns_40_20` | Coberto | Importar |
| `Extras` | `event_meta.servico_extras` | Coberto | Importar |
| `extra` | `event_meta.servico_extras` | Coberto | Fallback |
| `acrescimos` | `event_meta.servico_extras` | Coberto | Fallback |

### Servicos e extras ainda sem destino claro

| Coluna legacy | Destino atual | Estado | Acao |
| --- | --- | --- | --- |
| `Tipo de Serviço` | `event_meta.tipo_pacote` | Coberto | Importar |
| `Email` | sem destino | Falta | Guardar bruto; pode virar email geral do cliente |
| `combo beleza Solteiros` | sem destino | Falta | Novo campo ou preservar bruto |
| `combo beleza Solteiros 1` | sem destino | Falta | Novo campo ou preservar bruto |
| `Impressão de 100 fotos 15x23` | sem destino | Falta | Novo campo de servico |
| `ALBUM` | sem destino | Falta | Preservar bruto |
| `ALBUM DIGITAL` | sem destino | Falta | Preservar bruto |
| `BlueRay` | sem destino | Falta | Preservar bruto |
| `CD_fotos` | sem destino | Falta | Preservar bruto |
| `DVD` | sem destino | Falta | Preservar bruto |
| `FILME` | sem destino | Falta | Preservar bruto |
| `CONVITES` | sem destino | Falta | Preservar bruto |
| `CONVITES1` | sem destino | Falta | Preservar bruto |
| `LEMBRANÇAS` | sem destino | Falta | Preservar bruto |
| `LEMBRANÇAS1` | sem destino | Falta | Preservar bruto |
| `AUTOCOLANTES` | sem destino | Falta | Preservar bruto |
| `MALA` | sem destino | Falta | Preservar bruto |
| `Passaconta` | sem destino | Falta | Preservar bruto |

### Campos de layout/resumo textual legacy

| Coluna legacy | Destino atual | Estado | Acao |
| --- | --- | --- | --- |
| `DIVERSOS` | sem destino | Falta | Preservar bruto |
| `DIVERSOS TEXTO` | sem destino | Falta | Preservar bruto |
| `resumo_texto` | sem destino | Falta | Preservar bruto |
| `resumo_texto Copy` | sem destino | Falta | Preservar bruto |
| `TEXTO_RESUMO` | sem destino | Falta | Preservar bruto |
| `Côr:` | sem destino | Falta | Preservar bruto |
| `Côr 1:` | sem destino | Falta | Preservar bruto |

## O que ja pode ser importado sem mexer mais no schema

- identificacao do evento
- data
- report number
- noivos
- emails principais
- telemoveis principais
- moradas principais
- missa/local/localidade
- convidados
- entrega
- equipa
- a maioria dos servicos atuais
- campos base de batizado

## O que pede schema/UI novo antes do import final

- avos de batizado
- email dos pais
- padrinhos como texto legacy
- residencia apos casamento
- facebook
- telemoveis secundarios
- contactos brutos separados de mae/pai
- alguns campos logisticos auxiliares

## O que nao deve ser normalizado ja

O bloco comercial antigo deve entrar primeiro como carga legacy preservada:

- produtos
- quantidades
- subtotais
- debitos
- totais
- valores de contrato

## Proximo passo recomendado

1. criar colunas de preservacao (`legacy_payload`, `legacy_source_file`, `legacy_source_sheet`, `legacy_source_row`)
2. adicionar os novos campos simples em `event_meta`
3. so depois escrever o importador final de Excel

