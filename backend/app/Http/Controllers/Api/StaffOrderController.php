<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Support\Audit;
use App\Support\OrderDownloadService;
use App\Support\OrdersPdf;
use App\Support\SalesPdf;
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
        $eventIds = $request->query('event_ids');
        if (is_string($eventIds)) {
            $eventIds = array_filter(array_map('intval', explode(',', $eventIds)));
        } elseif (is_array($eventIds)) {
            $eventIds = array_filter(array_map('intval', $eventIds));
        } else {
            $eventIds = [];
        }

        if ($user && in_array($user->role, ['photographer', 'staff'], true)) {
            $query->whereHas('event', fn ($q) => $q->visibleTo($user));
        }

        if ($request->filled('event_id')) {
            $query->where('event_id', $request->integer('event_id'));
        }

        if (! empty($eventIds)) {
            $query->whereIn('event_id', $eventIds);
        }

        if (empty($eventIds) && ($request->filled('event_date') || $request->filled('event_type'))) {
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
            'cash_received_amount' => $order->cash_received_amount,
            'cash_change_amount' => $order->cash_change_amount,
            'cash_due_amount' => $order->cash_due_amount,
            'status' => $order->status,
            'total_amount' => $order->total_amount,
            'product_type' => $order->product_type,
            'delivery_type' => $order->delivery_type,
            'delivery_address' => $order->delivery_address,
            'notes' => $order->notes,
            'event' => $order->event ? [
                'id' => $order->event->id,
                'name' => $order->event->name,
                'event_date' => optional($order->event->event_date)->format('Y-m-d'),
            ] : null,
            'photos' => $order->items->filter(fn ($item) => $item->photo)->map(function ($item) {
                return [
                    'id' => $item->photo->id,
                    'number' => $item->photo->number,
                    'quantity' => $item->quantity ?? 1,
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
            'notes' => ['nullable', 'string', 'max:2000'],
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

    public function markPaid(Request $request, Order $order)
    {
        $this->ensureOrderAccess($order);
        $validated = $request->validate([
            'cash_received_amount' => ['nullable', 'numeric', 'min:0'],
            'cash_change_amount' => ['nullable', 'numeric', 'min:0'],
            'cash_due_amount' => ['nullable', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);

        $update = ['status' => 'paid'];
        if ($order->payment_method === 'cash') {
            $update['cash_received_amount'] = $validated['cash_received_amount'] ?? null;
            $update['cash_change_amount'] = $validated['cash_change_amount'] ?? null;
            $update['cash_due_amount'] = $validated['cash_due_amount'] ?? null;
        }
        if (array_key_exists('notes', $validated)) {
            $update['notes'] = $validated['notes'];
        }

        $order->update($update);
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

    public function exportTxt(Event $event): StreamedResponse
    {
        $this->ensureEventAccess($event);
        $orders = Order::with('items.photo')->where('event_id', $event->id)->orderBy('id')->get();

        $filename = 'event-'.$event->id.'-orders.txt';

        return response()->streamDownload(function () use ($event, $orders) {
            $cashTotal = 0;
            $digitalTotal = 0;
            $photosOwed = 0;
            $changeOwed = 0;

            echo "EVENTO: {$event->name}\n";
            echo "DATA: ".optional($event->event_date)->format('d/m/Y')."\n";
            echo str_repeat('=', 50)."\n\n";

            foreach ($orders as $o) {
                echo "PEDIDO #{$o->id} | {$o->order_code}\n";
                echo "CLIENTE: {$o->customer_name}".($o->customer_phone ? " | {$o->customer_phone}" : '')."\n";
                echo 'ESTADO: '.strtoupper($o->status).' | PAGAMENTO: '.strtoupper($o->payment_method ?? '-')."\n";

                foreach ($o->items as $item) {
                    if ($item->photo) {
                        $qty = $item->quantity ?? 1;
                        echo "  FOTO {$item->photo->number} x{$qty}\n";
                    }
                }

                echo 'TOTAL: '.number_format((float) $o->total_amount, 2, ',', '.').' €'."\n";

                if ($o->payment_method === 'cash') {
                    if ($o->cash_due_amount > 0) {
                        $photosOwed++;
                        echo 'FOTOS EM DÍVIDA: '.number_format((float) $o->cash_due_amount, 2, ',', '.')." €\n";
                    }
                    if ($o->cash_change_amount > 0) {
                        $changeOwed += (float) $o->cash_change_amount;
                        echo 'TROCO A DEVOLVER: '.number_format((float) $o->cash_change_amount, 2, ',', '.')." €\n";
                    }
                    $cashTotal += (float) $o->total_amount;
                } else {
                    $digitalTotal += (float) $o->total_amount;
                }

                if (! empty($o->notes)) {
                    echo "NOTAS: {$o->notes}\n";
                }

                echo str_repeat('-', 50)."\n";
            }

            echo "\n".str_repeat('=', 50)."\n";
            echo "RESUMO\n";
            echo str_repeat('=', 50)."\n";
            echo 'TOTAL DINHEIRO FÍSICO: '.number_format($cashTotal, 2, ',', '.')." €\n";
            echo 'TOTAL DIGITAL/ONLINE: '.number_format($digitalTotal, 2, ',', '.')." €\n";
            echo 'TOTAL GERAL: '.number_format($cashTotal + $digitalTotal, 2, ',', '.')." €\n";
            if ($photosOwed > 0) {
                echo "PEDIDOS COM FOTOS EM DÍVIDA: {$photosOwed}\n";
            }
            if ($changeOwed > 0) {
                echo 'TOTAL TROCOS A DEVOLVER: '.number_format($changeOwed, 2, ',', '.')." €\n";
            }
        }, $filename, ['Content-Type' => 'text/plain; charset=utf-8']);
    }

    public function exportOrdersPdf(Event $event)
    {
        $this->ensureEventAccess($event);
        $pdf = OrdersPdf::generate($event);
        $filename = 'pedidos-evento-'.$event->id.'.pdf';

        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="'.$filename.'"',
        ]);
    }

    public function exportSalesPdf(Request $request, Event $event)
    {
        $this->ensureEventAccess($event);
        $commissionRate = max(0, min(100, (float) $request->query('commission_rate', 15)));
        $pdf = SalesPdf::generate($event, $commissionRate);
        $filename = 'vendas-evento-'.$event->id.'.pdf';

        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="'.$filename.'"',
        ]);
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
