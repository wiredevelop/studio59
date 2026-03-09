<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\OfflineSync;
use Illuminate\Http\Request;

class OfflineSyncController extends Controller
{
    public function index()
    {
        $user = auth()->user();
        if ($user && $user->role === 'photographer') {
            abort(403);
        }

        return view('offline.index', [
            'events' => Event::orderByDesc('event_date')->get(),
            'syncs' => OfflineSync::with('event')->orderByDesc('id')->limit(50)->get(),
        ]);
    }

    public function import(Request $request)
    {
        $user = $request->user();
        if ($user && $user->role === 'photographer') {
            abort(403);
        }

        $validated = $request->validate([
            'event_id' => ['required', 'integer', 'exists:events,id'],
            'payload' => ['required', 'file', 'mimes:json,txt', 'max:20480'],
        ]);

        $event = Event::findOrFail($validated['event_id']);

        $request->merge(['device_id' => 'web-upload']);
        app(\App\Http\Controllers\Api\OfflineSyncController::class)->import($request, $event);

        return redirect()->route('offline.index')->with('ok', 'Ficheiro importado.');
    }
}
