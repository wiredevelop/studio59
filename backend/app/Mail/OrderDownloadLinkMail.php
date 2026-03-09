<?php

namespace App\Mail;

use App\Models\Order;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class OrderDownloadLinkMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public Order $order,
        public string $downloadUrl
    ) {
    }

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Studio 59 - Link de download do pedido '.$this->order->order_code
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.order_download_link'
        );
    }
}
