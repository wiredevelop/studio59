<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\Order;
use App\Models\Photo;
use App\Support\Audit;
use App\Support\OrderDownloadService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Stripe\PaymentIntent;
use Stripe\Stripe;

class GuestController extends Controller
{
    public function events()
    {
        $events = Event::query()
            ->whereDate('event_date', Carbon::today('Europe/Lisbon'))
            ->where('is_active_today', true)
            ->orderBy('name')
            ->get();

        return view('guest.events', compact('events'));
    }

    public function showEnter(Event $event)
    {
        return view('guest.enter', compact('event'));
    }

    public function enter(Request $request, Event $event)
    {
        $request->validate([
            'pin' => ['required', 'string'],
        ]);

        $pin = trim($request->string('pin')->toString());
        $accessPin = (string) ($event->access_pin ?? '');

        if (! hash_equals($accessPin, $pin)) {
            return back()->withErrors(['PIN inválido.'])->withInput();
        }

        session()->put($this->sessionKey($event->id), true);

        return redirect()->route('guest.catalog', $event)
            ->with('clear_guest_cart', true);
    }

    public function reset(Event $event)
    {
        session()->forget($this->sessionKey($event->id));

        return redirect()->route('guest.enter.form', $event)
            ->with('ok', 'Sessão limpa. Novo convidado pronto.')
            ->with('clear_guest_cart', true);
    }

    public function catalog(Request $request, Event $event)
    {
        $this->ensureSession($event);

        $search = trim((string) $request->query('search', ''));

        $photos = $event->photos()
            ->where('status', 'active')
            ->whereNotNull('preview_path')
            ->when($search !== '', fn ($q) => $q->where('number', 'like', '%'.$search.'%'))
            ->orderBy('number')
            ->paginate(9)
            ->withQueryString();

        return view('guest.catalog', [
            'event' => $event,
            'photos' => $photos,
            'search' => $search,
        ]);
    }

    public function cart(Event $event)
    {
        $this->ensureSession($event);

        return view('guest.cart', [
            'event' => $event,
        ]);
    }

    public function checkout(Event $event)
    {
        $this->ensureSession($event);

        return view('guest.checkout', [
            'event' => $event,
        ]);
    }

    public function faceSearch(Request $request, Event $event)
    {
        @set_time_limit(0);

        $this->ensureSession($event);

        $validated = $request->validate([
            'selfie' => ['required', 'image', 'max:5120'],
        ]);

        $tmpDir = storage_path('app/private/tmp');
        if (! is_dir($tmpDir)) {
            mkdir($tmpDir, 0775, true);
        }

        $selfieFile = $validated['selfie'];
        $selfiePath = $tmpDir.'/face-selfie-'.$event->id.'-'.uniqid().'.jpg';
        $selfieFile->move($tmpDir, basename($selfiePath));

        $photos = $event->photos()
            ->where('status', 'active')
            ->whereNotNull('preview_path')
            ->get(['id', 'preview_path', 'updated_at']);

        $photoList = [];
        foreach ($photos as $photo) {
            $path = Storage::disk('local')->path($photo->preview_path);
            if (is_file($path)) {
                $photoList[] = [
                    'id' => $photo->id,
                    'path' => $path,
                    'mtime' => filemtime($path) ?: null,
                ];
            }
        }

        $photosJson = $tmpDir.'/face-photos-'.$event->id.'-'.uniqid().'.json';
        file_put_contents($photosJson, json_encode($photoList, JSON_THROW_ON_ERROR));

        $indexDir = storage_path('app/private/face_index');
        if (! is_dir($indexDir)) {
            mkdir($indexDir, 0775, true);
        }
        $indexPath = $indexDir.'/event_'.$event->id.'.pkl';

        $insightDir = storage_path('app/private/insightface');
        if (! is_dir($insightDir)) {
            mkdir($insightDir, 0775, true);
        }
        putenv('INSIGHTFACE_HOME='.$insightDir);
        putenv('HOME='.$insightDir);

        $script = base_path('scripts/face_search.py');
        $cmd = [
            'python3',
            $script,
            '--event', (string) $event->id,
            '--selfie', $selfiePath,
            '--photos', $photosJson,
            '--index', $indexPath,
        ];

        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];

