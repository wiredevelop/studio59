<?php

namespace App\Support;

use App\Models\Event;
use App\Models\Order;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Support\Carbon;

class OrdersPdf
{
    public static function generate(Event $event): string
    {
        $orders = Order::with('items.photo')
            ->where('event_id', $event->id)
            ->orderBy('id')
            ->get();

        $dateLabel = $event->event_date
            ? Carbon::parse($event->event_date)->locale('pt_PT')->translatedFormat('l, d \\d\\e F \\d\\e Y')
            : null;
        if ($dateLabel) {
            $dateLabel = ucfirst($dateLabel);
        }

        $data = compact('event', 'orders', 'dateLabel');

        $html = view('pdfs.event_orders', $data)->render();

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
