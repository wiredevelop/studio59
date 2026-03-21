<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59 - Entrar</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="/brand.css">
</head>
<body class="bg-gray-100 min-h-screen">
<main class="max-w-md mx-auto p-6">
    @if(session('ok'))
        <div class="bg-green-100 border border-green-300 p-3 rounded mb-4">{{ session('ok') }}</div>
    @endif
    @if($errors->any())
        <div class="bg-red-100 border border-red-300 p-3 rounded mb-4">{{ $errors->first() }}</div>
    @endif

    <div class="bg-white border rounded p-4">
        <h1 class="text-xl font-semibold mb-2">{{ $event->name }}</h1>
        <p class="text-sm text-gray-600 mb-4">Introduza o PIN para aceder ao catálogo.</p>
        <form method="post" action="{{ route('guest.enter.submit', $event) }}" class="space-y-3">
            @csrf
            <input name="pin" type="text" inputmode="numeric" pattern="\\d{4}" class="w-full border rounded p-2" placeholder="PIN" required autofocus>
            <button class="w-full bg-black text-white p-2 rounded">Entrar</button>
        </form>
    </div>
</main>
</body>
</html>
