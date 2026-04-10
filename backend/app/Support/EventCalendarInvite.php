<?php

namespace App\Support;

use App\Models\Event;
use App\Models\User;
use Illuminate\Support\Carbon;

class EventCalendarInvite
{
    private const TZ = 'Europe/Lisbon';

    public static function build(Event $event, User $user, string $method = 'REQUEST', ?string $summaryLabel = null): string
    {
        $uid = 'event-'.$event->id.'@studio59.wiredevelop.pt';
        $sequence = $event->updated_at?->timestamp ?? time();

        $dtstamp = Carbon::now('UTC')->format('Ymd\THis\Z');
        [$dtstart, $dtend, $allDay] = self::buildDateBlock($event);

        $summaryText = $summaryLabel ?: ($event->event_type ?: 'Evento');
        $summary = self::escape($summaryText);
        $location = self::escape($event->location ?? '');
        $description = self::escape(self::buildDescription($event));
        $organizerEmail = config('mail.from.address');
        $organizerName = config('mail.from.name') ?: 'Studio 59';
        $organizer = $organizerEmail ? 'ORGANIZER;CN='.$organizerName.':MAILTO:'.$organizerEmail : null;
        $attendee = 'ATTENDEE;CN='.self::escape($user->name).';ROLE=REQ-PARTICIPANT;RSVP=TRUE:MAILTO:'.$user->email;

        $lines = [
            'BEGIN:VCALENDAR',
            'VERSION:2.0',
            'PRODID:-//Studio59//Events//PT',
            'CALSCALE:GREGORIAN',
            'METHOD:'.$method,
            'BEGIN:VEVENT',
            'UID:'.$uid,
            'SEQUENCE:'.$sequence,
            'DTSTAMP:'.$dtstamp,
        ];

        if ($allDay) {
            $lines[] = 'DTSTART;VALUE=DATE:'.$dtstart;
            $lines[] = 'DTEND;VALUE=DATE:'.$dtend;
        } else {
            $lines[] = 'DTSTART;TZID='.self::TZ.':'.$dtstart;
            $lines[] = 'DTEND;TZID='.self::TZ.':'.$dtend;
        }

        $lines[] = 'SUMMARY:'.$summary;
        if (strtoupper($method) === 'CANCEL') {
            $lines[] = 'STATUS:CANCELLED';
        }
        if ($location !== '') {
            $lines[] = 'LOCATION:'.$location;
        }
        if ($description !== '') {
            $lines[] = 'DESCRIPTION:'.$description;
        }
        if ($organizer) {
            $lines[] = $organizer;
        }
        $lines[] = $attendee;
        $lines[] = 'END:VEVENT';
        $lines[] = 'END:VCALENDAR';

        return implode("\r\n", $lines)."\r\n";
    }

    private static function buildDateBlock(Event $event): array
    {
        $date = self::parseEventDate($event->event_date);

        $storeRaw = trim((string) ($event->store_time_raw ?? ''));
        if ($storeRaw === '' && is_array($event->event_meta ?? null)) {
            $metaTime = $event->event_meta['estar_na_loja_as'] ?? null;
            if (is_string($metaTime)) {
                $storeRaw = trim($metaTime);
            }
        }
        $timeRaw = $storeRaw !== '' ? $storeRaw : trim((string) ($event->event_time ?? ''));
        $timeNormalized = self::normalizeTime($timeRaw);
        if ($timeNormalized === null && $storeRaw !== '') {
            $timeNormalized = self::normalizeTime($event->event_time ?? '');
        }

        if ($timeNormalized === null) {
            $start = $date->format('Ymd');
            $end = $date->copy()->addDay()->format('Ymd');
            return [$start, $end, true];
        }
        $timeRaw = $timeNormalized;

        $time = null;
        foreach (['H:i', 'H:i:s'] as $format) {
            try {
                $time = Carbon::createFromFormat($format, $timeRaw, self::TZ);
                break;
            } catch (\Exception $e) {
                $time = null;
            }
        }
        if ($time === null) {
            $startAt = Carbon::parse($date->format('Y-m-d').' '.$timeRaw, self::TZ);
        } else {
            $startAt = $date->copy()->setTime($time->hour, $time->minute, $time->second);
        }

        $endAt = $date->copy()->setTime(23, 59, 0);
        if ($endAt->lessThanOrEqualTo($startAt)) {
            $endAt = $endAt->addDay();
        }
        return [$startAt->format('Ymd\THis'), $endAt->format('Ymd\THis'), false];
    }

    private static function parseEventDate($value): Carbon
    {
        if ($value instanceof Carbon) {
            return $value->copy()->timezone(self::TZ);
        }

        $raw = is_string($value) ? trim($value) : trim((string) $value);
        if ($raw === '') {
            return Carbon::now(self::TZ);
        }

        if (preg_match('/^\\d{4}-\\d{2}-\\d{2}(?:\\s+\\d{2}:\\d{2}:\\d{2})?/', $raw, $match)) {
            $raw = $match[0];
        }

        try {
            return Carbon::parse($raw, self::TZ);
        } catch (\Exception $e) {
            return Carbon::parse($raw);
        }
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

    private static function buildDescription(Event $event): string
    {
        $parts = [];
        if (! empty($event->event_type)) {
            $parts[] = 'Tipo: '.$event->event_type;
        }
        if (! empty($event->legacy_report_number)) {
            $parts[] = 'Nº: '.$event->legacy_report_number;
        }
        if (! empty($event->event_date)) {
            $parts[] = 'Data: '.$event->event_date;
        }
        $storeRaw = trim((string) ($event->store_time_raw ?? ''));
        if ($storeRaw === '' && is_array($event->event_meta ?? null)) {
            $metaTime = $event->event_meta['estar_na_loja_as'] ?? null;
            if (is_string($metaTime)) {
                $storeRaw = trim($metaTime);
            }
        }
        $storeNormalized = self::normalizeTime($storeRaw);
        if ($storeNormalized === null && ! empty($event->event_time)) {
            $storeNormalized = self::normalizeTime($event->event_time);
        }
        if ($storeNormalized !== null) {
            $parts[] = 'Hora: '.$storeNormalized.' ate 23:59';
        }
        return implode(' | ', $parts);
    }

    private static function escape(string $value): string
    {
        $value = str_replace('\\', '\\\\', $value);
        $value = str_replace("\r\n", '\\n', $value);
        $value = str_replace("\n", '\\n', $value);
        $value = str_replace(',', '\\,', $value);
        $value = str_replace(';', '\\;', $value);
        return $value;
    }
}
