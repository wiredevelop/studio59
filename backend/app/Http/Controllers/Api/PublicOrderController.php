<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PublicCreateOrderRequest;
use App\Models\Order;
use App\Models\Photo;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;

class PublicOrderController extends Controller
{
    public function store(PublicCreateOrderRequest $request)
    {
        $eventSession = $request->attributes->get('event_session');

        if ((int) $eventSession->event_id !== (int) $request->integer('event_id')) {
            return response()->json(['message' => 'Invalid session for event'], 403);
        }

        $photoItemsPayload = $request->input('photo_items');
        $photoIds = collect($request->input('photo_ids'));
        $photoItems = collect();

        if (is_array($photoItemsPayload) && ! empty($photoItemsPayload)) {
            $photoItems = collect($photoItemsPayload)
                ->map(fn ($item) => [
                    'photo_id' => (int) ($item['photo_id'] ?? 0),
                    'quantity' => max(1, (int) ($item['quantity'] ?? 1)),
                ])
                ->filter(fn ($item) => $item['photo_id'] > 0)
                ->values();
            $photoIds = $photoItems->pluck('photo_id')->unique()->values();
        } else {
            $photoIds = $photoIds->unique()->values();
            $photoItems = $photoIds->map(fn ($id) => ['photo_id' => (int) $id, 'quantity' => 1])->values();
        }

        $photos = Photo::query()
            ->where('event_id', $request->integer('event_id'))
            ->whereIn('id', $photoIds)
            ->get();

        if ($photos->count() !== $photoIds->count()) {
            return response()->json(['message' => 'Some photos do not belong to event'], 422);
        }

        $order = DB::transaction(function () use ($request, $photos, $photoItems) {
            $price = (float) $photos->first()->event->price_per_photo;
            $quantities = $photoItems->keyBy('photo_id');
            $itemsTotal = 0;
            foreach ($photos as $photo) {
                $qty = (int) ($quantities[$photo->id]['quantity'] ?? 1);
                $itemsTotal += $qty * $price;
            }

            $deliveryType = $request->input('delivery_type');
            $productType = $request->string('product_type')->toString();
            $wantsFilm = (bool) $request->boolean('wants_film');
            $shippingFee = $deliveryType === 'shipping' ? 5.00 : 0.00;
            $filmFee = $wantsFilm ? 30.00 : 0.00;
            $extrasTotal = $shippingFee + $filmFee;
            $total = $itemsTotal + $extrasTotal;

            $order = Order::create([
                'event_id' => $request->integer('event_id'),
                'order_code' => $this->newOrderCode(),
                'customer_name' => $request->string('customer_name')->toString(),
                'customer_phone' => $request->input('customer_phone'),
                'customer_email' => $request->input('customer_email'),
                'product_type' => $productType,
                'delivery_type' => $deliveryType,
                'delivery_address' => $request->input('delivery_address'),
                'wants_film' => $wantsFilm,
                'film_fee' => $filmFee,
                'shipping_fee' => $shippingFee,
                'extras_total' => $extrasTotal,
                'items_total' => $itemsTotal,
                'payment_method' => $request->string('payment_method')->toString(),
                'status' => 'pending',
                'total_amount' => $total,
            ]);

            foreach ($photos as $photo) {
                $qty = (int) ($quantities[$photo->id]['quantity'] ?? 1);
                $order->items()->create([
                    'photo_id' => $photo->id,
                    'price' => $price,
                    'quantity' => $qty,
                ]);
            }

            return $order;
        });

        return response()->json([
            'order_code' => $order->order_code,
            'status' => $order->status,
            'total_amount' => $order->total_amount,
        ], 201);
    }

    public function show(Request $request, string $orderCode)
    {
        $order = Order::with(['items.photo'])->where('order_code', $orderCode)->firstOrFail();

        return response()->json([
            'order_code' => $order->order_code,
            'status' => $order->status,
            'total_amount' => $order->total_amount,
            'items_total' => $order->items_total,
            'extras_total' => $order->extras_total,
            'shipping_fee' => $order->shipping_fee,
            'film_fee' => $order->film_fee,
            'product_type' => $order->product_type,
            'delivery_type' => $order->delivery_type,
            'delivery_address' => $order->delivery_address,
            'wants_film' => $order->wants_film,
            'payment_method' => $order->payment_method,
            'customer_name' => $order->customer_name,
            'photos' => $order->items->map(fn ($i) => [
                'id' => $i->photo->id,
                'number' => $i->photo->number,
                'quantity' => $i->quantity ?? 1,
            ]),
        ]);
    }

    public function downloadLink(Request $request, string $orderCode)
    {
        $request->validate([
            'photo_id' => ['required', 'integer', 'exists:photos,id'],
        ]);

        $order = Order::with('items.photo')->where('order_code', $orderCode)->firstOrFail();

        if ($order->status !== 'paid') {
            return response()->json(['message' => 'Order is not paid'], 422);
        }

        $photo = $order->items->firstWhere('photo_id', (int) $request->integer('photo_id'))?->photo;
        if (! $photo) {
            return response()->json(['message' => 'Photo not in order'], 403);
        }

        $url = URL::temporarySignedRoute(
            'public.download.original',
            now()->addMinutes(10),
            ['order' => $order->id, 'photo' => $photo->id]
        );

        return response()->json(['download_url' => $url, 'expires_in_minutes' => 10]);
    }

    public function streamOriginal(Request $request, int $order, int $photo)
    {
        $orderModel = Order::with('items.photo')->findOrFail($order);

        if ($orderModel->status !== 'paid') {
            abort(403);
        }

        $photoModel = $orderModel->items->firstWhere('photo_id', $photo)?->photo;
        if (! $photoModel) {
            abort(403);
        }

        $path = storage_path('app/private/'.$photoModel->original_path);
        if (! is_file($path)) {
            abort(404);
        }

        return response()->download(
            $path,
            $photoModel->number.'.jpg'
        );
    }

    private function newOrderCode(): string
    {
        do {
            $code = 'S59-'.Str::upper(Str::random(8));
        } while (Order::where('order_code', $code)->exists());

        return $code;
    }
}
