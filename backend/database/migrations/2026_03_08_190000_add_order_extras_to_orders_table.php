<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('product_type', 20)->nullable()->after('customer_email');
            $table->string('delivery_type', 20)->nullable()->after('product_type');
            $table->text('delivery_address')->nullable()->after('delivery_type');
            $table->boolean('wants_film')->default(false)->after('delivery_address');
            $table->decimal('film_fee', 10, 2)->default(0)->after('wants_film');
            $table->decimal('shipping_fee', 10, 2)->default(0)->after('film_fee');
            $table->decimal('extras_total', 10, 2)->default(0)->after('shipping_fee');
            $table->decimal('items_total', 10, 2)->default(0)->after('extras_total');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn([
                'product_type',
                'delivery_type',
                'delivery_address',
                'wants_film',
                'film_fee',
                'shipping_fee',
                'extras_total',
                'items_total',
            ]);
        });
    }
};
