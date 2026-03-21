<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use App\Models\Event;

class EventUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $eventTime = $this->input('event_time');
        if (is_string($eventTime)) {
            $trim = trim($eventTime);
            if ($trim === '') {
                $this->merge(['event_time' => null]);
            } elseif (preg_match('/^\\d{2}:\\d{2}:\\d{2}$/', $trim)) {
                $this->merge(['event_time' => substr($trim, 0, 5)]);
            }
        }
        foreach (['event_date', 'base_price', 'price_per_photo', 'access_pin'] as $field) {
            $value = $this->input($field);
            if (is_string($value) && trim($value) === '') {
                $this->merge([$field => null]);
            }
        }
    }

    public function rules(): array
    {
        $rules = [
            'client_id' => ['nullable', 'integer', 'exists:clients,id'],
            'name' => ['nullable', 'string', 'max:255'],
            'internal_code' => ['nullable', 'string', 'max:50'],
            'legacy_report_number' => ['nullable', 'string', 'max:50'],
            'event_type' => ['nullable', 'string', 'max:120'],
            'event_date' => ['required', 'date'],
            'event_time' => ['nullable', 'date_format:H:i'],
            'location' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string'],
            'status' => ['nullable', 'string', 'max:30'],
            'access_mode' => ['nullable', 'string', 'max:30'],
            'qr_enabled' => ['nullable', 'boolean'],
            'is_locked' => ['nullable', 'boolean'],
            'storage_path' => ['nullable', 'string', 'max:255'],
            'event_meta' => ['nullable', 'array'],
            'event_meta.noivo_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.noiva_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.noivo_contacto' => ['nullable', 'string', 'max:255'],
            'event_meta.noiva_contacto' => ['nullable', 'string', 'max:255'],
            'event_meta.noivo_profissao' => ['nullable', 'string', 'max:255'],
            'event_meta.noiva_profissao' => ['nullable', 'string', 'max:255'],
            'event_meta.noivo_morada' => ['nullable', 'string', 'max:500'],
            'event_meta.noiva_morada' => ['nullable', 'string', 'max:500'],
            'event_meta.noivo_instagram' => ['nullable', 'string', 'max:255'],
            'event_meta.noiva_instagram' => ['nullable', 'string', 'max:255'],
            'event_meta.noivo_coordenadas' => ['nullable', 'string', 'max:255'],
            'event_meta.noiva_coordenadas' => ['nullable', 'string', 'max:255'],
            'event_meta.noivo_filho_de_1' => ['nullable', 'string', 'max:255'],
            'event_meta.noivo_filho_de_2' => ['nullable', 'string', 'max:255'],
            'event_meta.noiva_filho_de_1' => ['nullable', 'string', 'max:255'],
            'event_meta.noiva_filho_de_2' => ['nullable', 'string', 'max:255'],
            'event_meta.missa_hora' => ['nullable', 'date_format:H:i'],
            'event_meta.casa_noivo_chegada' => ['nullable', 'date_format:H:i'],
            'event_meta.casa_noivo_saida' => ['nullable', 'date_format:H:i'],
            'event_meta.casa_noiva_chegada' => ['nullable', 'date_format:H:i'],
            'event_meta.casa_noiva_saida' => ['nullable', 'date_format:H:i'],
            'event_meta.igreja_local' => ['nullable', 'string', 'max:255'],
            'event_meta.igreja_localidade' => ['nullable', 'string', 'max:255'],
            'event_meta.quinta_local' => ['nullable', 'string', 'max:255'],
            'event_meta.almoco_localidade' => ['nullable', 'string', 'max:255'],
            'event_meta.instagram_noivos' => ['nullable', 'string', 'max:255'],
            'event_meta.instagram_pais' => ['nullable', 'string', 'max:255'],
            'event_meta.numero_convidados' => ['nullable', 'integer', 'min:0'],
            'event_meta.tipo_pacote' => ['nullable', 'string', 'max:255'],
            'event_meta.data_entrega' => ['nullable', 'date'],
            'event_meta.estar_na_loja_as' => ['nullable', 'date_format:H:i'],
            'event_meta.bebe_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.pai_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.mae_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.padrinho_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.madrinha_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.contacto_pais' => ['nullable', 'string', 'max:255'],
            'event_meta.morada' => ['nullable', 'string', 'max:500'],
            'event_meta.cliente_noivo_num' => ['nullable', 'string', 'max:50'],
            'event_meta.cliente_noiva_num' => ['nullable', 'string', 'max:50'],
            'event_meta.cliente_batizado_num' => ['nullable', 'string', 'max:50'],
            'event_meta.servico_save_the_date' => ['nullable', 'boolean'],
            'event_meta.servico_fotos_love_story' => ['nullable', 'boolean'],
            'event_meta.servico_video_love_story' => ['nullable', 'boolean'],
            'event_meta.servico_projectar_love_story' => ['nullable', 'boolean'],
            'event_meta.servico_combo_beleza_love_story' => ['nullable', 'boolean'],
            'event_meta.servico_album_digital_30_5' => ['nullable', 'boolean'],
            'event_meta.servico_combo_beleza_ttd' => ['nullable', 'boolean'],
            'event_meta.servico_album_digital' => ['nullable', 'boolean'],
            'event_meta.servico_album_convidados' => ['nullable', 'boolean'],
            'event_meta.servico_albuns_40_20' => ['nullable', 'boolean'],
            'event_meta.servico_same_day_edit' => ['nullable', 'boolean'],
            'event_meta.servico_projectar_same_day_edit' => ['nullable', 'boolean'],
            'event_meta.servico_galeria_digital_convidados' => ['nullable', 'boolean'],
            'event_meta.servico_foto_lembranca_qr' => ['nullable', 'boolean'],
            'event_meta.servico_impressao_100_11x22_7' => ['nullable', 'boolean'],
            'event_meta.servico_video_depois_do_sim' => ['nullable', 'boolean'],
            'event_meta.servico_num_profissionais' => ['nullable', 'integer', 'min:0'],
            'event_meta.servico_condicoes_minimas' => ['nullable', 'string'],
            'event_meta.servico_prazo_entrega' => ['nullable', 'string', 'max:255'],
            'event_meta.servico_tela' => ['nullable', 'string', 'max:255'],
            'event_meta.servico_musicas' => ['nullable', 'string'],
            'event_meta.servico_usb' => ['nullable', 'string', 'max:255'],
            'event_meta.servico_drone' => ['nullable', 'boolean'],
            'event_meta.servico_extras' => ['nullable', 'string'],
            'event_meta.equipa_de_trabalho' => ['nullable', 'string', 'max:255'],
            'event_meta.foto_noivos' => ['nullable', 'image', 'max:5120'],
            'access_pin' => ['nullable', 'string', 'regex:/^\\d{4}$/'],
            'is_active_today' => ['nullable', 'boolean'],
            'base_price' => ['required', 'numeric', 'min:0'],
            'price_per_photo' => ['required', 'numeric', 'min:0'],
            'staff_ids' => ['nullable', 'array'],
            'staff_ids.*' => ['integer', Rule::exists('users', 'id')->where(function ($query) {
                $query->whereIn('role', ['photographer']);
            })],
        ];

        if ($this->boolean('autosave')) {
            $rules['event_date'] = ['nullable', 'date'];
            $rules['base_price'] = ['nullable', 'numeric', 'min:0'];
            $rules['price_per_photo'] = ['nullable', 'numeric', 'min:0'];
            $lenient = [
                'event_time',
                'event_meta.missa_hora',
                'event_meta.casa_noivo_chegada',
                'event_meta.casa_noivo_saida',
                'event_meta.casa_noiva_chegada',
                'event_meta.casa_noiva_saida',
                'event_meta.estar_na_loja_as',
                'event_meta.data_entrega',
            ];
            foreach ($lenient as $field) {
                $rules[$field] = ['nullable', 'string', 'max:50'];
            }
            $rules['event_meta.numero_convidados'] = ['nullable'];
            $rules['event_meta.servico_num_profissionais'] = ['nullable'];
        }

        return $rules;
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            if (! $this->boolean('enforce_required')) {
                return;
            }
            $event = $this->route('event');
            $type = $this->input('event_type') ?: ($event?->event_type ?? null);
            $meta = $this->input('event_meta', $event?->event_meta ?? []);
            $status = $this->input('status') ?: ($event?->status ?? null);
            if ($type === 'casamento' && $status !== 'rascunho') {
                $required = [
                    'noivo_nome' => 'Nome do noivo',
                    'noiva_nome' => 'Nome da noiva',
                    'noivo_contacto' => 'Telemóvel do noivo',
                    'noiva_contacto' => 'Telemóvel da noiva',
                    'noivo_profissao' => 'Profissão do noivo',
                    'noiva_profissao' => 'Profissão da noiva',
                    'noivo_morada' => 'Morada do noivo',
                    'noiva_morada' => 'Morada da noiva',
                ];
                foreach ($required as $field => $label) {
                    if (empty($meta[$field])) {
                        $validator->errors()->add("event_meta.$field", "Campo obrigatório para casamento: {$label}.");
                    }
                }
            }
            if ($type === 'batizado') {
                $required = [
                    'bebe_nome' => 'Nome do bebé',
                    'pai_nome' => 'Nome do pai',
                    'mae_nome' => 'Nome da mãe',
                    'padrinho_nome' => 'Nome do padrinho',
                    'madrinha_nome' => 'Nome da madrinha',
                    'contacto_pais' => 'Contacto dos pais',
                    'morada' => 'Morada',
                ];
                foreach ($required as $field => $label) {
                    if (empty($meta[$field])) {
                        $validator->errors()->add("event_meta.$field", "Campo obrigatório para batizado: {$label}.");
                    }
                }
            }
        });
        $validator->after(function ($validator) {
            $report = trim((string) $this->input('legacy_report_number', ''));
            if ($report === '') {
                return;
            }
            $event = $this->route('event');
            if ($event && $event->legacy_report_number === $report) {
                return;
            }
            $exists = Event::query()
                ->where('legacy_report_number', $report)
                ->when($event, fn ($q) => $q->where('id', '<>', $event->id))
                ->exists();
            if ($exists) {
                $validator->errors()->add('legacy_report_number', 'Este Nº de reportagem já existe.');
            }
        });
    }
}
