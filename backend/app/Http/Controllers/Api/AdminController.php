<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Checkpoint;
use App\Models\PatrolLog;
use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class AdminController extends Controller
{
    public function dashboard(Request $request)
    {
        $this->ensureAdmin($request);

        $usersByRole = User::query()
            ->selectRaw('role, COUNT(*) as total')
            ->groupBy('role')
            ->pluck('total', 'role');

        $checkpointCoverage = Checkpoint::query()
            ->withCount('logs')
            ->orderBy('sort_order')
            ->get()
            ->map(fn (Checkpoint $checkpoint) => [
                'label' => $checkpoint->name,
                'value' => $checkpoint->logs_count,
            ]);

        $scanTrend = collect(range(6, 0))->map(function (int $offset) {
            $date = now()->subDays($offset);

            return [
                'label' => $date->format('d M'),
                'value' => PatrolLog::query()
                    ->whereDate('scanned_at', $date->toDateString())
                    ->count(),
            ];
        });

        return response()->json([
            'stats' => [
                'total_users' => User::query()->count(),
                'total_checkpoints' => Checkpoint::query()->count(),
                'total_logs' => PatrolLog::query()->count(),
                'today_logs' => PatrolLog::query()->whereDate('scanned_at', now()->toDateString())->count(),
            ],
            'charts' => [
                'users_by_role' => [
                    ['label' => 'Admin', 'value' => (int) ($usersByRole['admin'] ?? 0)],
                    ['label' => 'Supervisor', 'value' => (int) ($usersByRole['supervisor'] ?? 0)],
                    ['label' => 'Security', 'value' => (int) ($usersByRole['security'] ?? 0)],
                ],
                'checkpoint_coverage' => $checkpointCoverage,
                'scan_trend' => $scanTrend,
            ],
        ]);
    }

    public function report(Request $request)
    {
        $this->ensureAdmin($request);

        return response()->json($this->buildReportPayload(
            $request->string('period', 'daily')->toString(),
        ));
    }

    public function exportPdf(Request $request)
    {
        $this->ensureAdmin($request);

        $report = $this->buildReportPayload($request->string('period', 'daily')->toString());
        $html = view('reports.summary', [
            'title' => 'Admin Report',
            'roleLabel' => 'Admin',
            'report' => $report,
        ])->render();

        $options = new Options();
        $options->set('isRemoteEnabled', true);

        $pdf = new Dompdf($options);
        $pdf->loadHtml($html);
        $pdf->setPaper('A4');
        $pdf->render();

        return response($pdf->output(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="admin-report-'.$report['period'].'.pdf"',
        ]);
    }

    public function masterData(Request $request)
    {
        $this->ensureAdmin($request);

        return response()->json([
            'roles' => Role::query()
                ->with('permissions:id,name,slug')
                ->orderBy('name')
                ->get(),
            'permissions' => Permission::query()->orderBy('name')->get(),
        ]);
    }

    public function users(Request $request)
    {
        $this->ensureAdmin($request);

        return response()->json([
            'data' => User::query()
                ->with('roleRecord:id,name,slug')
                ->orderBy('name')
                ->get()
                ->map(fn (User $user) => $this->transformUser($user)),
        ]);
    }

    public function storeUser(Request $request)
    {
        $this->ensureAdmin($request);

        $payload = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'nik' => ['required', 'string', 'max:100', 'unique:users,nik'],
            'email' => ['required', 'email', 'max:191', 'unique:users,email'],
            'password' => ['required', 'string', 'min:6'],
            'role_id' => ['required', 'integer', 'exists:roles,id'],
        ]);

        $role = Role::query()->findOrFail($payload['role_id']);

        $user = User::query()->create([
            'name' => $payload['name'],
            'nik' => $payload['nik'],
            'email' => $payload['email'],
            'password' => Hash::make($payload['password']),
            'role' => $role->slug,
            'role_id' => $role->id,
        ]);

        return response()->json([
            'message' => 'User berhasil dibuat.',
            'data' => $this->transformUser($user->fresh('roleRecord')),
        ], 201);
    }

    public function updateUser(Request $request, User $user)
    {
        $this->ensureAdmin($request);

        $payload = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'nik' => ['required', 'string', 'max:100', Rule::unique('users', 'nik')->ignore($user->id)],
            'email' => ['required', 'email', 'max:191', Rule::unique('users', 'email')->ignore($user->id)],
            'password' => ['nullable', 'string', 'min:6'],
            'role_id' => ['required', 'integer', 'exists:roles,id'],
        ]);

        $role = Role::query()->findOrFail($payload['role_id']);

        $user->fill([
            'name' => $payload['name'],
            'nik' => $payload['nik'],
            'email' => $payload['email'],
            'role' => $role->slug,
            'role_id' => $role->id,
        ]);

        if (filled($payload['password'] ?? null)) {
            $user->password = Hash::make($payload['password']);
        }

        $user->save();

        return response()->json([
            'message' => 'User berhasil diperbarui.',
            'data' => $this->transformUser($user->fresh('roleRecord')),
        ]);
    }

    public function destroyUser(Request $request, User $user)
    {
        $this->ensureAdmin($request);

        abort_if($user->role === 'admin' && User::query()->where('role', 'admin')->count() <= 1, 422, 'Minimal satu admin harus tetap tersedia.');

        $user->delete();

        return response()->json([
            'message' => 'User berhasil dihapus.',
        ]);
    }

    public function checkpoints(Request $request)
    {
        $this->ensureAdmin($request);

        return response()->json([
            'data' => Checkpoint::query()
                ->withCount('logs')
                ->orderBy('sort_order')
                ->get(),
        ]);
    }

    public function storeCheckpoint(Request $request)
    {
        $this->ensureAdmin($request);

        $payload = $request->validate([
            'building_name' => ['required', 'string', 'max:100'],
            'name' => ['required', 'string', 'max:100'],
            'nfc_uid' => ['required', 'string', 'max:100', 'unique:checkpoints,nfc_uid'],
            'qr_code' => ['nullable', 'string', 'max:100', 'unique:checkpoints,qr_code'],
            'sort_order' => ['required', 'integer', 'min:1'],
        ]);

        $checkpoint = Checkpoint::query()->create($payload);

        return response()->json([
            'message' => 'Checkpoint berhasil dibuat.',
            'data' => $checkpoint,
        ], 201);
    }

    public function updateCheckpoint(Request $request, Checkpoint $checkpoint)
    {
        $this->ensureAdmin($request);

        $payload = $request->validate([
            'building_name' => ['required', 'string', 'max:100'],
            'name' => ['required', 'string', 'max:100'],
            'nfc_uid' => ['required', 'string', 'max:100', Rule::unique('checkpoints', 'nfc_uid')->ignore($checkpoint->id)],
            'qr_code' => ['nullable', 'string', 'max:100', Rule::unique('checkpoints', 'qr_code')->ignore($checkpoint->id)],
            'sort_order' => ['required', 'integer', 'min:1'],
        ]);

        $checkpoint->update($payload);

        return response()->json([
            'message' => 'Checkpoint berhasil diperbarui.',
            'data' => $checkpoint->fresh(),
        ]);
    }

    public function destroyCheckpoint(Request $request, Checkpoint $checkpoint)
    {
        $this->ensureAdmin($request);

        $checkpoint->delete();

        return response()->json([
            'message' => 'Checkpoint berhasil dihapus.',
        ]);
    }

    private function ensureAdmin(Request $request): User
    {
        $user = $request->user();

        abort_unless($user->role === 'admin', 403, 'Akses hanya untuk admin.');

        return $user;
    }

    private function transformUser(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'nik' => $user->nik,
            'email' => $user->email,
            'role' => $user->role,
            'role_id' => $user->role_id,
            'role_name' => $user->roleRecord?->name,
            'created_at' => optional($user->created_at)->toIso8601String(),
        ];
    }

    private function buildReportPayload(string $period): array
    {
        [$period, $start, $end, $label] = $this->resolvePeriod($period);

        $logs = PatrolLog::query()
            ->whereBetween('scanned_at', [$start, $end])
            ->with(['checkpoint:id,name,building_name', 'patrolSession.user:id,name,nik'])
            ->get();

        $users = User::query()->whereBetween('created_at', [$start, $end])->get();

        return [
            'period' => $period,
            'range_label' => $label,
            'summary' => [
                'total_users' => User::query()->count(),
                'new_users' => $users->count(),
                'total_scans' => $logs->count(),
                'unique_security' => $logs->pluck('patrolSession.user.id')->filter()->unique()->count(),
            ],
            'checkpoint_breakdown' => $logs
                ->groupBy('checkpoint_id')
                ->map(fn ($group) => [
                    'label' => $group->first()?->checkpoint?->name ?? 'Checkpoint',
                    'area' => $group->first()?->checkpoint?->building_name ?? '-',
                    'value' => $group->count(),
                ])
                ->sortByDesc('value')
                ->values(),
            'security_breakdown' => $logs
                ->groupBy(fn (PatrolLog $log) => $log->patrolSession?->user?->id)
                ->map(fn ($group) => [
                    'label' => $group->first()?->patrolSession?->user?->name ?? 'Security',
                    'nik' => $group->first()?->patrolSession?->user?->nik,
                    'value' => $group->count(),
                ])
                ->sortByDesc('value')
                ->values(),
            'recent_activity' => $logs->sortByDesc('scanned_at')->take(12)->values()->map(fn (PatrolLog $log) => [
                'security_name' => $log->patrolSession?->user?->name,
                'nik' => $log->patrolSession?->user?->nik,
                'checkpoint_name' => $log->checkpoint?->name,
                'building_name' => $log->checkpoint?->building_name,
                'gps_latitude' => $log->gps_latitude,
                'gps_longitude' => $log->gps_longitude,
                'gps_map_url' => $log->gps_map_url,
                'scanned_at' => optional($log->scanned_at)->toIso8601String(),
                'sync_status' => $log->sync_status,
            ]),
        ];
    }

    private function resolvePeriod(string $period): array
    {
        return match ($period) {
            'monthly' => ['monthly', now()->startOfMonth(), now()->endOfMonth(), now()->translatedFormat('F Y')],
            'weekly' => ['weekly', now()->startOfWeek(), now()->endOfWeek(), now()->startOfWeek()->format('d M').' - '.now()->endOfWeek()->format('d M Y')],
            default => ['daily', now()->startOfDay(), now()->endOfDay(), now()->translatedFormat('d F Y')],
        };
    }
}
