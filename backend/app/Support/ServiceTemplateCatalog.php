<?php

namespace App\Support;

use App\Models\ServiceTemplate;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;

class ServiceTemplateCatalog
{
    public static function defaults(): array
    {
        return [
            [
                'slug' => 'casamento',
                'name' => 'Casamento',
                'description' => 'Ficha base de casamento.',
                'sort_order' => 10,
                'is_active' => true,
                'settings' => [
                    'name_fields' => ['noivo_nome', 'noiva_nome'],
                    'name_joiner' => ' & ',
                ],
                'fields' => self::casamentoFields(),
            ],
            [
                'slug' => 'batizado',
                'name' => 'Batizado',
                'description' => 'Ficha base de batizado.',
                'sort_order' => 20,
                'is_active' => true,
                'settings' => [
                    'name_fields' => ['bebe_nome'],
                    'name_joiner' => ' ',
                ],
                'fields' => self::batizadoFields(),
            ],
            [
                'slug' => 'comunhao',
                'name' => 'Comunhão',
                'description' => 'Ficha de comunhão criada a partir dos dados importados.',
                'sort_order' => 30,
                'is_active' => true,
                'settings' => [
                    'name_fields' => ['noivo_nome'],
                    'name_joiner' => ' ',
                ],
                'fields' => self::comunhaoFields(),
            ],
            [
                'slug' => 'bodas',
                'name' => 'Bodas',
                'description' => 'Ficha de bodas criada a partir dos dados importados.',
                'sort_order' => 40,
                'is_active' => true,
                'settings' => [
                    'name_fields' => ['noivo_nome', 'noiva_nome'],
                    'name_joiner' => ' & ',
                ],
                'fields' => self::bodasFields(),
            ],
            [
                'slug' => 'aniversario',
                'name' => 'Aniversário',
                'description' => 'Ficha genérica de aniversário.',
                'sort_order' => 50,
                'is_active' => true,
                'settings' => [
                    'name_fields' => ['noivo_nome', 'nome_livre'],
                    'name_joiner' => ' ',
                ],
                'fields' => self::genericCelebrationFields('Aniversariante'),
            ],
            [
                'slug' => 'outros',
                'name' => 'Outros',
                'description' => 'Ficha genérica para serviços sem tipo específico.',
                'sort_order' => 60,
                'is_active' => true,
                'settings' => [
                    'name_fields' => ['noivo_nome', 'nome_livre'],
                    'name_joiner' => ' ',
                ],
                'fields' => self::genericCelebrationFields('Cliente'),
            ],
        ];
    }

    public static function defaultBySlug(string $slug): ?array
    {
        foreach (self::defaults() as $template) {
            if ($template['slug'] === $slug) {
                return $template;
            }
        }

        return null;
    }

    public static function normalizeSlug(?string $value): string
    {
        $slug = Str::of((string) $value)->lower()->ascii()->slug('_')->toString();

        return $slug !== '' ? $slug : 'outros';
    }

    public static function activeTemplates(): Collection
    {
        return ServiceTemplate::query()
            ->active()
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();
    }

    public static function findByType(?string $type): ?ServiceTemplate
    {
        $slug = self::normalizeSlug($type);

        return ServiceTemplate::query()
            ->where('slug', $slug)
            ->first();
    }

    public static function fieldsFor(?ServiceTemplate $template): array
    {
        $fields = $template?->fields;

        return is_array($fields) ? self::normalizeFields($fields) : [];
    }

