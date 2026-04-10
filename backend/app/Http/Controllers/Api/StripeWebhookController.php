<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Support\Audit;
use App\Support\OrderDownloadService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Stripe\Webhook;
use Stripe\Exception\SignatureVerificationException;

class StripeWebhookController extends Controller
{
    public function handle(Request $request)
    {
        $secret = config('services.stripe.webhook_secret');
        if (empty($secret)) {
            Log::warning('Stripe webhook secret not configured');
            return response('Webhook not configured', 500);
        }

        $payload = $request->getContent();
        $signature = $request->header('Stripe-Signature');

        try {
            $event = Webhook::constructEvent($payload, $signature, $secret);
        } catch (SignatureVerificationException $e) {
            Log::warning('Stripe webhook signature verification failed', ['error' => $e->getMessage()]);
            return response('Invalid signature', 400);
        } catch (\UnexpectedValueException $e) {
            Log::warning('Stripe webhook invalid payload', ['error' => $e->getMessage()]);
            return response('Invalid payload', 400);
        }

        if (! isset($event->data->object)) {
            return response()->json(['received' => true]);
        }

        switch ($event->type) {
            case 'checkout.session.completed':
            case 'checkout.session.async_payment_succeeded':
                $this->handleCheckoutSessionPaid($event->data->object);
                break;
            case 'checkout.session.expired':
                $this->handleCheckoutSessionExpired($event->data->object);
                break;
            case 'payment_intent.succeeded':
                $this->handlePaymentIntentSucceeded($event->data->object);
                break;
            case 'payment_intent.payment_failed':
                $this->handlePaymentIntentFailed($event->data->object);
                break;
        }

        return response()->json(['received' => true]);
    }

    private function handleCheckoutSessionPaid($session): void
    {
        $orderId = $session->metadata->order_id ?? null;
        $orderCode = $session->metadata->order_code ?? null;

        $order = Order::query()
            ->when($orderId, fn ($q) => $q->where('id', $orderId))
            ->when(! $orderId && $orderCode, fn ($q) => $q->where('order_code', $orderCode))
            ->first();

        if (! $order) {
            Log::warning('Stripe webhook order not found', [
                'session_id' => $session->id ?? null,
                'order_id' => $orderId,
                'order_code' => $orderCode,
            ]);
            return;
        }

        $updates = [
            'stripe_session_id' => $session->id ?? $order->stripe_session_id,
            'stripe_payment_intent_id' => $session->payment_intent ?? $order->stripe_payment_intent_id,
        ];

        if ($order->status !== 'paid') {
            $updates['status'] = 'paid';
        }

        $order->update($updates);

        if ($order->wasChanged('status') && $order->status === 'paid') {
            $sent = OrderDownloadService::sendAccessLink($order);
            Audit::log('stripe.checkout.paid', Order::class, $order->id, [
                'order_code' => $order->order_code,
                'session_id' => $session->id ?? null,
                'sent' => $sent,
            ]);
        }
    }

    private function handleCheckoutSessionExpired($session): void
    {
        if (empty($session->metadata->order_id) && empty($session->metadata->order_code)) {
            return;
        }

        $order = Order::query()
            ->when(! empty($session->metadata->order_id), fn ($q) => $q->where('id', $session->metadata->order_id))
            ->when(empty($session->metadata->order_id) && ! empty($session->metadata->order_code), fn ($q) => $q->where('order_code', $session->metadata->order_code))
            ->first();

        if (! $order) {
            return;
        }

        if (empty($order->stripe_session_id)) {
            $order->update(['stripe_session_id' => $session->id ?? null]);
        }
    }

    private function handlePaymentIntentSucceeded($intent): void
    {
        $order = null;
        if (! empty($intent->id)) {
            $order = Order::query()->where('stripe_payment_intent_id', $intent->id)->first();
        }

        if (! $order && ! empty($intent->metadata->order_id)) {
            $order = Order::query()->where('id', $intent->metadata->order_id)->first();
        }
        if (! $order && ! empty($intent->metadata->order_code)) {
            $order = Order::query()->where('order_code', $intent->metadata->order_code)->first();
        }

        if (! $order) {
            Log::warning('Stripe payment intent order not found', [
                'payment_intent' => $intent->id ?? null,
                'order_id' => $intent->metadata->order_id ?? null,
                'order_code' => $intent->metadata->order_code ?? null,
            ]);
            return;
        }

        $updates = [
            'stripe_payment_intent_id' => $intent->id ?? $order->stripe_payment_intent_id,
        ];
        if ($order->status !== 'paid') {
            $updates['status'] = 'paid';
        }
        $order->update($updates);

        if ($order->wasChanged('status') && $order->status === 'paid') {
            $sent = OrderDownloadService::sendAccessLink($order);
            Audit::log('stripe.payment_intent.paid', Order::class, $order->id, [
                'order_code' => $order->order_code,
                'payment_intent' => $intent->id ?? null,
                'sent' => $sent,
            ]);
        }
    }

    private function handlePaymentIntentFailed($intent): void
    {
        Log::info('Stripe payment intent failed', [
            'payment_intent' => $intent->id ?? null,
            'order_id' => $intent->metadata->order_id ?? null,
            'order_code' => $intent->metadata->order_code ?? null,
            'message' => $intent->last_payment_error->message ?? null,
        ]);
    }
}
