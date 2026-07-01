<?php

namespace App\Support;

use App\Models\Event;
use App\Support\ServiceTemplateCatalog;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;

class EventPdf
{
    public static function path(
        Event $event,
        bool $includePricing = true,
        bool $includeInternal = true
    ): string
    {
        if ($includePricing && $includeInternal) {
            return 'events/'.$event->id.'/ficha.pdf';
        }

        return 'events/'.$event->id.'/ficha-'
            .($includePricing ? 'pricing' : 'no-pricing')
            .'-'
            .($includeInternal ? 'internal' : 'no-internal')
            .'.pdf';
    }

    public static function ensure(
        Event $event,
        bool $includePricing = true,
        bool $includeInternal = true
    ): string
    {
        $path = self::path($event, $includePricing, $includeInternal);
        if (Storage::disk('local')->exists($path)) {
            $lastModified = Storage::disk('local')->lastModified($path);
            $updatedAt = $event->updated_at?->timestamp;
            if ($updatedAt && $lastModified >= $updatedAt) {
                return $path;
            }
        }
        self::generate($event, $includePricing, $includeInternal);

        return $path;
    }

    public static function generate(
        Event $event,
        bool $includePricing = true,
        bool $includeInternal = true
    ): string
    {
        $event->loadMissing('client', 'staff.user');
        $meta = $event->event_meta ?? [];

        $dateLabel = null;
        if ($event->event_date) {
            $dateLabel = Carbon::parse($event->event_date)
                ->locale('pt_PT')
                ->translatedFormat('l, d \\d\\e F \\d\\e Y');
            $dateLabel = ucfirst($dateLabel);
        }

        $staffNames = $event->staff
            ->map(function ($staff) {
                $user = $staff->user;
                return $user?->username ?: $user?->name;
            })
            ->filter()
            ->values();
        $namesLine = $staffNames->implode(' + ');

        $data = [
            'event' => $event,
            'meta' => $meta,
            'dateLabel' => $dateLabel,
            'dateShort' => $event->event_date ? Carbon::parse($event->event_date)->format('d/m/y') : null,
            'namesLine' => $namesLine,
            'eventTypeLabel' => strtoupper($event->event_type ?: 'EVENTO'),
            'serviceTemplate' => ServiceTemplateCatalog::findByType($event->event_type),
            'showPricing' => $includePricing,
            'showInternal' => $includeInternal,
        ];

        $template = match ($event->event_type ?? '') {
            'casamento' => 'pdfs.template-casamento',
            'batizado' => 'pdfs.event_sheet',
            default => 'pdfs.event_sheet_dynamic',
        };
        $html = view($template, $data)->render();

        $options = new Options();
        $options->set('isRemoteEnabled', true);
        $options->set('defaultFont', 'DejaVu Sans');
        $dompdf = new Dompdf($options);
        $dompdf->loadHtml($html, 'UTF-8');
        $dompdf->setPaper('A4', 'portrait');
        $dompdf->render();

        $path = self::path($event, $includePricing, $includeInternal);
        Storage::disk('local')->makeDirectory(dirname($path));
        Storage::disk('local')->put($path, $dompdf->output());

        return $path;
    }
}
