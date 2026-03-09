<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Model;

class EventPasswordHistory extends Model
{
    use HasFactory;

    protected $fillable = [
        'event_id',
        'password_hash',
        'changed_by',
    ];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }
}
