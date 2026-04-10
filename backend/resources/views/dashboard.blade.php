@extends('layouts.app')
@section('page_title', 'Dashboard')
@section('page_subtitle', 'Resumo operacional do Studio 59')
@section('page_actions')
    @if(auth()->user()->hasPermission('events.create'))
        <a class="desk-btn primary" href="{{ route('events.create') }}">Novo evento</a>
    @endif
    @if(auth()->user()->hasPermission('orders.list'))
        <a class="desk-btn" href="{{ route('orders.index') }}">Ver pedidos</a>
    @endif
@endsection
@section('content')
<div class="desk-grid kpi">
    <div class="desk-kpi-card">
        <div class="desk-kpi-label">Serviços agendados</div>
        <div class="desk-kpi-value">{{ $metrics['scheduled_services'] ?? 0 }}</div>
        <div class="desk-kpi-note">A partir de hoje</div>
    </div>
    <div class="desk-kpi-card">
        <div class="desk-kpi-label">Eventos deste mês</div>
        <div class="desk-kpi-value">{{ $metrics['events_month'] ?? 0 }}</div>
        <div class="desk-kpi-note">Agenda atual</div>
    </div>
    <div class="desk-kpi-card">
        <div class="desk-kpi-label">Pedidos pendentes</div>
        <div class="desk-kpi-value">{{ $metrics['orders_pending'] ?? 0 }}</div>
        <div class="desk-kpi-note">A validar</div>
    </div>
    <div class="desk-kpi-card">
        <div class="desk-kpi-label">Vendas pagas</div>
        <div class="desk-kpi-value">{{ number_format($metrics['total_sales'] ?? 0, 2) }}€</div>
        <div class="desk-kpi-note">{{ $metrics['orders_paid'] ?? 0 }} pedidos pagos</div>
    </div>
    <div class="desk-kpi-card">
        <div class="desk-kpi-label">Fotos por tratar</div>
        <div class="desk-kpi-value">{{ $metrics['photos_pending'] ?? 0 }}</div>
        <div class="desk-kpi-note">Previews pendentes</div>
    </div>
    <div class="desk-kpi-card">
        <div class="desk-kpi-label">Sincronizações</div>
        <div class="desk-kpi-value">{{ $metrics['sync_pending'] ?? 0 }}</div>
        <div class="desk-kpi-note">Pendentes</div>
    </div>
</div>

<div class="desk-grid two">
    <div class="desk-card">
        <div class="flex items-center justify-between mb-4">
            <div class="font-semibold">Atividade recente</div>
            <span class="desk-badge info">Hoje</span>
        </div>
        <div class="grid gap-3 text-sm">
            @forelse($recentOrders as $order)
                <div class="flex items-center justify-between">
                    <div>
                        <div class="font-medium">{{ $order->customer_name ?: 'Cliente' }}</div>
                        <div class="text-xs text-gray-500">{{ $order->order_code }} · {{ optional($order->event)->name ?? 'Sem evento' }}</div>
                    </div>
                    <span class="desk-badge {{ $order->status === 'paid' ? 'success' : 'warn' }}">{{ strtoupper($order->status) }}</span>
                </div>
            @empty
                <div class="desk-empty">Sem atividade recente.</div>
            @endforelse
        </div>
    </div>

    <div class="desk-card">
        <div class="flex items-center justify-between mb-4">
            <div class="font-semibold">Próximos eventos</div>
            <span class="desk-badge">Agenda</span>
        </div>
        <div class="grid gap-3 text-sm">
            @forelse($events->sortBy('event_date')->take(6) as $event)
                <div class="flex items-center justify-between">
                    <div>
                        <div class="font-medium">{{ $event->name }}</div>
                        <div class="text-xs text-gray-500">{{ $event->event_date?->format('d/m/Y') }} · {{ $event->location ?: 'Local a definir' }}</div>
                    </div>
                    <span class="desk-badge {{ $event->status === 'active' ? 'success' : 'info' }}">{{ strtoupper($event->status ?? 'ABERTO') }}</span>
                </div>
            @empty
                <div class="desk-empty">Sem eventos agendados.</div>
            @endforelse
        </div>
    </div>
</div>

<div class="desk-grid two">
    <div class="desk-card">
        <div class="flex items-center justify-between mb-4">
            <div class="font-semibold">Pedidos pendentes</div>
            <a class="desk-btn" href="{{ route('orders.index', ['status' => 'pending']) }}">Ver todos</a>
        </div>
        <div class="grid gap-3 text-sm">
            @php($pendingOrders = $recentOrders->where('status', 'pending'))
            @forelse($pendingOrders->take(5) as $order)
                <div class="flex items-center justify-between">
                    <div>
                        <div class="font-medium">{{ $order->order_code }}</div>
                        <div class="text-xs text-gray-500">{{ $order->customer_name ?: 'Cliente' }} · {{ number_format($order->total_amount, 2) }}€</div>
                    </div>
                    <span class="desk-badge warn">Pendente</span>
                </div>
            @empty
                <div class="desk-empty">Nenhum pedido pendente.</div>
            @endforelse
        </div>
    </div>

    <div class="desk-card">
        <div class="flex items-center justify-between mb-4">
            <div class="font-semibold">Sincronização</div>
            <span class="desk-badge {{ ($metrics['sync_pending'] ?? 0) > 0 ? 'warn' : 'success' }}">
                {{ ($metrics['sync_pending'] ?? 0) > 0 ? 'Atenção' : 'Ok' }}
            </span>
        </div>
        <div class="text-sm text-gray-500">
            {{ ($metrics['sync_pending'] ?? 0) > 0 ? 'Existem sincronizações pendentes que requerem atenção.' : 'Todos os dados estão sincronizados.' }}
        </div>
    </div>
</div>
@endsection
