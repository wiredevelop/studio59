<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OfflineSync extends Model
{
    use HasFactory;

    protected $fillable = [
        'event_id',
        'device_id',
        'status',
        'checksum',
        'payload',
        'error',
    ];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }
}
