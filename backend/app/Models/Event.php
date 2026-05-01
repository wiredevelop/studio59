<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Model;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

class Event extends Model
{
    use HasFactory;

    protected $appends = [
        'report_number',
    ];

    protected $fillable = [
        'client_id',
        'name',
        'internal_code',
        'legacy_report_number',
        'legacy_client_number',
        'event_type',
        'service_raw',
        'event_date',
        'event_time',
        'delivery_date',
        'guest_count',
        'location',
        'city',
        'address',
        'address2',
        'mass_time_raw',
        'store_time_raw',
        'bride_departure_time_raw',
        'groom_departure_time_raw',
        'notes',
        'status',
        'access_mode',
        'qr_token',
        'qr_enabled',
        'is_locked',
        'storage_path',
        'event_meta',
        'access_pin',
        'is_active_today',
        'created_by',
        'price_per_photo',
        'base_price',
        'total_price',
        'bride_name',
        'groom_name',
        'bride_email',
        'groom_email',
        'bride_phone',
        'groom_phone',
    ];

    protected $casts = [
        'event_date' => 'date',
        'event_time' => 'string',
        'delivery_date' => 'date',
        'guest_count' => 'integer',
        'is_active_today' => 'boolean',
        'qr_enabled' => 'boolean',
        'is_locked' => 'boolean',
        'price_per_photo' => 'decimal:2',
        'base_price' => 'decimal:2',
        'total_price' => 'decimal:2',
        'event_meta' => 'array',
    ];

    public function getReportNumberAttribute(): ?string
    {
        return $this->internal_code ?: $this->legacy_report_number;
    }

    public function getEventMetaAttribute($value): array
    {
        $meta = $value;
        if (is_string($meta)) {
            $decoded = json_decode($meta, true);
            $meta = is_array($decoded) ? $decoded : [];
        }
        if (! is_array($meta)) {
            $meta = [];
        }

        return $this->mergeLegacyMeta($meta);
    }

