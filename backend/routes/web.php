<?php

use App\Http\Controllers\Web\AuthController;
use App\Http\Controllers\Web\DashboardController;
use App\Http\Controllers\Web\DownloadAccessController;
use App\Http\Controllers\Web\EventController;
use App\Http\Controllers\Web\GuestController;
use App\Http\Controllers\Web\ClientController;
use App\Http\Controllers\Web\OfflineSyncController as WebOfflineSyncController;
use App\Http\Controllers\Web\OrderController;
use App\Http\Controllers\Web\ProfileController;
use App\Http\Controllers\Web\UploadController;
use App\Http\Controllers\Web\UserController;
use App\Models\Photo;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;

Route::middleware('guest')->group(function () {
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login'])->name('login.submit');
});

Route::post('/logout', [AuthController::class, 'logout'])->middleware(['auth', 'nocache'])->name('logout');

Route::prefix('/guest')->name('guest.')->group(function () {
    Route::get('/events', [GuestController::class, 'events'])->name('events');
    Route::get('/events/{event}/enter', [GuestController::class, 'showEnter'])->name('enter.form');
    Route::post('/events/{event}/enter', [GuestController::class, 'enter'])->name('enter.submit');
    Route::post('/events/{event}/reset', [GuestController::class, 'reset'])->name('reset');
    Route::get('/events/{event}/catalog', [GuestController::class, 'catalog'])->name('catalog');
    Route::get('/events/{event}/cart', [GuestController::class, 'cart'])->name('cart');
    Route::get('/events/{event}/checkout', [GuestController::class, 'checkout'])->name('checkout');
    Route::post('/events/{event}/catalog/face-search', [GuestController::class, 'faceSearch'])->name('catalog.faceSearch');
    Route::post('/events/{event}/order', [GuestController::class, 'storeOrder'])->name('order.store');
    Route::get('/orders/{orderCode}', [GuestController::class, 'order'])->name('order.show');
    Route::get('/orders/{orderCode}/status', [GuestController::class, 'orderStatus'])->name('order.status');
});

Route::get('/downloads/{token}', [DownloadAccessController::class, 'show'])->name('downloads.show');
Route::get('/downloads/{token}/photo/{photoId}', [DownloadAccessController::class, 'download'])->name('downloads.photo');
Route::post('/downloads/{token}/bulk', [DownloadAccessController::class, 'bulkDownload'])->name('downloads.bulk');

Route::get('/preview/{photo}', function (Photo $photo) {
    abort_unless($photo->preview_path && Storage::disk('local')->exists($photo->preview_path), 404);
    $path = storage_path('app/private/'.$photo->preview_path);
    $mtime = filemtime($path);
    $etag = md5($photo->preview_path.'|'.$mtime.'|'.filesize($path));
    $response = response()->file($path);
    $response->setEtag($etag);
    $response->setLastModified(\Illuminate\Support\Carbon::createFromTimestampUTC($mtime));
    $response->setPublic();
    $response->setMaxAge(31536000);
    $response->setSharedMaxAge(31536000);
    $response->headers->addCacheControlDirective('immutable', true);
    if ($response->isNotModified(request())) {
        return $response;
    }
    return $response;
})->name('preview.image');

