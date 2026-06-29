@php
    $field = is_array($field) ? $field : [];
    $optionsText = old("fields.$index.options_text", implode("\n", (array) ($field['options'] ?? [])));
@endphp
<div class="event-card event-subcard space-y-3" data-field-row>
    <div class="flex items-center justify-between gap-3">
        <div class="font-semibold text-sm">Campo</div>
        <button type="button" data-remove-field class="desk-btn">Remover</button>
    </div>
    <div class="grid md:grid-cols-6 gap-3">
        <div>
            <label class="block text-xs">Secção</label>
            <input name="fields[{{ $index }}][section]" value="{{ old("fields.$index.section", $field['section'] ?? 'Ficha') }}" class="border p-2 rounded w-full">
        </div>
        <div>
            <label class="block text-xs">Ord. secção</label>
            <input type="number" name="fields[{{ $index }}][section_order]" value="{{ old("fields.$index.section_order", $field['section_order'] ?? 100) }}" class="border p-2 rounded w-full">
        </div>
        <div>
            <label class="block text-xs">Chave</label>
            <input name="fields[{{ $index }}][key]" value="{{ old("fields.$index.key", $field['key'] ?? '') }}" class="border p-2 rounded w-full">
        </div>
        <div>
            <label class="block text-xs">Label</label>
            <input name="fields[{{ $index }}][label]" value="{{ old("fields.$index.label", $field['label'] ?? '') }}" class="border p-2 rounded w-full">
        </div>
        <div>
            <label class="block text-xs">Origem</label>
            <select name="fields[{{ $index }}][source]" class="border p-2 rounded w-full">
                <option value="meta" {{ old("fields.$index.source", $field['source'] ?? 'meta') === 'meta' ? 'selected' : '' }}>event_meta</option>
                <option value="event" {{ old("fields.$index.source", $field['source'] ?? '') === 'event' ? 'selected' : '' }}>events.*</option>
            </select>
        </div>
        <div>
            <label class="block text-xs">Tipo</label>
            <select name="fields[{{ $index }}][type]" class="border p-2 rounded w-full">
                @foreach(['text', 'textarea', 'number', 'date', 'time', 'checkbox', 'select', 'email'] as $type)
                    <option value="{{ $type }}" {{ old("fields.$index.type", $field['type'] ?? 'text') === $type ? 'selected' : '' }}>{{ $type }}</option>
                @endforeach
            </select>
        </div>
    </div>
    <div class="grid md:grid-cols-5 gap-3">
        <div>
            <label class="block text-xs">Ordem</label>
            <input type="number" name="fields[{{ $index }}][order]" value="{{ old("fields.$index.order", $field['order'] ?? 100) }}" class="border p-2 rounded w-full">
        </div>
        <div>
            <label class="block text-xs">Largura</label>
            <select name="fields[{{ $index }}][width]" class="border p-2 rounded w-full">
                @foreach(['half', 'full', 'third'] as $width)
                    <option value="{{ $width }}" {{ old("fields.$index.width", $field['width'] ?? 'half') === $width ? 'selected' : '' }}>{{ $width }}</option>
                @endforeach
            </select>
        </div>
        <div class="md:col-span-2">
            <label class="block text-xs">Placeholder</label>
            <input name="fields[{{ $index }}][placeholder]" value="{{ old("fields.$index.placeholder", $field['placeholder'] ?? '') }}" class="border p-2 rounded w-full">
        </div>
        <div class="grid grid-cols-3 gap-2 items-end">
            <label class="flex items-center gap-2 text-xs">
                <input type="hidden" name="fields[{{ $index }}][required]" value="0">
                <input type="checkbox" name="fields[{{ $index }}][required]" value="1" {{ old("fields.$index.required", $field['required'] ?? false) ? 'checked' : '' }}>
                <span>Obrig.</span>
            </label>
            <label class="flex items-center gap-2 text-xs">
                <input type="hidden" name="fields[{{ $index }}][show_in_form]" value="0">
                <input type="checkbox" name="fields[{{ $index }}][show_in_form]" value="1" {{ old("fields.$index.show_in_form", array_key_exists('show_in_form', $field) ? $field['show_in_form'] : true) ? 'checked' : '' }}>
                <span>Form</span>
            </label>
            <label class="flex items-center gap-2 text-xs">
                <input type="hidden" name="fields[{{ $index }}][show_in_pdf]" value="0">
                <input type="checkbox" name="fields[{{ $index }}][show_in_pdf]" value="1" {{ old("fields.$index.show_in_pdf", $field['show_in_pdf'] ?? true) ? 'checked' : '' }}>
                <span>PDF</span>
            </label>
        </div>
    </div>
    <div>
        <label class="block text-xs">Opções</label>
        <textarea name="fields[{{ $index }}][options_text]" rows="2" class="border p-2 rounded w-full" placeholder="Uma por linha ou separadas por vírgula">{{ $optionsText }}</textarea>
    </div>
</div>
