@extends('layouts.app')
@section('content')
<div class="flex items-center justify-between mb-2">
<h1 class="text-xl font-semibold">Upload PROVAS - {{ $event->name }}</h1>
<a href="{{ route('events.show', $event) }}" class="border bg-white px-3 py-2 rounded">Abrir Dossier</a>
</div>
<p class="mb-4 text-sm text-gray-600">Upload resumível por chunks JPEG</p>
<input id="picker" type="file" multiple accept="image/jpeg" class="mb-3" />
<div class="w-full bg-gray-200 rounded h-4 mb-4"><div id="bar" class="bg-green-600 h-4 rounded" style="width:0%"></div></div>
<div id="stats" class="text-sm text-gray-600 mb-4">Aguardando upload...</div>
<div id="log" class="bg-white border rounded p-3 h-48 overflow-auto text-sm"></div>

<h2 class="font-semibold mt-6 mb-2">Últimas fotos</h2>
<div class="grid grid-cols-3 md:grid-cols-6 gap-2">
@foreach($photos as $photo)
    <div class="bg-white border p-2 text-xs text-center">
        <div>#{{ $photo->number }}</div>
        @if($photo->preview_path)
            <img src="{{ route('preview.image', $photo) }}" class="w-full h-24 object-cover mt-1">
        @endif
    </div>
@endforeach
</div>

<script src="https://cdn.jsdelivr.net/npm/resumablejs@1.1.0/resumable.min.js"></script>
<script>
const log = document.getElementById('log');
const bar = document.getElementById('bar');
const stats = document.getElementById('stats');
const append = (t) => { log.innerHTML += `<div>${t}</div>`; log.scrollTop = log.scrollHeight; };
let uploadCounter = 0;
let totalBytes = 0;
let startedAt = null;
let lastTick = null;
let lastUploaded = 0;
const eventId = '{{ $event->id }}';

const chunkSize = 5 * 1024 * 1024;
const r = new Resumable({
    target: '{{ route('uploads.chunk', $event) }}',
    chunkSize: chunkSize,
    simultaneousUploads: 2,
    maxChunkRetries: 5,
    chunkRetryInterval: 1500,
    testChunks: false,
    headers: { 'X-CSRF-TOKEN': '{{ csrf_token() }}' },
    query: (file, chunk) => {
        return {
        upload_id: file._studioUploadId,
        file_name: file.fileName,
        chunk_index: Math.floor(chunk.offset / chunkSize),
        total_chunks: Math.ceil(file.size / chunkSize),
        };
    },
    fileParameterName: 'chunk'
});

r.assignBrowse(document.getElementById('picker'));

const humanBytes = (bytes) => {
    if (!bytes || bytes <= 0) return '0 B';
    const units = ['B','KB','MB','GB','TB'];
    let v = bytes;
    let i = 0;
    while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
    return `${v.toFixed(2)} ${units[i]}`;
};
const humanTime = (sec) => {
    if (!isFinite(sec) || sec < 0) return '—';
    const s = Math.ceil(sec);
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const r = s % 60;
    if (h > 0) return `${h}h ${m}m ${r}s`;
    if (m > 0) return `${m}m ${r}s`;
    return `${r}s`;
};
const fileFingerprint = (file) => {
    const lm = file.file && file.file.lastModified ? file.file.lastModified : (file.lastModified || '');
    return `${file.fileName}|${file.size}|${lm}`;
};
const uploadKey = (fingerprint) => `studio59_upload_${eventId}_${fingerprint}`;

r.on('fileAdded', function(file){
    uploadCounter += 1;
    const fingerprint = fileFingerprint(file);
    const storedId = localStorage.getItem(uploadKey(fingerprint));
    if (storedId) {
        file._studioUploadId = storedId;
        append(`Rascunho: retomar ${file.fileName}`);
    } else {
        // Keep upload_id short and unique to avoid collisions/truncation.
        file._studioUploadId = `u${Date.now().toString(36)}-${uploadCounter.toString(36)}-${Math.random().toString(36).slice(2,8)}`;
        localStorage.setItem(uploadKey(fingerprint), file._studioUploadId);
        append(`Fila: ${file.fileName}`);
    }
    totalBytes = r.files.reduce((sum, f) => sum + f.size, 0);
    if (!startedAt) {
        startedAt = Date.now();
        lastTick = startedAt;
        lastUploaded = 0;
    }
    r.upload();
});
r.on('fileSuccess', function(file, message){
    let payload = null;
    try { payload = JSON.parse(message); } catch (_) {}
    if (!payload || payload.uploaded !== true || !payload.photo || !payload.photo.id) {
        append(`ERRO: ${file.fileName} concluido sem foto criada (reenvia este ficheiro).`);
        return;
    }
    const fingerprint = fileFingerprint(file);
    localStorage.removeItem(uploadKey(fingerprint));
    append(`OK: ${file.fileName} -> #${payload.photo.number}`);
});
r.on('fileError', function(file, msg){ append(`ERRO: ${file.fileName} ${msg}`); });
r.on('progress', function(){
    const p = r.progress();
    bar.style.width = Math.floor(p*100) + '%';
    const now = Date.now();
    const elapsed = (now - (startedAt || now)) / 1000;
    const uploaded = totalBytes * p;
    const deltaTime = (now - (lastTick || now)) / 1000;
    const deltaBytes = uploaded - lastUploaded;
    const speed = deltaTime > 0 ? (deltaBytes / deltaTime) : 0;
    const remaining = speed > 0 ? (totalBytes - uploaded) / speed : Infinity;
    lastTick = now;
    lastUploaded = uploaded;
    stats.textContent = `Progresso: ${(p*100).toFixed(1)}% • ${humanBytes(uploaded)} / ${humanBytes(totalBytes)} • ${humanBytes(speed)}/s • ETA ${humanTime(remaining)} • Decorrido ${humanTime(elapsed)}`;
});
r.on('complete', function(){
    stats.textContent = 'Upload completo.';
});
</script>
@endsection
