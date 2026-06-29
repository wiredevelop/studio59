<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('events', function (Blueprint $table) {
            $table->json('legacy_payload')->nullable()->after('event_meta');
            $table->string('legacy_source_file', 120)->nullable()->after('legacy_payload');
            $table->string('legacy_source_sheet', 120)->nullable()->after('legacy_source_file');
            $table->unsignedInteger('legacy_source_row')->nullable()->after('legacy_source_sheet');

            $table->index(['legacy_source_file']);
            $table->index(['legacy_source_sheet']);
        });
    }

    public function down(): void
    {
        Schema::table('events', function (Blueprint $table) {
            $table->dropIndex(['legacy_source_file']);
            $table->dropIndex(['legacy_source_sheet']);
            $table->dropColumn([
                'legacy_payload',
                'legacy_source_file',
                'legacy_source_sheet',
                'legacy_source_row',
            ]);
        });
    }
};