Route::middleware(['auth', 'nocache'])->group(function () {
    Route::get('/', [DashboardController::class, 'index'])
        ->middleware('permission:dashboard.view')
        ->name('dashboard');

    Route::get('/settings', [ProfileController::class, 'edit'])->name('settings.edit');
    Route::put('/settings', [ProfileController::class, 'update'])->name('settings.update');

    Route::get('/events/{event}/photos/{photo}/original', [EventController::class, 'original'])
        ->middleware('permission:photos.manage')
        ->name('events.photos.original');
    Route::get('/events/{event}/qr', [EventController::class, 'qr'])
        ->middleware('permission:events.read')
        ->name('events.qr');
    Route::delete('/events/{event}/photos/{photo}', [EventController::class, 'destroyPhoto'])
        ->middleware('permission:photos.manage')
        ->name('events.photos.destroy');
    Route::post('/events/{event}/photos/bulk-delete', [EventController::class, 'bulkDestroyPhotos'])
        ->middleware('permission:photos.manage')
        ->name('events.photos.bulk-delete');
    Route::post('/events/{event}/photos/{photo}/retry-preview', [EventController::class, 'retryPreview'])
        ->middleware('permission:photos.manage')
        ->name('events.photos.retry-preview');

    Route::get('/events', [EventController::class, 'index'])
        ->middleware('permission:events.read')
        ->name('events.index');
    Route::get('/events/create', [EventController::class, 'create'])
        ->middleware('permission:events.write')
        ->name('events.create');
    Route::post('/events', [EventController::class, 'store'])
        ->middleware('permission:events.write')
        ->name('events.store');
    Route::get('/events/{event}', [EventController::class, 'show'])
        ->middleware('permission:events.read')
        ->name('events.show');
    Route::get('/events/{event}/pdf', [EventController::class, 'pdf'])
        ->middleware('permission:events.read')
        ->name('events.pdf');
    Route::get('/events/{event}/edit', [EventController::class, 'edit'])
        ->middleware('permission:events.write')
        ->name('events.edit');
    Route::put('/events/{event}', [EventController::class, 'update'])
        ->middleware('permission:events.write')
        ->name('events.update');
    Route::delete('/events/{event}', [EventController::class, 'destroy'])
        ->middleware('permission:events.write')
        ->name('events.destroy');
    Route::post('/events/{event}/staff', [EventController::class, 'staffAssign'])
        ->middleware('permission:events.write')
        ->name('events.staff.assign');
    Route::delete('/events/{event}/staff/{user}', [EventController::class, 'staffRemove'])
        ->middleware('permission:events.write')
        ->name('events.staff.remove');

    Route::get('/events/{event}/uploads', [UploadController::class, 'index'])
        ->middleware('permission:uploads.manage')
        ->name('uploads.index');
    Route::post('/events/{event}/uploads/chunk', [UploadController::class, 'chunk'])
        ->middleware('permission:uploads.manage')
        ->name('uploads.chunk');
    Route::get('/events/{event}/uploads/status', [UploadController::class, 'status'])
        ->middleware('permission:uploads.manage')
        ->name('uploads.status');

    Route::get('/orders', [OrderController::class, 'index'])
        ->middleware('permission:orders.read')
        ->name('orders.index');
    Route::post('/orders/bulk-status', [OrderController::class, 'bulkStatus'])
        ->middleware('permission:orders.write')
        ->name('orders.bulkStatus');
    Route::post('/orders/{order}/mark-paid', [OrderController::class, 'markPaid'])
        ->middleware('permission:orders.write')
        ->name('orders.markPaid');
    Route::post('/orders/{order}/send-download-link', [OrderController::class, 'sendDownloadLink'])
        ->middleware('permission:orders.download')
        ->name('orders.sendDownloadLink');
    Route::get('/orders/{order}/download-all', [OrderController::class, 'downloadAll'])
        ->middleware('permission:orders.download')
        ->name('orders.downloadAll');
    Route::get('/events/{event}/orders/export', [OrderController::class, 'exportCsv'])
        ->middleware('permission:orders.export')
        ->name('orders.export');

    Route::middleware('permission:users.manage')->group(function () {
        Route::resource('users', UserController::class)->except(['show']);
    });

    Route::middleware('permission:clients.read')->group(function () {
        Route::get('/clients', [ClientController::class, 'index'])->name('clients.index');
        Route::get('/clients/{client}', [ClientController::class, 'show'])->name('clients.show');
    });
    Route::middleware('permission:clients.write')->group(function () {
        Route::get('/clients/create', [ClientController::class, 'create'])->name('clients.create');
        Route::post('/clients', [ClientController::class, 'store'])->name('clients.store');
        Route::get('/clients/{client}/edit', [ClientController::class, 'edit'])->name('clients.edit');
        Route::put('/clients/{client}', [ClientController::class, 'update'])->name('clients.update');
        Route::delete('/clients/{client}', [ClientController::class, 'destroy'])->name('clients.destroy');
    });

    Route::middleware('permission:events.read')->group(function () {
        Route::get('/offline', [WebOfflineSyncController::class, 'index'])->name('offline.index');
    });
    Route::middleware('permission:events.write')->group(function () {
        Route::post('/offline/import', [WebOfflineSyncController::class, 'import'])->name('offline.import');
    });
});
