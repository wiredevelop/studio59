<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('events', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->date('event_date');
            $table->string('location')->nullable();
            $table->string('access_password');
            $table->boolean('is_active_today')->default(false);
            $table->decimal('price_per_photo', 10, 2)->default(2.50);
            $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
            $table->timestamps();

            $table->index(['event_date', 'is_active_today']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('events');
    }
};
