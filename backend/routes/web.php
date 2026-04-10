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
    Route::post('/events/{event}/payment-intent', [GuestController::class, 'createPaymentIntent'])->name('payment.intent');
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
        ->middleware('permission:photos.original')
        ->name('events.photos.original');
    Route::get('/events/{event}/qr', [EventController::class, 'qr'])
        ->middleware('permission:events.view')
        ->name('events.qr');
    Route::delete('/events/{event}/photos/{photo}', [EventController::class, 'destroyPhoto'])
        ->middleware('permission:photos.delete')
        ->name('events.photos.destroy');
    Route::post('/events/{event}/photos/bulk-delete', [EventController::class, 'bulkDestroyPhotos'])
        ->middleware('permission:photos.bulk_delete')
        ->name('events.photos.bulk-delete');
    Route::post('/events/{event}/photos/{photo}/retry-preview', [EventController::class, 'retryPreview'])
        ->middleware('permission:photos.update')
        ->name('events.photos.retry-preview');

    Route::get('/events', [EventController::class, 'index'])
        ->middleware('permission:events.view')
        ->name('events.index');
    Route::get('/events/create', [EventController::class, 'create'])
        ->middleware('permission:events.create')
        ->name('events.create');
    Route::post('/events', [EventController::class, 'store'])
        ->middleware('permission:events.create')
        ->name('events.store');
    Route::get('/events/{event}', [EventController::class, 'show'])
        ->middleware('permission:events.view')
        ->name('events.show');
    Route::get('/events/{event}/pdf', [EventController::class, 'pdf'])
        ->middleware('permission:events.view')
        ->name('events.pdf');
    Route::get('/events/{event}/edit', [EventController::class, 'edit'])
        ->middleware('permission:events.update')
        ->name('events.edit');
    Route::put('/events/{event}', [EventController::class, 'update'])
        ->middleware('permission:events.update')
        ->name('events.update');
    Route::delete('/events/{event}', [EventController::class, 'destroy'])
        ->middleware('permission:events.delete')
        ->name('events.destroy');
    Route::post('/events/{event}/staff', [EventController::class, 'staffAssign'])
        ->middleware('permission:events.update')
        ->name('events.staff.assign');
    Route::delete('/events/{event}/staff/{user}', [EventController::class, 'staffRemove'])
        ->middleware('permission:events.update')
        ->name('events.staff.remove');

    Route::get('/events/{event}/uploads', [UploadController::class, 'index'])
        ->middleware('permission:uploads.list')
        ->name('uploads.index');
    Route::get('/events/{event}/uploads/latest', [UploadController::class, 'latest'])
        ->middleware('permission:uploads.list')
        ->name('uploads.latest');
    Route::post('/events/{event}/uploads/chunk', [UploadController::class, 'chunk'])
        ->middleware('permission:uploads.create')
        ->name('uploads.chunk');
    Route::get('/events/{event}/uploads/status', [UploadController::class, 'status'])
        ->middleware('permission:uploads.list')
        ->name('uploads.status');

    Route::get('/orders', [OrderController::class, 'index'])
        ->middleware('permission:orders.list')
        ->name('orders.index');
    Route::post('/orders/bulk-status', [OrderController::class, 'bulkStatus'])
        ->middleware('permission:orders.bulk')
        ->name('orders.bulkStatus');
    Route::post('/orders/{order}/mark-paid', [OrderController::class, 'markPaid'])
        ->middleware('permission:orders.update')
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

    Route::middleware('permission:users.list')->group(function () {
        Route::get('/users', [UserController::class, 'index'])->name('users.index');
    });
    Route::middleware('permission:users.create')->group(function () {
        Route::get('/users/create', [UserController::class, 'create'])->name('users.create');
        Route::post('/users', [UserController::class, 'store'])->name('users.store');
    });
    Route::middleware('permission:users.update')->group(function () {
        Route::get('/users/{user}/edit', [UserController::class, 'edit'])->name('users.edit');
        Route::put('/users/{user}', [UserController::class, 'update'])->name('users.update');
    });
    Route::middleware('permission:users.delete')->group(function () {
        Route::delete('/users/{user}', [UserController::class, 'destroy'])->name('users.destroy');
    });

    Route::middleware('permission:clients.list')->group(function () {
        Route::get('/clients', [ClientController::class, 'index'])->name('clients.index');
    });
    Route::middleware('permission:clients.view')->group(function () {
        Route::get('/clients/{client}', [ClientController::class, 'show'])->name('clients.show');
    });
    Route::middleware('permission:clients.create')->group(function () {
        Route::get('/clients/create', [ClientController::class, 'create'])->name('clients.create');
        Route::post('/clients', [ClientController::class, 'store'])->name('clients.store');
    });
    Route::middleware('permission:clients.update')->group(function () {
        Route::get('/clients/{client}/edit', [ClientController::class, 'edit'])->name('clients.edit');
        Route::put('/clients/{client}', [ClientController::class, 'update'])->name('clients.update');
    });
    Route::middleware('permission:clients.delete')->group(function () {
        Route::delete('/clients/{client}', [ClientController::class, 'destroy'])->name('clients.destroy');
    });

    Route::middleware('permission:offline.export')->group(function () {
        Route::get('/offline', [WebOfflineSyncController::class, 'index'])->name('offline.index');
    });
    Route::middleware('permission:offline.import')->group(function () {
        Route::post('/offline/import', [WebOfflineSyncController::class, 'import'])->name('offline.import');
    });
});
