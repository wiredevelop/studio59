<?php

namespace App\Http\Middleware;

use App\Models\EventSession;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureEventSession
{
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken() ?: $request->header('X-Event-Session-Token');

        if (! $token) {
            return response()->json(['message' => 'Event session token required'], 401);
        }

        $session = EventSession::where('token_hash', hash('sha256', $token))
            ->where('expires_at', '>', now())
            ->first();

        if (! $session) {
            return response()->json(['message' => 'Invalid or expired event session'], 401);
        }

        $eventId = (int) $request->route('id');
        if ($eventId > 0 && $eventId !== (int) $session->event_id) {
            return response()->json(['message' => 'Token not valid for this event'], 403);
        }

        $request->attributes->set('event_session', $session);

        return $next($request);
    }
}
