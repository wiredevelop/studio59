<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Model;
use App\Models\User;

class Event extends Model
{
    use HasFactory;

    protected $fillable = [
        'client_id',
        'name',
        'internal_code',
        'event_type',
        'event_date',
        'event_time',
        'location',
        'notes',
        'status',
        'access_mode',
        'qr_token',
        'qr_enabled',
        'is_locked',
        'storage_path',
        'event_meta',
        'access_password',
        'access_pin',
        'is_active_today',
        'created_by',
        'price_per_photo',
    ];

    protected $casts = [
        'event_date' => 'date',
        'event_time' => 'string',
        'is_active_today' => 'boolean',
        'qr_enabled' => 'boolean',
        'is_locked' => 'boolean',
        'price_per_photo' => 'decimal:2',
        'event_meta' => 'array',
    ];

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function photos(): HasMany
    {
        return $this->hasMany(Photo::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function staff(): HasMany
    {
        return $this->hasMany(EventStaff::class);
    }

    public function invitations(): HasMany
    {
        return $this->hasMany(EventInvitation::class);
    }

    public function passwordHistories(): HasMany
    {
        return $this->hasMany(EventPasswordHistory::class);
    }

    public function scopeVisibleTo($query, User $user)
    {
        if ($user->role !== 'photographer') {
            return $query;
        }

        return $query->whereHas('staff', function ($q) use ($user) {
            $q->where('user_id', $user->id);
        });
    }
}
