<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_items', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('order_id');
            $table->unsignedBigInteger('photo_id');
            $table->decimal('price', 10, 2);
            $table->timestamps();

            $table->index('order_id');
            $table->index('photo_id');
            $table->unique(['order_id', 'photo_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_items');
    }
};
