<?php

namespace App\Support;

use App\Models\Event;
use App\Models\Order;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Support\Carbon;

class SalesPdf
{
    public static function generate(Event $event, float $commissionRate = 15.0): string
    {
        $event->loadMissing('staff.user');

        $orders = Order::with('items.photo')
            ->where('event_id', $event->id)
            ->orderBy('id')
            ->get();

        $cashTotal    = 0.0;
        $digitalTotal = 0.0;
        $photosSold   = 0;
        $changeOwed   = 0.0;
        $photosOwed   = 0.0;
        $notesList    = [];

        foreach ($orders as $o) {
            $amount = (float) $o->total_amount;
            if ($o->payment_method === 'cash') {
                $cashTotal += $amount;
                if ((float) $o->cash_change_amount > 0 && ! $o->cash_change_given) {
                    $changeOwed += (float) $o->cash_change_amount;
                }
                if ((float) $o->cash_due_amount > 0) {
                    $photosOwed += (float) $o->cash_due_amount;
                }
            } else {
                $digitalTotal += $amount;
            }
            foreach ($o->items as $item) {
                $photosSold += (int) ($item->quantity ?? 1);
            }
            if (! empty($o->notes)) {
                $notesList[] = ['code' => $o->order_code, 'text' => $o->notes];
            }
        }

        $grandTotal   = $cashTotal + $digitalTotal;
        $staffMembers = $event->staff
            ->map(fn ($s) => $s->user?->username ?: $s->user?->name)
            ->filter()
            ->values();
        $memberCount = max(1, $staffMembers->count());

        $commissionPerMember = round($grandTotal / $memberCount * ($commissionRate / 100), 2);

        $dateLabel = $event->event_date
            ? Carbon::parse($event->event_date)->locale('pt_PT')->translatedFormat('l, d \\d\\e F \\d\\e Y')
            : null;
        if ($dateLabel) {
            $dateLabel = ucfirst($dateLabel);
        }

        $data = compact(
            'event',
            'orders',
            'cashTotal',
            'digitalTotal',
            'grandTotal',
            'photosSold',
            'changeOwed',
            'photosOwed',
            'staffMembers',
            'memberCount',
            'commissionRate',
            'commissionPerMember',
            'notesList',
            'dateLabel',
        );

        $html = view('pdfs.event_sales', $data)->render();

        $options = new Options();
        $options->set('isRemoteEnabled', true);
        $options->set('defaultFont', 'DejaVu Sans');
        $dompdf = new Dompdf($options);
        $dompdf->loadHtml($html, 'UTF-8');
        $dompdf->setPaper('A4', 'portrait');
        $dompdf->render();

        return $dompdf->output();
    }
}
