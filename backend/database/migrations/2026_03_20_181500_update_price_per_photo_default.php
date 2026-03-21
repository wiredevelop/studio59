<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE events MODIFY price_per_photo DECIMAL(10,2) NOT NULL DEFAULT 5.00");
    }

    public function down(): void
    {
        DB::statement("ALTER TABLE events MODIFY price_per_photo DECIMAL(10,2) NOT NULL DEFAULT 2.50");
    }
};
