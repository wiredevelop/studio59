<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Support\Str;

class TeamAssignment
{
    public static function resolveUserIds(?string $raw): array
    {
        if (! is_string($raw) || trim($raw) === '') {
            return [];
        }

        $raw = trim($raw);
        $parts = self::splitParts($raw);
        if (! $parts) {
            return [];
        }

        $tokens = [];
        foreach ($parts as $part) {
            $token = self::normalizeToken($part);
            if ($token === '') {
                continue;
            }
            $tokens[] = $token;
        }

        $userRows = User::whereNotNull('username')->get(['id', 'username']);
        $usersByUsername = [];
        foreach ($userRows as $user) {
            $username = Str::of((string) $user->username)->ascii()->lower()->toString();
            if ($username === '') {
                continue;
            }
            $usersByUsername[$username] = (int) $user->id;
        }

        $ids = [];
        foreach ($tokens as $token) {
            if (isset($usersByUsername[$token])) {
                $ids[] = $usersByUsername[$token];
                continue;
            }
            if (strlen($token) > 2) {
                $prefix = substr($token, 0, 2);
                if (isset($usersByUsername[$prefix])) {
                    $ids[] = $usersByUsername[$prefix];
                }
            }
        }

        $normalizedRaw = self::normalizeRaw($raw);
        foreach ($usersByUsername as $username => $userId) {
            if ($username === '') {
                continue;
            }
            $pattern = '/(^|[^a-z0-9])'.preg_quote($username, '/').'([^a-z0-9]|$)/';
            if (preg_match($pattern, $normalizedRaw)) {
                $ids[] = $userId;
            }
        }

        return array_values(array_unique($ids));
    }

    private static function splitParts(string $raw): array
    {
        $text = str_replace(["\r", "\n"], ' ', $raw);
        $text = preg_replace('/\s*[+,&;\/]+\s*/', ',', $text);
        $text = preg_replace('/\s+e\s+/iu', ',', $text);
        $text = preg_replace('/\s+and\s+/iu', ',', $text);
        $parts = array_map('trim', explode(',', $text));
        return array_values(array_filter($parts, fn ($p) => $p !== ''));
    }

    private static function normalizeToken(string $raw): string
    {
        $text = preg_replace('/\(.*?\)/', '', $raw);
        $text = trim((string) $text);
        $text = str_replace(['"', "'"], '', $text);
        $text = preg_replace('/[^\pL\pN]+/u', ' ', $text);
        $text = trim((string) $text);
        if ($text === '') {
            return '';
        }
        $first = explode(' ', $text)[0] ?? '';
        if ($first === '') {
            return '';
        }
        return Str::of($first)->ascii()->lower()->toString();
    }

    private static function normalizeRaw(string $raw): string
    {
        $text = Str::of($raw)->ascii()->lower()->toString();
        $text = preg_replace('/[^a-z0-9]+/i', ' ', $text);
        $text = trim((string) $text);
        return ' '.$text.' ';
    }
}
