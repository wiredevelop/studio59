<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsurePermission
{
    public function handle(Request $request, Closure $next, string ...$permissions): Response
    {
        $user = $request->user();
        if (! $user) {
            abort(401);
        }

        $required = collect($permissions)
            ->flatMap(fn (string $perm) => explode(',', $perm))
            ->map(fn (string $perm) => trim($perm))
            ->filter()
            ->values()
            ->all();

        if ($required === []) {
            return $next($request);
        }

        foreach ($required as $perm) {
            if ($user->hasPermission($perm)) {
                return $next($request);
            }
        }

        abort(403);
    }
}
