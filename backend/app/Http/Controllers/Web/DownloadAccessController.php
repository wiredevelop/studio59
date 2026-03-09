<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Photo;
use Illuminate\Http\Request;
use ZipArchive;

class DownloadAccessController extends Controller
{
    public function show(string $token)
    {
        $order = $this->resolveOrderByToken($token);

        abort_unless($order->status === 'paid', 403, 'Pedido ainda não está pago.');

        return view('downloads.show', [
            'order' => $order,
            'token' => $token,
        ]);
    }

    public function download(string $token, int $photoId)
    {
        $order = $this->resolveOrderByToken($token);
        abort_unless($order->status === 'paid', 403, 'Pedido ainda não está pago.');

        $photo = $order->items->firstWhere('photo_id', $photoId)?->photo;
        abort_unless($photo instanceof Photo, 403);

        $path = storage_path('app/private/'.$photo->original_path);
        abort_unless(is_file($path), 404);

        return response()->download($path, $photo->number.'.jpg');
    }

    public function bulkDownload(Request $request, string $token)
    {
        $order = $this->resolveOrderByToken($token);
        abort_unless($order->status === 'paid', 403, 'Pedido ainda não está pago.');

        $validated = $request->validate([
            'photo_ids' => ['nullable', 'array'],
            'photo_ids.*' => ['integer'],
        ]);

        $requestedIds = collect($validated['photo_ids'] ?? [])->map(fn ($id) => (int) $id)->unique()->values();
        $items = $order->items->filter(fn ($item) => $item->photo instanceof Photo);

        if ($requestedIds->isNotEmpty()) {
            $items = $items->whereIn('photo_id', $requestedIds->all());
        }

        abort_if($items->isEmpty(), 422, 'Sem fotos válidas para download.');

        $tmpDir = storage_path('app/private/tmp');
        if (! is_dir($tmpDir)) {
            mkdir($tmpDir, 0775, true);
        }

        if (! class_exists(ZipArchive::class)) {
            abort(500, 'Extensão ZIP não disponível no servidor.');
        }

        $zipPath = $tmpDir.'/order-'.$order->order_code.'-'.uniqid().'.zip';
        $zip = new ZipArchive();

        if ($zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
            abort(500, 'Não foi possível gerar ZIP.');
        }

        foreach ($items as $item) {
            $photo = $item->photo;
            $path = storage_path('app/private/'.$photo->original_path);
            if (is_file($path)) {
                $zip->addFile($path, $photo->number.'.jpg');
            }
        }

        $zip->close();

        return response()->download($zipPath, 'pedido-'.$order->order_code.'.zip')->deleteFileAfterSend(true);
    }

    private function resolveOrderByToken(string $token): Order
    {
        return Order::with(['event', 'items.photo'])
            ->where('download_token_hash', hash('sha256', $token))
            ->firstOrFail();
    }
}
