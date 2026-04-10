<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class FirebaseAccessToken
{
    private const CACHE_KEY = 'firebase_access_token_v1';
    private const TOKEN_TTL = 3500;
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function get(): ?string
    {
        $cached = Cache::get(self::CACHE_KEY);
        if (is_string($cached) && $cached !== '') {
            return $cached;
        }

        $serviceAccount = $this->loadServiceAccount();
        if (! $serviceAccount) {
            return null;
        }

        $tokenUri = $serviceAccount['token_uri'] ?? 'https://oauth2.googleapis.com/token';
        $clientEmail = $serviceAccount['client_email'] ?? null;
        $privateKey = $serviceAccount['private_key'] ?? null;
        if (! $clientEmail || ! $privateKey) {
            return null;
        }

        $jwt = $this->buildJwt($clientEmail, $privateKey, $tokenUri);
        if (! $jwt) {
            return null;
        }

        $response = Http::asForm()->post($tokenUri, [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt,
        ]);

        if (! $response->ok()) {
            logger()->warning('Firebase token request failed', ['status' => $response->status(), 'body' => $response->body()]);
            return null;
        }

        $accessToken = $response->json('access_token');
        if (! is_string($accessToken) || $accessToken === '') {
            return null;
        }

        Cache::put(self::CACHE_KEY, $accessToken, self::TOKEN_TTL);
        return $accessToken;
    }

    public function getProjectId(): ?string
    {
        $serviceAccount = $this->loadServiceAccount();
        $projectId = $serviceAccount['project_id'] ?? null;
        return is_string($projectId) ? $projectId : null;
    }

    private function loadServiceAccount(): ?array
    {
        $value = config('services.firebase.service_account');
        if (! $value) {
            return null;
        }
        if (is_file($value)) {
            $json = json_decode(file_get_contents($value), true);
            return is_array($json) ? $json : null;
        }
        $json = json_decode($value, true);
        return is_array($json) ? $json : null;
    }

    private function buildJwt(string $clientEmail, string $privateKey, string $tokenUri): ?string
    {
        $now = time();
        $header = ['alg' => 'RS256', 'typ' => 'JWT'];
        $payload = [
            'iss' => $clientEmail,
            'sub' => $clientEmail,
            'aud' => $tokenUri,
            'iat' => $now,
            'exp' => $now + 3600,
            'scope' => self::SCOPE,
        ];

        $segments = [
            $this->base64UrlEncode(json_encode($header)),
            $this->base64UrlEncode(json_encode($payload)),
        ];

        $signingInput = implode('.', $segments);
        $signature = '';
        $ok = openssl_sign($signingInput, $signature, $privateKey, 'sha256');
        if (! $ok) {
            return null;
        }

        $segments[] = $this->base64UrlEncode($signature);
        return implode('.', $segments);
    }

    private function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}
