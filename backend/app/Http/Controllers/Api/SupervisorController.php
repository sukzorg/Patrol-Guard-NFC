<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Checkpoint;
use App\Models\PatrolLog;
use App\Models\PatrolSession;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class SupervisorController extends Controller
{
    public function dashboard(Request $request)
    {
        $this->ensureSupervisor($request);

        return response()->json($this->buildDashboardPayload());
    }

    public function report(Request $request)
    {
        $this->ensureSupervisor($request);

        return response()->json($this->buildReportPayload(
            $request->string('period', 'daily')->toString(),
        ));
    }

    public function exportPdf(Request $request)
    {
        $this->ensureSupervisor($request);

        $report = $this->buildReportPayload($request->string('period', 'daily')->toString());
        $html = view('reports.summary', [
            'title' => 'Supervisor Report',
            'roleLabel' => 'Supervisor',
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
            'Content-Disposition' => 'attachment; filename="supervisor-report-'.$report['period'].'.pdf"',
        ]);
    }

    private function ensureSupervisor(Request $request)
    {
        $user = $request->user();

        abort_unless(in_array($user->role, ['supervisor', 'admin'], true), 403, 'Akun ini tidak memiliki akses supervisor.');

        return $user;
    }

    private function buildDashboardPayload(): array
    {
        $totalCheckpoints = max(1, Checkpoint::query()->count());
        $activeSessions = PatrolSession::query()
            ->with(['user:id,name,nik', 'logs'])
            ->where('status', 'active')
            ->latest('started_at')
            ->get();
        $latestLog = PatrolLog::query()
            ->latest('synced_at')
            ->latest('scanned_at')
            ->first();
        $coveredCheckpoints = PatrolLog::query()
            ->distinct()
            ->count('checkpoint_id');

        $sessions = $activeSessions->map(function (PatrolSession $session) use ($totalCheckpoints) {
            $completed = $session->logs->pluck('checkpoint_id')->unique()->count();

            return [
                'id' => $session->id,
                'security_name' => $session->user?->name,
                'guard_name' => $session->user?->name,
                'nik' => $session->user?->nik,
                'shift' => $session->shift,
                'status' => $session->status,
                'started_at' => optional($session->started_at)->toIso8601String(),
                'completed_checkpoints' => $completed,
                'total_checkpoints' => $totalCheckpoints,
            ];
        });

        return [
            'generated_at' => now()->toIso8601String(),
            'stats' => [
                'active_security' => $activeSessions->count(),
                'active_guards' => $activeSessions->count(),
                'pending_sync' => PatrolLog::query()->where('sync_status', '!=', 'synced')->count(),
                'coverage_percentage' => (int) round(($coveredCheckpoints / $totalCheckpoints) * 100),
                'last_upload' => optional($latestLog?->synced_at ?? $latestLog?->scanned_at)->toIso8601String(),
            ],
            'sessions' => $sessions,
            'recent_logs' => PatrolLog::query()
                ->with(['checkpoint:id,name,building_name', 'patrolSession.user:id,name,nik'])
                ->latest('scanned_at')
                ->take(8)
                ->get()
                ->map(fn (PatrolLog $log) => [
                    'id' => $log->id,
                    'security_name' => $log->patrolSession?->user?->name,
                    'guard_name' => $log->patrolSession?->user?->name,
                    'nik' => $log->patrolSession?->user?->nik,
                    'checkpoint_name' => $log->checkpoint?->name,
                    'building_name' => $log->checkpoint?->building_name,
                    'gps_latitude' => $log->gps_latitude,
                    'gps_longitude' => $log->gps_longitude,
                    'gps_map_url' => $log->gps_map_url,
                    'scanned_at' => optional($log->scanned_at)->toIso8601String(),
                    'sync_status' => $log->sync_status,
                ]),
            'checkpoints' => Checkpoint::query()
                ->withCount('logs')
                ->withMax('logs', 'scanned_at')
                ->orderBy('sort_order')
                ->get()
                ->map(fn (Checkpoint $checkpoint) => [
                    'id' => $checkpoint->id,
                    'name' => $checkpoint->name,
                'building_name' => $checkpoint->building_name,
                'qr_code' => $checkpoint->qr_code,
                'scan_count' => $checkpoint->logs_count,
                'last_scanned_at' => filled($checkpoint->logs_max_scanned_at)
                    ? Carbon::parse($checkpoint->logs_max_scanned_at)->toIso8601String()
                        : null,
                ]),
        ];
    }

    private function buildReportPayload(string $period): array
    {
        [$period, $start, $end, $label] = $this->resolvePeriod($period);

        $logsQuery = PatrolLog::query()
            ->whereBetween('scanned_at', [$start, $end])
            ->with(['checkpoint:id,name,building_name', 'patrolSession.user:id,name,nik']);

        $logs = $logsQuery->get();
        $sessions = PatrolSession::query()
            ->with('user:id,name,nik')
            ->whereBetween('started_at', [$start, $end])
            ->get();

        $checkpointSummary = $logs
            ->groupBy('checkpoint_id')
            ->map(fn ($group) => [
                'label' => $group->first()?->checkpoint?->name ?? 'Checkpoint',
                'area' => $group->first()?->checkpoint?->building_name ?? '-',
                'value' => $group->count(),
            ])
            ->sortByDesc('value')
            ->values();

        $securitySummary = $logs
            ->groupBy(fn (PatrolLog $log) => $log->patrolSession?->user?->id)
            ->map(fn ($group) => [
                'label' => $group->first()?->patrolSession?->user?->name ?? 'Security',
                'nik' => $group->first()?->patrolSession?->user?->nik,
                'value' => $group->count(),
            ])
            ->sortByDesc('value')
            ->values();

        return [
            'period' => $period,
            'range_label' => $label,
            'summary' => [
                'total_scans' => $logs->count(),
                'synced_logs' => $logs->where('sync_status', 'synced')->count(),
                'active_sessions' => $sessions->where('status', 'active')->count(),
                'unique_security' => $logs->pluck('patrolSession.user.id')->filter()->unique()->count(),
            ],
            'checkpoint_breakdown' => $checkpointSummary,
            'security_breakdown' => $securitySummary,
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
