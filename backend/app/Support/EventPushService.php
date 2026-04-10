<?php

namespace App\Support;

use App\Models\Event;
use App\Models\StaffDeviceToken;
use App\Models\User;

class EventPushService
{
    public function __construct(private FirebaseMessagingService $messaging)
    {
    }

    public function sendToUser(Event $event, User $user, string $reason, ?string $label = null): void
    {
        if ($event->status === 'rascunho') {
            return;
        }

        $tokens = StaffDeviceToken::query()
            ->where('user_id', $user->id)
            ->pluck('token')
            ->all();

        if (empty($tokens)) {
            return;
        }

        $title = match ($reason) {
            'updated' => 'Evento atualizado',
            'removed', 'cancelled' => 'Removido do evento',
            'removed_notice' => 'Removido do serviço',
            default => 'Novo evento publicado',
        };
        $body = $label ?: ($event->event_type ?: 'Evento');
        $data = [
            'event_id' => (string) $event->id,
            'reason' => $reason,
        ];

        $this->messaging->sendToTokens($tokens, $title, $body, $data);
    }
}
