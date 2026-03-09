<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('offline_syncs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->string('device_id', 120)->nullable();
            $table->string('status', 30)->default('pending');
            $table->string('checksum', 64)->nullable();
            $table->longText('payload')->nullable();
            $table->text('error')->nullable();
            $table->timestamps();

            $table->index(['event_id', 'status']);
            $table->index(['checksum']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('offline_syncs');
    }
};
