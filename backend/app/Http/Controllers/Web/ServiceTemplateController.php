<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\ServiceTemplate;
use App\Support\ServiceTemplateCatalog;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ServiceTemplateController extends Controller
{
    public function index()
    {
        return view('service_templates.index', [
            'templates' => ServiceTemplate::query()
                ->withCount('events')
                ->orderBy('sort_order')
                ->orderBy('name')
                ->get(),
        ]);
    }

    public function create()
    {
        return view('service_templates.form', [
            'template' => new ServiceTemplate([
                'is_active' => true,
                'sort_order' => 100,
                'settings' => ['name_fields' => [], 'name_joiner' => ' & '],
                'fields' => [],
            ]),
            'isEdit' => false,
            'defaultTemplates' => collect(ServiceTemplateCatalog::defaults())->mapWithKeys(fn ($template) => [
                $template['slug'] => $template['name'],
            ])->all(),
        ]);
    }

    public function store(Request $request)
    {
        $validated = $this->validateTemplate($request);
        ServiceTemplate::create($validated);

        return redirect()->route('service-templates.index')->with('ok', 'Tipo de serviço criado.');
    }

    public function edit(ServiceTemplate $serviceTemplate)
    {
        return view('service_templates.form', [
            'template' => $serviceTemplate,
            'isEdit' => true,
            'defaultTemplates' => collect(ServiceTemplateCatalog::defaults())->mapWithKeys(fn ($template) => [
                $template['slug'] => $template['name'],
            ])->all(),
        ]);
    }

    public function update(Request $request, ServiceTemplate $serviceTemplate)
    {
        $oldSlug = $serviceTemplate->slug;
        $validated = $this->validateTemplate($request, $serviceTemplate);
        $serviceTemplate->update($validated);

        if ($oldSlug !== $serviceTemplate->slug) {
            Event::query()
                ->where('event_type', $oldSlug)
                ->update(['event_type' => $serviceTemplate->slug]);
        }

        return redirect()->route('service-templates.index')->with('ok', 'Tipo de serviço atualizado.');
    }

    public function destroy(ServiceTemplate $serviceTemplate)
    {
        $inUse = Event::query()->where('event_type', $serviceTemplate->slug)->exists();
        if ($inUse) {
            return back()->withErrors(['O tipo de serviço está a ser usado em eventos e não pode ser apagado.']);
        }

        $serviceTemplate->delete();

        return redirect()->route('service-templates.index')->with('ok', 'Tipo de serviço removido.');
    }

    private function validateTemplate(Request $request, ?ServiceTemplate $serviceTemplate = null): array
    {
        $validated = $request->validate([
            'slug' => [
                'required',
                'string',
                'max:80',
                Rule::unique('service_templates', 'slug')->ignore($serviceTemplate?->id),
            ],
            'name' => ['required', 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:255'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['nullable', 'boolean'],
            'name_fields' => ['nullable', 'string', 'max:255'],
            'name_joiner' => ['nullable', 'string', 'max:20'],
            'fields' => ['nullable', 'array'],
            'fields.*.section' => ['nullable', 'string', 'max:120'],
            'fields.*.section_order' => ['nullable', 'integer', 'min:0'],
            'fields.*.key' => ['nullable', 'string', 'max:120'],
            'fields.*.label' => ['nullable', 'string', 'max:120'],
            'fields.*.source' => ['nullable', Rule::in(['event', 'meta'])],
            'fields.*.type' => ['nullable', Rule::in(['text', 'textarea', 'number', 'date', 'time', 'checkbox', 'select', 'email'])],
            'fields.*.order' => ['nullable', 'integer', 'min:0'],
            'fields.*.width' => ['nullable', Rule::in(['full', 'half', 'third'])],
            'fields.*.placeholder' => ['nullable', 'string', 'max:255'],
            'fields.*.options_text' => ['nullable', 'string'],
            'fields.*.required' => ['nullable', 'boolean'],
            'fields.*.show_in_form' => ['nullable', 'boolean'],
            'fields.*.show_in_pdf' => ['nullable', 'boolean'],
        ]);

        $fields = [];
        foreach ((array) ($validated['fields'] ?? []) as $field) {
            $key = trim((string) ($field['key'] ?? ''));
            $label = trim((string) ($field['label'] ?? ''));
            if ($key === '' || $label === '') {
                continue;
            }
            $fields[] = [
                'section' => trim((string) ($field['section'] ?? 'Ficha')),
                'section_order' => (int) ($field['section_order'] ?? 100),
                'key' => $key,
                'label' => $label,
                'source' => ($field['source'] ?? 'meta') === 'event' ? 'event' : 'meta',
                'type' => $field['type'] ?? 'text',
                'order' => (int) ($field['order'] ?? 100),
                'width' => $field['width'] ?? 'half',
                'placeholder' => trim((string) ($field['placeholder'] ?? '')),
                'required' => ! empty($field['required']),
                'show_in_form' => array_key_exists('show_in_form', $field) ? (bool) $field['show_in_form'] : true,
                'show_in_pdf' => ! empty($field['show_in_pdf']),
                'options' => preg_split('/[\r\n,]+/', (string) ($field['options_text'] ?? '')) ?: [],
            ];
        }

        return [
            'slug' => ServiceTemplateCatalog::normalizeSlug($validated['slug']),
            'name' => trim($validated['name']),
            'description' => trim((string) ($validated['description'] ?? '')) ?: null,
            'sort_order' => (int) ($validated['sort_order'] ?? 100),
            'is_active' => $request->boolean('is_active', true),
            'settings' => [
                'name_fields' => array_values(array_filter(array_map('trim', explode(',', (string) ($validated['name_fields'] ?? ''))))),
                'name_joiner' => (string) ($validated['name_joiner'] ?? ' & '),
            ],
            'fields' => ServiceTemplateCatalog::normalizeFields($fields),
        ];
    }
}
