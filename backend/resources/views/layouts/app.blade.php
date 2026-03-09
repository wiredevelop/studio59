<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59</title>
    <link rel="icon" href="/favicon.ico" sizes="any">
    <link rel="icon" href="/favicon.png" type="image/png">
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 min-h-screen">
<nav class="bg-black text-white p-4">
    <div class="max-w-7xl mx-auto flex items-center justify-between">
        <a href="{{ route('dashboard') }}" class="font-bold">Studio 59</a>
        @auth
        <div class="flex items-center gap-2">
            @if(auth()->user()->hasPermission('clients.read'))
                <a href="{{ route('clients.index') }}" class="bg-white text-black px-3 py-1 rounded">Clientes</a>
            @endif
            @if(auth()->user()->hasPermission('events.read') && auth()->user()->role !== 'photographer')
                <a href="{{ route('offline.index') }}" class="bg-white text-black px-3 py-1 rounded">Sincronizar</a>
            @endif
            @if(auth()->user()->hasPermission('users.manage'))
                <a href="{{ route('users.index') }}" class="bg-white text-black px-3 py-1 rounded">Utilizadores</a>
            @endif
            <a href="{{ route('settings.edit') }}" class="bg-white text-black px-3 py-1 rounded">Definições</a>
            <a href="{{ route('guest.events') }}" class="bg-white text-black px-3 py-1 rounded">Modo Convidado</a>
            <form method="post" action="{{ route('logout') }}">
                @csrf
                <button class="bg-white text-black px-3 py-1 rounded">Logout</button>
            </form>
        </div>
        @endauth
    </div>
</nav>
<main class="max-w-7xl mx-auto p-6">
    @if(session('ok'))
    <div class="bg-green-100 border border-green-300 p-3 rounded mb-4">{{ session('ok') }}</div>
    @endif
    @if($errors->any())
    <div class="bg-red-100 border border-red-300 p-3 rounded mb-4">{{ $errors->first() }}</div>
    @endif
    @yield('content')
</main>
</body>
</html>
