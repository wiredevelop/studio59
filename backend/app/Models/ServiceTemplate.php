<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Model;

class ServiceTemplate extends Model
{
    protected $fillable = [
        'slug',
        'name',
        'description',
        'is_active',
        'sort_order',
        'settings',
        'fields',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'sort_order' => 'integer',
        'settings' => 'array',
        'fields' => 'array',
    ];

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    public function events(): HasMany
    {
        return $this->hasMany(Event::class, 'event_type', 'slug');
    }
}
