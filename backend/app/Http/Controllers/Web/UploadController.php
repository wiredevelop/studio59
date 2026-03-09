<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Http\Requests\ChunkUploadRequest;
use App\Jobs\GeneratePhotoPreview;
use App\Models\Event;
use App\Models\Photo;
use App\Models\UploadChunk;
use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class UploadController extends Controller
{
    public function index(Event $event)
    {
        $this->ensureEventAccess($event);
        return view('uploads.index', [
            'event' => $event,
            'photos' => $event->photos()->orderByDesc('id')->take(200)->get(),
        ]);
    }

    public function chunk(ChunkUploadRequest $request, Event $event)
    {
        $this->ensureEventAccess($event);
        $uploadId = $request->string('upload_id')->toString();
        $chunkIndex = $request->integer('chunk_index');
        $totalChunks = $request->integer('total_chunks');
        $fileName = $this->sanitizeFileName($request->string('file_name')->toString());

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
                // Recovery path for legacy/broken rows from previous runs.
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

    public function status(Request $request, Event $event)
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

        $photo = DB::transaction(function () use ($event, $assembledFullPath, $checksum) {
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
            Audit::log('photo.uploaded', Photo::class, $photo->id, [
                'event_id' => $event->id,
                'number' => $photo->number,
            ]);

            return $photo;
        }, 5);

        Storage::disk('local')->deleteDirectory($tmpDir);

        return $photo;
    }

    private function sanitizeFileName(string $fileName): string
    {
        $clean = Str::of($fileName)->replaceMatches('/[^A-Za-z0-9._-]/', '_')->toString();

        return (string) Str::of($clean)->limit(180, '');
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