        $process = proc_open($cmd, $descriptors, $pipes);
        if (! is_resource($process)) {
            @unlink($selfiePath);
            @unlink($photosJson);
            return response()->json(['message' => 'Falha ao iniciar face search'], 500);
        }

        fclose($pipes[0]);
        $stdout = stream_get_contents($pipes[1]);
        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[1]);
        fclose($pipes[2]);
        $exitCode = proc_close($process);

        @unlink($selfiePath);
        @unlink($photosJson);

        if ($exitCode !== 0) {
            \Log::warning('Face search failed', [
                'event_id' => $event->id,
                'stderr' => trim($stderr),
            ]);
            return response()->json(['message' => 'Falha no processamento facial', 'detail' => trim($stderr)], 422);
        }

        $data = json_decode($stdout, true);
        if (! is_array($data)) {
            \Log::warning('Face search invalid response', [
                'event_id' => $event->id,
                'stdout' => trim($stdout),
                'stderr' => trim($stderr),
            ]);
            return response()->json(['message' => 'Resposta inválida do reconhecimento facial'], 422);
        }

        if (isset($data['error'])) {
            $msg = $data['error'] === 'no_face_detected' ? 'Nenhum rosto detetado.' : 'Erro no reconhecimento facial.';
            return response()->json(['message' => $msg], 422);
        }

        $suggested = $data['suggested'] ?? [];
        $suggestedIds = collect($suggested)->pluck('id')->unique()->values();

        $photosById = Photo::query()
            ->whereIn('id', $suggestedIds)
            ->get(['id', 'number', 'preview_path'])
            ->keyBy('id');

        $payload = $suggestedIds->map(function ($id) use ($photosById) {
            $photo = $photosById->get($id);
            if (! $photo) return null;
            return [
                'id' => $photo->id,
                'number' => $photo->number,
                'preview_url' => route('preview.image', ['photo' => $photo->id]),
            ];
        })->filter()->values();

        return response()->json(['suggested' => $payload]);
    }

    public function storeOrder(Request $request, Event $event)
    {
        $this->ensureSession($event);

        $validated = $request->validate([
            'customer_name' => ['required', 'string', 'max:255'],
            'customer_phone' => ['required', 'string', 'max:80'],
            'customer_email' => ['required', 'email', 'max:255'],
            'payment_method' => ['required', 'in:cash,online'],
            'product_type' => ['required', 'in:digital,paper,both'],
            'delivery_type' => ['nullable', 'in:pickup,shipping'],
            'delivery_address' => ['nullable', 'string', 'max:255'],
            'wants_film' => ['nullable', 'boolean'],
            'photo_ids' => ['nullable', 'array'],
            'photo_ids.*' => ['integer', 'exists:photos,id'],
            'photo_items' => ['nullable', 'array'],
            'photo_items.*.photo_id' => ['required_with:photo_items', 'integer', 'exists:photos,id'],
            'photo_items.*.quantity' => ['nullable', 'integer', 'min:1'],
        ]);

        if ($validated['product_type'] !== 'digital' && empty($validated['delivery_type'])) {
            return back()->withErrors(['Escolhe o tipo de entrega.'])->withInput();
        }
        if (($validated['delivery_type'] ?? '') === 'shipping' && empty($validated['delivery_address'])) {
            return back()->withErrors(['Morada obrigatória para envio.'])->withInput();
        }

        $photoItemsPayload = $request->input('photo_items');
        $photoIds = collect($validated['photo_ids'] ?? []);
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

        if ($photoIds->isEmpty()) {
            return back()->withErrors(['Seleciona pelo menos 1 foto.'])->withInput();
        }

        $photos = Photo::query()
            ->where('event_id', $event->id)
            ->where('status', 'active')
            ->whereIn('id', $photoIds)
            ->get();

        if ($photos->count() !== $photoIds->count()) {
            return back()->withErrors(['Algumas fotos não pertencem ao evento.']);
        }

        if ($validated['payment_method'] !== 'cash') {
            return back()->withErrors(['Para pagamento online usa o formulário abaixo.'])->withInput();
        }

        $paymentMethod = 'cash';

        $order = DB::transaction(function () use ($event, $validated, $photos, $photoItems, $paymentMethod) {
            $price = (float) $event->price_per_photo;
            $quantities = $photoItems->keyBy('photo_id');
            $itemsTotal = 0;
            foreach ($photos as $photo) {
                $qty = (int) ($quantities[$photo->id]['quantity'] ?? 1);
                $itemsTotal += $qty * $price;
            }

            $deliveryType = $validated['delivery_type'] ?? null;
            $productType = $validated['product_type'];
            $wantsFilm = (bool) ($validated['wants_film'] ?? false);
            $shippingFee = $deliveryType === 'shipping' ? 5.00 : 0.00;
            $filmFee = $wantsFilm ? 30.00 : 0.00;
            $extrasTotal = $shippingFee + $filmFee;
            $total = $itemsTotal + $extrasTotal;

            $order = Order::create([
                'event_id' => $event->id,
                'order_code' => $this->newOrderCode(),
                'customer_name' => $validated['customer_name'],
                'customer_phone' => $validated['customer_phone'],
                'customer_email' => $validated['customer_email'],
                'product_type' => $productType,
                'delivery_type' => $deliveryType,
                'delivery_address' => $validated['delivery_address'] ?? null,
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

        Audit::log('guest.order.created', Order::class, $order->id, [
            'event_id' => $event->id,
            'order_code' => $order->order_code,
            'payment_method' => $order->payment_method,
            'photo_count' => $order->items()->count(),
        ]);

        return redirect()->route('guest.order.show', $order->order_code)
            ->with('ok', 'Pedido '.$order->order_code.' criado com sucesso.');
    }

    public function createPaymentIntent(Request $request, Event $event)
    {
        $this->ensureSession($event);

        $validated = $request->validate([
            'customer_name' => ['required', 'string', 'max:255'],
            'customer_phone' => ['required', 'string', 'max:80'],
            'customer_email' => ['required', 'email', 'max:255'],
            'payment_method' => ['required', 'in:online'],
            'product_type' => ['required', 'in:digital,paper,both'],
            'delivery_type' => ['nullable', 'in:pickup,shipping'],
            'delivery_address' => ['nullable', 'string', 'max:255'],
            'wants_film' => ['nullable', 'boolean'],
            'photo_ids' => ['nullable', 'array'],
            'photo_ids.*' => ['integer', 'exists:photos,id'],
            'photo_items' => ['nullable', 'array'],
            'photo_items.*.photo_id' => ['required_with:photo_items', 'integer', 'exists:photos,id'],
            'photo_items.*.quantity' => ['nullable', 'integer', 'min:1'],
        ]);

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
        if (! class_exists(\Stripe\Stripe::class)) {
            \Log::error('Stripe SDK missing: install stripe/stripe-php and run composer install.');
            return response()->json(['message' => 'Stripe indisponível no servidor (SDK em falta).'], 500);
        }

        $photoItemsPayload = $request->input('photo_items');
        $photoIds = collect($validated['photo_ids'] ?? []);
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

        if ($photoIds->isEmpty()) {
            return response()->json(['message' => 'Seleciona pelo menos 1 foto.'], 422);
        }

        $photos = Photo::query()
            ->where('event_id', $event->id)
            ->where('status', 'active')
            ->whereIn('id', $photoIds)
            ->get();

        if ($photos->count() !== $photoIds->count()) {
            return response()->json(['message' => 'Algumas fotos não pertencem ao evento.'], 422);
        }

        $order = DB::transaction(function () use ($event, $validated, $photos, $photoItems) {
            $price = (float) $event->price_per_photo;
            $quantities = $photoItems->keyBy('photo_id');
            $itemsTotal = 0;
            foreach ($photos as $photo) {
                $qty = (int) ($quantities[$photo->id]['quantity'] ?? 1);
                $itemsTotal += $qty * $price;
            }

            $deliveryType = $validated['delivery_type'] ?? null;
            $productType = $validated['product_type'];
            $wantsFilm = (bool) ($validated['wants_film'] ?? false);
            $shippingFee = $deliveryType === 'shipping' ? 5.00 : 0.00;
            $filmFee = $wantsFilm ? 30.00 : 0.00;
            $extrasTotal = $shippingFee + $filmFee;
            $total = $itemsTotal + $extrasTotal;

            $order = Order::create([
                'event_id' => $event->id,
                'order_code' => $this->newOrderCode(),
                'customer_name' => $validated['customer_name'],
                'customer_phone' => $validated['customer_phone'],
                'customer_email' => $validated['customer_email'],
                'product_type' => $productType,
                'delivery_type' => $deliveryType,
                'delivery_address' => $validated['delivery_address'] ?? null,
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
                    'event_id' => (string) $event->id,
                    'customer_name' => $order->customer_name,
                    'photo_items' => $photoSummary,
                    'photo_count' => (string) $photos->count(),
                    'items_qty' => (string) $photoItems->sum('quantity'),
                ],
            ];

            $intentPayload['automatic_payment_methods'] = [
                'enabled' => true,
                'allow_redirects' => 'always',
            ];

            $intent = PaymentIntent::create($intentPayload);
        } catch (\Throwable $e) {
            \Log::error('Stripe payment intent failed', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
            ]);
            return response()->json(['message' => 'Falha ao iniciar pagamento online. Tenta novamente.'], 422);
        }

        $order->update([
            'stripe_payment_intent_id' => $intent->id ?? null,
        ]);

        Audit::log('guest.order.created', Order::class, $order->id, [
            'event_id' => $event->id,
            'order_code' => $order->order_code,
            'payment_method' => $order->payment_method,
            'photo_count' => $order->items()->count(),
        ]);

        return response()->json([
            'client_secret' => $intent->client_secret,
            'order_code' => $order->order_code,
            'publishable_key' => $stripePublishable,
        ]);
    }

    public function order(string $orderCode)
    {
        $order = Order::with('items.photo', 'event')->where('order_code', $orderCode)->firstOrFail();

        [$downloadUrl, $downloadExpiresAt] = $this->resolveDownloadInfo($order);

        return view('guest.order', compact('order', 'downloadUrl', 'downloadExpiresAt'));
    }

    public function orderStatus(string $orderCode)
    {
        $order = Order::query()->where('order_code', $orderCode)->firstOrFail();

        [$downloadUrl, $downloadExpiresAt] = $this->resolveDownloadInfo($order);

        return response()->json([
            'status' => $order->status,
            'download_url' => $downloadUrl,
            'download_expires_at' => $downloadExpiresAt?->toIso8601String(),
            'download_expires_label' => $downloadExpiresAt?->format('d/m/Y H:i'),
        ])->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
    }

    private function ensureSession(Event $event): void
    {
        abort_unless(session()->has($this->sessionKey($event->id)), 403);
    }

    private function sessionKey(int $eventId): string
    {
        return 'guest_event_'.$eventId;
    }

    private function resolveDownloadInfo(Order $order): array
    {
        $downloadUrl = null;
        $downloadExpiresAt = null;
        if (in_array($order->status, ['paid', 'delivered'], true)) {
            if ($order->download_link_sent_at) {
                $downloadExpiresAt = $order->download_link_sent_at->copy()->addDays(7);
            }
            $isExpired = OrderDownloadService::isLinkExpired($order);
            if (! $order->download_token) {
                $downloadUrl = OrderDownloadService::createAccessLink($order);
                $downloadExpiresAt = $order->download_link_sent_at?->copy()->addDays(7);
            } elseif (! $isExpired) {
                $downloadUrl = OrderDownloadService::getExistingAccessLink($order);
                if (! $downloadUrl) {
                    $downloadUrl = OrderDownloadService::createAccessLink($order);
                    $downloadExpiresAt = $order->download_link_sent_at?->copy()->addDays(7);
                }
            }
        }

        return [$downloadUrl, $downloadExpiresAt];
    }

    private function newOrderCode(): string
    {
        do {
            $code = 'S59-'.Str::upper(Str::random(8));
        } while (Order::where('order_code', $code)->exists());

        return $code;
    }
}
