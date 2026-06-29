@extends('layouts.app')
@section('page_title', 'Tipos de serviço')
@section('page_subtitle', 'Gerir fichas e templates PDF por tipo de serviço')
@section('page_actions')
    <a href="{{ route('service-templates.create') }}" class="desk-btn primary">Novo tipo</a>
@endsection
@section('content')
<div class="desk-card overflow-hidden">
    <table class="min-w-full text-sm">
        <thead class="bg-gray-50 text-left">
            <tr>
                <th class="px-4 py-3">Tipo</th>
                <th class="px-4 py-3">Slug</th>
                <th class="px-4 py-3">Ativo</th>
                <th class="px-4 py-3">Eventos</th>
                <th class="px-4 py-3">Campos</th>
                <th class="px-4 py-3"></th>
            </tr>
        </thead>
        <tbody>
            @forelse($templates as $template)
                <tr class="border-t">
                    <td class="px-4 py-3">
                        <div class="font-medium">{{ $template->name }}</div>
                        @if($template->description)
                            <div class="text-xs text-gray-500">{{ $template->description }}</div>
                        @endif
                    </td>
                    <td class="px-4 py-3 font-mono">{{ $template->slug }}</td>
                    <td class="px-4 py-3">{{ $template->is_active ? 'Sim' : 'Não' }}</td>
                    <td class="px-4 py-3">{{ $template->events_count }}</td>
                    <td class="px-4 py-3">{{ is_array($template->fields) ? count($template->fields) : 0 }}</td>
                    <td class="px-4 py-3">
                        <div class="flex justify-end gap-2">
                            <a href="{{ route('service-templates.edit', $template) }}" class="desk-btn">Editar</a>
                            <form method="post" action="{{ route('service-templates.destroy', $template) }}" onsubmit="return confirm('Apagar este tipo de serviço?');">
                                @csrf
                                @method('DELETE')
                                <button class="desk-btn" {{ $template->events_count > 0 ? 'disabled' : '' }}>Apagar</button>
                            </form>
                        </div>
                    </td>
                </tr>
            @empty
                <tr>
                    <td colspan="6" class="px-4 py-6 text-center text-gray-500">Sem tipos de serviço configurados.</td>
                </tr>
            @endforelse
        </tbody>
    </table>
</div>
@endsection
