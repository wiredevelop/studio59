<?php

use App\Http\Controllers\Api\PublicEventController;
use App\Http\Controllers\Api\PublicOrderController;
use App\Http\Controllers\Api\StaffAuthController;
use App\Http\Controllers\Api\StaffClientController;
use App\Http\Controllers\Api\StaffEventController;
use App\Http\Controllers\Api\StaffOrderController;
use App\Http\Controllers\Api\OfflineSyncController;
use Illuminate\Support\Facades\Route;

Route::prefix('public')->middleware('throttle:public-api')->group(function () {
    Route::get('/events/today', [PublicEventController::class, 'today']);
    Route::post('/events/pin', [PublicEventController::class, 'enterByPin']);
    Route::post('/events/{id}/enter', [PublicEventController::class, 'enter']);
    Route::get('/events/qr/{token}', [PublicEventController::class, 'enterByQr']);
    Route::get('/orders/{order_code}', [PublicOrderController::class, 'show']);
    Route::post('/orders/{order_code}/download-link', [PublicOrderController::class, 'downloadLink']);

    Route::middleware('event.session')->group(function () {
        Route::get('/events/{id}/photos', [PublicEventController::class, 'photos']);
        Route::post('/events/{id}/face-search', [PublicEventController::class, 'faceSearch']);
        Route::post('/orders', [PublicOrderController::class, 'store']);
    });

    Route::get('/download/{order}/{photo}', [PublicOrderController::class, 'streamOriginal'])
        ->middleware('signed')
        ->name('public.download.original');
});

Route::post('/auth/login', [StaffAuthController::class, 'login']);

Route::middleware(['auth:sanctum', 'role:admin,staff,photographer'])->group(function () {
    Route::post('/auth/logout', [StaffAuthController::class, 'logout']);
    Route::get('/auth/me', [StaffAuthController::class, 'me']);
    Route::put('/auth/me', [StaffAuthController::class, 'updateProfile']);

    Route::middleware('permission:events.read')->group(function () {
        Route::get('/events', [StaffEventController::class, 'index'])->name('api.events.index');
        Route::get('/events/lookup', [StaffEventController::class, 'lookup']);
        Route::get('/events/{event}', [StaffEventController::class, 'show'])->name('api.events.show');
        Route::get('/events/{event}/pdf', [StaffEventController::class, 'pdf'])->name('api.events.pdf');
        Route::get('/events/{event}/staff', [StaffEventController::class, 'staffIndex']);
    });
    Route::middleware('permission:events.write')->group(function () {
        Route::post('/events', [StaffEventController::class, 'store'])->name('api.events.store');
        Route::put('/events/{event}', [StaffEventController::class, 'update'])->name('api.events.update');
        Route::delete('/events/{event}', [StaffEventController::class, 'destroy'])->name('api.events.destroy');
        Route::get('/staff/users', [StaffEventController::class, 'staffUsersAll']);
        Route::get('/events/{event}/staff/users', [StaffEventController::class, 'staffUsers']);
        Route::post('/events/{event}/staff', [StaffEventController::class, 'staffAssign']);
        Route::delete('/events/{event}/staff/{user}', [StaffEventController::class, 'staffRemove']);
    });

    Route::middleware('permission:photos.manage')->group(function () {
        Route::get('/events/{event}/photos', [StaffEventController::class, 'photos']);
        Route::delete('/events/{event}/photos/{photo}', [StaffEventController::class, 'destroyPhoto']);
        Route::post('/events/{event}/photos/bulk-delete', [StaffEventController::class, 'bulkDestroyPhotos']);
        Route::post('/events/{event}/photos/{photo}/retry-preview', [StaffEventController::class, 'retryPreview']);
    });

    Route::middleware('permission:uploads.manage')->group(function () {
        Route::get('/events/{event}/uploads', [StaffEventController::class, 'uploadsIndex']);
        Route::post('/events/{event}/uploads/chunk', [StaffEventController::class, 'uploadChunk']);
        Route::get('/events/{event}/uploads/status', [StaffEventController::class, 'uploadStatus']);
    });

    Route::middleware('permission:orders.read')->group(function () {
        Route::get('/orders', [StaffOrderController::class, 'list']);
        Route::get('/orders/{order}', [StaffOrderController::class, 'show']);
        Route::get('/events/{id}/orders', [StaffOrderController::class, 'index']);
    });
    Route::middleware('permission:orders.write')->group(function () {
        Route::post('/orders/bulk-status', [StaffOrderController::class, 'bulkStatus']);
        Route::put('/orders/{order}', [StaffOrderController::class, 'update']);
        Route::post('/orders/{order}/mark-paid', [StaffOrderController::class, 'markPaid']);
    });
    Route::middleware('permission:orders.download')->group(function () {
        Route::post('/orders/{order}/send-download-link', [StaffOrderController::class, 'sendDownloadLink']);
        Route::get('/orders/{order}/download-all', [StaffOrderController::class, 'downloadAll']);
    });
    Route::middleware('permission:orders.export')->group(function () {
        Route::get('/events/{event}/orders/export', [StaffOrderController::class, 'exportCsv']);
    });

    Route::middleware('permission:events.read')->group(function () {
        Route::get('/offline/events/{event}/export', [OfflineSyncController::class, 'export']);
    });
    Route::middleware('permission:events.write')->group(function () {
        Route::post('/offline/events/{event}/import', [OfflineSyncController::class, 'import']);
    });

    Route::middleware('permission:users.manage')->group(function () {
        Route::get('/users', [\App\Http\Controllers\Api\StaffUserController::class, 'index']);
        Route::post('/users', [\App\Http\Controllers\Api\StaffUserController::class, 'store']);
        Route::get('/users/{user}', [\App\Http\Controllers\Api\StaffUserController::class, 'show']);
        Route::put('/users/{user}', [\App\Http\Controllers\Api\StaffUserController::class, 'update']);
        Route::delete('/users/{user}', [\App\Http\Controllers\Api\StaffUserController::class, 'destroy']);
    });

    Route::middleware('permission:clients.read')->group(function () {
        Route::get('/clients', [StaffClientController::class, 'index']);
        Route::get('/clients/{client}', [StaffClientController::class, 'show']);
    });
    Route::middleware('permission:clients.write')->group(function () {
        Route::post('/clients', [StaffClientController::class, 'store']);
        Route::put('/clients/{client}', [StaffClientController::class, 'update']);
        Route::delete('/clients/{client}', [StaffClientController::class, 'destroy']);
    });
});
