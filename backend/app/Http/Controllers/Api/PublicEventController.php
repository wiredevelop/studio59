<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PublicEnterEventRequest;
use App\Models\Event;
use App\Models\EventSession;
use App\Models\Photo;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class PublicEventController extends Controller
{
    public function today()
    {
        $events = Event::query()
            ->whereDate('event_date', Carbon::today('Europe/Lisbon'))
            ->where('is_active_today', true)
            ->orderBy('name')
            ->get(['id', 'name', 'event_date', 'location']);

        return response()->json(['data' => $events]);
    }

    public function enter(PublicEnterEventRequest $request, int $id)
    {
        $event = Event::findOrFail($id);

        $pinInput = trim($request->string('pin')->toString());
        if ($pinInput === '') {
            $pinInput = trim($request->string('password')->toString());
        }
        if (! hash_equals((string) $event->access_pin, $pinInput)) {
            return response()->json(['message' => 'Invalid PIN'], 422);
        }

        $plainToken = Str::random(64);
        EventSession::create([
            'event_id' => $event->id,
            'token_hash' => hash('sha256', $plainToken),
            'expires_at' => now()->addHours(24),
        ]);

        return response()->json([
            'event_session_token' => $plainToken,
            'event' => [
                'id' => $event->id,
                'name' => $event->name,
                'event_type' => $event->event_type,
                'event_meta' => $event->event_meta,
                'event_date' => optional($event->event_date)->format('Y-m-d'),
                'location' => $event->location,
                'base_price' => $event->base_price,
                'price_per_photo' => $event->price_per_photo,
                'qr_token' => $event->qr_token,
            ],
        ]);
    }

    public function enterByPin(Request $request)
    {
        $validated = $request->validate([
            'pin' => ['required', 'regex:/^\\d{4}$/'],
        ]);

        $event = Event::query()
            ->where('access_pin', $validated['pin'])
            ->firstOrFail();

        if (! $event->access_pin) {
            return response()->json(['message' => 'Event not available'], 403);
        }

        $today = Carbon::today('Europe/Lisbon');
        $start = $event->event_date?->copy() ?? $today;
        $end = $start->copy()->addDay();

        if ($today->lt($start) || $today->gt($end) || $event->is_locked) {
            return response()->json(['message' => 'Event not available'], 403);
        }

        $plainToken = Str::random(64);
        EventSession::create([
            'event_id' => $event->id,
            'token_hash' => hash('sha256', $plainToken),
            'expires_at' => now()->addHours(24),
        ]);

        return response()->json([
            'event_session_token' => $plainToken,
            'event' => [
                'id' => $event->id,
                'name' => $event->name,
                'event_type' => $event->event_type,
                'event_meta' => $event->event_meta,
                'event_date' => optional($event->event_date)->format('Y-m-d'),
                'location' => $event->location,
                'base_price' => $event->base_price,
                'price_per_photo' => $event->price_per_photo,
                'qr_token' => $event->qr_token,
            ],
        ]);
    }

    public function enterByQr(Request $request, string $token)
    {
        $event = Event::query()
            ->where('qr_token', $token)
            ->firstOrFail();

        if (! $event->qr_enabled || $event->is_locked) {
            return response()->json(['message' => 'Event not available'], 403);
        }

        $plainToken = Str::random(64);
        EventSession::create([
            'event_id' => $event->id,
            'token_hash' => hash('sha256', $plainToken),
            'expires_at' => now()->addHours(24),
        ]);

        return response()->json([
            'event_session_token' => $plainToken,
            'event' => [
                'id' => $event->id,
                'name' => $event->name,
                'event_type' => $event->event_type,
                'event_meta' => $event->event_meta,
                'event_date' => optional($event->event_date)->format('Y-m-d'),
                'location' => $event->location,
                'base_price' => $event->base_price,
                'price_per_photo' => $event->price_per_photo,
                'qr_token' => $event->qr_token,
            ],
        ]);
    }

    public function photos(Request $request, int $id)
    {
        $event = Event::findOrFail($id);
        $search = trim((string) $request->query('search', ''));
        $perPage = (int) $request->query('per_page', 50);
        if ($perPage < 1) {
            $perPage = 50;
        } elseif ($perPage > 200) {
            $perPage = 200;
        }

        $photos = Photo::query()
            ->where('event_id', $event->id)
            ->where('status', 'active')
            ->whereNotNull('preview_path')
            ->when($search !== '', fn ($q) => $q->where('number', 'like', '%'.$search.'%'))
            ->orderBy('number')
            ->paginate($perPage)
            ->through(fn (Photo $photo) => [
                'id' => $photo->id,
                'number' => $photo->number,
                'preview_url' => $photo->preview_path
                    ? $request->getSchemeAndHttpHost().route('preview.image', ['photo' => $photo->id], false)
                    : null,
            ]);

        return response()->json($photos);
    }

    public function faceSearch(Request $request, int $id)
    {
        @set_time_limit(0);

        $event = Event::findOrFail($id);

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
            ->get(['id', 'preview_path']);

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

        $payload = $suggestedIds->map(function ($pid) use ($photosById, $request) {
            $photo = $photosById->get($pid);
            if (! $photo) return null;
            return [
                'id' => $photo->id,
                'number' => $photo->number,
                'preview_url' => $photo->preview_path
                    ? $request->getSchemeAndHttpHost().route('preview.image', ['photo' => $photo->id], false)
                    : null,
            ];
        })->filter()->values();

        return response()->json(['suggested' => $payload]);
    }
}
