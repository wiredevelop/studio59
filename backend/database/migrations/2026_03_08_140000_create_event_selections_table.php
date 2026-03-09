<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('event_selections', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->string('device_id', 120)->nullable();
            $table->foreignId('photo_id')->nullable()->constrained()->nullOnDelete();
            $table->string('status', 30)->default('selected');
            $table->string('uuid', 50)->unique();
            $table->timestamp('selected_at')->nullable();
            $table->timestamps();

            $table->index(['event_id', 'device_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('event_selections');
    }
};
