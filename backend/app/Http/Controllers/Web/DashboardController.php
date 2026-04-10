<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\Order;
use App\Models\Photo;
use App\Models\OfflineSync;
use Illuminate\Support\Carbon;

class DashboardController extends Controller
{
    public function index()
    {
        $user = auth()->user();
        $eventQuery = Event::query()->orderByDesc('event_date');
        $orderQuery = Order::with('event')->latest();

        if ($user && $user->role === 'photographer') {
            $eventQuery->visibleTo($user);
            $orderQuery->whereHas('event', fn ($q) => $q->visibleTo($user));
        }

        $now = Carbon::now();
        $monthStart = $now->copy()->startOfMonth();
        $monthEnd = $now->copy()->endOfMonth();

        $eventsBase = Event::query();
        $ordersBase = Order::query();

        if ($user && $user->role === 'photographer') {
            $eventsBase->visibleTo($user);
            $ordersBase->whereHas('event', fn ($q) => $q->visibleTo($user));
        }

        $eventIds = $eventsBase->pluck('id');

        $metrics = [
            'scheduled_services' => (clone $eventsBase)->whereDate('event_date', '>=', $now)->count(),
            'events_month' => (clone $eventsBase)->whereBetween('event_date', [$monthStart, $monthEnd])->count(),
            'orders_pending' => (clone $ordersBase)->where('status', 'pending')->count(),
            'orders_paid' => (clone $ordersBase)->where('status', 'paid')->count(),
            'total_sales' => (clone $ordersBase)->where('status', 'paid')->sum('total_amount'),
            'photos_pending' => Photo::when($eventIds->isNotEmpty(), fn ($q) => $q->whereIn('event_id', $eventIds))
                ->where('preview_status', 'pending')
                ->count(),
            'sync_pending' => OfflineSync::when($eventIds->isNotEmpty(), fn ($q) => $q->whereIn('event_id', $eventIds))
                ->where('status', 'pending')
                ->count(),
        ];

        return view('dashboard', [
            'events' => $eventQuery->take(10)->get(),
            'recentOrders' => $orderQuery->take(15)->get(),
            'metrics' => $metrics,
        ]);
    }
}
