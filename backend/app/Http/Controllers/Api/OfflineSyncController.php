<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\OfflineSync;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Client;
use App\Models\EventSelection;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OfflineSyncController extends Controller
{
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
        ]);

        $raw = file_get_contents($validated['payload']->getRealPath());
        $checksum = hash('sha256', $raw);

        $existing = OfflineSync::query()->where('checksum', $checksum)->first();
        if ($existing) {
            return response()->json(['message' => 'Already imported', 'sync_id' => $existing->id]);
        }

        $sync = OfflineSync::create([
            'event_id' => $event->id,
            'device_id' => $validated['device_id'] ?? null,
            'status' => 'processing',
            'checksum' => $checksum,
            'payload' => $raw,
        ]);

        try {
            $data = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
            $orders = $data['orders'] ?? [];
            $clients = $data['clients'] ?? [];
            $selections = $data['selections'] ?? [];
            $orderUpdates = $data['order_updates'] ?? [];

            DB::transaction(function () use ($event, $orders, $clients, $selections, $orderUpdates) {
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
                    $order = Order::query()->firstOrCreate(
                        ['order_code' => $orderPayload['order_code']],
                        [
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
                        ]
                    );

                    if (! empty($orderPayload['items']) && is_array($orderPayload['items'])) {
                        foreach ($orderPayload['items'] as $item) {
                            OrderItem::query()->firstOrCreate(
                                [
                                    'order_id' => $order->id,
                                    'photo_id' => $item['photo_id'] ?? null,
                                ],
                                [
                                    'price' => $item['price'] ?? 0,
                                    'quantity' => $item['quantity'] ?? 1,
                                ]
                            );
                        }
                    }
                }

                foreach ($selections as $sel) {
                    if (empty($sel['uuid'])) continue;
                    EventSelection::firstOrCreate(
                        ['uuid' => $sel['uuid']],
                        [
                            'event_id' => $event->id,
                            'device_id' => $sel['device_id'] ?? null,
                            'photo_id' => $sel['photo_id'] ?? null,
                            'status' => $sel['status'] ?? 'selected',
                            'selected_at' => $sel['selected_at'] ?? now(),
                        ]
                    );
                }

                foreach ($orderUpdates as $update) {
                    if (empty($update['order_id']) || empty($update['status'])) continue;
                    Order::where('id', $update['order_id'])->update(['status' => $update['status']]);
                }
            });

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
}
