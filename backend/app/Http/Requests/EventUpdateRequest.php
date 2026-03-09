<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class EventUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'client_id' => ['nullable', 'integer', 'exists:clients,id'],
            'name' => ['required', 'string', 'max:255'],
            'internal_code' => ['nullable', 'string', 'max:50'],
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
            'event_meta.missa_hora' => ['nullable', 'date_format:H:i'],
            'event_meta.casa_noivo_chegada' => ['nullable', 'date_format:H:i'],
            'event_meta.casa_noivo_saida' => ['nullable', 'date_format:H:i'],
            'event_meta.casa_noiva_chegada' => ['nullable', 'date_format:H:i'],
            'event_meta.casa_noiva_saida' => ['nullable', 'date_format:H:i'],
            'event_meta.igreja_local' => ['nullable', 'string', 'max:255'],
            'event_meta.quinta_local' => ['nullable', 'string', 'max:255'],
            'event_meta.instagram_noivos' => ['nullable', 'string', 'max:255'],
            'event_meta.instagram_pais' => ['nullable', 'string', 'max:255'],
            'event_meta.numero_convidados' => ['nullable', 'integer', 'min:0'],
            'event_meta.tipo_pacote' => ['nullable', 'string', 'max:255'],
            'event_meta.bebe_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.pai_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.mae_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.padrinho_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.madrinha_nome' => ['nullable', 'string', 'max:255'],
            'event_meta.contacto_pais' => ['nullable', 'string', 'max:255'],
            'event_meta.morada' => ['nullable', 'string', 'max:500'],
            'access_password' => ['nullable', 'string', 'max:255'],
            'access_pin' => ['nullable', 'string', 'regex:/^\\d{4}$/'],
            'is_active_today' => ['nullable', 'boolean'],
            'price_per_photo' => ['required', 'numeric', 'min:0'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            $event = $this->route('event');
            $type = $this->input('event_type') ?: ($event?->event_type ?? null);
            $meta = $this->input('event_meta', $event?->event_meta ?? []);
            if ($type === 'casamento') {
                $required = ['noivo_nome', 'noiva_nome', 'noivo_contacto', 'noiva_contacto', 'noivo_profissao', 'noiva_profissao', 'noivo_morada', 'noiva_morada'];
                foreach ($required as $field) {
                    if (empty($meta[$field])) {
                        $validator->errors()->add("event_meta.$field", 'Campo obrigatório para casamento.');
                    }
                }
            }
            if ($type === 'batizado') {
                $required = ['bebe_nome', 'pai_nome', 'mae_nome', 'padrinho_nome', 'madrinha_nome', 'contacto_pais', 'morada'];
                foreach ($required as $field) {
                    if (empty($meta[$field])) {
                        $validator->errors()->add("event_meta.$field", 'Campo obrigatório para batizado.');
                    }
                }
            }
        });
    }
}
