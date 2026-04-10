<?php

namespace App\Support;

use App\Mail\OrderDownloadLinkMail;
use App\Models\Order;
use Illuminate\Support\Facades\Crypt;
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
            'download_token' => Crypt::encryptString($token),
            'download_link_sent_at' => now(),
        ])->save();

        return route('downloads.show', ['token' => $token]);
    }

    public static function isLinkExpired(Order $order): bool
    {
        if (! $order->download_link_sent_at) {
            return true;
        }

        return now()->greaterThan($order->download_link_sent_at->copy()->addDays(7));
    }

    public static function getExistingAccessLink(Order $order): ?string
    {
        if (! $order->download_token || ! $order->download_token_hash || self::isLinkExpired($order)) {
            return null;
        }

        try {
            $token = Crypt::decryptString($order->download_token);
        } catch (Throwable) {
            return null;
        }

        if (! $token) {
            return null;
        }

        return route('downloads.show', ['token' => $token]);
    }

    public static function ensureAccessLink(Order $order, bool $forceNew = false): string
    {
        if (! $forceNew) {
            $existing = self::getExistingAccessLink($order);
            if ($existing) {
                return $existing;
            }
        }

        return self::createAccessLink($order);
    }

    public static function sendAccessLink(Order $order, bool $forceNew = true): bool
    {
        $url = self::ensureAccessLink($order, $forceNew);
        if (! $order->customer_email) {
            return false;
        }

        try {
            Mail::to($order->customer_email)->send(new OrderDownloadLinkMail($order, $url));
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
