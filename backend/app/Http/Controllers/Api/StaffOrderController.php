<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Support\Audit;
use App\Support\OrderDownloadService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use App\Models\Event;
use Symfony\Component\HttpFoundation\StreamedResponse;
use ZipArchive;

class StaffOrderController extends Controller
{
    public function index(Request $request, int $id)
    {
        $user = $request->user();
        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
            $allowed = Event::query()->visibleTo($user)->where('id', $id)->exists();
            abort_unless($allowed, 403);
        }

        $query = Order::query()->where('event_id', $id)->orderByDesc('id');

        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }

        if ($request->filled('q')) {
            $q = trim((string) $request->query('q'));
            $query->where(function ($sub) use ($q) {
                $sub->where('customer_name', 'like', '%'.$q.'%')
                    ->orWhere('order_code', 'like', '%'.$q.'%');
            });
        }

        return response()->json($query->paginate(30));
    }

    public function list(Request $request)
    {
        $user = $request->user();
        $query = Order::with(['event'])->orderByDesc('id');

        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
            $query->whereHas('event', fn ($q) => $q->visibleTo($user));
        }

        if ($request->filled('event_id')) {
            $query->where('event_id', $request->integer('event_id'));
        }

        if ($request->filled('event_date') || $request->filled('event_type')) {
            $eventDate = $request->query('event_date');
            $eventType = $request->query('event_type');
            $query->whereHas('event', function ($q) use ($eventDate, $eventType) {
                if (! empty($eventDate)) {
                    $q->whereDate('event_date', $eventDate);
                }
                if (! empty($eventType)) {
                    $q->where('event_type', $eventType);
                }
            });
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

        return response()->json($query->paginate(30));
    }

    public function show(Order $order)
    {
        $this->ensureOrderAccess($order);
        $order->loadMissing(['event', 'items.photo']);

        return response()->json([
            'id' => $order->id,
            'order_code' => $order->order_code,
            'customer_name' => $order->customer_name,
            'customer_email' => $order->customer_email,
            'customer_phone' => $order->customer_phone,
            'payment_method' => $order->payment_method,
            'status' => $order->status,
            'total_amount' => $order->total_amount,
            'event' => $order->event ? [
                'id' => $order->event->id,
                'name' => $order->event->name,
                'event_date' => optional($order->event->event_date)->format('Y-m-d'),
            ] : null,
            'photos' => $order->items->filter(fn ($item) => $item->photo)->map(function ($item) {
                return [
                    'id' => $item->photo->id,
                    'number' => $item->photo->number,
                ];
            })->values(),
        ]);
    }

    public function update(Request $request, Order $order)
    {
        $this->ensureOrderAccess($order);
        $user = $request->user();
        if ($user && $user->role === 'photographer') {
            abort(403);
        }
        $validated = $request->validate([
            'customer_name' => ['required', 'string', 'max:255'],
            'customer_email' => ['nullable', 'email', 'max:255'],
            'customer_phone' => ['nullable', 'string', 'max:50'],
            'payment_method' => ['nullable', 'string', 'max:50'],
            'status' => ['required', Rule::in(['pending', 'paid'])],
        ]);

        $order->update($validated);
        Audit::log('api.order.updated', Order::class, $order->id, ['status' => $order->status]);

        return $this->show($order->fresh());
    }

    public function bulkStatus(Request $request)
    {
        $validated = $request->validate([
            'order_ids' => ['required', 'array', 'min:1'],
            'order_ids.*' => ['integer', 'exists:orders,id'],
            'status' => ['required', Rule::in(['pending', 'paid'])],
        ]);

        $user = $request->user();
        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
            if ($validated['status'] !== 'paid') {
                if ($user->role === 'photographer') {
                    abort(403);
                }
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
        Audit::log('api.order.bulk_status', Order::class, null, [
            'status' => $validated['status'],
            'count' => $updated,
        ]);

        return response()->json(['updated' => $updated]);
    }

    public function markPaid(Order $order)
    {
        $this->ensureOrderAccess($order);
        $order->update(['status' => 'paid']);
        $sent = OrderDownloadService::sendAccessLink($order);
        Audit::log('api.order.mark_paid', Order::class, $order->id, ['order_code' => $order->order_code]);

        return response()->json([
            'message' => 'Order marked paid',
            'download_link_emailed' => $sent,
        ]);
    }

    public function sendDownloadLink(Request $request, Order $order)
    {
        $this->ensureOrderAccess($order);
        $user = request()->user();
        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
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
            return response()->json(['message' => 'Order must be paid to send link'], 422);
        }

        $sent = OrderDownloadService::sendAccessLink($order, true);
        Audit::log('api.order.download_link.send', Order::class, $order->id, ['sent' => $sent]);

        if (! $sent) {
            if (! $hasEmail) {
                return response()->json(['message' => 'Email em falta no pedido.'], 422);
            }
            return response()->json(['message' => 'Falha ao enviar email (verifica a configuração). O link ficou disponível para o cliente.'], 422);
        }

        return response()->json(['message' => 'Link de download enviado por email.', 'sent' => true]);
    }

    public function downloadAll(Order $order)
    {
        $this->ensureOrderAccess($order);
        $user = request()->user();
        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
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
        $user = request()->user();
        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
            abort(403);
        }
        $filename = 'event-'.$event->id.'-orders.csv';
        $orders = Order::with('items.photo')->where('event_id', $event->id)->orderBy('id')->get();

        return response()->streamDownload(function () use ($orders) {
            $out = fopen('php://output', 'w');
            fputcsv($out, ['pedido_id', 'order_code', 'nome', 'fotos', 'status', 'total']);
            foreach ($orders as $o) {
                $numbers = $o->items->map(fn ($i) => $i->photo->number)->implode('|');
                fputcsv($out, [$o->id, $o->order_code, $o->customer_name, $numbers, $o->status, $o->total_amount]);
            }
            fclose($out);
        }, $filename, ['Content-Type' => 'text/csv']);
    }

    private function ensureEventAccess(Event $event): void
    {
        $user = request()->user();
        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
            $assigned = $event->staff()->where('user_id', $user->id)->exists();
            abort_unless($assigned, 403);
        }
    }

    private function ensureOrderAccess(Order $order): void
    {
        $user = request()->user();
        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
            $assigned = $order->event && $order->event->staff()->where('user_id', $user->id)->exists();
            abort_unless($assigned, 403);
        }
    }
}
