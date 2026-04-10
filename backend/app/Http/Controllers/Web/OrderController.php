<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\Order;
use App\Support\Audit;
use App\Support\OrderDownloadService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\StreamedResponse;
use ZipArchive;

class OrderController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $query = Order::with(['event', 'items.photo'])->orderByDesc('id');

        if ($user && $user->role === 'photographer') {
            $query->whereHas('event', fn ($q) => $q->visibleTo($user));
        }

        if ($request->filled('event_id')) {
            $query->where('event_id', $request->integer('event_id'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }
        if ($request->filled('q')) {
            $q = trim((string) $request->query('q'));
            $query->where(function ($sub) use ($q) {
                $sub->where('customer_name', 'like', '%'.$q.'%')
                    ->orWhere('order_code', 'like', '%'.$q.'%')
                    ->orWhere('customer_phone', 'like', '%'.$q.'%')
                    ->orWhere('customer_email', 'like', '%'.$q.'%');
            });
        }

        return view('orders.index', [
            'orders' => $query->paginate(30),
            'events' => Event::query()
                ->visibleTo($user)
                ->orderByDesc('event_date')
                ->get(['id', 'name']),
        ]);
    }

    public function bulkStatus(Request $request)
    {
        $validated = $request->validate([
            'order_ids' => ['required', 'array', 'min:1'],
            'order_ids.*' => ['integer', 'exists:orders,id'],
            'status' => ['required', Rule::in(['pending', 'paid'])],
        ]);

        $user = $request->user();
        if ($user && $user->role === 'photographer') {
            if ($validated['status'] !== 'paid') {
                abort(403, 'Apenas pode aprovar pagamentos.');
            }
            $allowedCount = Order::query()
                ->whereIn('id', $validated['order_ids'])
                ->whereHas('event', fn ($q) => $q->visibleTo($user))
                ->count();
            if ($allowedCount !== count($validated['order_ids'])) {
                abort(403);
            }
        }

        $updated = Order::whereIn('id', $validated['order_ids'])->update(['status' => $validated['status']]);
        Audit::log('order.bulk_status', Order::class, null, [
            'status' => $validated['status'],
            'count' => $updated,
        ]);

        return back()->with('ok', "Atualizados {$updated} pedidos.");
    }

    public function markPaid(Order $order)
    {
        $this->ensureOrderAccess($order);
        $order->update(['status' => 'paid']);
        $hadEmail = ! empty($order->customer_email);
        $sent = OrderDownloadService::sendAccessLink($order);
        Audit::log('order.mark_paid', Order::class, $order->id, ['order_code' => $order->order_code]);

        if ($sent) {
            return back()->with('ok', 'Pedido marcado como pago e link enviado por email.');
        }

        if (! $hadEmail) {
            return back()->with('ok', 'Pedido marcado como pago. Sem email no pedido, o link não foi enviado.');
        }

        return back()->with('ok', 'Pedido marcado como pago. Falha ao enviar email (verifica a configuração).');
    }

    public function sendDownloadLink(Request $request, Order $order)
    {
        $this->ensureOrderAccess($order);
        $user = auth()->user();
        if ($user && $user->role === 'photographer') {
            abort(403);
        }
        $validated = $request->validate([
            'customer_email' => ['nullable', 'email', 'max:255'],
        ]);
        if (! empty($validated['customer_email'])) {
            $order->update(['customer_email' => $validated['customer_email']]);
        }
        $hasEmail = ! empty($order->customer_email);
        if ($order->status !== 'paid') {
            return back()->withErrors(['Pedido precisa estar paid para enviar link.']);
        }

        $sent = OrderDownloadService::sendAccessLink($order, true);
        Audit::log('order.download_link.send', Order::class, $order->id, ['sent' => $sent]);

        if (! $sent) {
            if (! $hasEmail) {
                return back()->withErrors(['Email em falta no pedido.']);
            }
            return back()->withErrors(['Falha ao enviar email (verifica a configuração). O link ficou disponível para o cliente.']);
        }

        return back()->with('ok', 'Link de download enviado por email.');
    }

    public function downloadAll(Order $order)
    {
        $this->ensureOrderAccess($order);
        $user = auth()->user();
        if ($user && $user->role === 'photographer') {
            abort(403);
        }
        $order->loadMissing(['items.photo']);
        if ($order->status === 'pending') {
            abort(403, 'Pedido ainda não está pago.');
        }

        $items = $order->items->filter(fn ($item) => $item->photo);
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

    public function exportCsv(Event $event): StreamedResponse
    {
        $this->ensureEventAccess($event);
        $user = auth()->user();
        if ($user && $user->role === 'photographer') {
            abort(403);
        }
        $filename = 'event-'.$event->id.'-orders.csv';
        $orders = Order::with('items.photo')->where('event_id', $event->id)->orderBy('id')->get();

        return response()->streamDownload(function () use ($orders) {
            $out = fopen('php://output', 'w');
            fputcsv($out, [
                'pedido_id',
                'order_code',
                'nome',
                'telefone',
                'email',
                'produto',
                'entrega',
                'morada',
                'filme',
                'fotos',
                'items_total',
                'extras_total',
                'shipping_fee',
                'film_fee',
                'status',
                'total',
            ]);
            foreach ($orders as $o) {
                $numbers = $o->items->map(function ($i) {
                    if (! $i->photo) return null;
                    $qty = $i->quantity ?? 1;
                    return $qty > 1 ? $i->photo->number.' x'.$qty : $i->photo->number;
                })->filter()->implode('|');
                fputcsv($out, [
                    $o->id,
                    $o->order_code,
                    $o->customer_name,
                    $o->customer_phone,
                    $o->customer_email,
                    $o->product_type,
                    $o->delivery_type,
                    $o->delivery_address,
                    $o->wants_film ? 'sim' : 'nao',
                    $numbers,
                    $o->items_total,
                    $o->extras_total,
                    $o->shipping_fee,
                    $o->film_fee,
                    $o->status,
                    $o->total_amount,
                ]);
            }
            fclose($out);
        }, $filename, ['Content-Type' => 'text/csv']);
    }

    private function ensureEventAccess(Event $event): void
    {
        $user = auth()->user();
        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
            $assigned = $event->staff()->where('user_id', $user->id)->exists();
            abort_unless($assigned, 403);
        }
    }

    private function ensureOrderAccess(Order $order): void
    {
        $user = auth()->user();
        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
            $assigned = $order->event && $order->event->staff()->where('user_id', $user->id)->exists();
            abort_unless($assigned, 403);
        }
    }
}
