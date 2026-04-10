<?php

namespace App\Support;

use App\Mail\EventInviteMail;
use App\Models\Event;
use App\Models\EventInvitation;
use App\Models\User;
use App\Support\EventPushService;
use Illuminate\Support\Facades\Mail;

class EventInviteService
{
    public function sendForEvent(Event $event, string $reason): void
    {
        if ($event->status === 'rascunho' || $event->status === 'cancelled') {
            return;
        }

        $staff = $event->staff()->with('user')->get();
        $admins = User::query()->where('role', 'admin')->get();
        $recipients = $staff
            ->pluck('user')
            ->filter()
            ->merge($admins)
            ->unique('id')
            ->values();
        if ($recipients->isEmpty()) {
            return;
        }

        $teamLabel = $this->buildTeamLabel($event, $staff);
        $eventLabel = $this->buildEventLabel($event, $teamLabel);

        $staffByUser = [];
        foreach ($staff as $member) {
            if ($member->user) {
                $staffByUser[$member->user->id] = $member;
            }
        }

        $push = app(EventPushService::class);
        foreach ($recipients as $user) {
            $member = $staffByUser[$user->id] ?? null;
            if (! $user || empty($user->email)) {
                if ($user) {
                    $push->sendToUser($event, $user, $reason);
                }
                continue;
            }

            $ics = EventCalendarInvite::build($event, $user, 'REQUEST', $eventLabel);
            $status = 'sent';
            try {
                Mail::to($user->email)->send(new EventInviteMail($event, $user, $reason, $ics, $eventLabel));
            } catch (\Throwable $e) {
                $status = 'failed';
                logger()->warning('Failed to send event invite', [
                    'event_id' => $event->id,
                    'user_id' => $user->id,
                    'error' => $e->getMessage(),
                ]);
            }

            EventInvitation::create([
                'event_id' => $event->id,
                'user_id' => $user->id,
                'invite_type' => $member?->role ?? 'admin',
                'status' => $status,
                'channel' => 'email',
                'message' => $reason,
                'sent_at' => $status === 'sent' ? now() : null,
            ]);

            $push->sendToUser($event, $user, $reason, $eventLabel);
        }
    }

    public function sendCancellation(Event $event, User $user, $staff = null): void
    {
        if ($event->status === 'rascunho') {
            return;
        }

        EventInvitation::where('event_id', $event->id)
            ->where('user_id', $user->id)
            ->update([
                'status' => 'cancelled',
                'invite_type' => 'cancelled',
                'sent_at' => now(),
            ]);

        $staffList = $staff ?? $event->staff()->with('user')->get();
        $teamLabel = $this->buildTeamLabel($event, $staffList);
        $eventLabel = $this->buildEventLabel($event, $teamLabel);

        $push = app(EventPushService::class);
        if (! empty($user->email)) {
            $ics = EventCalendarInvite::build($event, $user, 'CANCEL', $eventLabel);
            $status = 'sent';
            try {
                Mail::to($user->email)->send(new EventInviteMail($event, $user, 'cancelled', $ics, $eventLabel));
            } catch (\Throwable $e) {
                $status = 'failed';
                logger()->warning('Failed to send event cancellation', [
                    'event_id' => $event->id,
                    'user_id' => $user->id,
                    'error' => $e->getMessage(),
                ]);
            }

            EventInvitation::create([
                'event_id' => $event->id,
                'user_id' => $user->id,
                'invite_type' => 'cancelled',
                'status' => $status,
                'channel' => 'email',
                'message' => 'cancelled',
                'sent_at' => $status === 'sent' ? now() : null,
            ]);
        }

        $push->sendToUser($event, $user, 'removed', $eventLabel);
        $dateLabel = '';
        if (! empty($event->event_date)) {
            try {
                $dateLabel = \Illuminate\Support\Carbon::parse($event->event_date)->format('d/m/Y');
            } catch (\Throwable $e) {
                $dateLabel = '';
            }
        }
        $removalBody = $dateLabel !== ''
            ? 'Foi removido do serviço do dia '.$dateLabel
            : 'Foi removido do serviço';
        $push->sendToUser($event, $user, 'removed_notice', $removalBody);
    }

    public function sendPushForEvent(Event $event, string $reason): void
    {
        if ($event->status === 'rascunho' || $event->status === 'cancelled') {
            return;
        }

        $staff = $event->staff()->with('user')->get();
        $admins = User::query()->where('role', 'admin')->get();
        $recipients = $staff
            ->pluck('user')
            ->filter()
            ->merge($admins)
            ->unique('id')
            ->values();
        if ($recipients->isEmpty()) {
            return;
        }

        $teamLabel = $this->buildTeamLabel($event, $staff);
        $eventLabel = $this->buildEventLabel($event, $teamLabel);

        $push = app(EventPushService::class);
        foreach ($recipients as $user) {
            $push->sendToUser($event, $user, $reason, $eventLabel);
        }
    }

    private function buildEventLabel(Event $event, string $teamLabel): string
    {
        $type = trim((string) ($event->event_type ?: $event->service_raw));
        $typeLabel = $type !== '' ? mb_convert_case(mb_strtolower($type), MB_CASE_TITLE, 'UTF-8') : 'Evento';

        $dateLabel = '';
        if (! empty($event->event_date)) {
            try {
                $dateLabel = \Illuminate\Support\Carbon::parse($event->event_date)->format('d/m/Y');
            } catch (\Throwable $e) {
                $dateLabel = '';
            }
        }

        $parts = [$typeLabel];
        if ($teamLabel !== '') {
            $parts[] = $teamLabel;
        }
        if ($dateLabel !== '') {
            $parts[] = $dateLabel;
        }

        return implode(' - ', $parts);
    }

    private function buildTeamLabel(Event $event, $staff): string
    {
        $tokens = [];
        foreach ($staff as $member) {
            $username = $member->user?->username;
            if (! is_string($username) || trim($username) === '') {
                continue;
            }
            $clean = preg_replace('/[^\pL\pN]+/u', '', $username);
            if ($clean === '') {
                continue;
            }
            $tokens[] = mb_strtoupper($clean);
        }

        $tokens = array_values(array_unique($tokens));
        return empty($tokens) ? '' : implode('+', $tokens);
    }
}
