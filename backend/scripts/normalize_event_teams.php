<?php

use App\Models\Event;
use App\Models\EventStaff;
use App\Support\TeamAssignment;
use Illuminate\Support\Str;

require __DIR__.'/../vendor/autoload.php';

$app = require __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$dryRun = in_array('--dry-run', $argv, true);

const CANONICAL_MAP = [
    'humberto' => 'Humberto',
    'berto' => 'Humberto',
    'hb' => 'Humberto',
    'jl' => 'JL',
    'joao luis' => 'JL',
    'joão luis' => 'JL',
    'lm' => 'LM',
    'luis' => 'LM',
    'luís' => 'LM',
    'miguel' => 'MG',
    'mg' => 'MG',
    'miguel barreto' => 'MB',
    'barreto' => 'MB',
    'mb' => 'MB',
    'ana luisa' => 'AL',
    'ana luísa' => 'AL',
    'al' => 'AL',
    'carina' => 'CM',
    'cm' => 'CM',
    'marco' => 'MC',
    'mc' => 'MC',
    'flavio' => 'FL',
    'flávio' => 'FL',
    'fl' => 'FL',
    'gc' => 'GC',
    'ivan' => 'IV',
    'iv' => 'IV',
    'tiago' => 'Tiago',
    'rodrigo' => 'Rodrigo',
];

function split_parts(string $raw): array
{
    $text = str_replace(["\r", "\n"], ' ', $raw);
    $text = preg_replace('/\s*[+,&;\/]+\s*/', ',', $text);
    $text = preg_replace('/\s+e\s+/iu', ',', $text);
    $text = preg_replace('/\s+and\s+/iu', ',', $text);
    $parts = array_map('trim', explode(',', $text));
    return array_values(array_filter($parts, fn ($p) => $p !== ''));
}

function strip_parens(string $raw): string
{
    return preg_replace('/\(.*?\)/', '', $raw);
}

function normalize_raw(string $raw): string
{
    $text = Str::of($raw)->ascii()->lower()->toString();
    $text = preg_replace('/[^a-z0-9]+/i', ' ', $text);
    return trim((string) $text);
}

function normalize_token(string $raw): string
{
    $text = strip_parens($raw);
    $text = str_replace(['"', "'"], '', $text);
    $text = preg_replace('/[^\pL\pN]+/u', ' ', $text);
    $text = trim((string) $text);
    if ($text === '') {
        return '';
    }
    $first = explode(' ', $text)[0] ?? '';
    return Str::of($first)->ascii()->lower()->toString();
}

function canonical_for(string $part): ?string
{
    $clean = strip_parens($part);
    $full = normalize_raw($clean);
    if ($full !== '' && array_key_exists($full, CANONICAL_MAP)) {
        return CANONICAL_MAP[$full];
    }
    $token = normalize_token($clean);
    if ($token !== '' && array_key_exists($token, CANONICAL_MAP)) {
        return CANONICAL_MAP[$token];
    }
    return null;
}

$eventsScanned = 0;
$eventsUpdated = 0;
$staffLinksUpdated = 0;
$unknownByEvent = [];
$unknownTokens = [];

Event::query()
    ->orderBy('id')
    ->chunkById(200, function ($events) use (
        $dryRun,
        &$eventsScanned,
        &$eventsUpdated,
        &$staffLinksUpdated,
        &$unknownByEvent,
        &$unknownTokens
    ) {
        foreach ($events as $event) {
            $eventsScanned++;
            $meta = $event->event_meta ?? [];
            $raw = $meta['equipa_de_trabalho'] ?? $meta['EQUIPA DE TRABALHO'] ?? null;
            if (! is_string($raw) || trim($raw) === '') {
                continue;
            }

            $parts = split_parts($raw);
            if (! $parts) {
                continue;
            }

            $tokens = [];
            $unknown = [];
            foreach ($parts as $part) {
                $canonical = canonical_for($part);
                if ($canonical !== null) {
                    $tokens[] = $canonical;
                } else {
                    $clean = trim(strip_parens($part));
                    if ($clean !== '') {
                        $tokens[] = $clean;
                        $unknown[] = $clean;
                    }
                }
            }

            $tokens = array_values(array_unique(array_filter($tokens, fn ($t) => $t !== '')));
            if (! $tokens) {
                if ($unknown) {
                    $unknownByEvent[$event->id] = $unknown;
                    $unknownTokens = array_values(array_unique(array_merge($unknownTokens, $unknown)));
                }
                continue;
            }

            $newTeam = implode('+', $tokens);
            $rawTrimmed = trim((string) $raw);
            if ($newTeam !== $rawTrimmed || array_key_exists('EQUIPA DE TRABALHO', $meta)) {
                $meta['equipa_de_trabalho'] = $newTeam;
                unset($meta['EQUIPA DE TRABALHO']);
                if (! $dryRun) {
                    $event->update(['event_meta' => $meta]);
                }
                $eventsUpdated++;
            }

            $ids = TeamAssignment::resolveUserIds($newTeam);
            if ($ids) {
                $existing = EventStaff::where('event_id', $event->id)->pluck('user_id')->all();
                $toRemove = array_diff($existing, $ids);
                $toAdd = array_diff($ids, $existing);
                if (! $dryRun) {
                    if ($toRemove) {
                        EventStaff::where('event_id', $event->id)
                            ->whereIn('user_id', $toRemove)
                            ->delete();
                    }
                    foreach ($toAdd as $userId) {
                        EventStaff::updateOrCreate(
                            ['event_id' => $event->id, 'user_id' => $userId],
                            ['role' => 'photographer', 'status' => 'assigned', 'invited_at' => now()]
                        );
                    }
                }
                if ($toRemove || $toAdd) {
                    $staffLinksUpdated++;
                }
            }

            if ($unknown) {
                $unknownByEvent[$event->id] = $unknown;
                $unknownTokens = array_values(array_unique(array_merge($unknownTokens, $unknown)));
            }
        }
    });

echo 'Events scanned: '.$eventsScanned.PHP_EOL;
echo 'Events updated: '.$eventsUpdated.PHP_EOL;
echo 'Staff links updated: '.$staffLinksUpdated.PHP_EOL;
if ($unknownTokens) {
    echo 'Unknown tokens (unique): '.implode(', ', $unknownTokens).PHP_EOL;
    foreach ($unknownByEvent as $eventId => $tokens) {
        echo 'Event '.$eventId.': '.implode(', ', $tokens).PHP_EOL;
    }
}
if ($dryRun) {
    echo "Dry run only. Use without --dry-run to apply.\n";
}
