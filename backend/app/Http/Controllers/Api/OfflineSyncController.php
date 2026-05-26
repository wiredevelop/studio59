<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\OfflineSync;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Client;
use App\Models\EventSelection;
use App\Models\Photo;
use App\Jobs\GeneratePhotoPreview;
use App\Support\OrderDownloadService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\Http\UploadedFile;
use Illuminate\Validation\ValidationException;

class OfflineSyncController extends Controller
{
    public function importPhotoBatch(Request $request, Event $event)
    {
        $files = $this->extractPhotoUploads($request);
        $validated = $request->validate([
            'photos_meta' => ['nullable', 'string'],
        ]);
        if (count($files) < 1) {
            throw ValidationException::withMessages([
                'photos' => 'The photos field is required.',
            ]);
        }
        if (count($files) > 20) {
            throw ValidationException::withMessages([
                'photos' => 'No máximo 20 fotos por lote.',
            ]);
        }
        foreach ($files as $file) {
            $validator = validator(
                ['photo' => $file],
                ['photo' => ['file', 'mimes:jpg,jpeg', 'max:51200']],
            );
            if ($validator->fails()) {
                throw ValidationException::withMessages([
                    'photos' => $validator->errors()->first('photo'),
                ]);
            }
        }

        $photosMeta = $this->decodePhotosMeta($validated['photos_meta'] ?? null);
        $photoMap = $this->importPhotos($event, $files, $photosMeta);

        return response()->json([
            'message' => 'Photos imported',
            'imported' => count($files),
            'mapped' => count($photoMap['id_map'] ?? []),
        ]);
    }

    public function export(Event $event)
    {
        $payload = [
            'event' => $event->only([
                'id',
                'name',
                'event_date',
                'event_time',
                'location',
                'status',
                'internal_code',
                'qr_token',
                'qr_enabled',
                'is_locked',
                'base_price',
                'price_per_photo',
                'event_type',
                'event_meta',
            ]),
            'client' => $event->client ? $event->client->only(['id', 'name', 'phone', 'email', 'notes', 'marketing_consent']) : null,
            'photos' => $event->photos()->orderBy('number')->get([
                'id',
                'number',
                'checksum',
                'status',
                'preview_path',
                'original_path',
                'created_at',
            ]),
            'orders' => $event->orders()->with('items')->orderByDesc('id')->get(),
            'selections' => EventSelection::where('event_id', $event->id)->orderByDesc('id')->get(),
            'exported_at' => now()->toIso8601String(),
        ];

        return response()->json($payload);
    }

