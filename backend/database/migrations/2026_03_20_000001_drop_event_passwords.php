<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('events', 'access_password')) {
            Schema::table('events', function (Blueprint $table) {
                $table->dropColumn('access_password');
            });
        }

        if (Schema::hasTable('event_password_histories')) {
            Schema::drop('event_password_histories');
        }
    }

    public function down(): void
    {
        if (! Schema::hasColumn('events', 'access_password')) {
            Schema::table('events', function (Blueprint $table) {
                $table->string('access_password')->nullable()->after('location');
            });
        }

        if (! Schema::hasTable('event_password_histories')) {
            Schema::create('event_password_histories', function (Blueprint $table) {
                $table->id();
                $table->foreignId('event_id')->constrained()->cascadeOnDelete();
                $table->string('password_hash');
                $table->foreignId('changed_by')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamps();
            });
        }
    }
};
