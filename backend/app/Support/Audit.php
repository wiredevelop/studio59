<?php

namespace App\Support;

use App\Models\AuditLog;

class Audit
{
    public static function log(string $action, ?string $entityType = null, ?int $entityId = null, array $meta = []): void
    {
        AuditLog::create([
            'user_id' => auth()->id(),
            'action' => $action,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'meta' => $meta,
            'ip' => request()?->ip(),
        ]);
    }
}
