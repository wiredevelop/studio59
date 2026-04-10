<?php

namespace App\Support;

use Illuminate\Support\Facades\Http;

class FirebaseMessagingService
{
    public function __construct(private FirebaseAccessToken $accessToken)
    {
    }

    public function sendToTokens(array $tokens, string $title, string $body, array $data = []): void
    {
        $tokens = array_values(array_unique(array_filter($tokens, fn ($t) => is_string($t) && $t !== '')));
        if (empty($tokens)) {
            return;
        }

        $projectId = $this->accessToken->getProjectId();
        $bearer = $this->accessToken->get();
        if (! $projectId || ! $bearer) {
            return;
        }

        $endpoint = 'https://fcm.googleapis.com/v1/projects/'.$projectId.'/messages:send';
        foreach ($tokens as $token) {
            $payload = [
                'message' => [
                    'token' => $token,
                    'notification' => [
                        'title' => $title,
                        'body' => $body,
                    ],
                    'data' => array_map('strval', $data),
                ],
            ];

            $response = Http::withToken($bearer)->post($endpoint, $payload);
            if (! $response->ok()) {
                logger()->warning('FCM send failed', [
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);
            }
        }
    }
}
