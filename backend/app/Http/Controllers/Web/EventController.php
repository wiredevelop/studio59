<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Http\Requests\EventStoreRequest;
use App\Http\Requests\EventUpdateRequest;
use App\Jobs\GeneratePhotoPreview;
use App\Models\Event;
use App\Models\Photo;
use App\Models\User;
use App\Support\Audit;
use App\Support\EventPdf;
use App\Support\TeamAssignment;
use Illuminate\Support\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class EventController extends Controller
{
    public function index(Request $request)
    {
        $user = auth()->user();
        $type = $request->query('type');
        $typeForView = $type;
        $reportSearch = trim((string) $request->input('legacy_report_number', ''));
        $hasReportSearch = $reportSearch !== '';
        $currentEvent = null;
        $meta = [];
        $prevUrl = null;
        $nextUrl = null;
        $firstUrl = null;
        $lastUrl = null;
        $currentIndex = null;
        $totalResults = 0;
        $hasFilters = false;
        $searchMode = $request->boolean('search_mode');

        if (in_array($type, ['casamento', 'batizado'], true)) {
            $query = Event::query()->withCount('photos')->orderByDesc('id');
            if ($user && $user->role === 'photographer') {
                $query->visibleTo($user);
            }
            if (! $hasReportSearch) {
                $query->where('event_type', 'like', '%'.$type.'%');
            }

            $baseFilters = $request->only([
                'legacy_report_number',
                'access_pin',
                'event_date',
                'event_time',
                'base_price',
                'price_per_photo',
            ]);
            foreach ($baseFilters as $field => $value) {
                if ($value === null || $value === '') {
                    continue;
                }
                $hasFilters = true;
                if ($field === 'event_date') {
                    $query->whereDate('event_date', $value);
                    continue;
                }
                if ($field === 'legacy_report_number') {
                    $query->where(function ($inner) use ($value) {
                        $inner->where('legacy_report_number', 'like', '%'.$value.'%')
                            ->orWhere('internal_code', 'like', '%'.$value.'%');
                    });
                    continue;
                }
                $query->where($field, 'like', '%'.$value.'%');
            }

            $metaFilters = $request->input('event_meta', []);
            $booleanMeta = [
                'servico_save_the_date',
                'servico_fotos_love_story',
                'servico_video_love_story',
                'servico_projectar_love_story',
                'servico_combo_beleza_love_story',
                'servico_album_digital_30_5',
                'servico_combo_beleza_ttd',
                'servico_album_digital',
                'servico_album_convidados',
                'servico_albuns_40_20',
                'servico_same_day_edit',
                'servico_projectar_same_day_edit',
                'servico_galeria_digital_convidados',
                'servico_foto_lembranca_qr',
                'servico_impressao_100_11x22_7',
                'servico_video_depois_do_sim',
                'servico_drone',
            ];
            foreach ($metaFilters as $key => $value) {
                if ($value === null || $value === '') {
                    continue;
                }
                $hasFilters = true;
                if (in_array($key, $booleanMeta, true)) {
                    if ($request->boolean("event_meta.$key")) {
                        $query->where("event_meta->$key", true);
                    }
                    continue;
                }
                $query->where("event_meta->$key", 'like', '%'.$value.'%');
            }

            $staffIds = array_values(array_filter((array) $request->input('staff_ids', [])));
            if ($staffIds) {
                $hasFilters = true;
                $query->whereHas('staff', function ($q) use ($staffIds) {
                    $q->whereIn('user_id', $staffIds);
                });
            }

            if (! ($searchMode && ! $hasFilters && ! $request->filled('event_id'))) {
                $ids = $query->pluck('id')->values();
                $totalResults = $ids->count();
                if ($totalResults > 0) {
                    $currentId = (int) $request->query('event_id', 0);
                    if (! $currentId || ! $ids->contains($currentId)) {
                        $currentId = $ids->first();
                    }
                    $currentIndex = $ids->search($currentId);
                    $currentEvent = Event::withCount('photos')->find($currentId);
                    $meta = $currentEvent?->event_meta ?? [];
                    $baseQuery = $request->except('event_id');
                    if ($totalResults > 0) {
                        $firstUrl = route('events.index', array_merge($baseQuery, [
                            'event_id' => $ids->first(),
                        ]));
                        $lastUrl = route('events.index', array_merge($baseQuery, [
                            'event_id' => $ids->last(),
                        ]));
                    }
                    if ($currentIndex > 0) {
                        $prevUrl = route('events.index', array_merge($baseQuery, [
                            'event_id' => $ids[$currentIndex - 1],
                        ]));
                    }
                    if ($currentIndex < $totalResults - 1) {
                        $nextUrl = route('events.index', array_merge($baseQuery, [
                            'event_id' => $ids[$currentIndex + 1],
                        ]));
                    }
                }
            }
            if ($hasReportSearch && $currentEvent) {
                $normalizedType = $this->normalizeEventType($currentEvent->event_type);
                if ($normalizedType) {
                    $typeForView = $normalizedType;
                }
            }
            if ($typeForView !== $type && isset($ids) && $totalResults > 0) {
                $baseQuery = $request->except('event_id');
                $baseQuery['type'] = $typeForView;
                $firstUrl = route('events.index', array_merge($baseQuery, [
                    'event_id' => $ids->first(),
                ]));
                $lastUrl = route('events.index', array_merge($baseQuery, [
                    'event_id' => $ids->last(),
                ]));
                if ($currentIndex > 0) {
                    $prevUrl = route('events.index', array_merge($baseQuery, [
                        'event_id' => $ids[$currentIndex - 1],
                    ]));
                }
                if ($currentIndex < $totalResults - 1) {
                    $nextUrl = route('events.index', array_merge($baseQuery, [
                        'event_id' => $ids[$currentIndex + 1],
                    ]));
                }
            }
        }

        return view('events.index', [
            'type' => $typeForView,
            'currentEvent' => $currentEvent,
            'meta' => $meta,
            'prevUrl' => $prevUrl,
            'nextUrl' => $nextUrl,
            'firstUrl' => $firstUrl,
            'lastUrl' => $lastUrl,
            'currentIndex' => $currentIndex,
            'totalResults' => $totalResults,
            'staffUsers' => User::where('role', 'photographer')->orderBy('name')->get(),
            'teamUsers' => User::whereNotNull('username')->orderBy('name')->get(),
            'searchMode' => $searchMode && ! $currentEvent,
            'selectedStaffIds' => $currentEvent
                ? $currentEvent->staff()->pluck('user_id')->all()
                : (array) $request->input('staff_ids', []),
        ]);
    }

    public function create()
    {
        $teamUsers = User::whereNotNull('username')->orderBy('name')->get();
        $teamUsersPayload = $teamUsers->map(function ($u) {
            return [
                'id' => $u->id,
                'name' => $u->name,
                'username' => $u->username,
            ];
        })->values();
        return view('events.create', [
            'staffUsers' => User::where('role', 'photographer')->orderBy('name')->get(),
            'teamUsers' => $teamUsers,
            'teamUsersPayload' => $teamUsersPayload,
            'nextReportNumber' => $this->nextLegacyReportNumber(),
        ]);
    }

    public function store(EventStoreRequest $request)
    {
        $validated = $request->validated();
        $reportNumber = $validated['legacy_report_number'] ?? null;
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
        $validated['internal_code'] = $this->generateInternalCode(
            $validated['event_type'] ?? null,
            $validated['event_date'] ?? null,
            $validated['name'] ?? null
        );
        if (is_string($reportNumber) && trim($reportNumber) !== '') {
            $validated['legacy_report_number'] = trim($reportNumber);
        } else {
            $validated['legacy_report_number'] = $this->nextLegacyReportNumber();
        }
        $validated['qr_token'] = $validated['qr_token'] ?? Str::random(48);
        $validated['qr_enabled'] = true;
        $validated['is_locked'] = false;
        $validated['access_mode'] = 'both';
        if ($request->boolean('autosave')) {
            if (empty($validated['event_date'])) {
                $validated['event_date'] = Carbon::today('Europe/Lisbon');
            }
            if (array_key_exists('base_price', $validated) && ($validated['base_price'] === null || $validated['base_price'] === '')) {
                unset($validated['base_price']);
            }
            if (array_key_exists('price_per_photo', $validated) && ($validated['price_per_photo'] === null || $validated['price_per_photo'] === '')) {
                unset($validated['price_per_photo']);
            }
            $validated['status'] = 'rascunho';
            $validated['is_active_today'] = false;
        } else {
            $validated['status'] = $this->statusForDate($validated['event_date'] ?? now());
            $validated['is_active_today'] = $this->isActiveTodayForDate($validated['event_date'] ?? now());
        }
        if (! empty($validated['access_pin'])) {
            $exists = Event::query()->where('access_pin', $validated['access_pin'])->exists();
            if ($exists) {
                $validated['access_pin'] = $this->generateAccessPin($validated['event_date'] ?? now());
            }
        } else {
            $validated['access_pin'] = $this->generateAccessPin($validated['event_date'] ?? now());
        }

        $event = Event::create($validated + ['created_by' => auth()->id()]);
        $teamIds = TeamAssignment::resolveUserIds($meta['equipa_de_trabalho'] ?? null);
        $staffIds = array_values(array_unique(array_merge($validated['staff_ids'] ?? [], $teamIds)));
        foreach ($staffIds as $userId) {
            \App\Models\EventStaff::updateOrCreate(
                ['event_id' => $event->id, 'user_id' => $userId],
                [
                    'role' => 'photographer',
                    'status' => 'assigned',
                    'invited_at' => now(),
                ]
            );
        }
        $this->ensureClientNumbers($event);
        if ($request->hasFile('event_meta.foto_noivos')) {
            $this->storeCouplePhoto($event, $request->file('event_meta.foto_noivos'));
        }
        Audit::log('event.created', Event::class, $event->id, [
            'event_name' => $event->name,
        ]);
        if (! $request->boolean('autosave')) {
            EventPdf::generate($event);
        }

        if ($request->boolean('autosave')) {
            return response()->json([
                'event_id' => $event->id,
                'update_url' => route('events.update', $event),
            ]);
        }

        return redirect()->route('events.index')->with('ok', 'Evento criado');
    }

    public function show(Request $request, Event $event)
    {
        $this->ensureEventAccess($event);

        $folder = $request->query('folder', 'previews');
        if (! in_array($folder, ['previews', 'provas'], true)) {
            $folder = 'previews';
        }

        $search = trim((string) $request->query('search', ''));
        $photos = $event->photos()
            ->when($search !== '', fn ($q) => $q->where('number', 'like', '%'.$search.'%'))
            ->orderBy('number')
            ->paginate(72)
            ->withQueryString();

        return view('events.show', [
            'event' => $event,
            'staff' => $event->staff()->with('user')->get(),
            'users' => User::where('role', 'photographer')->orderBy('name')->get(),
            'folder' => $folder,
            'search' => $search,
            'photos' => $photos,
            'totalPhotos' => $event->photos()->count(),
            'previewReady' => $event->photos()->whereNotNull('preview_path')->count(),
            'previewFailed' => $event->photos()->where('preview_status', 'failed')->count(),
        ]);
    }

    public function qr(Event $event)
    {
        $this->ensureEventAccess($event);
        $qrUrl = url('/api/public/events/qr/'.$event->qr_token);

        return view('events.qr', [
            'event' => $event,
            'qrUrl' => $qrUrl,
        ]);
    }

    public function edit(Event $event)
    {
        $this->ensureEventAccess($event);
        return view('events.edit', [
            'event' => $event,
            'staffUsers' => User::where('role', 'photographer')->orderBy('name')->get(),
            'teamUsers' => User::whereNotNull('username')->orderBy('name')->get(),
            'selectedStaffIds' => $event->staff()->pluck('user_id')->all(),
        ]);
    }

    public function update(EventUpdateRequest $request, Event $event)
    {
        $this->ensureEventAccess($event);
        $validated = $request->validated();
        $printPdf = $request->boolean('print_pdf');
        if ($request->boolean('autosave')) {
            if (array_key_exists('event_date', $validated) && ($validated['event_date'] === null || $validated['event_date'] === '')) {
                unset($validated['event_date']);
            }
            if (array_key_exists('base_price', $validated) && ($validated['base_price'] === null || $validated['base_price'] === '')) {
                unset($validated['base_price']);
            }
            if (array_key_exists('price_per_photo', $validated) && ($validated['price_per_photo'] === null || $validated['price_per_photo'] === '')) {
                unset($validated['price_per_photo']);
            }
        }
        $reportNumber = $validated['legacy_report_number'] ?? null;
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
        if (empty($event->internal_code)) {
            $validated['internal_code'] = $this->generateInternalCode(
                $validated['event_type'] ?? $event->event_type,
                $validated['event_date'] ?? $event->event_date,
                $validated['name'] ?? $event->name
            );
        }
        if (is_string($reportNumber) && trim($reportNumber) !== '') {
            $validated['legacy_report_number'] = trim($reportNumber);
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
        $validated['is_locked'] = $request->boolean('is_locked', $event->is_locked);
        $validated['access_mode'] = 'both';
        if (! $request->boolean('autosave')) {
            $validated['status'] = $this->statusForDate($validated['event_date'] ?? $event->event_date ?? now());
            $validated['is_active_today'] = $this->isActiveTodayForDate($validated['event_date'] ?? $event->event_date ?? now());
        }
        $event->update($validated);
        $teamIds = TeamAssignment::resolveUserIds($meta['equipa_de_trabalho'] ?? null);
        $staffIds = array_values(array_unique(array_merge(
            $event->staff()->pluck('user_id')->all(),
            $validated['staff_ids'] ?? [],
            $teamIds
        )));
        $this->syncStaff($event, $staffIds);
        $this->ensureClientNumbers($event);
        if ($request->hasFile('event_meta.foto_noivos')) {
            $this->storeCouplePhoto($event, $request->file('event_meta.foto_noivos'));
        }

        Audit::log('event.updated', Event::class, $event->id);
        if (! $request->boolean('autosave')) {
            $pdfPath = EventPdf::generate($event);
            if ($printPdf) {
                return response()->file(Storage::disk('local')->path($pdfPath), [
                    'Content-Type' => 'application/pdf',
                    'Content-Disposition' => 'inline; filename="evento-'.$event->id.'.pdf"',
                ]);
            }
        }

        if ($request->boolean('autosave')) {
            return response()->json([
                'event_id' => $event->id,
            ]);
        }

        $returnUrl = $request->input('return_url');
        if (is_string($returnUrl) && $returnUrl !== '') {
            if (str_starts_with($returnUrl, '/') && ! str_starts_with($returnUrl, '//')) {
                return redirect()->to($returnUrl)->with('ok', 'Evento atualizado');
            }
            if (str_starts_with($returnUrl, url('/'))) {
                return redirect()->to($returnUrl)->with('ok', 'Evento atualizado');
            }
        }

        return redirect()->route('events.index')->with('ok', 'Evento atualizado');
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

    public function destroy(Event $event)
    {
        $this->ensureEventAccess($event);
        $eventId = $event->id;
        Storage::disk('local')->deleteDirectory('events/'.$event->id);
        Storage::disk('local')->deleteDirectory('chunks/'.$event->id);
        $event->delete();
        Audit::log('event.deleted', Event::class, $eventId);

        return redirect()->route('events.index')->with('ok', 'Evento removido');
    }

    public function original(Event $event, Photo $photo)
    {
        $this->ensureEventAccess($event);
        abort_unless((int) $photo->event_id === (int) $event->id, 404);
        abort_unless(Storage::disk('local')->exists($photo->original_path), 404);

        return response()->file(storage_path('app/private/'.$photo->original_path));
    }

    public function destroyPhoto(Event $event, Photo $photo)
    {
        $this->ensureEventAccess($event);
        abort_unless((int) $photo->event_id === (int) $event->id, 404);
        $photoNumber = $photo->number;

        if ($photo->preview_path) {
            Storage::disk('local')->delete($photo->preview_path);
        }
        Storage::disk('local')->delete($photo->original_path);
        $photo->delete();
        Audit::log('photo.deleted', Photo::class, $photo->id, [
            'event_id' => $event->id,
            'number' => $photoNumber,
        ]);

        return redirect()->route('events.show', $event)->with('ok', 'Foto removida');
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

        if ($photos->isEmpty()) {
            return back()->withErrors(['Nenhuma foto válida selecionada.']);
        }

        $deleted = 0;
        foreach ($photos as $photo) {
            if ($photo->preview_path) {
                Storage::disk('local')->delete($photo->preview_path);
            }
            Storage::disk('local')->delete($photo->original_path);
            $photo->delete();
            $deleted++;

            Audit::log('photo.deleted.bulk', Photo::class, $photo->id, [
                'event_id' => $event->id,
                'number' => $photo->number,
            ]);
        }

        return back()->with('ok', $deleted.' fotos apagadas.');
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
        Audit::log('photo.preview.retry', Photo::class, $photo->id, ['event_id' => $event->id]);

        return back()->with('ok', 'Regeneração de preview enviada para a fila.');
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

    public function staffAssign(Request $request, Event $event)
    {
        $this->ensureEventAccess($event);
        $validated = $request->validate([
            'user_id' => ['required', 'integer', Rule::exists('users', 'id')->where(function ($query) {
                $query->whereIn('role', ['photographer']);
            })],
            'role' => ['nullable', 'string', 'max:40'],
        ]);

        \App\Models\EventStaff::updateOrCreate(
            ['event_id' => $event->id, 'user_id' => $validated['user_id']],
            [
                'role' => $validated['role'] ?? 'photographer',
                'status' => 'assigned',
                'invited_at' => now(),
            ]
        );

        return back()->with('ok', 'Staff associado.');
    }

    public function staffRemove(Event $event, User $user)
    {
        $this->ensureEventAccess($event);
        \App\Models\EventStaff::where('event_id', $event->id)
            ->where('user_id', $user->id)
            ->delete();

        return back()->with('ok', 'Staff removido.');
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

    private function storeCouplePhoto(Event $event, $file): void
    {
        $path = $file->store('events/'.$event->id.'/meta', 'public');
        $meta = $event->event_meta ?? [];
        $meta['foto_noivos'] = $path;
        $event->update(['event_meta' => $meta]);
    }

    private function syncStaff(Event $event, array $staffIds): void
    {
        $existing = $event->staff()->pluck('user_id')->all();
        $toAdd = array_diff($staffIds, $existing);
        $toRemove = array_diff($existing, $staffIds);

        if ($toRemove) {
            \App\Models\EventStaff::where('event_id', $event->id)
                ->whereIn('user_id', $toRemove)
                ->delete();
        }

        foreach ($toAdd as $userId) {
            \App\Models\EventStaff::updateOrCreate(
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

    private function normalizeEventType(?string $raw): ?string
    {
        if (! $raw) {
            return null;
        }
        $text = Str::of($raw)->lower()->toString();
        if (str_contains($text, 'casamento')) {
            return 'casamento';
        }
        if (str_contains($text, 'batizado') || str_contains($text, 'baptizado')) {
            return 'batizado';
        }
        return null;
    }

    private function nextLegacyReportNumber(): ?string
    {
        $max = Event::query()
            ->whereNotNull('legacy_report_number')
            ->whereRaw("legacy_report_number REGEXP '^[0-9]+$'")
            ->selectRaw('MAX(CAST(legacy_report_number AS UNSIGNED)) as max_num')
            ->value('max_num');
        if ($max === null) {
            return null;
        }
        return (string) (((int) $max) + 1);
    }

    private function ensureEventAccess(Event $event): void
    {
        $user = auth()->user();
        if ($user && $user->role === 'photographer') {
            $assigned = $event->staff()->where('user_id', $user->id)->exists();
            abort_unless($assigned, 403);
        }
    }
}