    public static function normalizeFields(array $fields): array
    {
        return collect($fields)
            ->filter(fn ($field) => is_array($field) && ! empty($field['key']))
            ->map(function (array $field, int $index) {
                $type = in_array(($field['type'] ?? 'text'), [
                    'text', 'textarea', 'number', 'date', 'time', 'checkbox', 'select', 'email',
                ], true) ? $field['type'] : 'text';

                return [
                    'key' => (string) $field['key'],
                    'label' => trim((string) ($field['label'] ?? $field['key'])),
                    'source' => ($field['source'] ?? 'meta') === 'event' ? 'event' : 'meta',
                    'section' => trim((string) ($field['section'] ?? 'Ficha')),
                    'section_order' => (int) ($field['section_order'] ?? 100),
                    'order' => (int) ($field['order'] ?? ($index + 1)),
                    'type' => $type,
                    'width' => in_array(($field['width'] ?? 'half'), ['full', 'half', 'third'], true)
                        ? $field['width']
                        : 'half',
                    'placeholder' => trim((string) ($field['placeholder'] ?? '')),
                    'required' => ! empty($field['required']),
                    'show_in_form' => array_key_exists('show_in_form', $field) ? (bool) $field['show_in_form'] : true,
                    'show_in_pdf' => array_key_exists('show_in_pdf', $field) ? (bool) $field['show_in_pdf'] : true,
                    'options' => self::normalizeOptions($field['options'] ?? []),
                ];
            })
            ->sortBy([
                ['section_order', 'asc'],
                ['order', 'asc'],
                ['label', 'asc'],
            ])
            ->values()
            ->all();
    }

    public static function groupedFields(?ServiceTemplate $template, bool $forPdf = false): array
    {
        $fields = collect(self::fieldsFor($template))
            ->filter(fn (array $field) => $forPdf ? $field['show_in_pdf'] : $field['show_in_form'])
            ->groupBy(fn (array $field) => $field['section_order'].'|'.$field['section']);

        return $fields->map(function (Collection $group, string $key) {
            [, $title] = explode('|', $key, 2);

            return [
                'title' => $title,
                'fields' => $group->values()->all(),
            ];
        })->values()->all();
    }

    public static function buildEventName(?ServiceTemplate $template, ?string $eventType, $eventDate, array $meta, ?string $fallback = null): string
    {
        $typeLabel = $template?->name ? Str::upper($template->name) : Str::upper((string) ($eventType ?: 'Evento'));
        $settings = is_array($template?->settings) ? $template->settings : [];
        $nameKeys = array_values(array_filter((array) ($settings['name_fields'] ?? [])));
        $joiner = (string) ($settings['name_joiner'] ?? ' & ');
        $parts = [];

        foreach ($nameKeys as $key) {
            $value = trim((string) ($meta[$key] ?? ''));
            if ($value !== '') {
                $parts[] = $value;
            }
        }

        $names = implode($joiner, array_unique($parts));
        $dateLabel = $eventDate ? Carbon::parse($eventDate)->format('Y-m-d') : null;
        $result = array_values(array_filter([$typeLabel, $names, $dateLabel]));

        return $result ? implode(' - ', $result) : ($fallback ?: 'Evento');
    }

    public static function widthClass(string $width): string
    {
        return match ($width) {
            'full' => 'md:col-span-2',
            'third' => '',
            default => '',
        };
    }

    private static function normalizeOptions($options): array
    {
        if (is_string($options)) {
            $options = preg_split('/[\r\n,]+/', $options) ?: [];
        }

        return collect((array) $options)
            ->map(fn ($option) => trim((string) $option))
            ->filter()
            ->values()
            ->all();
    }

    private static function field(
        string $key,
        string $label,
        string $type = 'text',
        string $source = 'meta',
        string $section = 'Ficha',
        int $sectionOrder = 100,
        int $order = 10,
        string $width = 'half',
        bool $required = false,
        bool $showInPdf = true,
        array $options = [],
        string $placeholder = ''
    ): array {
        return compact(
            'key',
            'label',
            'type',
            'source',
            'section',
            'sectionOrder',
            'order',
            'width',
            'required',
            'showInPdf',
            'options',
            'placeholder',
        ) + [
            'section_order' => $sectionOrder,
            'show_in_form' => true,
            'show_in_pdf' => $showInPdf,
        ];
    }

