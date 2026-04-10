@extends('layouts.app')
@section('page_title', 'Utilizadores')
@section('page_subtitle', 'Equipa e permissões')
@section('page_actions')
    <a href="{{ route('users.create') }}" class="desk-btn primary">Novo utilizador</a>
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
                    <a class="desk-btn" href="{{ route('users.edit', $user) }}">Editar</a>
                    <form method="post" action="{{ route('users.destroy', $user) }}" onsubmit="return confirm('Apagar utilizador?');">
                        @csrf
                        @method('DELETE')
                        <button class="desk-btn">Apagar</button>
                    </form>
                </td>
            </tr>
        @endforeach
        </tbody>
    </table>
</div>

<div class="mt-3">{{ $users->links() }}</div>
@endsection
