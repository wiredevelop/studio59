@extends('layouts.app')
@section('page_title', 'Utilizadores')
@section('page_subtitle', 'Equipa e permissões')
@section('page_actions')
    @if(auth()->user()?->hasPermission('users.create'))
        <a href="{{ route('users.create') }}" class="desk-btn primary">Novo utilizador</a>
    @endif
@endsection
@section('content')
<div class="desk-card overflow-x-auto">
    <table class="desk-table">
        <thead>
            <tr>
                <th class="p-2 text-left">Nome</th>
                <th class="p-2 text-left">Username</th>
                <th class="p-2 text-left">Email</th>
                <th class="p-2 text-left">Role</th>
                <th class="p-2 text-left">Ações</th>
            </tr>
        </thead>
        <tbody>
        @foreach($users as $user)
            <tr>
                <td class="p-2">{{ $user->name }}</td>
                <td class="p-2">{{ $user->username ?: '-' }}</td>
                <td class="p-2">{{ $user->email }}</td>
                <td class="p-2">{{ $user->role }}</td>
                <td class="p-2 flex gap-3">
                    @if(auth()->user()?->hasPermission('users.update'))
                        <a class="desk-btn" href="{{ route('users.edit', $user) }}">Editar</a>
                    @endif
                    @if(auth()->user()?->hasPermission('users.delete'))
                        <form method="post" action="{{ route('users.destroy', $user) }}" onsubmit="return confirm('Apagar utilizador?');">
                            @csrf
                            @method('DELETE')
                            <button class="desk-btn">Apagar</button>
                        </form>
                    @endif
                    @unless(auth()->user()?->hasPermission('users.update') || auth()->user()?->hasPermission('users.delete'))
                        <span class="text-sm text-gray-400">Sem ações</span>
                    @endunless
                </td>
            </tr>
        @endforeach
        </tbody>
    </table>
</div>

<div class="mt-3">{{ $users->links() }}</div>
@endsection
