<?php

namespace App\Support;

use App\Mail\OrderDownloadLinkMail;
use App\Models\Order;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Throwable;

class OrderDownloadService
{
    public static function createAccessLink(Order $order): string
    {
        $token = Str::random(64);
        $order->forceFill([
            'download_token_hash' => hash('sha256', $token),
        ])->save();

        return route('downloads.show', ['token' => $token]);
    }

    public static function sendAccessLink(Order $order): bool
    {
        if (! $order->customer_email) {
            return false;
        }

        $url = self::createAccessLink($order);

        try {
            Mail::to($order->customer_email)->send(new OrderDownloadLinkMail($order, $url));
            $order->forceFill([
                'download_link_sent_at' => now(),
            ])->save();
            return true;
        } catch (Throwable $e) {
            Log::error('Failed sending order download link email', [
                'order_id' => $order->id,
                'order_code' => $order->order_code,
                'email' => $order->customer_email,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }
}
