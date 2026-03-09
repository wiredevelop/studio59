<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('events', function (Blueprint $table) {
            $table->foreignId('client_id')->nullable()->after('id')->constrained('clients')->nullOnDelete();
            $table->string('internal_code', 50)->nullable()->after('name');
            $table->string('event_type', 120)->nullable()->after('internal_code');
            $table->time('event_time')->nullable()->after('event_date');
            $table->text('notes')->nullable()->after('location');
            $table->string('status', 30)->default('draft')->after('notes');
            $table->string('access_mode', 30)->default('qr')->after('status');
            $table->string('qr_token', 80)->nullable()->after('access_mode');
            $table->boolean('qr_enabled')->default(true)->after('qr_token');
            $table->boolean('is_locked')->default(false)->after('qr_enabled');
            $table->string('storage_path')->nullable()->after('is_locked');
            $table->json('event_meta')->nullable()->after('storage_path');

            $table->index(['status', 'event_date']);
            $table->unique(['internal_code'], 'events_internal_code_unique');
        });
    }

    public function down(): void
    {
        Schema::table('events', function (Blueprint $table) {
            $table->dropUnique('events_internal_code_unique');
            $table->dropIndex(['status', 'event_date']);
            $table->dropForeign(['client_id']);
            $table->dropColumn([
                'client_id',
                'internal_code',
                'event_type',
                'event_time',
                'notes',
                'status',
                'access_mode',
                'qr_token',
                'qr_enabled',
                'is_locked',
                'storage_path',
                'event_meta',
            ]);
        });
    }
};
