@extends('layouts.app')
@section('content')
<div class="max-w-md mx-auto bg-white p-6 rounded shadow">
    <h1 class="text-xl font-semibold mb-4">Login Staff</h1>
    <form method="post" action="{{ route('login.submit') }}" class="space-y-3">
        @csrf
        <input type="text" name="login" value="{{ old('login') }}" placeholder="Email ou username" class="w-full border p-2 rounded" required>
        <input type="password" name="password" placeholder="Password" class="w-full border p-2 rounded" required>
        <div class="flex gap-2">
            <button class="flex-1 bg-black text-white py-2 rounded">Entrar</button>
            <a class="flex-1 border border-black text-black py-2 rounded text-center" href="/app/studio59.apk" download>Download APP</a>
        </div>
    </form>
</div>
@endsection