    private static function casamentoFields(): array
    {
        return [
            self::field('noivo_nome', 'Nome do noivo', 'text', 'meta', 'Noivo', 10, 10, 'half', true),
            self::field('noiva_nome', 'Nome da noiva', 'text', 'meta', 'Noiva', 20, 10, 'half', true),
            self::field('noivo_contacto', 'Telemóvel do noivo', 'text', 'meta', 'Noivo', 10, 20),
            self::field('noiva_contacto', 'Telemóvel da noiva', 'text', 'meta', 'Noiva', 20, 20),
            self::field('noivo_profissao', 'Profissão do noivo', 'text', 'meta', 'Noivo', 10, 30),
            self::field('noiva_profissao', 'Profissão da noiva', 'text', 'meta', 'Noiva', 20, 30),
            self::field('noivo_instagram', 'Instagram do noivo', 'text', 'meta', 'Noivo', 10, 40),
            self::field('noiva_instagram', 'Instagram da noiva', 'text', 'meta', 'Noiva', 20, 40),
            self::field('missa_hora', 'Hora da missa', 'time', 'meta', 'Agenda', 30, 10),
            self::field('igreja_local', 'Igreja/local', 'text', 'meta', 'Agenda', 30, 20),
            self::field('igreja_localidade', 'Localidade', 'text', 'meta', 'Agenda', 30, 30),
            self::field('quinta_local', 'Refeição', 'select', 'meta', 'Agenda', 30, 40, 'half', false, true, ['Almoço', 'Jantar']),
            self::field('almoco_localidade', 'Quinta/restaurante', 'text', 'meta', 'Agenda', 30, 50),
            self::field('guest_count', 'Nº convidados', 'number', 'event', 'Produção', 40, 10),
            self::field('delivery_date', 'Data de entrega', 'date', 'event', 'Produção', 40, 20),
            self::field('equipa_de_trabalho', 'Equipa de trabalho', 'text', 'meta', 'Produção', 40, 30),
            self::field('servico_num_profissionais', 'Nº profissionais', 'number', 'meta', 'Produção', 40, 40),
            self::field('servico_extras', 'Extras', 'textarea', 'meta', 'Serviço', 50, 10, 'full'),
        ];
    }

    private static function batizadoFields(): array
    {
        return [
            self::field('bebe_nome', 'Nome do bebé', 'text', 'meta', 'Batizado', 10, 10, 'half', true),
            self::field('pai_nome', 'Nome do pai', 'text', 'meta', 'Batizado', 10, 20),
            self::field('mae_nome', 'Nome da mãe', 'text', 'meta', 'Batizado', 10, 30),
            self::field('padrinho_nome', 'Padrinho', 'text', 'meta', 'Batizado', 10, 40),
            self::field('madrinha_nome', 'Madrinha', 'text', 'meta', 'Batizado', 10, 50),
            self::field('contacto_pai', 'Contacto do pai', 'text', 'meta', 'Contactos', 20, 10),
            self::field('contacto_mae', 'Contacto da mãe', 'text', 'meta', 'Contactos', 20, 20),
            self::field('email_pais', 'Email dos pais', 'email', 'meta', 'Contactos', 20, 30),
            self::field('morada', 'Morada', 'text', 'meta', 'Agenda', 30, 10, 'full'),
            self::field('missa_hora', 'Hora da missa', 'time', 'meta', 'Agenda', 30, 20),
            self::field('igreja_local', 'Igreja/local', 'text', 'meta', 'Agenda', 30, 30),
            self::field('igreja_localidade', 'Localidade', 'text', 'meta', 'Agenda', 30, 40),
            self::field('guest_count', 'Nº convidados', 'number', 'event', 'Produção', 40, 10),
            self::field('delivery_date', 'Data de entrega', 'date', 'event', 'Produção', 40, 20),
            self::field('equipa_de_trabalho', 'Equipa de trabalho', 'text', 'meta', 'Produção', 40, 30),
            self::field('servico_extras', 'Extras', 'textarea', 'meta', 'Serviço', 50, 10, 'full'),
        ];
    }

