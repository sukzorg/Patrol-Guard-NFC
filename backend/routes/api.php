<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\CheckpointController;
use App\Http\Controllers\Api\PatrolController;
use App\Http\Controllers\Api\SupervisorController;
use Illuminate\Support\Facades\Route;

Route::get('/ping', function () {
    return response()->json([
        'status' => 'ok',
        'app' => config('app.name'),
        'time' => now()->toIso8601String(),
    ]);
});

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth.api')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/checkpoints', [CheckpointController::class, 'index']);

    Route::post('/patrol/start', [PatrolController::class, 'start']);
    Route::post('/patrol/scan', [PatrolController::class, 'scan']);
    Route::post('/patrol/sync', [PatrolController::class, 'sync']);
    Route::post('/patrol/end', [PatrolController::class, 'end']);

    Route::get('/supervisor/dashboard', [SupervisorController::class, 'dashboard']);
    Route::get('/supervisor/reports', [SupervisorController::class, 'report']);
    Route::get('/supervisor/reports/export', [SupervisorController::class, 'exportPdf']);

    Route::get('/admin/dashboard', [AdminController::class, 'dashboard']);
    Route::get('/admin/reports', [AdminController::class, 'report']);
    Route::get('/admin/reports/export', [AdminController::class, 'exportPdf']);
    Route::get('/admin/master-data', [AdminController::class, 'masterData']);
    Route::get('/admin/users', [AdminController::class, 'users']);
    Route::post('/admin/users', [AdminController::class, 'storeUser']);
    Route::put('/admin/users/{user}', [AdminController::class, 'updateUser']);
    Route::delete('/admin/users/{user}', [AdminController::class, 'destroyUser']);
    Route::get('/admin/checkpoints', [AdminController::class, 'checkpoints']);
    Route::post('/admin/checkpoints', [AdminController::class, 'storeCheckpoint']);
    Route::put('/admin/checkpoints/{checkpoint}', [AdminController::class, 'updateCheckpoint']);
    Route::delete('/admin/checkpoints/{checkpoint}', [AdminController::class, 'destroyCheckpoint']);
});
