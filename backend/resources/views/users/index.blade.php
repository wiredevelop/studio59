@extends('layouts.app')
@section('content')
<div class="flex items-center justify-between mb-4">
    <h1 class="text-xl font-semibold">Utilizadores</h1>
    <a href="{{ route('users.create') }}" class="bg-black text-white px-3 py-2 rounded">Novo utilizador</a>
</div>

<div class="bg-white rounded shadow overflow-x-auto">
    <table class="w-full text-sm">
        <thead class="bg-gray-100">
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
            <tr class="border-t">
                <td class="p-2">{{ $user->name }}</td>
                <td class="p-2">{{ $user->username ?: '-' }}</td>
                <td class="p-2">{{ $user->email }}</td>
                <td class="p-2">{{ $user->role }}</td>
                <td class="p-2 flex gap-3">
                    <a class="text-blue-600" href="{{ route('users.edit', $user) }}">Editar</a>
                    <form method="post" action="{{ route('users.destroy', $user) }}" onsubmit="return confirm('Apagar utilizador?');">
                        @csrf
                        @method('DELETE')
                        <button class="text-red-600">Apagar</button>
                    </form>
                </td>
            </tr>
        @endforeach
        </tbody>
    </table>
</div>

<div class="mt-3">{{ $users->links() }}</div>
@endsection