    private static function comunhaoFields(): array
    {
        return [
            self::field('noivo_nome', 'Nome do comunicante', 'text', 'meta', 'Comunhão', 10, 10, 'half', true),
            self::field('noivo_contacto', 'Contacto principal', 'text', 'meta', 'Comunhão', 10, 20),
            self::field('noivo_filho_de_1', 'Pai', 'text', 'meta', 'Família', 20, 10),
            self::field('noiva_filho_de_1', 'Mãe', 'text', 'meta', 'Família', 20, 20),
            self::field('missa_hora', 'Hora da missa', 'time', 'meta', 'Agenda', 30, 10),
            self::field('igreja_local', 'Igreja/local', 'text', 'meta', 'Agenda', 30, 20),
            self::field('igreja_localidade', 'Localidade', 'text', 'meta', 'Agenda', 30, 30),
            self::field('address', 'Morada', 'text', 'event', 'Agenda', 30, 40, 'full'),
            self::field('guest_count', 'Nº convidados', 'number', 'event', 'Produção', 40, 10),
            self::field('delivery_date', 'Data de entrega', 'date', 'event', 'Produção', 40, 20),
            self::field('equipa_de_trabalho', 'Equipa de trabalho', 'text', 'meta', 'Produção', 40, 30),
            self::field('servico_extras', 'Observações do serviço', 'textarea', 'meta', 'Serviço', 50, 10, 'full'),
        ];
    }

    private static function bodasFields(): array
    {
        return [
            self::field('noivo_nome', 'Nome 1', 'text', 'meta', 'Casal', 10, 10, 'half', true),
            self::field('noiva_nome', 'Nome 2', 'text', 'meta', 'Casal', 10, 20, 'half', true),
            self::field('noivo_contacto', 'Contacto principal', 'text', 'meta', 'Casal', 10, 30),
            self::field('missa_hora', 'Hora da cerimónia', 'time', 'meta', 'Agenda', 20, 10),
            self::field('igreja_local', 'Cerimónia/local', 'text', 'meta', 'Agenda', 20, 20),
            self::field('igreja_localidade', 'Localidade', 'text', 'meta', 'Agenda', 20, 30),
            self::field('quinta_local', 'Refeição', 'text', 'meta', 'Agenda', 20, 40),
            self::field('guest_count', 'Nº convidados', 'number', 'event', 'Produção', 30, 10),
            self::field('delivery_date', 'Data de entrega', 'date', 'event', 'Produção', 30, 20),
            self::field('equipa_de_trabalho', 'Equipa de trabalho', 'text', 'meta', 'Produção', 30, 30),
            self::field('servico_extras', 'Observações do serviço', 'textarea', 'meta', 'Serviço', 40, 10, 'full'),
        ];
    }

    private static function genericCelebrationFields(string $mainLabel): array
    {
        return [
            self::field('noivo_nome', $mainLabel, 'text', 'meta', 'Ficha', 10, 10, 'half'),
            self::field('nome_livre', 'Nome alternativo', 'text', 'meta', 'Ficha', 10, 20, 'half'),
            self::field('noivo_contacto', 'Contacto principal', 'text', 'meta', 'Ficha', 10, 30),
            self::field('location', 'Local', 'text', 'event', 'Agenda', 20, 10),
            self::field('city', 'Localidade', 'text', 'event', 'Agenda', 20, 20),
            self::field('address', 'Morada', 'text', 'event', 'Agenda', 20, 30, 'full'),
            self::field('guest_count', 'Nº convidados', 'number', 'event', 'Produção', 30, 10),
            self::field('delivery_date', 'Data de entrega', 'date', 'event', 'Produção', 30, 20),
            self::field('equipa_de_trabalho', 'Equipa de trabalho', 'text', 'meta', 'Produção', 30, 30),
            self::field('servico_extras', 'Observações do serviço', 'textarea', 'meta', 'Serviço', 40, 10, 'full'),
        ];
    }
}
