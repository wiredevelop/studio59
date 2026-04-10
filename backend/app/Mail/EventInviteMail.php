<?php

namespace App\Mail;

use App\Models\Event;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class EventInviteMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public Event $event,
        public User $user,
        public string $reason,
        public string $icsContent,
        public string $eventLabel
    ) {
    }

    public function envelope(): Envelope
    {
        $label = $this->eventLabel !== '' ? $this->eventLabel : 'EVENTO';
        $subject = $label;
        return new Envelope(
            subject: $subject
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.event_invite'
        );
    }

    public function attachments(): array
    {
        return [
            \Illuminate\Mail\Mailables\Attachment::fromData(
                fn () => $this->icsContent,
                'evento-'.$this->event->id.'.ics'
            )->withMime('text/calendar; charset=UTF-8; method=REQUEST'),
        ];
    }
}
