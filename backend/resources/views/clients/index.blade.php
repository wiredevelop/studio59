@extends('layouts.app')
@section('page_title', 'Clientes')
@section('page_subtitle', 'Gestão de clientes e contactos')
@section('page_actions')
    @if(auth()->user()?->hasPermission('clients.create'))
        <a href="{{ route('clients.create') }}" class="desk-btn primary">Novo cliente</a>
    @endif
@endsection
@section('content')
<form class="desk-card desk-toolbar" method="get">
    <input type="text" name="q" value="{{ $q }}" placeholder="Pesquisar nome, email, telefone" class="desk-input">
    <button class="desk-btn">Pesquisar</button>
</form>

<div class="desk-card overflow-x-auto">
    <table class="desk-table">
        <thead>
            <tr>
                <th class="p-2 text-left">Nome</th>
                <th class="p-2 text-left">Email</th>
                <th class="p-2 text-left">Telefone</th>
                <th class="p-2 text-center">Ações</th>
            </tr>
        </thead>
        <tbody>
        @foreach($clients as $client)
            <tr>
                <td class="p-2">{{ $client->name }}</td>
                <td class="p-2">{{ $client->email }}</td>
                <td class="p-2">{{ $client->phone }}</td>
                <td class="p-2 text-center">
                    <div class="flex items-center justify-center gap-2">
                        @if(auth()->user()?->hasPermission('clients.view'))
                            <a class="desk-btn" href="{{ route('clients.show', $client) }}">Ver</a>
                        @endif
                        @if(auth()->user()?->hasPermission('clients.update'))
                            <a class="desk-btn" href="{{ route('clients.edit', $client) }}">Editar</a>
                        @endif
                        @if(auth()->user()?->hasPermission('clients.delete'))
                            <form method="post" action="{{ route('clients.destroy', $client) }}" onsubmit="return confirm('Remover cliente?');">
                                @csrf
                                @method('DELETE')
                                <button class="desk-btn">Apagar</button>
                            </form>
                        @endif
                        @unless(auth()->user()?->hasPermission('clients.view') || auth()->user()?->hasPermission('clients.update') || auth()->user()?->hasPermission('clients.delete'))
                            <span class="text-sm text-gray-400">Sem ações</span>
                        @endunless
                    </div>
                </td>
            </tr>
        @endforeach
        </tbody>
    </table>
</div>
<div class="mt-3">{{ $clients->links() }}</div>
@endsection
