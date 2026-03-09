<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Http\Requests\EventStoreRequest;
use App\Http\Requests\EventUpdateRequest;
use App\Jobs\GeneratePhotoPreview;
use App\Models\Event;
use App\Models\EventPasswordHistory;
use App\Models\Photo;
use App\Models\User;
use App\Support\Audit;
use Illuminate\Support\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class EventController extends Controller
{
    public function index()
    {
        $user = auth()->user();
        $query = Event::withCount('photos')->orderByDesc('event_date');
        if ($user && $user->role === 'photographer') {
            $query->visibleTo($user);
        }

        return view('events.index', [
            'events' => $query->paginate(20),
        ]);
    }

    public function create()
    {
        return view('events.create', [
            'staffUsers' => User::where('role', 'photographer')->orderBy('name')->get(),
        ]);
    }

    public function store(EventStoreRequest $request)
    {
        $validated = $request->validated();
        $validated['internal_code'] = $this->generateInternalCode(
            $validated['event_type'] ?? null,
            $validated['event_date'] ?? null,
            $validated['name'] ?? null
        );
        $validated['qr_token'] = $validated['qr_token'] ?? Str::random(48);
        $validated['qr_enabled'] = true;
        $validated['is_locked'] = false;
        $validated['access_mode'] = 'both';
        $validated['status'] = $this->statusForDate($validated['event_date'] ?? now());
        $validated['is_active_today'] = $this->isActiveTodayForDate($validated['event_date'] ?? now());
        if (empty($validated['access_password'])) {
            $validated['access_password'] = Str::random(16);
        }
        if (empty($validated['access_pin'])) {
            $validated['access_pin'] = $this->generateAccessPin($validated['event_date'] ?? now());
        }

        $event = Event::create($validated + ['created_by' => auth()->id()]);
        $staffIds = $validated['staff_ids'] ?? [];
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
        EventPasswordHistory::create([
            'event_id' => $event->id,
            'password_hash' => Hash::make($event->access_password),
            'changed_by' => auth()->id(),
        ]);
        Audit::log('event.created', Event::class, $event->id, [
            'event_name' => $event->name,
        ]);

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
        ]);
    }

    public function update(EventUpdateRequest $request, Event $event)
    {
        $this->ensureEventAccess($event);
        $validated = $request->validated();
        if (empty($event->internal_code)) {
            $validated['internal_code'] = $this->generateInternalCode(
                $validated['event_type'] ?? $event->event_type,
                $validated['event_date'] ?? $event->event_date,
                $validated['name'] ?? $event->name
            );
        }
        if (empty($event->qr_token) && empty($validated['qr_token'])) {
            $validated['qr_token'] = Str::random(48);
        }
        if (empty($event->access_pin) && empty($validated['access_pin'])) {
            $validated['access_pin'] = $this->generateAccessPin($validated['event_date'] ?? $event->event_date ?? now());
        }
        $validated['qr_enabled'] = true;
        $validated['is_locked'] = $request->boolean('is_locked', $event->is_locked);
        $validated['access_mode'] = 'both';
        $validated['status'] = $this->statusForDate($validated['event_date'] ?? $event->event_date ?? now());
        $validated['is_active_today'] = $this->isActiveTodayForDate($validated['event_date'] ?? $event->event_date ?? now());
        $hasPassword = array_key_exists('access_password', $validated);
        $passwordChanged = $hasPassword && $validated['access_password'] !== $event->access_password;
        $event->update($validated);

        if ($passwordChanged) {
            EventPasswordHistory::create([
                'event_id' => $event->id,
                'password_hash' => Hash::make($event->access_password),
                'changed_by' => auth()->id(),
            ]);
        }

        Audit::log('event.updated', Event::class, $event->id, [
            'password_changed' => $passwordChanged,
        ]);

        return redirect()->route('events.index')->with('ok', 'Evento atualizado');
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
        $date = $eventDate instanceof Carbon ? $eventDate : Carbon::parse($eventDate);
        $start = $date->toDateString();
        $end = $date->copy()->addDay()->toDateString();

        for ($i = 0; $i < 40; $i++) {
            $pin = (string) random_int(1000, 9999);
            $exists = Event::query()
                ->whereBetween('event_date', [$start, $end])
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
        $user = auth()->user();
        if ($user && $user->role === 'photographer') {
            $assigned = $event->staff()->where('user_id', $user->id)->exists();
            abort_unless($assigned, 403);
        }
    }
}