    public function import(Request $request, Event $event)
    {
        $validated = $request->validate([
            'device_id' => ['nullable', 'string', 'max:120'],
            'payload' => ['required', 'file', 'mimes:json,txt', 'max:20480'],
            'photos' => ['nullable', 'array'],
            'photos.*' => ['file', 'mimes:jpg,jpeg', 'max:51200'],
        ]);

        $raw = file_get_contents($validated['payload']->getRealPath());
        $checksum = hash('sha256', $raw);

        $existing = OfflineSync::query()->where('checksum', $checksum)->first();
        if ($existing && $existing->status === 'completed') {
            return response()->json(['message' => 'Already imported', 'sync_id' => $existing->id]);
        }
        $sync = $existing ?: new OfflineSync();
        $sync->fill([
            'event_id' => $event->id,
            'device_id' => $validated['device_id'] ?? null,
            'status' => 'processing',
            'checksum' => $checksum,
            'payload' => $raw,
            'error' => null,
        ]);
        $sync->save();

        try {
            $data = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
            $photoMap = $this->importPhotos($event, $request->file('photos', []), $data['photos'] ?? []);
            $orders = $data['orders'] ?? [];
            $clients = $data['clients'] ?? [];
            $selections = $data['selections'] ?? [];
            $orderUpdates = $data['order_updates'] ?? [];
            $emailsToSend = [];
            $supportsCashColumns = $this->supportsOrderCashColumns();

            DB::transaction(function () use ($event, $orders, $clients, $selections, $orderUpdates, $photoMap, &$emailsToSend, $supportsCashColumns) {
                foreach ($clients as $clientPayload) {
                    $email = $clientPayload['email'] ?? null;
                    $phone = $clientPayload['phone'] ?? null;
                    $query = Client::query();
                    if ($email) {
                        $query->where('email', $email);
                    } elseif ($phone) {
                        $query->where('phone', $phone);
                    }
                    $existing = $query->first();
                    if ($existing) {
                        $existing->update([
                            'name' => $clientPayload['name'] ?? $existing->name,
                            'phone' => $phone ?? $existing->phone,
                            'email' => $email ?? $existing->email,
                        ]);
                    } else {
                        Client::create([
                            'name' => $clientPayload['name'] ?? 'Cliente',
                            'phone' => $phone,
                            'email' => $email,
                            'notes' => $clientPayload['notes'] ?? null,
                            'marketing_consent' => $clientPayload['marketing_consent'] ?? false,
                        ]);
                    }
                }

                foreach ($orders as $orderPayload) {
                    $attributes = [
                        'event_id' => $event->id,
                        'customer_name' => $orderPayload['customer_name'] ?? 'Cliente',
                        'customer_phone' => $orderPayload['customer_phone'] ?? null,
                        'customer_email' => $orderPayload['customer_email'] ?? null,
                        'product_type' => $orderPayload['product_type'] ?? null,
                        'delivery_type' => $orderPayload['delivery_type'] ?? null,
                        'delivery_address' => $orderPayload['delivery_address'] ?? null,
                        'wants_film' => $orderPayload['wants_film'] ?? false,
                        'film_fee' => $orderPayload['film_fee'] ?? 0,
                        'shipping_fee' => $orderPayload['shipping_fee'] ?? 0,
                        'extras_total' => $orderPayload['extras_total'] ?? 0,
                        'items_total' => $orderPayload['items_total'] ?? 0,
                        'payment_method' => $orderPayload['payment_method'] ?? 'cash',
                        'status' => $orderPayload['status'] ?? 'pending',
                        'total_amount' => $orderPayload['total_amount'] ?? 0,
                        'created_at' => $orderPayload['created_at'] ?? now(),
                        'updated_at' => $orderPayload['updated_at'] ?? now(),
                    ];
                    if ($supportsCashColumns) {
                        $attributes['cash_received_amount'] = $orderPayload['cash_received_amount'] ?? null;
                        $attributes['cash_change_amount'] = $orderPayload['cash_change_amount'] ?? null;
                        $attributes['cash_due_amount'] = $orderPayload['cash_due_amount'] ?? null;
                    }
                    $order = Order::query()->firstOrCreate(
                        ['order_code' => $orderPayload['order_code']],
                        $attributes
                    );

                    if (! empty($orderPayload['items']) && is_array($orderPayload['items'])) {
                        foreach ($orderPayload['items'] as $item) {
                            $resolvedPhotoId = $this->resolveImportedPhotoId($event, $item, $photoMap);
                            OrderItem::query()->firstOrCreate(
                                [
                                    'order_id' => $order->id,
                                    'photo_id' => $resolvedPhotoId,
                                ],
                                [
                                    'price' => $item['price'] ?? 0,
                                    'quantity' => $item['quantity'] ?? 1,
                                ]
                            );
                        }
                    }

                    if (
                        in_array($order->status, ['paid', 'delivered'], true) &&
                        in_array((string) $order->product_type, ['digital', 'both'], true) &&
                        ! empty($order->customer_email)
                    ) {
                        $emailsToSend[] = $order->id;
                    }
                }

                foreach ($selections as $sel) {
                    if (empty($sel['uuid'])) continue;
                    $resolvedPhotoId = $this->resolveImportedPhotoId($event, $sel, $photoMap);
                    EventSelection::firstOrCreate(
                        ['uuid' => $sel['uuid']],
                        [
                            'event_id' => $event->id,
                            'device_id' => $sel['device_id'] ?? null,
                            'photo_id' => $resolvedPhotoId,
                            'status' => $sel['status'] ?? 'selected',
                            'selected_at' => $sel['selected_at'] ?? now(),
                        ]
                    );
                }

                foreach ($orderUpdates as $update) {
                    if (empty($update['order_id']) || empty($update['status'])) continue;
                    $updatePayload = [
                        'status' => $update['status'],
                    ];
                    if ($supportsCashColumns) {
                        $updatePayload['cash_received_amount'] = $update['cash_received_amount'] ?? null;
                        $updatePayload['cash_change_amount'] = $update['cash_change_amount'] ?? null;
                        $updatePayload['cash_due_amount'] = $update['cash_due_amount'] ?? null;
                    }
                    if (array_key_exists('notes', $update)) {
                        $updatePayload['notes'] = $update['notes'];
                    }
                    Order::where('id', $update['order_id'])->update($updatePayload);
                }
            });

            foreach (array_unique($emailsToSend) as $orderId) {
                $order = Order::query()->find($orderId);
                if ($order) {
                    OrderDownloadService::sendAccessLink($order, true);
                }
            }

            $sync->update(['status' => 'completed']);

            return response()->json(['message' => 'Imported', 'sync_id' => $sync->id]);
        } catch (\Throwable $e) {
            $sync->update([
                'status' => 'error',
                'error' => $e->getMessage(),
            ]);

            return response()->json(['message' => 'Import failed', 'detail' => $e->getMessage()], 422);
        }
    }

