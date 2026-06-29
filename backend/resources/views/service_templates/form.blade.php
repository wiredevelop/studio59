@extends('layouts.app')
@section('page_title', $isEdit ? 'Editar tipo de serviço' : 'Novo tipo de serviço')
@section('page_subtitle', 'Configurar campos da ficha e PDF')
@section('page_actions')
    <a href="{{ route('service-templates.index') }}" class="desk-btn">Voltar</a>
@endsection
@section('content')
@php
    $fields = old('fields', is_array($template->fields) ? $template->fields : []);
    $settings = old('name_fields', implode(', ', (array) data_get($template->settings, 'name_fields', [])));
@endphp
<form method="post" action="{{ $isEdit ? route('service-templates.update', $template) : route('service-templates.store') }}" class="event-form space-y-6">
    @csrf
    @if($isEdit)
        @method('PUT')
    @endif

    <div class="event-card space-y-3">
        <div class="font-semibold">Dados base</div>
        <div class="grid md:grid-cols-4 gap-3">
            <div>
                <label class="block text-sm">Slug</label>
                <input name="slug" value="{{ old('slug', $template->slug) }}" class="border p-2 rounded w-full" required>
            </div>
            <div>
                <label class="block text-sm">Nome</label>
                <input name="name" value="{{ old('name', $template->name) }}" class="border p-2 rounded w-full" required>
            </div>
            <div>
                <label class="block text-sm">Ordem</label>
                <input type="number" min="0" name="sort_order" value="{{ old('sort_order', $template->sort_order ?? 100) }}" class="border p-2 rounded w-full">
            </div>
            <label class="flex items-center gap-2 mt-6">
                <input type="hidden" name="is_active" value="0">
                <input type="checkbox" name="is_active" value="1" {{ old('is_active', $template->is_active ?? true) ? 'checked' : '' }}>
                <span>Ativo</span>
            </label>
        </div>
        <div>
            <label class="block text-sm">Descrição</label>
            <input name="description" value="{{ old('description', $template->description) }}" class="border p-2 rounded w-full">
        </div>
        <div class="grid md:grid-cols-2 gap-3">
            <div>
                <label class="block text-sm">Campos para gerar nome</label>
                <input name="name_fields" value="{{ $settings }}" class="border p-2 rounded w-full" placeholder="Ex: noivo_nome, noiva_nome">
            </div>
            <div>
                <label class="block text-sm">Separador do nome</label>
                <input name="name_joiner" value="{{ old('name_joiner', data_get($template->settings, 'name_joiner', ' & ')) }}" class="border p-2 rounded w-full" placeholder=" & ">
            </div>
        </div>
    </div>

    <div class="event-card space-y-3">
        <div class="flex items-center justify-between gap-3">
            <div class="font-semibold">Campos da ficha</div>
            <button type="button" id="add-field-row" class="desk-btn">Adicionar campo</button>
        </div>
        <div id="field-rows" class="space-y-3">
            @foreach($fields as $index => $field)
                @include('service_templates.partials.field-row', ['index' => $index, 'field' => $field])
            @endforeach
        </div>
    </div>

    <button class="bg-black text-white px-3 py-2 rounded">Guardar</button>
</form>

<template id="field-row-template">
    @include('service_templates.partials.field-row', ['index' => '__INDEX__', 'field' => []])
</template>

<script>
    document.addEventListener('DOMContentLoaded', () => {
        const container = document.getElementById('field-rows');
        const addButton = document.getElementById('add-field-row');
        const template = document.getElementById('field-row-template');
        let counter = container.querySelectorAll('[data-field-row]').length;

        const bindRemove = (scope) => {
            scope.querySelectorAll('[data-remove-field]').forEach((button) => {
                button.addEventListener('click', () => {
                    button.closest('[data-field-row]')?.remove();
                });
            });
        };

        bindRemove(document);

        addButton?.addEventListener('click', () => {
            const html = template.innerHTML.replaceAll('__INDEX__', String(counter++));
            const wrapper = document.createElement('div');
            wrapper.innerHTML = html.trim();
            const row = wrapper.firstElementChild;
            if (!row) return;
            container.appendChild(row);
            bindRemove(row);
        });
    });
</script>
@endsection
