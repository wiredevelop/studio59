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

        $userRows = User::query()->get(['id', 'username', 'name']);
        $usersByToken = [];
        $usersByUsername = [];
        foreach ($userRows as $user) {
            $username = Str::of((string) $user->username)->ascii()->lower()->toString();
            if ($username !== '') {
                $usersByUsername[$username] = (int) $user->id;
                $usersByToken[$username][] = (int) $user->id;
            }
            $initials = self::initialsFromName($user->name ?? null);
            if ($initials !== '') {
                $usersByToken[$initials][] = (int) $user->id;
            }
        }

        $ids = [];
        foreach ($tokens as $token) {
            if (isset($usersByToken[$token])) {
                foreach ($usersByToken[$token] as $userId) {
                    $ids[] = $userId;
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
        foreach ($userRows as $user) {
            $name = trim((string) ($user->name ?? ''));
            if ($name === '') {
                continue;
            }
            $parts = preg_split('/\s+/', $name) ?: [];
            $parts = array_values(array_filter($parts, fn ($p) => $p !== ''));
            if (count($parts) === 1) {
                $single = self::normalizeRaw($parts[0]);
                if ($single !== '  ' && str_contains($normalizedRaw, $single)) {
                    $ids[] = (int) $user->id;
                }
                continue;
            }
            $full = self::normalizeRaw($name);
            if ($full !== '  ' && str_contains($normalizedRaw, $full)) {
                $ids[] = (int) $user->id;
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

    private static function initialsFromName(?string $name): string
    {
        if (! is_string($name)) {
            return '';
        }
        $parts = preg_split('/\s+/', trim($name));
        if (! $parts || $parts[0] === '') {
            return '';
        }
        $first = $parts[0] ?? '';
        $last = $parts[count($parts) - 1] ?? $first;
        if ($first === '' || $last === '') {
            return '';
        }
        $initials = mb_substr($first, 0, 1).mb_substr($last, 0, 1);
        return Str::of($initials)->ascii()->lower()->toString();
    }
}
