@php
    use App\Support\ServiceTemplateCatalog;

    $meta = is_array($meta ?? null) ? $meta : [];
    $eventModel = $event ?? null;
    $groups = ServiceTemplateCatalog::groupedFields($serviceTemplate ?? null);
@endphp

@foreach($groups as $group)
    <div class="event-card space-y-3">
        <div class="font-semibold">{{ $group['title'] }}</div>
        <div class="grid md:grid-cols-2 gap-3">
            @foreach($group['fields'] as $field)
                @php
                    $isEventField = $field['source'] === 'event';
                    $inputName = $isEventField ? $field['key'] : 'event_meta['.$field['key'].']';
                    $oldKey = $isEventField ? $field['key'] : 'event_meta.'.$field['key'];
                    $currentValue = $isEventField
                        ? old($oldKey, data_get($eventModel, $field['key']))
                        : old($oldKey, $meta[$field['key']] ?? null);
                    $widthClass = ServiceTemplateCatalog::widthClass($field['width']);
                @endphp
                <div class="{{ $widthClass }}">
                    <label class="block text-sm">{{ $field['label'] }}</label>
                    @if($field['type'] === 'textarea')
                        <textarea name="{{ $inputName }}" rows="3" class="border p-2 rounded w-full" placeholder="{{ $field['placeholder'] }}" {{ $field['required'] ? 'required' : '' }}>{{ $currentValue }}</textarea>
                    @elseif($field['type'] === 'select')
                        <select name="{{ $inputName }}" class="border p-2 rounded w-full" {{ $field['required'] ? 'required' : '' }}>
                            <option value="">Selecione</option>
                            @foreach($field['options'] as $option)
                                <option value="{{ $option }}" {{ (string) $currentValue === (string) $option ? 'selected' : '' }}>{{ $option }}</option>
                            @endforeach
                        </select>
                    @elseif($field['type'] === 'checkbox')
                        <label class="flex items-center gap-2 border p-2 rounded w-full">
                            <input type="hidden" name="{{ $inputName }}" value="0">
                            <input type="checkbox" name="{{ $inputName }}" value="1" {{ !empty($currentValue) ? 'checked' : '' }}>
                            <span>{{ $field['label'] }}</span>
                        </label>
                    @else
                        <input
                            type="{{ $field['type'] === 'email' ? 'email' : ($field['type'] === 'number' ? 'number' : ($field['type'] === 'date' ? 'date' : ($field['type'] === 'time' ? 'time' : 'text'))) }}"
                            name="{{ $inputName }}"
                            value="{{ $currentValue }}"
                            class="border p-2 rounded w-full"
                            placeholder="{{ $field['placeholder'] }}"
                            {{ $field['type'] === 'number' ? 'step=1' : '' }}
                            {{ $field['required'] ? 'required' : '' }}
                        >
                    @endif
                </div>
            @endforeach
        </div>
    </div>
@endforeach
