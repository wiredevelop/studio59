<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59</title>
    <link rel="icon" href="/favicon.ico" sizes="any">
    <link rel="icon" href="/favicon.png" type="image/png">
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="/brand.css">
</head>
<body class="bg-gray-100 min-h-screen">
@php($user = auth()->user())
@if(Route::is('login'))
    <main>
        @yield('content')
    </main>
@else
    <div class="desk-shell">
        <aside class="desk-sidebar">
            <div class="desk-brand">
                <div class="desk-logo">S59</div>
                <div>
                    <div class="desk-brand-title">Studio 59</div>
                    <div class="desk-brand-subtitle">Backoffice</div>
                </div>
            </div>

            <div>
                <div class="desk-nav-section">Operação</div>
                <nav class="desk-nav">
                    <a href="{{ route('dashboard') }}" class="desk-nav-item {{ request()->routeIs('dashboard') ? 'is-active' : '' }}">
                        <span class="desk-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                <rect x="3" y="3" width="8" height="8" rx="2"></rect>
                                <rect x="13" y="3" width="8" height="8" rx="2"></rect>
                                <rect x="3" y="13" width="8" height="8" rx="2"></rect>
                                <rect x="13" y="13" width="8" height="8" rx="2"></rect>
                            </svg>
                        </span>
                        <span>Dashboard</span>
                    </a>
                    @if($user && $user->hasPermission('events.view'))
                        <a href="{{ route('events.index') }}" class="desk-nav-item {{ request()->routeIs('events.*') ? 'is-active' : '' }}">
                            <span class="desk-icon">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                    <rect x="3" y="4" width="18" height="18" rx="3"></rect>
                                    <path d="M8 2v4M16 2v4M3 10h18"></path>
                                </svg>
                            </span>
                            <span>Eventos</span>
                        </a>
                    @endif
                    @if($user && $user->hasPermission('orders.list'))
                        <a href="{{ route('orders.index') }}" class="desk-nav-item {{ request()->routeIs('orders.*') ? 'is-active' : '' }}">
                            <span class="desk-icon">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                    <path d="M7 3h10l2 4H5l2-4Z"></path>
                                    <path d="M5 7h14v12a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2Z"></path>
                                </svg>
                            </span>
                            <span>Pedidos</span>
                        </a>
                    @endif
                    @if($user && $user->hasPermission('clients.list'))
                        <a href="{{ route('clients.index') }}" class="desk-nav-item {{ request()->routeIs('clients.*') ? 'is-active' : '' }}">
                            <span class="desk-icon">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                    <path d="M16 21v-2a4 4 0 0 0-8 0v2"></path>
                                    <circle cx="12" cy="7" r="4"></circle>
                                </svg>
                            </span>
                            <span>Clientes</span>
                        </a>
                    @endif
                    @if($user && $user->hasPermission('offline.export') && $user->role !== 'photographer')
                        <a href="{{ route('offline.index') }}" class="desk-nav-item {{ request()->routeIs('offline.*') ? 'is-active' : '' }}">
                            <span class="desk-icon">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                    <path d="M21 12a9 9 0 1 1-9-9"></path>
                                    <path d="M12 7v6l4 2"></path>
                                </svg>
                            </span>
                            <span>Sincronização</span>
                        </a>
                    @endif
                </nav>
            </div>

            <div>
                <div class="desk-nav-section">Admin</div>
                <nav class="desk-nav">
                    @if($user && $user->hasPermission('users.list'))
                        <a href="{{ route('users.index') }}" class="desk-nav-item {{ request()->routeIs('users.*') ? 'is-active' : '' }}">
                            <span class="desk-icon">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                    <circle cx="12" cy="7" r="4"></circle>
                                    <path d="M5.5 21a6.5 6.5 0 0 1 13 0"></path>
                                </svg>
                            </span>
                            <span>Utilizadores</span>
                        </a>
                    @endif
                    <a href="{{ route('settings.edit') }}" class="desk-nav-item {{ request()->routeIs('settings.*') ? 'is-active' : '' }}">
                        <span class="desk-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                <path d="M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z"></path>
                                <path d="M19.4 15a7.97 7.97 0 0 0 .1-2 7.97 7.97 0 0 0-.1-2l2-1.6-2-3.4-2.4 1a7.8 7.8 0 0 0-3.4-2l-.6-2.6h-4l-.6 2.6a7.8 7.8 0 0 0-3.4 2l-2.4-1-2 3.4 2 1.6a7.97 7.97 0 0 0-.1 2 7.97 7.97 0 0 0 .1 2l-2 1.6 2 3.4 2.4-1a7.8 7.8 0 0 0 3.4 2l.6 2.6h4l.6-2.6a7.8 7.8 0 0 0 3.4-2l2.4 1 2-3.4-2-1.6Z"></path>
                            </svg>
                        </span>
                        <span>Definições</span>
                    </a>
                    <a href="{{ route('guest.events') }}" class="desk-nav-item">
                        <span class="desk-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                <path d="M4 12h16"></path>
                                <path d="M12 4v16"></path>
                            </svg>
                        </span>
                        <span>Modo Convidado</span>
                    </a>
                </nav>
            </div>
        </aside>

        <div class="desk-main">
            <header class="desk-topbar">
                <div>
                    <div class="desk-title">@yield('page_title', 'Dashboard')</div>
                    @hasSection('page_subtitle')
                        <div class="desk-subtitle">@yield('page_subtitle')</div>
                    @endif
                </div>
                <div>
                    @yield('page_search')
                </div>
                <div class="desk-topbar-actions">
                    @yield('page_actions')
                </div>
                @auth
                <div class="desk-user">
                    <div class="desk-user-meta">
                        <div class="desk-user-name">{{ $user?->name ?? 'Conta' }}</div>
                        <div class="desk-user-role">{{ ucfirst($user?->role ?? '') }}</div>
                    </div>
                    <form method="post" action="{{ route('logout') }}">
                        @csrf
                        <button class="desk-icon-btn" title="Terminar sessão">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                <path d="M16 17l5-5-5-5"></path>
                                <path d="M21 12H9"></path>
                                <path d="M13 7V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2v-2"></path>
                            </svg>
                        </button>
                    </form>
                </div>
                @endauth
            </header>

            <main class="desk-content">
                @if(session('ok'))
                    <div class="desk-card alt">{{ session('ok') }}</div>
                @endif
                @if($errors->any())
                    <div class="desk-card alt">{{ $errors->first() }}</div>
                @endif
                @yield('content')
            </main>
        </div>
    </div>
@endif
</body>
</html>
