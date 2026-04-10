<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('upload_chunks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->string('upload_id', 100);
            $table->string('file_name');
            $table->unsignedInteger('total_chunks');
            $table->unsignedInteger('received_chunks')->default(0);
            $table->boolean('is_completed')->default(false);
            $table->timestamps();

            $table->unique(['event_id', 'upload_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('upload_chunks');
    }
};