    private function mergeLegacyMeta(array $meta): array
    {
        $meta = $this->setMetaIfMissing($meta, 'noivo_nome', $this->groom_name ?? ($meta['NOIVO'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'noiva_nome', $this->bride_name ?? ($meta['NOIVA'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'noivo_contacto', $this->groom_phone ?? ($meta['Telemovel noivo'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'noiva_contacto', $this->bride_phone ?? ($meta['Telemovel noiva'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'noivo_profissao', $meta['Profissão do Noivo'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'noiva_profissao', $meta['Profissão da Noiva'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'noivo_instagram', $meta['Instagram'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'noiva_instagram', $meta['Instagram2'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'noivo_filho_de_1', $meta['FILHO DE'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'noiva_filho_de_1', $meta['FILHA DE'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'noivo_morada', $this->address ?? ($meta['MORADA'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'noiva_morada', $this->address2 ?? ($meta['MORADA2'] ?? null));
        $meta = $this->setMetaIfMissing(
            $meta,
            'missa_hora',
            $this->normalizeTimeValue($this->mass_time_raw ?? ($meta['MISSA ÀS'] ?? null))
        );
        $meta = $this->setMetaIfMissing(
            $meta,
            'casa_noivo_chegada',
            $this->normalizeTimeValue($meta['HORAS_raw'] ?? ($meta['HORAS'] ?? null))
        );
        $meta = $this->setMetaIfMissing(
            $meta,
            'casa_noiva_chegada',
            $this->normalizeTimeValue($meta['HORAS2'] ?? ($meta['HORAS2_raw'] ?? null))
        );
        $meta = $this->setMetaIfMissing(
            $meta,
            'casa_noivo_saida',
            $this->normalizeTimeValue($this->groom_departure_time_raw ?? ($meta['sair noivo'] ?? ($meta['SAIR_NOIVO_raw'] ?? null)))
        );
        $meta = $this->setMetaIfMissing(
            $meta,
            'casa_noiva_saida',
            $this->normalizeTimeValue($this->bride_departure_time_raw ?? ($meta['sair noiva'] ?? ($meta['SAIR_NOIVA_raw'] ?? null)))
        );
        $meta = $this->setMetaIfMissing($meta, 'igreja_local', $this->location ?? ($meta['LOCAL'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'igreja_localidade', $this->city ?? ($meta['LOCALIDADE'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'quinta_local', $meta['ALMOÇO'] ?? ($meta['Almoço 1'] ?? null));
        if (! array_key_exists('quinta_local', $meta)) {
            $meta = $this->setMetaIfMissing($meta, 'quinta_local', $this->location ?? null);
        }
        $meta = $this->setMetaIfMissing($meta, 'almoco_localidade', $this->city ?? null);
        $meta = $this->setMetaIfMissing(
            $meta,
            'numero_convidados',
            $this->normalizeGuestCount($this->guest_count ?? ($meta['Nº CONVIDADOS'] ?? null))
        );
        $meta = $this->setMetaIfMissing(
            $meta,
            'data_entrega',
            $this->formatDateValue($this->delivery_date ?? ($meta['DATA ENTREGA'] ?? null))
        );
        $meta = $this->setMetaIfMissing(
            $meta,
            'preco_base',
            $this->normalizeMoneyValue($meta['PRECO_BASE_raw'] ?? ($meta['PRECO_raw'] ?? null))
        );
        $meta = $this->setMetaIfMissing(
            $meta,
            'estar_na_loja_as',
            $this->normalizeTimeValue(
                $this->store_time_raw
                ?? ($meta['Estar na Loja ás:'] ?? null)
            )
        );
        $meta = $this->setMetaIfMissing($meta, 'tipo_pacote', $meta['Tipo de Serviço'] ?? null);

        $meta = $this->setMetaIfMissing($meta, 'servico_num_profissionais', $meta['Nº de Profissionais'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'servico_condicoes_minimas', $meta['condições minimas de trabalho'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'servico_prazo_entrega', $meta['prazo de entrega'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'servico_tela', $meta['Tela'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'servico_musicas', $meta['Musicas'] ?? ($meta['Musicas2'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_usb', $meta['Pen'] ?? null);
        $meta = $this->setMetaIfMissing($meta, 'servico_extras', $meta['Extras'] ?? ($meta['extra'] ?? ($meta['acrescimos'] ?? null)));

        $meta = $this->setMetaIfMissing($meta, 'servico_save_the_date', $this->parseLegacyBool($meta['Save the Date 1'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_projectar_love_story', $this->parseLegacyBool($meta['projectar love story'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_combo_beleza_love_story', $this->parseLegacyBool($meta['Combo Beleza Love Story'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_combo_beleza_ttd', $this->parseLegacyBool($meta['Combo Beleza TTD'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_same_day_edit', $this->parseLegacyBool($meta['Same Day Edit'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_projectar_same_day_edit', $this->parseLegacyBool($meta['projectar same day edite'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_galeria_digital_convidados', $this->parseLegacyBool($meta['galeria digital com fotos de convidados'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_foto_lembranca_qr', $this->parseLegacyBool($meta['Foto Lembrança QR Code'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_impressao_100_11x22_7', $this->parseLegacyBool($meta['Impressão de 100 fotos 15x22,7'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_video_depois_do_sim', $this->parseLegacyBool($meta['Video depois do Sim'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_drone', $this->parseLegacyBool($meta['Drone'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_album_convidados', $this->legacyTruthy($meta['Album dos Convidados:'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_album_digital', $this->legacyTruthy($meta['Album dos noivos:'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'servico_albuns_40_20', $this->legacyTruthy($meta['albuns_pais'] ?? null));
        $meta = $this->setMetaIfMissing($meta, 'equipa_de_trabalho', $meta['EQUIPA DE TRABALHO'] ?? null);

        $meta = $this->mergeLegacyBatizadoMeta($meta);

        return $meta;
    }

    private function mergeLegacyBatizadoMeta(array $meta): array
    {
        $type = Str::of((string) ($this->event_type ?? $this->service_raw ?? ''))
            ->lower()
            ->toString();
        if (! str_contains($type, 'batiz')) {
            return $meta;
        }

        $meta = $this->setMetaIfMissing($meta, 'pai_nome', $this->groom_name ?? null);
        $meta = $this->setMetaIfMissing($meta, 'mae_nome', $this->bride_name ?? null);
        $meta = $this->setMetaIfMissing($meta, 'bebe_nome', $meta['BEBE'] ?? ($meta['BEBÉ'] ?? null));

        $contactoPai = $this->mergeContacts([
            $this->groom_phone ?? null,
            $meta['TELEF.'] ?? null,
            $meta['Telemovel noivo'] ?? null,
            $meta['contacto_pais'] ?? null,
        ]);
        $contactoMae = $this->mergeContacts([
            $this->bride_phone ?? null,
            $meta['TELEF2'] ?? null,
            $meta['Telemovel noiva'] ?? null,
            $meta['contacto_pais_2'] ?? null,
        ]);
        $meta = $this->setMetaIfMissing($meta, 'contacto_pai', $contactoPai);
        $meta = $this->setMetaIfMissing($meta, 'contacto_mae', $contactoMae);

        $contact = $this->mergeContacts([
            $meta['contacto_pai'] ?? null,
            $meta['contacto_mae'] ?? null,
            $meta['contacto_pais'] ?? null,
            $meta['contacto_pais_2'] ?? null,
        ]);
        $meta = $this->setMetaIfMissing($meta, 'contacto_pais', $contact);

        $instagram = $this->mergeContacts([
            $meta['Instagram'] ?? null,
            $meta['Instagram2'] ?? null,
        ]);
        $meta = $this->setMetaIfMissing($meta, 'instagram_pais', $instagram);

        return $meta;
    }

    private function setMetaIfMissing(array $meta, string $key, $value): array
    {
        if (array_key_exists($key, $meta)) {
            return $meta;
        }
        if ($value === null || $value === '') {
            return $meta;
        }
        $meta[$key] = $value;
        return $meta;
    }

    private function parseLegacyBool($value): ?bool
    {
        if ($value === null || $value === '') {
            return null;
        }
        if (is_bool($value)) {
            return $value;
        }
        if (is_numeric($value)) {
            return ((int) $value) !== 0;
        }
        $text = strtolower(trim((string) $value));
        if ($text === '') {
            return null;
        }
        if (in_array($text, ['sim', 's', 'yes', 'y', 'true', '1'], true)) {
            return true;
        }
        if (in_array($text, ['nao', 'não', 'n', 'no', 'false', '0'], true)) {
            return false;
        }
        return null;
    }

    private function legacyTruthy($value): ?bool
    {
        if ($value === null || $value === '') {
            return null;
        }
        if (is_bool($value)) {
            return $value;
        }
        if (is_numeric($value)) {
            return (float) $value > 0;
        }
        $text = strtolower(trim((string) $value));
        if ($text === '') {
            return null;
        }
        if (in_array($text, ['nao', 'não', 'n', 'no', 'false', '0'], true)) {
            return false;
        }
        return true;
    }

    private function mergeContacts(array $values): ?string
    {
        $parts = [];
        foreach ($values as $value) {
            if ($value === null) {
                continue;
            }
            $text = trim((string) $value);
            if ($text === '') {
                continue;
            }
            $parts[] = $text;
        }
        if (! $parts) {
            return null;
        }
        $parts = array_values(array_unique($parts));
        return implode(' / ', $parts);
    }

    private function normalizeTimeValue($value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        $text = trim((string) $value);
        if ($text === '') {
            return null;
        }
        $text = str_ireplace('h', ':', $text);
        $text = str_replace([',', '.'], ':', $text);
        if (preg_match('/^\\d{1,2}:$/', $text)) {
            $text .= '00';
        }
        if (preg_match('/^\\d{1,2}$/', $text)) {
            $hour = (int) $text;
            if ($hour >= 0 && $hour <= 23) {
                return sprintf('%02d:00', $hour);
            }
        }
        if (preg_match('/^(\\d{1,2}):(\\d{2})$/', $text, $m)) {
            $hour = (int) $m[1];
            $min = (int) $m[2];
            if ($hour >= 0 && $hour <= 23 && $min >= 0 && $min <= 59) {
                return sprintf('%02d:%02d', $hour, $min);
            }
        }
        if (preg_match('/(\\d{1,2}):(\\d{2})/', $text, $m)) {
            $hour = (int) $m[1];
            $min = (int) $m[2];
            if ($hour >= 0 && $hour <= 23 && $min >= 0 && $min <= 59) {
                return sprintf('%02d:%02d', $hour, $min);
            }
        }
        if (preg_match('/\\b(\\d{1,2})\\b/', $text, $m)) {
            $hour = (int) $m[1];
            if ($hour >= 0 && $hour <= 23) {
                return sprintf('%02d:00', $hour);
            }
        }
        return null;
    }

    private function normalizeGuestCount($value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }
        $num = null;
        if (is_numeric($value)) {
            $num = (int) round((float) $value);
        } else {
            $text = trim((string) $value);
            if ($text === '') {
                return null;
            }
            $text = str_replace(',', '.', $text);
            if (preg_match('/^\\d+(\\.\\d+)?$/', $text)) {
                $num = (int) round((float) $text);
            } else {
                $digits = preg_replace('/\\D+/', '', $text);
                if ($digits === '') {
                    return null;
                }
                $num = (int) $digits;
            }
        }
        while ($num >= 1000 && $num % 10 === 0) {
            $num = (int) ($num / 10);
        }
        if ($num >= 500 && $num % 10 === 0) {
            $candidate = (int) ($num / 10);
            if ($candidate > 0 && $candidate <= 500) {
                $num = $candidate;
            }
        }
        return $num;
    }

    private function normalizeMoneyValue($value): ?float
    {
        if ($value === null || $value === '') {
            return null;
        }
        if (is_numeric($value)) {
            return (float) $value;
        }
        $text = strtolower(trim((string) $value));
        if ($text === '') {
            return null;
        }
        $text = str_replace(['€', 'eur', 'euros'], '', $text);
        if (! preg_match('/\\d+(?:[\\.,]\\d{3})*(?:[\\.,]\\d+)?/', $text, $m)) {
            return null;
        }
        $num = $m[0];
        if (str_contains($num, ',') && str_contains($num, '.')) {
            if (strrpos($num, ',') > strrpos($num, '.')) {
                $num = str_replace('.', '', $num);
                $num = str_replace(',', '.', $num);
            } else {
                $num = str_replace(',', '', $num);
            }
        } elseif (str_contains($num, ',')) {
            $num = str_replace(',', '.', $num);
        }
        if (! is_numeric($num)) {
            return null;
        }
        return (float) $num;
    }

    private function formatDateValue($value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        if ($value instanceof Carbon) {
            return $value->toDateString();
        }
        if ($value instanceof \DateTimeInterface) {
            return Carbon::instance($value)->toDateString();
        }
        $text = trim((string) $value);
        if ($text === '') {
            return null;
        }
        try {
            $parsed = Carbon::parse($text, null);
            return $parsed->toDateString();
        } catch (\Throwable $e) {
            return null;
        }
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function photos(): HasMany
    {
        return $this->hasMany(Photo::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function staff(): HasMany
    {
        return $this->hasMany(EventStaff::class);
    }

    public function invitations(): HasMany
    {
        return $this->hasMany(EventInvitation::class);
    }

    public function scopeVisibleTo($query, User $user)
    {
        if ($user->hasPermission('events.view.all')) {
            return $query;
        }
        if (! in_array($user->role, ['photographer', 'staff'], true)) {
            return $query;
        }

        $username = Str::of((string) $user->username)->ascii()->lower()->toString();
        $initials = '';
        if (! empty($user->name)) {
            $parts = preg_split('/\s+/', trim((string) $user->name));
            $first = $parts[0] ?? '';
            $last = $parts[count($parts) - 1] ?? $first;
            if ($first !== '' && $last !== '') {
                $initials = Str::of(mb_substr($first, 0, 1).mb_substr($last, 0, 1))->ascii()->lower()->toString();
            }
        }

        return $query->where(function ($inner) use ($user, $username, $initials) {
            $inner->whereHas('staff', function ($q) use ($user) {
                $q->where('user_id', $user->id);
            });
            if ($username !== '') {
                $inner->orWhereRaw(
                    "LOWER(JSON_UNQUOTE(JSON_EXTRACT(event_meta, '$.equipa_de_trabalho'))) LIKE ?",
                    ['%'.$username.'%']
                );
                $inner->orWhereRaw(
                    "LOWER(JSON_UNQUOTE(JSON_EXTRACT(event_meta, '$.\"EQUIPA DE TRABALHO\"'))) LIKE ?",
                    ['%'.$username.'%']
                );
            }
            if ($initials !== '') {
                $inner->orWhereRaw(
                    "LOWER(JSON_UNQUOTE(JSON_EXTRACT(event_meta, '$.equipa_de_trabalho'))) LIKE ?",
                    ['%'.$initials.'%']
                );
                $inner->orWhereRaw(
                    "LOWER(JSON_UNQUOTE(JSON_EXTRACT(event_meta, '$.\"EQUIPA DE TRABALHO\"'))) LIKE ?",
                    ['%'.$initials.'%']
                );
            }
        });
    }
}
