<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\Order;

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

        return view('dashboard', [
            'events' => $eventQuery->take(10)->get(),
            'recentOrders' => $orderQuery->take(15)->get(),
        ]);
    }
}
