<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\Order;
use App\Models\Photo;
use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

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
            'password' => ['required', 'string'],
        ]);

        if (! hash_equals($event->access_password, $request->string('password')->toString())) {
            return back()->withErrors(['Senha inválida.'])->withInput();
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
            ->paginate(60)
            ->withQueryString();

        return view('guest.catalog', [
            'event' => $event,
            'photos' => $photos,
            'search' => $search,
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
            'customer_phone' => ['nullable', 'string', 'max:80'],
            'customer_email' => ['nullable', 'email', 'max:255'],
            'payment_method' => ['required', 'in:cash,online'],
            'photo_ids' => ['required', 'array', 'min:1'],
            'photo_ids.*' => ['integer', 'exists:photos,id'],
        ]);

        $photoIds = collect($validated['photo_ids'])->unique()->values();
        $photos = Photo::query()
            ->where('event_id', $event->id)
            ->where('status', 'active')
            ->whereIn('id', $photoIds)
            ->get();

        if ($photos->count() !== $photoIds->count()) {
            return back()->withErrors(['Algumas fotos não pertencem ao evento.']);
        }

        $order = DB::transaction(function () use ($event, $validated, $photos) {
            $price = (float) $event->price_per_photo;

            $order = Order::create([
                'event_id' => $event->id,
                'order_code' => $this->newOrderCode(),
                'customer_name' => $validated['customer_name'],
                'customer_phone' => $validated['customer_phone'] ?? null,
                'customer_email' => $validated['customer_email'] ?? null,
                'payment_method' => $validated['payment_method'],
                'status' => 'pending',
                'total_amount' => $photos->count() * $price,
            ]);

            foreach ($photos as $photo) {
                $order->items()->create([
                    'photo_id' => $photo->id,
                    'price' => $price,
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

        return redirect()->route('guest.catalog', $event)
            ->with('ok', 'Pedido '.$order->order_code.' criado com sucesso.')
            ->with('clear_guest_cart', true);
    }

    public function order(string $orderCode)
    {
        $order = Order::with('items.photo', 'event')->where('order_code', $orderCode)->firstOrFail();

        return view('guest.order', compact('order'));
    }

    private function ensureSession(Event $event): void
    {
        abort_unless(session()->has($this->sessionKey($event->id)), 403);
    }

    private function sessionKey(int $eventId): string
    {
        return 'guest_event_'.$eventId;
    }

    private function newOrderCode(): string
    {
        do {
            $code = 'S59-'.Str::upper(Str::random(8));
        } while (Order::where('order_code', $code)->exists());

        return $code;
    }
}
