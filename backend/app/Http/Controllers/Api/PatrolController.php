<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PatrolLog;
use App\Models\PatrolSession;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

class PatrolController extends Controller
{
    public function start(Request $request)
    {
        $user = $this->guardUser($request);

        $payload = $request->validate([
            'shift' => ['required', 'string', 'max:50'],
        ]);

        $existingSession = PatrolSession::query()
            ->where('user_id', $user->id)
            ->where('status', 'active')
            ->latest('started_at')
            ->first();

        if ($existingSession) {
            return response()->json([
                'message' => 'Sesi patroli aktif ditemukan.',
                'data' => $this->transformSession($existingSession),
            ]);
        }

        $session = PatrolSession::query()->create([
            'uuid' => (string) Str::uuid(),
            'user_id' => $user->id,
            'shift' => $payload['shift'],
            'started_at' => now(),
            'status' => 'active',
        ]);

        return response()->json([
            'message' => 'Sesi patroli dimulai.',
            'data' => $this->transformSession($session),
        ], 201);
    }

    public function scan(Request $request)
    {
        $user = $this->guardUser($request);

        $payload = $request->validate([
            'patrol_session_id' => ['required', 'integer', 'exists:patrol_sessions,id'],
            'checkpoint_id' => ['required', 'integer', 'exists:checkpoints,id'],
            'local_uuid' => ['required', 'string', 'max:100'],
            'scanned_at' => ['required', 'date'],
            'gps_latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'gps_longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'source' => ['nullable', 'string', 'max:50'],
        ]);

        $session = PatrolSession::query()
            ->where('id', $payload['patrol_session_id'])
            ->where('user_id', $user->id)
            ->firstOrFail();

        $log = PatrolLog::query()->updateOrCreate(
            ['local_uuid' => $payload['local_uuid']],
            [
                'patrol_session_id' => $session->id,
                'checkpoint_id' => $payload['checkpoint_id'],
                'scanned_at' => Carbon::parse($payload['scanned_at']),
                'gps_latitude' => $payload['gps_latitude'] ?? null,
                'gps_longitude' => $payload['gps_longitude'] ?? null,
                'gps_map_url' => $this->buildGpsMapUrl(
                    $payload['gps_latitude'] ?? null,
                    $payload['gps_longitude'] ?? null,
                ),
                'sync_status' => 'synced',
                'source' => $payload['source'] ?? 'online-scan',
                'synced_at' => now(),
            ],
        );

        return response()->json([
            'message' => 'Scan checkpoint berhasil dicatat.',
            'data' => $this->transformLog($log->fresh(['checkpoint'])),
        ], 201);
    }

    public function sync(Request $request)
    {
        $user = $this->guardUser($request);

        $payload = $request->validate([
            'patrol_session_id' => ['required', 'integer', 'exists:patrol_sessions,id'],
            'logs' => ['required', 'array', 'min:1'],
            'logs.*.checkpoint_id' => ['required', 'integer', 'exists:checkpoints,id'],
            'logs.*.local_uuid' => ['required', 'string', 'max:100'],
            'logs.*.scanned_at' => ['required', 'date'],
            'logs.*.gps_latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'logs.*.gps_longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'logs.*.source' => ['nullable', 'string', 'max:50'],
        ]);

        $session = PatrolSession::query()
            ->where('id', $payload['patrol_session_id'])
            ->where('user_id', $user->id)
            ->firstOrFail();

        $synced = collect($payload['logs'])->map(function (array $logPayload) use ($session) {
            $log = PatrolLog::query()->updateOrCreate(
                ['local_uuid' => $logPayload['local_uuid']],
                [
                    'patrol_session_id' => $session->id,
                    'checkpoint_id' => $logPayload['checkpoint_id'],
                    'scanned_at' => Carbon::parse($logPayload['scanned_at']),
                    'gps_latitude' => $logPayload['gps_latitude'] ?? null,
                    'gps_longitude' => $logPayload['gps_longitude'] ?? null,
                    'gps_map_url' => $this->buildGpsMapUrl(
                        $logPayload['gps_latitude'] ?? null,
                        $logPayload['gps_longitude'] ?? null,
                    ),
                    'sync_status' => 'synced',
                    'source' => $logPayload['source'] ?? 'offline-sync',
                    'synced_at' => now(),
                ],
            );

            return $this->transformLog($log->fresh(['checkpoint']));
        });

        return response()->json([
            'message' => 'Seluruh log pending berhasil disinkronkan.',
            'data' => $synced,
        ]);
    }

    public function end(Request $request)
    {
        $user = $this->guardUser($request);

        $payload = $request->validate([
            'patrol_session_id' => ['required', 'integer', 'exists:patrol_sessions,id'],
        ]);

        $session = PatrolSession::query()
            ->where('id', $payload['patrol_session_id'])
            ->where('user_id', $user->id)
            ->firstOrFail();

        $session->update([
            'ended_at' => now(),
            'status' => 'completed',
        ]);

        return response()->json([
            'message' => 'Sesi patroli ditutup.',
            'data' => $this->transformSession($session->fresh()),
        ]);
    }

    private function guardUser(Request $request)
    {
        $user = $request->user();

        abort_unless(in_array($user->role, ['security', 'guard', 'admin'], true), 403, 'Akun ini bukan petugas patroli.');

        return $user;
    }

    private function transformSession(PatrolSession $session): array
    {
        return [
            'id' => $session->id,
            'uuid' => $session->uuid,
            'shift' => $session->shift,
            'status' => $session->status,
            'started_at' => optional($session->started_at)->toIso8601String(),
            'ended_at' => optional($session->ended_at)->toIso8601String(),
        ];
    }

    private function transformLog(PatrolLog $log): array
    {
        return [
            'id' => $log->id,
            'local_uuid' => $log->local_uuid,
            'checkpoint_id' => $log->checkpoint_id,
            'checkpoint_name' => $log->checkpoint?->name,
            'scanned_at' => optional($log->scanned_at)->toIso8601String(),
            'gps_latitude' => $log->gps_latitude,
            'gps_longitude' => $log->gps_longitude,
            'gps_map_url' => $log->gps_map_url,
            'gps_open_url' => $this->buildGpsOpenUrl($log->gps_latitude, $log->gps_longitude),
            'sync_status' => $log->sync_status,
            'synced_at' => optional($log->synced_at)->toIso8601String(),
        ];
    }

    private function buildGpsMapUrl($latitude, $longitude): ?string
    {
        if (!filled($latitude) || !filled($longitude)) {
            return null;
        }

        return 'https://staticmap.openstreetmap.de/staticmap.php?center='
            .$latitude.','.$longitude
            .'&zoom=18&size=640x320&markers='
            .$latitude.','.$longitude.',red-pushpin';
    }

    private function buildGpsOpenUrl($latitude, $longitude): ?string
    {
        if (!filled($latitude) || !filled($longitude)) {
            return null;
        }

        return 'https://www.openstreetmap.org/?mlat='
            .$latitude
            .'&mlon='
            .$longitude
            .'#map=18/'
            .$latitude
            .'/'
            .$longitude;
    }
}
