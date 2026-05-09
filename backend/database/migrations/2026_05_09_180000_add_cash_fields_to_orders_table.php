<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->decimal('cash_received_amount', 10, 2)->nullable()->after('payment_method');
            $table->decimal('cash_change_amount', 10, 2)->nullable()->after('cash_received_amount');
            $table->decimal('cash_due_amount', 10, 2)->nullable()->after('cash_change_amount');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn([
                'cash_received_amount',
                'cash_change_amount',
                'cash_due_amount',
            ]);
        });
    }
};
