<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('photos', function (Blueprint $table) {
            $table->string('preview_status', 20)->default('pending')->after('preview_path');
            $table->text('preview_error')->nullable()->after('preview_status');
            $table->string('checksum', 64)->nullable()->after('status');
            $table->index(['event_id', 'preview_status']);
            $table->unique(['event_id', 'checksum']);
        });
    }

    public function down(): void
    {
        Schema::table('photos', function (Blueprint $table) {
            $table->dropUnique('photos_event_id_checksum_unique');
            $table->dropIndex('photos_event_id_preview_status_index');
            $table->dropColumn(['preview_status', 'preview_error', 'checksum']);
        });
    }
};
