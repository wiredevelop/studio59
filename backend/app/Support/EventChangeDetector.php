<?php

namespace App\Support;

use App\Models\Event;
use Illuminate\Support\Str;

class EventChangeDetector
{
    public static function snapshot(Event $event): array
    {
        $meta = $event->event_meta ?? [];

        return [
            'event_date' => $event->event_date?->toDateString(),
            'event_time' => self::normalizeTime($event->event_time ?? null),
            'store_time_raw' => self::normalizeTime($event->store_time_raw ?? null),
            'store_time_meta' => self::normalizeTime($meta['estar_na_loja_as'] ?? null),
            'team_raw' => self::normalizeTeam($meta['equipa_de_trabalho'] ?? null),
            'event_type' => self::normalizeText($event->event_type ?? null),
            'service_raw' => self::normalizeText($event->service_raw ?? null),
            'staff_ids' => $event->staff()->pluck('user_id')->sort()->values()->all(),
        ];
    }

    public static function hasRelevantChanges(array $before, array $after): bool
    {
        $fields = [
            'event_date',
            'event_time',
            'store_time_raw',
            'store_time_meta',
            'team_raw',
            'event_type',
            'service_raw',
        ];
        foreach ($fields as $field) {
            if (($before[$field] ?? null) !== ($after[$field] ?? null)) {
                return true;
            }
        }

        $beforeStaff = $before['staff_ids'] ?? [];
        $afterStaff = $after['staff_ids'] ?? [];
        if ($beforeStaff !== $afterStaff) {
            return true;
        }

        return false;
    }

    private static function normalizeText($value): string
    {
        $text = trim((string) ($value ?? ''));
        if ($text === '') {
            return '';
        }
        return Str::of($text)->ascii()->lower()->toString();
    }

    private static function normalizeTeam($value): string
    {
        $text = self::normalizeText($value);
        if ($text === '') {
            return '';
        }
        $text = preg_replace('/[^a-z0-9]+/i', ' ', $text);
        $text = trim((string) $text);
        return $text;
    }

    private static function normalizeTime($value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        $text = trim((string) $value);
        if ($text === '') {
            return null;
        }
        $text = str_ireplace('h', ':', $text);
        $text = str_replace([',', '.'], ':', $text);
        $text = preg_replace('/[^0-9:]/', '', $text);
        if ($text === '') {
            return null;
        }
        if (preg_match('/^\\d{1,2}:$/', $text)) {
            $text .= '00';
        }
        if (preg_match('/^\\d{1,2}$/', $text)) {
            $hour = (int) $text;
            if ($hour >= 0 && $hour <= 23) {
                return sprintf('%02d:00', $hour);
            }
        }
        if (preg_match('/^(\\d{1,2}):(\\d{2})(?::\\d{2})?$/', $text, $m)) {
            $hour = (int) $m[1];
            $min = (int) $m[2];
            if ($hour >= 0 && $hour <= 23 && $min >= 0 && $min <= 59) {
                return sprintf('%02d:%02d', $hour, $min);
            }
        }
        return null;
    }
}
