@extends('layouts.app')
@section('content')
<div class="flex justify-between items-center mb-4">
    <h1 class="text-xl font-semibold">Clientes</h1>
    <a href="{{ route('clients.create') }}" class="bg-black text-white px-3 py-2 rounded">Novo</a>
</div>

<form class="mb-4">
    <input type="text" name="q" value="{{ $q }}" placeholder="Pesquisar nome, email, telefone" class="border rounded px-3 py-2 w-full">
</form>

<div class="bg-white rounded shadow overflow-hidden">
    <table class="w-full text-sm">
        <thead class="bg-gray-100">
            <tr>
                <th class="p-2 text-left">Nome</th>
                <th class="p-2 text-left">Email</th>
                <th class="p-2 text-left">Telefone</th>
                <th class="p-2 text-center">Ações</th>
            </tr>
        </thead>
        <tbody>
        @foreach($clients as $client)
            <tr class="border-t">
                <td class="p-2">{{ $client->name }}</td>
                <td class="p-2">{{ $client->email }}</td>
                <td class="p-2">{{ $client->phone }}</td>
                <td class="p-2 text-center">
                    <div class="flex items-center justify-center gap-2">
                        <a class="text-blue-600" href="{{ route('clients.show', $client) }}">Ver</a>
                        <a class="text-blue-600" href="{{ route('clients.edit', $client) }}">Editar</a>
                        <form method="post" action="{{ route('clients.destroy', $client) }}" onsubmit="return confirm('Remover cliente?');">
                            @csrf
                            @method('DELETE')
                            <button class="text-red-600">Apagar</button>
                        </form>
                    </div>
                </td>
            </tr>
        @endforeach
        </tbody>
    </table>
</div>
<div class="mt-3">{{ $clients->links() }}</div>
@endsection
