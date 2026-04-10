<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('events', function (Blueprint $table) {
            $table->string('legacy_report_number', 50)->nullable()->after('internal_code');
            $table->string('legacy_client_number', 50)->nullable()->after('legacy_report_number');
            $table->string('service_raw', 255)->nullable()->after('event_type');

            $table->string('bride_name')->nullable()->after('service_raw');
            $table->string('groom_name')->nullable()->after('bride_name');
            $table->string('bride_email')->nullable()->after('groom_name');
            $table->string('groom_email')->nullable()->after('bride_email');
            $table->string('bride_phone', 40)->nullable()->after('groom_email');
            $table->string('groom_phone', 40)->nullable()->after('bride_phone');

            $table->date('delivery_date')->nullable()->after('event_date');
            $table->integer('guest_count')->nullable()->after('event_time');

            $table->string('city', 120)->nullable()->after('location');
            $table->string('address')->nullable()->after('city');
            $table->string('address2')->nullable()->after('address');

            $table->string('mass_time_raw', 20)->nullable()->after('address2');
            $table->string('store_time_raw', 20)->nullable()->after('mass_time_raw');
            $table->string('bride_departure_time_raw', 20)->nullable()->after('store_time_raw');
            $table->string('groom_departure_time_raw', 20)->nullable()->after('bride_departure_time_raw');

            $table->decimal('total_price', 10, 2)->nullable()->after('base_price');

            $table->index(['legacy_report_number']);
            $table->index(['legacy_client_number']);
        });
    }

    public function down(): void
    {
        Schema::table('events', function (Blueprint $table) {
            $table->dropIndex(['legacy_report_number']);
            $table->dropIndex(['legacy_client_number']);
            $table->dropColumn([
                'legacy_report_number',
                'legacy_client_number',
                'service_raw',
                'bride_name',
                'groom_name',
                'bride_email',
                'groom_email',
                'bride_phone',
                'groom_phone',
                'delivery_date',
                'guest_count',
                'city',
                'address',
                'address2',
                'mass_time_raw',
                'store_time_raw',
                'bride_departure_time_raw',
                'groom_departure_time_raw',
                'total_price',
            ]);
        });
    }
};
