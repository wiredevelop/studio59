<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PublicCreateOrderRequest;
use App\Models\Order;
use App\Models\Photo;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Stripe\Checkout\Session as StripeCheckoutSession;
use Stripe\PaymentIntent;
use Stripe\Stripe;

class PublicOrderController extends Controller
{
    public function store(PublicCreateOrderRequest $request)
    {
        $eventSession = $request->attributes->get('event_session');

        if ((int) $eventSession->event_id !== (int) $request->integer('event_id')) {
            return response()->json(['message' => 'Invalid session for event'], 403);
        }

        if ($request->string('payment_method')->toString() !== 'cash') {
            return response()->json(['message' => 'Pagamento online deve ser concluído com Stripe.'], 422);
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
            ->with('event')
            ->where('event_id', $request->integer('event_id'))
            ->whereIn('id', $photoIds)
            ->get();

        if ($photos->count() !== $photoIds->count()) {
            return response()->json(['message' => 'Some photos do not belong to event'], 422);
        }

        if ($photoIds->isEmpty()) {
            return response()->json(['message' => 'Seleciona pelo menos 1 foto.'], 422);
        }

        if ($photos->isEmpty()) {
            return response()->json(['message' => 'Seleciona pelo menos 1 foto.'], 422);
        }

        $order = DB::transaction(function () use ($request, $photos, $photoItems) {
            $price = (float) ($photos->first()->event->price_per_photo ?? 0);
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

            $paymentMethod = $request->string('payment_method')->toString();
            $paymentMethod = $paymentMethod === 'cash' ? 'cash' : 'online';

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
                'payment_method' => $paymentMethod,
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

    public function createStripeIntent(Request $request)
    {
        $eventSession = $request->attributes->get('event_session');

        $validated = $request->validate([
            'event_id' => ['required', 'exists:events,id'],
            'customer_name' => ['required', 'string', 'max:255'],
            'customer_phone' => ['required', 'string', 'max:50'],
            'customer_email' => ['required', 'email', 'max:255'],
            'payment_method' => ['required', 'in:online'],
            'product_type' => ['required', 'in:digital,paper,both'],
            'delivery_type' => ['nullable', 'in:pickup,shipping'],
            'delivery_address' => ['nullable', 'string', 'max:1000'],
            'wants_film' => ['nullable', 'boolean'],
            'photo_ids' => ['nullable', 'array', 'min:1'],
            'photo_ids.*' => ['integer', 'exists:photos,id'],
            'photo_items' => ['nullable', 'array', 'min:1'],
            'photo_items.*.photo_id' => ['required_with:photo_items', 'integer', 'exists:photos,id'],
            'photo_items.*.quantity' => ['required_with:photo_items', 'integer', 'min:1', 'max:50'],
        ]);

        if ((int) $eventSession->event_id !== (int) $request->integer('event_id')) {
            return response()->json(['message' => 'Invalid session for event'], 403);
        }

        if ($validated['product_type'] !== 'digital' && empty($validated['delivery_type'])) {
            return response()->json(['message' => 'Escolhe o tipo de entrega.'], 422);
        }
        if (($validated['delivery_type'] ?? '') === 'shipping' && empty($validated['delivery_address'])) {
            return response()->json(['message' => 'Morada obrigatória para envio.'], 422);
        }

        $stripeSecret = config('services.stripe.secret');
        $stripePublishable = config('services.stripe.publishable');
        if (empty($stripeSecret) || empty($stripePublishable)) {
            return response()->json(['message' => 'Pagamento online indisponível de momento.'], 422);
        }
        if (! class_exists(Stripe::class)) {
            \Log::error('Stripe SDK missing: install stripe/stripe-php and run composer install.');
            return response()->json(['message' => 'Stripe indisponível no servidor (SDK em falta).'], 500);
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
            ->with('event')
            ->where('event_id', $request->integer('event_id'))
            ->whereIn('id', $photoIds)
            ->get();

        if ($photos->count() !== $photoIds->count()) {
            return response()->json(['message' => 'Some photos do not belong to event'], 422);
        }

        $order = DB::transaction(function () use ($request, $photos, $photoItems) {
            $price = (float) ($photos->first()->event->price_per_photo ?? 0);
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
                'payment_method' => 'online',
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

        Stripe::setApiKey($stripeSecret);
        $amountCents = (int) round(((float) $order->total_amount) * 100);
        if ($amountCents < 1) {
            return response()->json(['message' => 'Total inválido para pagamento online.'], 422);
        }

        $quantities = $photoItems->keyBy('photo_id');
        $photoSummary = $photos->map(function ($photo) use ($quantities) {
            $qty = (int) ($quantities[$photo->id]['quantity'] ?? 1);
            $label = $photo->number ?: $photo->id;
            return $label.'x'.$qty;
        })->implode(', ');
        if (strlen($photoSummary) > 480) {
            $photoSummary = substr($photoSummary, 0, 477).'...';
        }

        try {
            $intentPayload = [
                'amount' => $amountCents,
                'currency' => 'eur',
                'receipt_email' => $order->customer_email,
                'description' => 'Pedido '.$order->order_code.' - '.$order->customer_name,
                'metadata' => [
                    'order_id' => (string) $order->id,
                    'order_code' => $order->order_code,
                    'event_id' => (string) $request->integer('event_id'),
                    'customer_name' => $order->customer_name,
                    'photo_items' => $photoSummary,
                    'photo_count' => (string) $photos->count(),
                    'items_qty' => (string) $photoItems->sum('quantity'),
                ],
            ];

            $mobileMethodList = array_values(array_filter(array_map('trim', explode(',', (string) config('services.stripe.payment_methods_mobile')))));
            if (! empty($mobileMethodList)) {
                $intentPayload['payment_method_types'] = $mobileMethodList;
            } else {
                $intentPayload['automatic_payment_methods'] = [
                    'enabled' => true,
                    'allow_redirects' => 'always',
                ];
            }

            $intent = PaymentIntent::create($intentPayload);
        } catch (\Throwable $e) {
            \Log::error('Stripe payment intent failed', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
            ]);
            return response()->json(['message' => 'Falha ao iniciar pagamento online.'], 422);
        }

        $order->update([
            'stripe_payment_intent_id' => $intent->id ?? null,
        ]);

        return response()->json([
            'order_code' => $order->order_code,
            'client_secret' => $intent->client_secret,
            'publishable_key' => $stripePublishable,
        ], 201);
    }

    public function createStripeCheckoutSession(Request $request)
    {
        $eventSession = $request->attributes->get('event_session');

        $validated = $request->validate([
            'event_id' => ['required', 'exists:events,id'],
            'customer_name' => ['required', 'string', 'max:255'],
            'customer_phone' => ['required', 'string', 'max:50'],
            'customer_email' => ['required', 'email', 'max:255'],
            'payment_method_type' => ['required', Rule::in([
                'mb_way',
                'paypal',
                'revolut_pay',
                'amazon_pay',
                'bancontact',
                'eps',
                'klarna',
            ])],
            'product_type' => ['required', 'in:digital,paper,both'],
            'delivery_type' => ['nullable', 'in:pickup,shipping'],
            'delivery_address' => ['nullable', 'string', 'max:1000'],
            'wants_film' => ['nullable', 'boolean'],
            'photo_ids' => ['nullable', 'array', 'min:1'],
            'photo_ids.*' => ['integer', 'exists:photos,id'],
            'photo_items' => ['nullable', 'array', 'min:1'],
            'photo_items.*.photo_id' => ['required_with:photo_items', 'integer', 'exists:photos,id'],
            'photo_items.*.quantity' => ['required_with:photo_items', 'integer', 'min:1', 'max:50'],
        ]);

        if ((int) $eventSession->event_id !== (int) $request->integer('event_id')) {
            return response()->json(['message' => 'Invalid session for event'], 403);
        }

        if ($validated['product_type'] !== 'digital' && empty($validated['delivery_type'])) {
            return response()->json(['message' => 'Escolhe o tipo de entrega.'], 422);
        }
        if (($validated['delivery_type'] ?? '') === 'shipping' && empty($validated['delivery_address'])) {
            return response()->json(['message' => 'Morada obrigatória para envio.'], 422);
        }

        $stripeSecret = config('services.stripe.secret');
        $stripePublishable = config('services.stripe.publishable');
        if (empty($stripeSecret) || empty($stripePublishable)) {
            return response()->json(['message' => 'Pagamento online indisponível de momento.'], 422);
        }
        if (! class_exists(Stripe::class)) {
            Log::error('Stripe SDK missing: install stripe/stripe-php and run composer install.');
            return response()->json(['message' => 'Stripe indisponível no servidor (SDK em falta).'], 500);
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
            ->with('event')
            ->where('event_id', $request->integer('event_id'))
            ->whereIn('id', $photoIds)
            ->get();

        if ($photos->count() !== $photoIds->count()) {
            return response()->json(['message' => 'Some photos do not belong to event'], 422);
        }

        $order = DB::transaction(function () use ($request, $photos, $photoItems) {
            $price = (float) ($photos->first()->event->price_per_photo ?? 0);
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
                'payment_method' => 'online',
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

        Stripe::setApiKey($stripeSecret);
        $amountCents = (int) round(((float) $order->total_amount) * 100);
        if ($amountCents < 1) {
            return response()->json(['message' => 'Total inválido para pagamento online.'], 422);
        }

        $quantities = $photoItems->keyBy('photo_id');
        $photoSummary = $photos->map(function ($photo) use ($quantities) {
            $qty = (int) ($quantities[$photo->id]['quantity'] ?? 1);
            $label = $photo->number ?: $photo->id;
            return $label.'x'.$qty;
        })->implode(', ');
        if (strlen($photoSummary) > 480) {
            $photoSummary = substr($photoSummary, 0, 477).'...';
        }

        try {
            $successUrl = 'flutterstripe://checkout?status=success&order_code='.$order->order_code;
            $cancelUrl = 'flutterstripe://checkout?status=cancel&order_code='.$order->order_code;

            $session = StripeCheckoutSession::create([
                'mode' => 'payment',
                'payment_method_types' => [$validated['payment_method_type']],
                'line_items' => [[
                    'quantity' => 1,
                    'price_data' => [
                        'currency' => 'eur',
                        'unit_amount' => $amountCents,
                        'product_data' => [
                            'name' => 'Pedido '.$order->order_code,
                            'description' => 'Fotos: '.$photoSummary,
                        ],
                    ],
                ]],
                'success_url' => $successUrl,
                'cancel_url' => $cancelUrl,
                'customer_email' => $order->customer_email,
                'client_reference_id' => $order->order_code,
                'payment_intent_data' => [
                    'description' => 'Pedido '.$order->order_code.' - '.$order->customer_name,
                    'metadata' => [
                        'order_id' => (string) $order->id,
                        'order_code' => $order->order_code,
                        'event_id' => (string) $request->integer('event_id'),
                        'customer_name' => $order->customer_name,
                        'photo_items' => $photoSummary,
                        'photo_count' => (string) $photos->count(),
                        'items_qty' => (string) $photoItems->sum('quantity'),
                    ],
                ],
                'metadata' => [
                    'order_id' => (string) $order->id,
                    'order_code' => $order->order_code,
                    'event_id' => (string) $request->integer('event_id'),
                ],
            ]);
        } catch (\Throwable $e) {
            Log::error('Stripe checkout session failed', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
            ]);
            return response()->json(['message' => 'Falha ao iniciar pagamento online. Tenta novamente.'], 422);
        }

        $order->update([
            'stripe_session_id' => $session->id ?? null,
        ]);

        return response()->json([
            'order_code' => $order->order_code,
            'checkout_url' => $session->url,
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
            'photos' => $order->items
                ->filter(fn ($i) => $i->photo !== null)
                ->map(fn ($i) => [
                    'id' => $i->photo->id,
                    'number' => $i->photo->number,
                    'quantity' => $i->quantity ?? 1,
                ])
                ->values(),
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

    public function logClientIssue(Request $request)
    {
        $validated = $request->validate([
            'message' => ['required', 'string', 'max:2000'],
            'context' => ['nullable', 'array'],
        ]);

        $session = $request->attributes->get('event_session');

        Log::warning('mobile.client.issue', [
            'message' => $validated['message'],
            'context' => $validated['context'] ?? [],
            'event_id' => $session?->event_id,
            'session_id' => $session?->id,
            'ip' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        return response()->json(['ok' => true]);
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
