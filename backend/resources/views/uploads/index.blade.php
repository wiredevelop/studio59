@extends('layouts.app')
@section('page_title', 'Uploads')
@section('page_subtitle', $event->name)
@section('page_actions')
    <a href="{{ route('events.show', $event) }}" class="desk-btn">Abrir dossier</a>
@endsection
@section('content')
<p class="text-sm text-gray-600">Upload resumível por chunks JPEG</p>
<input id="picker" type="file" multiple accept="image/jpeg" class="mb-3" />
<div class="w-full bg-gray-200 rounded h-4 mb-4"><div id="bar" class="bg-green-600 h-4 rounded" style="width:0%"></div></div>
<div id="stats" class="text-sm text-gray-600 mb-4">Aguardando upload...</div>
<div id="log" class="desk-card h-48 overflow-auto text-sm"></div>

<h2 class="font-semibold mt-6 mb-2">Últimas fotos</h2>
<div id="latest-photos" class="grid grid-cols-3 md:grid-cols-6 gap-2">
@foreach($photos as $photo)
    <div class="desk-card text-xs text-center">
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
const latestPhotosGrid = document.getElementById('latest-photos');
const append = (t) => { log.innerHTML += `<div>${t}</div>`; log.scrollTop = log.scrollHeight; };
let uploadCounter = 0;
let totalBytes = 0;
let startedAt = null;
let statsTimer = null;
const speedSamples = [];
const fileStarts = new Map();
const uploadResults = [];
const failedUploads = [];
const eventId = '{{ $event->id }}';
const latestUrl = '{{ route('uploads.latest', $event) }}';

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
const pushSample = (t, bytes) => {
    speedSamples.push({ t, bytes });
    const cutoff = t - 8000;
    while (speedSamples.length > 2 && speedSamples[0].t < cutoff) speedSamples.shift();
};
const computeSpeed = () => {
    if (speedSamples.length < 2) return 0;
    const first = speedSamples[0];
    const last = speedSamples[speedSamples.length - 1];
    const dt = (last.t - first.t) / 1000;
    if (dt <= 0) return 0;
    return (last.bytes - first.bytes) / dt;
};
const updateStats = () => {
    if (!startedAt || totalBytes <= 0) return;
    const now = Date.now();
    const p = r.progress() || 0;
    const uploaded = totalBytes * p;
    pushSample(now, uploaded);
    const speed = computeSpeed();
    const remaining = speed > 0 ? (totalBytes - uploaded) / speed : Infinity;
    const elapsed = (now - startedAt) / 1000;
    bar.style.width = Math.floor(p * 100) + '%';
    stats.textContent = `Progresso: ${(p*100).toFixed(1)}% • ${humanBytes(uploaded)} / ${humanBytes(totalBytes)} • ${humanBytes(speed)}/s • ETA ${humanTime(remaining)} • Decorrido ${humanTime(elapsed)}`;
};

const renderLatestPhotos = (photos) => {
    if (!latestPhotosGrid) return;
    latestPhotosGrid.innerHTML = photos.map((p) => {
        const img = p.preview_url ? `<img src="${p.preview_url}" class="w-full h-24 object-cover mt-1">` : '';
        return `<div class="bg-white border p-2 text-xs text-center"><div>#${p.number}</div>${img}</div>`;
    }).join('');
};

const refreshLatestPhotos = async () => {
    try {
        const res = await fetch(latestUrl, { headers: { 'X-Requested-With': 'XMLHttpRequest' } });
        if (!res.ok) return;
        const data = await res.json();
        if (Array.isArray(data)) renderLatestPhotos(data);
    } catch (_) {}
};

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
        speedSamples.length = 0;
        pushSample(startedAt, 0);
        if (!statsTimer) statsTimer = setInterval(updateStats, 500);
    }
    fileStarts.set(file.uniqueIdentifier, Date.now());
    r.upload();
});
r.on('fileSuccess', function(file, message){
    const started = fileStarts.get(file.uniqueIdentifier) || Date.now();
    const duration = (Date.now() - started) / 1000;
    let payload = null;
    try { payload = JSON.parse(message); } catch (_) {}
    if (!payload || payload.uploaded !== true || !payload.photo || !payload.photo.id) {
        failedUploads.push({ name: file.fileName, seconds: duration });
        append(`ERRO: ${file.fileName} concluido sem foto criada (${humanTime(duration)}).`);
        return;
    }
    const fingerprint = fileFingerprint(file);
    localStorage.removeItem(uploadKey(fingerprint));
    uploadResults.push({ name: file.fileName, seconds: duration, ok: true });
    append(`OK: ${file.fileName} -> #${payload.photo.number} (${humanTime(duration)})`);
});
r.on('fileError', function(file, msg){
    const started = fileStarts.get(file.uniqueIdentifier) || Date.now();
    const duration = (Date.now() - started) / 1000;
    failedUploads.push({ name: file.fileName, seconds: duration });
    append(`ERRO: ${file.fileName} ${msg} (${humanTime(duration)})`);
});
r.on('progress', function(){
    updateStats();
});
r.on('complete', function(){
    if (statsTimer) {
        clearInterval(statsTimer);
        statsTimer = null;
    }
    updateStats();
    if (failedUploads.length > 0) {
        stats.textContent = `Upload completo com falhas (${failedUploads.length}).`;
        append('Falhas:');
        failedUploads.forEach((f) => append(`- ${f.name} (${humanTime(f.seconds)})`));
    } else {
        stats.textContent = 'Upload completo.';
    }
    refreshLatestPhotos();
});
</script>
@endsection
