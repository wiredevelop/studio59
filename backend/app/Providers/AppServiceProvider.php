<?php

namespace App\Providers;

use Illuminate\Support\Facades\DB;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        date_default_timezone_set('Europe/Lisbon');

        if (config('database.default') === 'sqlite') {
            DB::statement('PRAGMA busy_timeout = 10000');
        }

        RateLimiter::for('public-api', function (Request $request) {
            return Limit::perMinute(100)->by($request->ip());
        });
    }
}
