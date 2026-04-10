<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\EventSession;
use App\Models\Order;
use App\Models\Photo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ApiFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_event_flow_and_protected_download(): void
    {
        $user = User::factory()->create();
        $event = Event::create([
            'name' => 'Casamento A',
            'event_date' => now('Europe/Lisbon')->toDateString(),
            'location' => 'Lisboa',
            'access_pin' => '1234',
            'is_active_today' => true,
            'price_per_photo' => 2.50,
            'created_by' => $user->id,
        ]);

        $photo = Photo::create([
            'event_id' => $event->id,
            'number' => '0001',
            'original_path' => 'events/'.$event->id.'/originals/0001.jpg',
            'preview_path' => 'events/'.$event->id.'/previews/0001.jpg',
            'preview_status' => 'ready',
            'mime' => 'image/jpeg',
            'size' => 1000,
            'width' => 100,
            'height' => 100,
            'status' => 'active',
        ]);

        $this->createJpeg(storage_path('app/private/'.$photo->original_path));
        $this->createJpeg(storage_path('app/private/'.$photo->preview_path));

        $today = $this->getJson('/api/public/events/today');
        $today->assertOk()->assertJsonPath('data.0.id', $event->id);

        $enter = $this->postJson('/api/public/events/'.$event->id.'/enter', ['password' => '1234']);
        $enter->assertOk();
        $token = $enter->json('event_session_token');
        $this->assertNotEmpty($token);

        $photos = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/public/events/'.$event->id.'/photos');
        $photos->assertOk()->assertJsonPath('data.0.id', $photo->id);

        $orderResp = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/public/orders', [
                'event_id' => $event->id,
                'customer_name' => 'Ana',
                'payment_method' => 'cash',
                'photo_ids' => [$photo->id],
            ]);
        $orderResp->assertCreated();
        $orderCode = $orderResp->json('order_code');

        $pendingDownload = $this->postJson('/api/public/orders/'.$orderCode.'/download-link', [
            'photo_id' => $photo->id,
        ]);
        $pendingDownload->assertStatus(422);

        $order = Order::where('order_code', $orderCode)->firstOrFail();
        $order->update(['status' => 'paid']);

        $downloadLink = $this->postJson('/api/public/orders/'.$orderCode.'/download-link', [
            'photo_id' => $photo->id,
        ]);
        $downloadLink->assertOk();

        $url = $downloadLink->json('download_url');
        $this->assertNotEmpty($url);

        $path = parse_url($url, PHP_URL_PATH);
        $query = parse_url($url, PHP_URL_QUERY);
        $signed = $this->get($path.'?'.$query);
        $signed->assertOk();
    }

    public function test_staff_login_and_mark_paid_endpoint(): void
    {
        $user = User::factory()->create([
            'email' => 'staff@example.com',
            'password' => 'secret123',
        ]);

        $event = Event::create([
            'name' => 'Evento Staff',
            'event_date' => now('Europe/Lisbon')->toDateString(),
            'location' => 'Porto',
            'access_pin' => '9999',
            'is_active_today' => true,
            'price_per_photo' => 3.00,
            'created_by' => $user->id,
        ]);

        $photo = Photo::create([
            'event_id' => $event->id,
            'number' => '0001',
            'original_path' => 'events/'.$event->id.'/originals/0001.jpg',
            'preview_path' => 'events/'.$event->id.'/previews/0001.jpg',
            'preview_status' => 'ready',
            'mime' => 'image/jpeg',
            'size' => 1000,
            'width' => 100,
            'height' => 100,
            'status' => 'active',
        ]);

        $order = Order::create([
            'event_id' => $event->id,
            'order_code' => 'S59-TEST123',
            'customer_name' => 'Cliente',
            'payment_method' => 'cash',
            'status' => 'pending',
            'total_amount' => 3.00,
        ]);
        $order->items()->create(['photo_id' => $photo->id, 'price' => 3.00]);

        $login = $this->postJson('/api/auth/login', [
            'email' => 'staff@example.com',
            'password' => 'secret123',
        ]);
        $login->assertOk();
        $token = $login->json('token');

        $markPaid = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/orders/'.$order->id.'/mark-paid');

        $markPaid->assertOk();
        $this->assertDatabaseHas('orders', ['id' => $order->id, 'status' => 'paid']);
    }

    public function test_event_session_required_for_catalog_and_order_creation(): void
    {
        $user = User::factory()->create();
        $event = Event::create([
            'name' => 'Evento Seguro',
            'event_date' => now('Europe/Lisbon')->toDateString(),
            'location' => null,
            'access_pin' => '1234',
            'is_active_today' => true,
            'price_per_photo' => 2.50,
            'created_by' => $user->id,
        ]);

        $photo = Photo::create([
            'event_id' => $event->id,
            'number' => '0001',
            'original_path' => 'events/'.$event->id.'/originals/0001.jpg',
            'preview_path' => null,
            'mime' => 'image/jpeg',
            'size' => 1000,
            'width' => 100,
            'height' => 100,
            'status' => 'active',
        ]);

        $this->getJson('/api/public/events/'.$event->id.'/photos')->assertStatus(401);

        $this->postJson('/api/public/orders', [
            'event_id' => $event->id,
            'customer_name' => 'Sem token',
            'payment_method' => 'cash',
            'photo_ids' => [$photo->id],
        ])->assertStatus(401);

        EventSession::create([
            'event_id' => $event->id,
            'token_hash' => hash('sha256', 'abc123'),
            'expires_at' => now()->addHour(),
        ]);

        $this->withHeader('Authorization', 'Bearer abc123')
            ->getJson('/api/public/events/'.$event->id.'/photos')
            ->assertOk();
    }

    private function createJpeg(string $path): void
    {
        $dir = dirname($path);
        if (! is_dir($dir)) {
            mkdir($dir, 0777, true);
        }

        $img = imagecreatetruecolor(100, 100);
        $bg = imagecolorallocate($img, 240, 240, 240);
        imagefilledrectangle($img, 0, 0, 100, 100, $bg);
        imagejpeg($img, $path, 80);
        imagedestroy($img);
    }
}
