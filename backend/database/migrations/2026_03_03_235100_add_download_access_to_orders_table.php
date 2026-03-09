<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('download_token_hash', 64)->nullable()->after('total_amount');
            $table->timestamp('download_link_sent_at')->nullable()->after('download_token_hash');
            $table->index('download_token_hash');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropIndex(['download_token_hash']);
            $table->dropColumn(['download_token_hash', 'download_link_sent_at']);
        });
    }
};
