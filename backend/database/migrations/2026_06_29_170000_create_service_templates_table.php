<?php

use App\Support\ServiceTemplateCatalog;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('service_templates', function (Blueprint $table) {
            $table->id();
            $table->string('slug', 80)->unique();
            $table->string('name', 120);
            $table->string('description', 255)->nullable();
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(100);
            $table->json('settings')->nullable();
            $table->json('fields')->nullable();
            $table->timestamps();
        });

        $now = now();
        $rows = [];
        foreach (ServiceTemplateCatalog::defaults() as $template) {
            $rows[] = [
                'slug' => $template['slug'],
                'name' => $template['name'],
                'description' => $template['description'] ?? null,
                'is_active' => (bool) ($template['is_active'] ?? true),
                'sort_order' => (int) ($template['sort_order'] ?? 100),
                'settings' => json_encode($template['settings'] ?? [], JSON_UNESCAPED_UNICODE),
                'fields' => json_encode(ServiceTemplateCatalog::normalizeFields($template['fields'] ?? []), JSON_UNESCAPED_UNICODE),
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        if ($rows !== []) {
            DB::table('service_templates')->insert($rows);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('service_templates');
    }
};
