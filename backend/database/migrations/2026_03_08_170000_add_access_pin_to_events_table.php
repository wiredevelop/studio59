<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('events', function (Blueprint $table) {
            $table->string('access_pin', 4)->nullable()->after('access_password');
            $table->index(['access_pin', 'event_date']);
        });
    }

    public function down(): void
    {
        Schema::table('events', function (Blueprint $table) {
            $table->dropIndex(['access_pin', 'event_date']);
            $table->dropColumn('access_pin');
        });
    }
};
