<?php

namespace Database\Seeders;

use App\Models\Event;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        $admin = User::updateOrCreate(
            ['email' => 'admin@studio59.local'],
            ['name' => 'Studio 59 Admin', 'username' => 'admin', 'password' => 'password', 'role' => 'admin']
        );

        User::updateOrCreate(
            ['email' => 'staff@studio59.local'],
            ['name' => 'Studio 59 Staff', 'username' => 'staff', 'password' => 'password', 'role' => 'staff']
        );

        Event::updateOrCreate(
            ['name' => 'Demo', 'event_date' => now('Europe/Lisbon')->toDateString()],
            [
                'location' => 'Lisboa',
                'access_password' => '1234',
                'is_active_today' => true,
                'price_per_photo' => 2.50,
                'created_by' => $admin->id,
            ]
        );
    }
}
