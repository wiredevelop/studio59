<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Model;

class Order extends Model
{
    use HasFactory;

    protected $fillable = [
        'event_id',
        'order_code',
        'customer_name',
        'customer_phone',
        'customer_email',
        'product_type',
        'delivery_type',
        'delivery_address',
        'wants_film',
        'film_fee',
        'shipping_fee',
        'extras_total',
        'items_total',
        'payment_method',
        'stripe_session_id',
        'stripe_payment_intent_id',
        'status',
        'total_amount',
        'download_token_hash',
        'download_token',
        'download_link_sent_at',
    ];

    protected $casts = [
        'total_amount' => 'decimal:2',
        'items_total' => 'decimal:2',
        'extras_total' => 'decimal:2',
        'film_fee' => 'decimal:2',
        'shipping_fee' => 'decimal:2',
        'wants_film' => 'boolean',
        'download_link_sent_at' => 'datetime',
    ];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }
}
