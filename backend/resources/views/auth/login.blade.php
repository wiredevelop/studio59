@extends('layouts.app')
@section('content')
<section class="ios-login">
    <div class="ios-orb ios-orb-1"></div>
    <div class="ios-orb ios-orb-2"></div>
    <div class="ios-shell">
        <div class="ios-brand">Studio 59</div>
        <div class="ios-card">
            <div class="ios-title">Login Staff</div>
            <div class="ios-subtitle">Acesso interno ao sistema com estética iOS.</div>
            <form method="post" action="{{ route('login.submit') }}" class="ios-form">
                @csrf
                <div>
                    <label class="ios-label" for="login">Email ou username</label>
                    <input id="login" type="text" name="login" value="{{ old('login') }}" class="ios-input" required autofocus>
                </div>
                <div>
                    <label class="ios-label" for="password">Password</label>
                    <input id="password" type="password" name="password" class="ios-input" required>
                </div>
                <div class="ios-actions">
                    <button class="ios-btn ios-btn-primary" type="submit">Entrar</button>
                    <a class="ios-btn ios-btn-secondary" href="/app/studio59.apk" download>Download APP</a>
                </div>
            </form>
        </div>
    </div>
</section>
@endsection
