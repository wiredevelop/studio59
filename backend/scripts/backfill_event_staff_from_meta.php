<?php

use App\Models\Event;
use App\Models\EventStaff;
use App\Support\TeamAssignment;

require __DIR__.'/../vendor/autoload.php';

$app = require __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$dryRun = in_array('--dry-run', $argv, true);
$onlyMissing = in_array('--only-missing', $argv, true);

$eventsScanned = 0;
$linksCreated = 0;

Event::query()
    ->when($onlyMissing, fn ($q) => $q->whereDoesntHave('staff'))
    ->orderBy('id')
    ->chunkById(200, function ($events) use (&$eventsScanned, &$linksCreated, $dryRun) {
        foreach ($events as $event) {
            $eventsScanned++;
            $meta = $event->event_meta ?? [];
            $raw = $meta['equipa_de_trabalho'] ?? $meta['EQUIPA DE TRABALHO'] ?? null;
            if (! is_string($raw) || trim($raw) === '') {
                continue;
            }
            $ids = TeamAssignment::resolveUserIds($raw);
            if (! $ids) {
                continue;
            }
            foreach ($ids as $userId) {
                if ($dryRun) {
                    $linksCreated++;
                    continue;
                }
                EventStaff::updateOrCreate(
                    ['event_id' => $event->id, 'user_id' => $userId],
                    ['role' => 'photographer', 'status' => 'assigned', 'invited_at' => now()]
                );
                $linksCreated++;
            }
        }
    });

echo 'Events scanned: '.$eventsScanned.PHP_EOL;
echo 'Links created: '.$linksCreated.PHP_EOL;
if ($dryRun) {
    echo "Dry run only. Use without --dry-run to apply.\n";
}
