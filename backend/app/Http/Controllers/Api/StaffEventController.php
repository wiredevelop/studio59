<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\EventStoreRequest;
use App\Http\Requests\EventUpdateRequest;
use App\Models\Event;
use App\Support\Audit;
use App\Support\EventPdf;
use App\Support\TeamAssignment;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Models\Photo;
use App\Models\EventStaff;
use App\Models\EventInvitation;
use App\Models\User;
use App\Models\UploadChunk;
use App\Jobs\GeneratePhotoPreview;
use Illuminate\Support\Facades\DB;
use Illuminate\Database\QueryException;
use Illuminate\Support\Str;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

class StaffEventController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $query = Event::query();
        if ($user && $user->role === 'photographer') {
            $query->visibleTo($user);
        }

        $query = $this->applyEventFilters($query, $request);
        $query->orderByDesc('event_date')->orderByDesc('id');

        return response()->json($query->paginate(20));
    }

    public function lookup(Request $request)
    {
        $user = $request->user();
        $query = Event::query();
        if ($user && $user->role === 'photographer') {
            $query->visibleTo($user);
        }

        $query = $this->applyEventFilters($query, $request);
        $query->orderByDesc('event_date')->orderByDesc('id');

        $ids = $query->pluck('id');
        if ($ids->isEmpty()) {
            return response()->json([
                'event' => null,
                'prev_id' => null,
                'next_id' => null,
                'total' => 0,
            ]);
        }

        $currentId = (int) $request->query('current_id', 0);
        $index = $currentId ? $ids->search($currentId) : null;
        if ($index === false || $index === null) {
            $index = 0;
            $currentId = (int) $ids->first();
        }

        $prevId = $index > 0 ? (int) $ids[$index - 1] : null;
        $nextId = $index < ($ids->count() - 1) ? (int) $ids[$index + 1] : null;

        $event = Event::find($currentId);

        return response()->json([
            'event' => $event,
            'prev_id' => $prevId,
            'next_id' => $nextId,
            'total' => $ids->count(),
        ]);
    }

    private function applyEventFilters($query, Request $request)
    {
        $eventType = trim((string) $request->query('event_type', ''));
        $internalCode = trim((string) $request->query('internal_code', ''));
        $accessPin = trim((string) $request->query('access_pin', ''));
        $eventDate = trim((string) $request->query('event_date', ''));
        $eventTime = trim((string) $request->query('event_time', ''));
        $pricePerPhoto = trim((string) $request->query('price_per_photo', ''));
        $basePrice = trim((string) $request->query('base_price', ''));
        $q = trim((string) $request->query('q', ''));
        $meta = $request->query('meta', []);

        if ($eventType !== '') {
            $query->where('event_type', 'like', '%'.$eventType.'%');
        }
        if ($internalCode !== '') {
            $query->where(function ($inner) use ($internalCode) {
                $inner->where('internal_code', 'like', '%'.$internalCode.'%')
                    ->orWhere('legacy_report_number', 'like', '%'.$internalCode.'%');
            });
        }
        if ($accessPin !== '') {
            $query->where('access_pin', 'like', '%'.$accessPin.'%');
        }
        if ($eventDate !== '') {
            $query->whereDate('event_date', $eventDate);
        }
        if ($eventTime !== '') {
            $query->where('event_time', 'like', '%'.$eventTime.'%');
        }
        if ($pricePerPhoto !== '') {
            $query->where('price_per_photo', $pricePerPhoto);
        }
        if ($basePrice !== '') {
            $query->where('base_price', $basePrice);
        }
        if ($q !== '') {
            $query->where(function ($inner) use ($q) {
                $inner->where('name', 'like', '%'.$q.'%')
                    ->orWhere('internal_code', 'like', '%'.$q.'%')
                    ->orWhere('legacy_report_number', 'like', '%'.$q.'%')
                    ->orWhere('service_raw', 'like', '%'.$q.'%')
                    ->orWhere('bride_name', 'like', '%'.$q.'%')
                    ->orWhere('groom_name', 'like', '%'.$q.'%')
                    ->orWhere('access_pin', 'like', '%'.$q.'%');
            });
        }
        if (is_array($meta)) {
            foreach ($meta as $key => $value) {
                $val = trim((string) $value);
                if ($val === '' || $key === '') {
                    continue;
                }
                $query->where('event_meta->'.$key, 'like', '%'.$val.'%');
            }
        }

        return $query;
    }

    public function store(EventStoreRequest $request)
    {
        $validated = $request->validated();
        $meta = $validated['event_meta'] ?? [];
        if (array_key_exists('foto_noivos', $meta)) {
            unset($meta['foto_noivos']);
            $validated['event_meta'] = $meta;
        }
        if (empty($validated['name'])) {
            $validated['name'] = $this->buildEventName(
                $validated['event_type'] ?? null,
                $validated['event_date'] ?? null,
                $meta
            );
        }
        if (empty($validated['internal_code'])) {
            $validated['internal_code'] = $this->generateInternalCode(
                $validated['event_type'] ?? null,
                $validated['event_date'] ?? null,
                $validated['name'] ?? null
            );
        }
        if (empty($validated['qr_token'])) {
            $validated['qr_token'] = Str::random(48);
        }
        $validated['qr_enabled'] = true;
        $validated['access_mode'] = 'both';
        $validated['status'] = $this->statusForDate($validated['event_date'] ?? now());
        $validated['is_active_today'] = $this->isActiveTodayForDate($validated['event_date'] ?? now());
        if (! empty($validated['access_pin'])) {
            $exists = Event::query()->where('access_pin', $validated['access_pin'])->exists();
            if ($exists) {
                $validated['access_pin'] = $this->generateAccessPin($validated['event_date'] ?? now());
            }
        } else {
            $validated['access_pin'] = $this->generateAccessPin($validated['event_date'] ?? now());
        }

        $event = Event::create($validated + ['created_by' => $request->user()->id]);
        $teamIds = TeamAssignment::resolveUserIds($meta['equipa_de_trabalho'] ?? null);
        $staffIds = array_values(array_unique(array_merge($validated['staff_ids'] ?? [], $teamIds)));
        foreach ($staffIds as $userId) {
            EventStaff::updateOrCreate(
                ['event_id' => $event->id, 'user_id' => $userId],
                [
                    'role' => 'photographer',
                    'status' => 'assigned',
                    'invited_at' => now(),
                ]
            );
        }
        $this->ensureClientNumbers($event);
        Audit::log('api.event.created', Event::class, $event->id);
        EventPdf::generate($event);

        return response()->json($event, 201);
    }

    public function show(Event $event)
    {
        $this->ensureEventAccess($event);
        return response()->json($event);
    }

    public function pdf(Event $event)
    {
        $this->ensureEventAccess($event);
        $path = EventPdf::generate($event);

        return response()->file(Storage::disk('local')->path($path), [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="evento-'.$event->id.'.pdf"',
        ]);
    }

    public function update(EventUpdateRequest $request, Event $event)
    {
        $validated = $request->validated();
        $meta = $validated['event_meta'] ?? ($event->event_meta ?? []);
        if (array_key_exists('foto_noivos', $meta)) {
            unset($meta['foto_noivos']);
            $validated['event_meta'] = $meta;
        }
        if (empty($validated['name'])) {
            $validated['name'] = $this->buildEventName(
                $validated['event_type'] ?? $event->event_type,
                $validated['event_date'] ?? $event->event_date,
                $meta,
                $event->name
            );
        }
        if (empty($event->internal_code) && empty($validated['internal_code'])) {
            $validated['internal_code'] = $this->generateInternalCode(
                $validated['event_type'] ?? $event->event_type,
                $validated['event_date'] ?? $event->event_date,
                $validated['name'] ?? $event->name
            );
        }
        if (empty($event->qr_token) && empty($validated['qr_token'])) {
            $validated['qr_token'] = Str::random(48);
        }
        if (! empty($event->access_pin)) {
            unset($validated['access_pin']);
        } elseif (empty($validated['access_pin'])) {
            $validated['access_pin'] = $this->generateAccessPin($validated['event_date'] ?? $event->event_date ?? now());
        } else {
            $exists = Event::query()
                ->where('access_pin', $validated['access_pin'])
                ->where('id', '<>', $event->id)
                ->exists();
            if ($exists) {
                $validated['access_pin'] = $this->generateAccessPin($validated['event_date'] ?? $event->event_date ?? now());
            }
        }
        $validated['qr_enabled'] = true;
        $validated['access_mode'] = 'both';
        $validated['status'] = $this->statusForDate($validated['event_date'] ?? $event->event_date ?? now());
        $validated['is_active_today'] = $this->isActiveTodayForDate($validated['event_date'] ?? $event->event_date ?? now());
        $event->update($validated);
        $teamIds = TeamAssignment::resolveUserIds($meta['equipa_de_trabalho'] ?? null);
        $staffIds = array_values(array_unique(array_merge(
            $event->staff()->pluck('user_id')->all(),
            $validated['staff_ids'] ?? [],
            $teamIds
        )));
        $this->syncStaff($event, $staffIds);
        $this->ensureClientNumbers($event);

        Audit::log('api.event.updated', Event::class, $event->id);
        EventPdf::generate($event);

        return response()->json($event);
    }

    public function destroy(Event $event)
    {
        $eventId = $event->id;
        Storage::disk('local')->deleteDirectory('events/'.$event->id);
        Storage::disk('local')->deleteDirectory('chunks/'.$event->id);
        $event->delete();
        Audit::log('api.event.deleted', Event::class, $eventId);

        return response()->json(['message' => 'Deleted']);
    }

    public function photos(Request $request, Event $event)
    {
        $this->ensureEventAccess($event);
        $search = trim((string) $request->query('search', ''));
        $photos = $event->photos()
            ->when($search !== '', fn ($q) => $q->where('number', 'like', '%'.$search.'%'))
            ->orderBy('number')
            ->paginate(72);

        $photos->getCollection()->transform(function (Photo $photo) {
            return [
                'id' => $photo->id,
                'number' => $photo->number,
                'preview_url' => $photo->preview_path ? route('preview.image', $photo) : null,
                'preview_status' => $photo->preview_status,
                'preview_error' => $photo->preview_error,
            ];
        });

        return response()->json($photos);
    }

    public function destroyPhoto(Event $event, Photo $photo)
    {
        $this->ensureEventAccess($event);
        abort_unless((int) $photo->event_id === (int) $event->id, 404);

        if ($photo->preview_path) {
            Storage::disk('local')->delete($photo->preview_path);
        }
        Storage::disk('local')->delete($photo->original_path);
        $photoId = $photo->id;
        $photoNumber = $photo->number;
        $photo->delete();
        Audit::log('api.photo.deleted', Photo::class, $photoId, [
            'event_id' => $event->id,
            'number' => $photoNumber,
        ]);

        return response()->json(['message' => 'Deleted']);
    }

    public function bulkDestroyPhotos(Request $request, Event $event)
    {
        $this->ensureEventAccess($event);
        $validated = $request->validate([
            'photo_ids' => ['required', 'array', 'min:1'],
            'photo_ids.*' => ['integer', 'exists:photos,id'],
        ]);

        $photos = Photo::query()
            ->where('event_id', $event->id)
            ->whereIn('id', $validated['photo_ids'])
            ->get();

        $deleted = 0;
        foreach ($photos as $photo) {
            if ($photo->preview_path) {
                Storage::disk('local')->delete($photo->preview_path);
            }
            Storage::disk('local')->delete($photo->original_path);
            $photo->delete();
            $deleted++;

            Audit::log('api.photo.deleted.bulk', Photo::class, $photo->id, [
                'event_id' => $event->id,
                'number' => $photo->number,
            ]);
        }

        return response()->json(['deleted' => $deleted]);
    }

    public function retryPreview(Event $event, Photo $photo)
    {
        $this->ensureEventAccess($event);
        abort_unless((int) $photo->event_id === (int) $event->id, 404);

        $photo->update([
            'preview_status' => 'pending',
            'preview_error' => null,
            'preview_path' => null,
        ]);

        GeneratePhotoPreview::dispatch($photo->id);
        Audit::log('api.photo.preview.retry', Photo::class, $photo->id, ['event_id' => $event->id]);

        return response()->json(['message' => 'Retry queued']);
    }

    private function generateAccessPin($eventDate): string
    {
        for ($i = 0; $i < 40; $i++) {
            $pin = (string) random_int(1000, 9999);
            $exists = Event::query()
                ->where('access_pin', $pin)
                ->exists();
            if (! $exists) {
                return $pin;
            }
        }

        return (string) random_int(1000, 9999);
    }

    public function uploadsIndex(Event $event)
    {
        $this->ensureEventAccess($event);
        return response()->json([
            'event_id' => $event->id,
            'recent_photos' => $event->photos()->orderByDesc('id')->take(200)->get([
                'id',
                'number',
                'preview_status',
            ]),
        ]);
    }

    public function uploadChunk(Request $request, Event $event)
    {
        $this->ensureEventAccess($event);
        $validated = $request->validate([
            'upload_id' => ['required', 'string', 'max:100'],
            'chunk_index' => ['required', 'integer', 'min:0'],
            'total_chunks' => ['required', 'integer', 'min:1', 'max:40000'],
            'file_name' => ['required', 'string', 'max:200'],
            'chunk' => ['required', 'file', 'max:102400'],
        ]);

        $uploadId = $validated['upload_id'];
        $chunkIndex = $validated['chunk_index'];
        $totalChunks = $validated['total_chunks'];
        $fileName = $this->sanitizeFileName($validated['file_name']);

        $baseDir = 'chunks/'.$event->id.'/'.$uploadId;
        Storage::disk('local')->makeDirectory($baseDir);

        $upload = UploadChunk::query()
            ->where('event_id', $event->id)
            ->where('upload_id', $uploadId)
            ->first();

        if (! $upload) {
            $upload = UploadChunk::create([
                'event_id' => $event->id,
                'upload_id' => $uploadId,
                'file_name' => $fileName,
                'total_chunks' => $totalChunks,
                'received_chunks' => 0,
                'is_completed' => false,
            ]);
        } elseif ($upload->file_name !== $fileName || (int) $upload->total_chunks !== $totalChunks) {
            return response()->json([
                'message' => 'Upload id collision detected. Please retry.',
            ], 409);
        }

        if ($upload->is_completed) {
            $photo = $upload->photo_id ? Photo::find($upload->photo_id) : null;
            if (! $photo) {
                $upload->update([
                    'is_completed' => false,
                    'photo_id' => null,
                ]);
            } else {
                return response()->json([
                    'uploaded' => true,
                    'photo' => [
                        'id' => $photo->id,
                        'number' => $photo->number,
                        'preview_ready' => (bool) $photo->preview_path,
                    ],
                ]);
            }
        }

        $chunkPath = $baseDir.'/'.$chunkIndex.'.part';
        if (! Storage::disk('local')->exists($chunkPath)) {
            Storage::disk('local')->put($chunkPath, file_get_contents($request->file('chunk')->getRealPath()));
        }

        $received = count(Storage::disk('local')->files($baseDir));
        $upload->update(['received_chunks' => $received, 'total_chunks' => $totalChunks]);

        $isDone = $received >= $totalChunks;

        if ($isDone && ! $upload->is_completed) {
            $photo = $this->assembleAndStorePhoto($event, $uploadId, $totalChunks);
            $upload->update(['is_completed' => true, 'photo_id' => $photo->id]);

            return response()->json([
                'uploaded' => true,
                'photo' => [
                    'id' => $photo->id,
                    'number' => $photo->number,
                    'preview_ready' => (bool) $photo->preview_path,
                ],
            ]);
        }

        return response()->json([
            'uploaded' => false,
            'received_chunks' => $received,
            'total_chunks' => $totalChunks,
        ]);
    }

    public function uploadStatus(Request $request, Event $event)
    {
        $this->ensureEventAccess($event);
        $request->validate([
            'upload_id' => ['required', 'string', 'max:100'],
        ]);

        $upload = UploadChunk::query()
            ->where('event_id', $event->id)
            ->where('upload_id', $request->string('upload_id'))
            ->first();

        if (! $upload) {
            return response()->json([
                'exists' => false,
                'received_chunks' => 0,
                'total_chunks' => 0,
                'is_completed' => false,
            ]);
        }

        return response()->json([
            'exists' => true,
            'received_chunks' => $upload->received_chunks,
            'total_chunks' => $upload->total_chunks,
            'is_completed' => (bool) $upload->is_completed,
            'photo_id' => $upload->photo_id,
        ]);
    }

    public function staffIndex(Event $event)
    {
        $this->ensureEventAccess($event);
        $staff = EventStaff::query()
            ->where('event_id', $event->id)
            ->with('user:id,name,email,role')
            ->orderByDesc('id')
            ->get();

        return response()->json(['data' => $staff]);
    }

    public function staffUsers(Event $event)
    {
        $this->ensureEventAccess($event);
        $users = User::query()
            ->whereNotNull('username')
            ->orderBy('name')
            ->get(['id', 'name', 'username', 'email', 'role']);

        return response()->json(['data' => $users]);
    }

    public function staffUsersAll()
    {
        $users = User::query()
            ->whereNotNull('username')
            ->orderBy('name')
            ->get(['id', 'name', 'username', 'email', 'role']);

        return response()->json(['data' => $users]);
    }

    public function staffAssign(Request $request, Event $event)
    {
        $this->ensureEventAccess($event);
        $validated = $request->validate([
            'user_ids' => ['required', 'array', 'min:1'],
            'user_ids.*' => ['integer', Rule::exists('users', 'id')->where(function ($query) {
                $query->whereIn('role', ['photographer']);
            })],
            'role' => ['nullable', 'string', 'max:40'],
            'send_invite' => ['nullable', 'boolean'],
            'channel' => ['nullable', 'string', 'max:30'],
            'message' => ['nullable', 'string'],
        ]);

        $role = $validated['role'] ?? 'photographer';
        $sendInvite = $validated['send_invite'] ?? true;
        $channel = $validated['channel'] ?? 'email';
        $message = $validated['message'] ?? null;

        $assigned = [];
        foreach ($validated['user_ids'] as $userId) {
            $staff = EventStaff::query()->updateOrCreate(
                ['event_id' => $event->id, 'user_id' => $userId],
                [
                    'role' => $role,
                    'status' => 'invited',
                    'invited_at' => now(),
                ]
            );
            $assigned[] = $staff;

            if ($sendInvite) {
                EventInvitation::create([
                    'event_id' => $event->id,
                    'user_id' => $userId,
                    'invite_type' => $role,
                    'status' => 'sent',
                    'channel' => $channel,
                    'message' => $message,
                    'sent_at' => now(),
                ]);
            }
        }

        return response()->json(['data' => $assigned], 201);
    }

    public function staffRemove(Event $event, User $user)
    {
        $this->ensureEventAccess($event);
        EventStaff::query()
            ->where('event_id', $event->id)
            ->where('user_id', $user->id)
            ->delete();

        return response()->json(['message' => 'Removed']);
    }

    private function assembleAndStorePhoto(Event $event, string $uploadId, int $totalChunks): Photo
    {
        $tmpDir = 'chunks/'.$event->id.'/'.$uploadId;
        $assembledRelPath = 'chunks/'.$event->id.'/'.$uploadId.'/assembled.jpg';
        $assembledFullPath = Storage::disk('local')->path($assembledRelPath);

        for ($i = 0; $i < $totalChunks; $i++) {
            if (! Storage::disk('local')->exists($tmpDir.'/'.$i.'.part')) {
                abort(422, 'Missing chunks for upload assembly.');
            }
        }

        $out = fopen($assembledFullPath, 'wb');
        for ($i = 0; $i < $totalChunks; $i++) {
            $part = Storage::disk('local')->path($tmpDir.'/'.$i.'.part');
            $in = fopen($part, 'rb');
            stream_copy_to_stream($in, $out);
            fclose($in);
        }
        fclose($out);

        $imageType = @exif_imagetype($assembledFullPath);
        if ($imageType !== IMAGETYPE_JPEG) {
            Storage::disk('local')->deleteDirectory($tmpDir);
            abort(422, 'Final file is not a valid JPEG image.');
        }

        $checksum = hash_file('sha256', $assembledFullPath);

        try {
            $photo = DB::transaction(function () use ($event, $assembledFullPath, $checksum) {
                $existing = Photo::query()
                    ->where('event_id', $event->id)
                    ->where('checksum', $checksum)
                    ->first();

                if ($existing) {
                    return $existing;
                }

                $nextNumber = str_pad((string) ((int) (Photo::where('event_id', $event->id)->lockForUpdate()->max('number') ?? 0) + 1), 4, '0', STR_PAD_LEFT);
                $originalPath = 'events/'.$event->id.'/originals/'.$nextNumber.'.jpg';
                Storage::disk('local')->makeDirectory(dirname($originalPath));
                Storage::disk('local')->put($originalPath, file_get_contents($assembledFullPath));

                [$w, $h] = getimagesize(Storage::disk('local')->path($originalPath)) ?: [null, null];

                $photo = Photo::create([
                    'event_id' => $event->id,
                    'number' => $nextNumber,
                    'original_path' => $originalPath,
                    'mime' => 'image/jpeg',
                    'size' => Storage::disk('local')->size($originalPath),
                    'width' => $w,
                    'height' => $h,
                    'status' => 'active',
                    'preview_status' => 'pending',
                    'preview_error' => null,
                    'checksum' => $checksum,
                ]);

                GeneratePhotoPreview::dispatchSync($photo->id);
                Audit::log('api.photo.uploaded', Photo::class, $photo->id, [
                    'event_id' => $event->id,
                    'number' => $photo->number,
                ]);

                return $photo;
            }, 5);
        } catch (QueryException) {
            $photo = Photo::query()
                ->where('event_id', $event->id)
                ->where('checksum', $checksum)
                ->firstOrFail();
        }

        Storage::disk('local')->deleteDirectory($tmpDir);

        return $photo;
    }

    private function sanitizeFileName(string $fileName): string
    {
        $clean = Str::of($fileName)->replaceMatches('/[^A-Za-z0-9._-]/', '_')->toString();

        return (string) Str::of($clean)->limit(180, '');
    }

    private function generateInternalCode($eventType, $eventDate, $name): string
    {
        $date = $eventDate ? Carbon::parse($eventDate)->format('Ymd') : Carbon::now()->format('Ymd');
        $type = $eventType ? Str::upper(Str::substr($eventType, 0, 3)) : 'EVT';
        $initial = $name ? Str::upper(Str::substr(Str::slug($name, ''), 0, 2)) : 'EV';

        for ($i = 0; $i < 40; $i++) {
            $suffix = (string) random_int(100, 999);
            $code = $type.'-'.$date.'-'.$initial.$suffix;
            if (! Event::where('internal_code', $code)->exists()) {
                return $code;
            }
        }

        return $type.'-'.$date.'-'.Str::upper(Str::random(4));
    }

    private function buildEventName($eventType, $eventDate, array $meta, ?string $fallback = null): string
    {
        $typeLabel = $eventType ? Str::upper($eventType) : 'EVENTO';
        $dateLabel = $eventDate ? Carbon::parse($eventDate)->format('Y-m-d') : null;
        $names = '';
        if ($eventType === 'casamento') {
            $noivo = trim((string) ($meta['noivo_nome'] ?? ''));
            $noiva = trim((string) ($meta['noiva_nome'] ?? ''));
            if ($noivo && $noiva) {
                $names = $noivo.' & '.$noiva;
            } else {
                $names = trim($noivo.' '.$noiva);
            }
        } elseif ($eventType === 'batizado') {
            $names = trim((string) ($meta['bebe_nome'] ?? ''));
        }

        $parts = array_filter([$typeLabel, $names, $dateLabel]);
        return $parts ? implode(' - ', $parts) : ($fallback ?: 'Evento');
    }

    private function ensureClientNumbers(Event $event): void
    {
        $meta = $event->event_meta ?? [];
        $type = $event->event_type;
        $date = $event->event_date ? Carbon::parse($event->event_date)->format('Ymd') : Carbon::now()->format('Ymd');
        $changed = false;

        $makeNumber = function (string $suffix) use ($date): string {
            $rand = random_int(100, 999);
            return $date.$suffix.$rand;
        };

        if ($type === 'casamento') {
            if (empty($meta['cliente_noivo_num'])) {
                $meta['cliente_noivo_num'] = $makeNumber('1');
                $changed = true;
            }
            if (empty($meta['cliente_noiva_num'])) {
                $meta['cliente_noiva_num'] = $makeNumber('2');
                $changed = true;
            }
            if ($meta['cliente_noivo_num'] === $meta['cliente_noiva_num']) {
                $meta['cliente_noiva_num'] = $makeNumber('2');
                $changed = true;
            }
        } elseif ($type === 'batizado') {
            if (empty($meta['cliente_batizado_num'])) {
                $meta['cliente_batizado_num'] = $makeNumber('B');
                $changed = true;
            }
        }

        if ($changed) {
            $event->update(['event_meta' => $meta]);
        }
    }

    private function syncStaff(Event $event, array $staffIds): void
    {
        $existing = $event->staff()->pluck('user_id')->all();
        $toAdd = array_diff($staffIds, $existing);
        $toRemove = array_diff($existing, $staffIds);

        if ($toRemove) {
            EventStaff::where('event_id', $event->id)
                ->whereIn('user_id', $toRemove)
                ->delete();
        }

        foreach ($toAdd as $userId) {
            EventStaff::updateOrCreate(
                ['event_id' => $event->id, 'user_id' => $userId],
                [
                    'role' => 'photographer',
                    'status' => 'assigned',
                    'invited_at' => now(),
                ]
            );
        }
    }

    private function statusForDate($eventDate): string
    {
        $date = $eventDate instanceof Carbon ? $eventDate : Carbon::parse($eventDate);
        $today = Carbon::today('Europe/Lisbon');
        return $date->isSameDay($today) ? 'active' : 'scheduled';
    }

    private function isActiveTodayForDate($eventDate): bool
    {
        $date = $eventDate instanceof Carbon ? $eventDate : Carbon::parse($eventDate);
        $today = Carbon::today('Europe/Lisbon');
        return $date->isSameDay($today);
    }

    private function ensureEventAccess(Event $event): void
    {
        $user = request()->user();
        if ($user && $user->role === 'photographer') {
            $assigned = $event->staff()->where('user_id', $user->id)->exists();
            abort_unless($assigned, 403);
        }
    }
}
