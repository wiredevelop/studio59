@php
    use App\Support\ServiceTemplateCatalog;

    $meta = is_array($meta ?? null) ? $meta : [];
    $groups = ServiceTemplateCatalog::groupedFields($serviceTemplate ?? null, $forPdf ?? false);
@endphp

@foreach($groups as $group)
    @php
        $rows = collect($group['fields'])->map(function ($field) use ($event, $meta) {
            $value = $field['source'] === 'event'
                ? data_get($event, $field['key'])
                : ($meta[$field['key']] ?? null);

            if (is_bool($value)) {
                $value = $value ? 'Sim' : 'Não';
            }

            if ($value === null || $value === '') {
                return null;
            }

            return [
                'label' => $field['label'],
                'value' => $value,
            ];
        })->filter()->values();
    @endphp
    @if($rows->isNotEmpty())
        <div class="{{ ($forPdf ?? false) ? 'sheet-section' : 'bg-white border rounded p-4 mb-4' }}">
            <div class="{{ ($forPdf ?? false) ? 'section-title' : 'text-sm font-semibold mb-2' }}">{{ $group['title'] }}</div>
            <div class="{{ ($forPdf ?? false) ? 'kv-grid' : 'grid md:grid-cols-2 gap-2 text-sm' }}">
                @foreach($rows as $row)
                    <div class="{{ ($forPdf ?? false) ? 'kv-row' : '' }}">
                        <strong>{{ $row['label'] }}:</strong>
                        <span>{{ $row['value'] }}</span>
                    </div>
                @endforeach
            </div>
        </div>
    @endif
@endforeach
