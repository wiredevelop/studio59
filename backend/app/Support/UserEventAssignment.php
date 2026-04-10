<?php

namespace App\Support;

use App\Models\Event;
use App\Models\EventStaff;
use App\Models\User;
use Illuminate\Support\Str;

class UserEventAssignment
{
    public static function attachUserToExistingEvents(User $user): int
    {
        if ($user->role === 'admin') {
            return 0;
        }

        $matches = 0;
        Event::query()
            ->whereNotNull('event_meta')
            ->orderBy('id')
            ->chunkById(200, function ($events) use (&$matches, $user) {
                foreach ($events as $event) {
                    $meta = $event->event_meta ?? [];
                    $raw = $meta['equipa_de_trabalho'] ?? ($meta['EQUIPA DE TRABALHO'] ?? null);
                    if (! is_string($raw) || trim($raw) === '') {
                        continue;
                    }
                    if (! self::userMatchesRaw($user, $raw)) {
                        continue;
                    }
                    EventStaff::updateOrCreate(
                        ['event_id' => $event->id, 'user_id' => $user->id],
                        ['role' => $user->role === 'staff' ? 'staff' : 'photographer', 'status' => 'assigned', 'invited_at' => now()]
                    );
                    $matches++;
                }
            });

        return $matches;
    }

    private static function userMatchesRaw(User $user, string $raw): bool
    {
        $rawNorm = Str::of($raw)->ascii()->lower()->toString();
        $rawNorm = preg_replace('/[^a-z0-9]+/i', ' ', $rawNorm);
        $rawNorm = ' '.$rawNorm.' ';

        $tokens = [];
        $username = Str::of((string) $user->username)->ascii()->lower()->toString();
        if ($username !== '') {
            $tokens[] = $username;
        }
        $name = trim((string) $user->name);
        if ($name !== '') {
            $nameNorm = Str::of($name)->ascii()->lower()->toString();
            $tokens[] = $nameNorm;
            $parts = preg_split('/\\s+/', $nameNorm);
            $first = $parts[0] ?? '';
            $last = $parts[count($parts) - 1] ?? $first;
            if ($first !== '') {
                $tokens[] = $first;
            }
            if ($last !== '' && $last !== $first) {
                $tokens[] = $last;
            }
            $initials = '';
            if ($first !== '' && $last !== '') {
                $initials = Str::of(mb_substr($first, 0, 1).mb_substr($last, 0, 1))->ascii()->lower()->toString();
            }
            if ($initials !== '') {
                $tokens[] = $initials;
            }
        }

        $tokens = array_values(array_unique(array_filter($tokens, fn ($t) => $t !== '' && strlen($t) >= 2)));
        if (! $tokens) {
            return false;
        }

        foreach ($tokens as $token) {
            $pattern = '/(^|[^a-z0-9])'.preg_quote($token, '/').'([^a-z0-9]|$)/';
            if (preg_match($pattern, $rawNorm)) {
                return true;
            }
        }

        return false;
    }
}