    private function importPhotos(Event $event, array $files, array $photosMeta): array
    {
        $idMap = [];
        $numberMap = [];
        $existingPhotos = Photo::query()
            ->where('event_id', $event->id)
            ->get(['id', 'number', 'checksum']);
        $existingByNumber = [];
        $existingByChecksum = [];
        $nextNumber = 0;

        foreach ($existingPhotos as $photo) {
            $number = trim((string) $photo->number);
            if ($number !== '') {
                $existingByNumber[$number] = $photo;
                $nextNumber = max($nextNumber, (int) $number);
            }
            $checksum = trim((string) ($photo->checksum ?? ''));
            if ($checksum !== '') {
                $existingByChecksum[$checksum] = $photo;
            }
        }

        $metaByName = collect($photosMeta)
            ->filter(fn ($photo) => is_array($photo))
            ->mapWithKeys(function (array $photo) {
                $paths = [
                    $photo['original_path'] ?? null,
                    $photo['preview_path'] ?? null,
                ];
                foreach ($paths as $path) {
                    if (! is_string($path) || trim($path) === '') {
                        continue;
                    }
                    return [basename($path) => $photo];
                }

                return [];
            });
        $metaByNumber = collect($photosMeta)
            ->filter(fn ($photo) => is_array($photo) && ! empty($photo['number']))
            ->mapWithKeys(fn (array $photo) => [trim((string) $photo['number']) => $photo]);

        foreach ($files as $file) {
            if (! $file instanceof UploadedFile) {
                continue;
            }

            $meta = $metaByName->get($file->getClientOriginalName());
            $numberFromFile = preg_replace('/\D+/', '', pathinfo($file->getClientOriginalName(), PATHINFO_FILENAME));
            if (! is_array($meta) && is_string($numberFromFile) && $numberFromFile !== '') {
                $meta = $metaByNumber->get(str_pad($numberFromFile, 4, '0', STR_PAD_LEFT));
            }
            $photo = $this->storeImportedPhoto(
                $event,
                $file,
                is_array($meta) ? $meta : [],
                $existingByNumber,
                $existingByChecksum,
                $nextNumber,
            );

            if (is_array($meta) && ! empty($meta['id'])) {
                $idMap[(int) $meta['id']] = $photo->id;
            }
            if (! empty($photo->number)) {
                $numberMap[(string) $photo->number] = $photo->id;
            }
        }

        foreach ($photosMeta as $meta) {
            if (! is_array($meta)) {
                continue;
            }
            $number = isset($meta['number']) ? trim((string) $meta['number']) : '';
            if ($number !== '' && isset($existingByNumber[$number])) {
                $numberMap[$number] = $existingByNumber[$number]->id;
            }
            if (! empty($meta['id']) && $number !== '' && isset($numberMap[$number])) {
                $idMap[(int) $meta['id']] = $numberMap[$number];
            }
        }

        return [
            'id_map' => $idMap,
            'number_map' => $numberMap,
        ];
    }

    private function decodePhotosMeta(?string $raw): array
    {
        if (! is_string($raw) || trim($raw) === '') {
            return [];
        }

        try {
            $decoded = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
        } catch (\Throwable) {
            throw ValidationException::withMessages([
                'photos_meta' => 'Manifesto de fotos inválido.',
            ]);
        }

        return is_array($decoded) ? $decoded : [];
    }

