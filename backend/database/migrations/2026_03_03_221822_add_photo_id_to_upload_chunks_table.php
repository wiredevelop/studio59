<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('upload_chunks', function (Blueprint $table) {
            $table->foreignId('photo_id')->nullable()->after('is_completed')->constrained('photos')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('upload_chunks', function (Blueprint $table) {
            $table->dropConstrainedForeignId('photo_id');
        });
    }
};
