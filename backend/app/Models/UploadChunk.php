<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class UploadChunk extends Model
{
    use HasFactory;

    protected $fillable = [
        'event_id',
        'upload_id',
        'file_name',
        'total_chunks',
        'received_chunks',
        'is_completed',
        'photo_id',
    ];
}