    private function extractPhotoUploads(Request $request): array
    {
        $candidates = [
            $request->file('photos'),
            $request->file('photos[]'),
        ];

        foreach ($request->allFiles() as $key => $value) {
            if (str_starts_with((string) $key, 'photos')) {
                $candidates[] = $value;
            }
        }

        $files = [];
        $seen = [];
        foreach ($candidates as $candidate) {
            if ($candidate instanceof UploadedFile) {
                $key = spl_object_id($candidate);
                if (! isset($seen[$key])) {
                    $files[] = $candidate;
                    $seen[$key] = true;
                }
                continue;
            }
            if (! is_array($candidate)) {
                continue;
            }
            foreach ($candidate as $file) {
                if ($file instanceof UploadedFile) {
                    $key = spl_object_id($file);
                    if (! isset($seen[$key])) {
                        $files[] = $file;
                        $seen[$key] = true;
                    }
                }
            }
        }

        return array_values($files);
    }

    private function storeImportedPhoto(
        Event $event,
        UploadedFile $file,
        array $meta,
        array &$existingByNumber,
        array &$existingByChecksum,
        int &$nextNumber
    ): Photo {
        $imageType = @exif_imagetype($file->getRealPath());
        if ($imageType !== IMAGETYPE_JPEG) {
            throw ValidationException::withMessages([
                'photos' => 'Só são aceites fotos JPG/JPEG na importação offline.',
            ]);
        }

        $checksum = trim((string) ($meta['checksum'] ?? ''));
        if ($checksum !== '' && isset($existingByChecksum[$checksum])) {
            return $this->ensurePreviewGenerated($existingByChecksum[$checksum]);
        }

        $number = trim((string) ($meta['number'] ?? ''));
        if ($number !== '') {
            if (isset($existingByNumber[$number])) {
                $existing = $existingByNumber[$number];
                $existingChecksum = trim((string) ($existing->checksum ?? ''));
                if ($checksum === '' || $existingChecksum === '' || $existingChecksum === $checksum) {
                    return $this->ensurePreviewGenerated($existing);
                }
                throw ValidationException::withMessages([
                    'photos' => "Já existe uma foto #{$number} neste evento com ficheiro diferente.",
                ]);
            }
        } else {
            $nextNumber++;
            $number = str_pad((string) $nextNumber, 4, '0', STR_PAD_LEFT);
        }
        $nextNumber = max($nextNumber, (int) $number);

        $originalPath = 'events/'.$event->id.'/originals/'.$number.'.jpg';
        Storage::disk('local')->makeDirectory(dirname($originalPath));
        $stream = fopen($file->getRealPath(), 'rb');
        Storage::disk('local')->put($originalPath, $stream);
        if (is_resource($stream)) {
            fclose($stream);
        }

        $photo = Photo::query()->create([
            'event_id' => $event->id,
            'number' => $number,
            'original_path' => $originalPath,
            'mime' => 'image/jpeg',
            'size' => (int) ($file->getSize() ?? 0),
            'width' => null,
            'height' => null,
            'status' => 'active',
            'preview_status' => 'pending',
            'preview_error' => null,
            'checksum' => $checksum !== '' ? $checksum : null,
        ]);

        $existingByNumber[$number] = $photo;
        if ($checksum !== '') {
            $existingByChecksum[$checksum] = $photo;
        }

        return $this->ensurePreviewGenerated($photo);
    }

    private function ensurePreviewGenerated(Photo $photo): Photo
    {
        if (
            $photo->preview_path &&
            $photo->preview_status === 'ready' &&
            Storage::disk('local')->exists($photo->preview_path)
        ) {
            return $photo;
        }

        GeneratePhotoPreview::dispatchSync($photo->id);

        return $photo->fresh() ?? $photo;
    }

    private function resolveImportedPhotoId(Event $event, array $payload, array $photoMap): ?int
    {
        $number = isset($payload['photo_number']) ? trim((string) $payload['photo_number']) : '';
        if ($number !== '' && isset($photoMap['number_map'][$number])) {
            return (int) $photoMap['number_map'][$number];
        }

        $photoId = isset($payload['photo_id']) ? (int) $payload['photo_id'] : 0;
        if ($photoId > 0 && isset($photoMap['id_map'][$photoId])) {
            return (int) $photoMap['id_map'][$photoId];
        }

        if ($photoId > 0) {
            $existing = Photo::query()
                ->where('event_id', $event->id)
                ->where('id', $photoId)
                ->first();
            if ($existing) {
                return $existing->id;
            }
        }

        return null;
    }

    private function supportsOrderCashColumns(): bool
    {
        return Schema::hasColumn('orders', 'cash_received_amount')
            && Schema::hasColumn('orders', 'cash_change_amount')
            && Schema::hasColumn('orders', 'cash_due_amount');
    }
}
