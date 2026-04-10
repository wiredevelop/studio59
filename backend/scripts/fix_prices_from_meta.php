<?php

use App\Models\Event;

require __DIR__.'/../vendor/autoload.php';

$app = require __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

function normalize_money($value): ?float {
    if ($value === null || $value === '') {
        return null;
    }
    if (is_numeric($value)) {
        return (float) $value;
    }
    $text = strtolower(trim((string) $value));
    if ($text === '') {
        return null;
    }
    $text = str_replace(['€', 'eur', 'euros'], '', $text);
    if (! preg_match('/\\d+(?:[\\.,]\\d{3})*(?:[\\.,]\\d+)?/', $text, $m)) {
        return null;
    }
    $num = $m[0];
    if (str_contains($num, ',') && str_contains($num, '.')) {
        if (strrpos($num, ',') > strrpos($num, '.')) {
            $num = str_replace('.', '', $num);
            $num = str_replace(',', '.', $num);
        } else {
            $num = str_replace(',', '', $num);
        }
    } elseif (str_contains($num, ',')) {
        $num = str_replace(',', '.', $num);
    }
    if (! is_numeric($num)) {
        return null;
    }
    return (float) $num;
}

$updated = 0;

Event::query()
    ->whereNotNull('event_meta')
    ->orderBy('id')
    ->chunkById(200, function ($events) use (&$updated) {
        foreach ($events as $event) {
            $meta = $event->event_meta ?? [];
            $rawBase = $meta['PRECO_BASE_raw'] ?? null;
            $rawTotal = $meta['PRECO_raw'] ?? null;

            $newBase = normalize_money($rawBase);
            $newTotal = normalize_money($rawTotal);

            $update = [];
            if ($newBase !== null) {
                $update['base_price'] = $newBase;
            }
            if ($newTotal !== null) {
                $update['total_price'] = $newTotal;
            }
            if (! $update) {
                continue;
            }
            $event->update($update);
            $updated++;
        }
    });

echo 'Updated events: '.$updated.PHP_EOL;
