import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'services.dart';

class SupervisorScreen extends StatefulWidget {
  const SupervisorScreen({
    super.key,
    required this.authState,
    required this.onLogout,
  });

  final MobileAuthState authState;
  final Future<void> Function() onLogout;

  @override
  State<SupervisorScreen> createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends State<SupervisorScreen> {
  final apiClient = const PatrolApiClient();
  Map<String, dynamic>? dashboard;
  Map<String, dynamic>? report;
  bool isLoading = true;
  bool isExporting = false;
  String selectedPeriod = 'daily';
  String? errorMessage;

  String? _buildMapOpenUrl(dynamic latitude, dynamic longitude) {
    if (latitude == null || longitude == null) {
      return null;
    }

    return 'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=18/$latitude/$longitude';
  }

  Future<void> _openMap(dynamic latitude, dynamic longitude, [String? providedUrl]) async {
    final target = providedUrl ?? _buildMapOpenUrl(latitude, longitude);
    if (target == null) {
      return;
    }

    final launched = await launchUrl(
      Uri.parse(target),
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peta tidak bisa dibuka dari device ini.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final dashboardPayload =
          await apiClient.fetchSupervisorDashboard(widget.authState.token);
      final reportPayload = await apiClient.fetchSupervisorReport(
        widget.authState.token,
        selectedPeriod,
      );

      setState(() {
        dashboard = dashboardPayload;
        report = reportPayload;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    setState(() {
      isExporting = true;
      errorMessage = null;
    });

    try {
      final path = await apiClient.exportReportPdf(
        token: widget.authState.token,
        scope: 'supervisor',
        period: selectedPeriod,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF berhasil dibuat di $path')),
        );
      }
    } catch (error) {
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  Future<void> _showPreviewDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Report Supervisor'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Periode: ${report?['range_label'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('Total scan: ${report?['summary']?['total_scans'] ?? 0}'),
              Text('Security aktif: ${report?['summary']?['unique_security'] ?? 0}'),
              Text('Log tersinkron: ${report?['summary']?['synced_logs'] ?? 0}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exportPdf();
            },
            child: const Text('Export PDF'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = dashboard?['stats'] as Map<String, dynamic>? ?? {};
    final sessions = dashboard?['sessions'] as List<dynamic>? ?? [];
    final logs = dashboard?['recent_logs'] as List<dynamic>? ?? [];
    final checkpoints = dashboard?['checkpoints'] as List<dynamic>? ?? [];
    final summary = report?['summary'] as Map<String, dynamic>? ?? {};
    final securityBreakdown = report?['security_breakdown'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Mobile'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Active Security',
                    value: '${stats['active_security'] ?? stats['active_guards'] ?? 0}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    title: 'Pending Sync',
                    value: '${stats['pending_sync'] ?? 0}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    title: 'Coverage',
                    value: '${stats['coverage_percentage'] ?? 0}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rekap & Export PDF',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPeriod,
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Harian')),
                        DropdownMenuItem(value: 'weekly', child: Text('Mingguan')),
                        DropdownMenuItem(value: 'monthly', child: Text('Bulanan')),
                      ],
                      onChanged: (value) async {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          selectedPeriod = value;
                        });
                        await _load();
                      },
                      decoration: const InputDecoration(labelText: 'Periode laporan'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _showPreviewDialog,
                          icon: const Icon(Icons.preview_outlined),
                          label: const Text('Preview PDF'),
                        ),
                        OutlinedButton.icon(
                          onPressed: isExporting ? null : _exportPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(isExporting ? 'Memproses...' : 'Export PDF'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(report?['range_label']?.toString() ?? '-'),
                    const SizedBox(height: 8),
                    Text(
                      'Total scan ${summary['total_scans'] ?? 0} • Security aktif ${summary['unique_security'] ?? 0}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(errorMessage!),
                ),
              )
            else ...[
              _SectionTitle('Top Security'),
              const SizedBox(height: 10),
              if (securityBreakdown.isEmpty)
                const _EmptyCard('Belum ada rekap security.')
              else
                ...securityBreakdown.take(5).map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        title: Text('${row['label'] ?? '-'}'),
                        subtitle: Text('NIK: ${row['nik'] ?? '-'}'),
                        trailing: Chip(label: Text('${row['value'] ?? 0} scan')),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _SectionTitle('Active Sessions'),
              const SizedBox(height: 10),
              if (sessions.isEmpty)
                const _EmptyCard('Belum ada sesi patroli aktif.')
              else
                ...sessions.map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        title: Text('${session['security_name'] ?? session['guard_name'] ?? '-'}'),
                        subtitle: Text(
                          'NIK ${session['nik'] ?? '-'}\nShift ${session['shift']}\n${session['completed_checkpoints']}/${session['total_checkpoints']} checkpoint',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _SectionTitle('Checkpoint Coverage'),
              const SizedBox(height: 10),
              if (checkpoints.isEmpty)
                const _EmptyCard('Belum ada data checkpoint.')
              else
                ...checkpoints.take(6).map(
                  (checkpoint) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        title: Text('${checkpoint['name'] ?? '-'}'),
                        subtitle: Text(
                          '${checkpoint['building_name'] ?? '-'}\nScan: ${checkpoint['scan_count'] ?? 0}\nLast: ${checkpoint['last_scanned_at'] ?? 'Belum ada'}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _SectionTitle('Recent Logs'),
              const SizedBox(height: 10),
              if (logs.isEmpty)
                const _EmptyCard('Belum ada log patroli.')
              else
                ...logs.map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        title: Text(
                          '${log['security_name'] ?? log['guard_name'] ?? '-'} - ${log['checkpoint_name'] ?? '-'}',
                        ),
                        subtitle: Text(
                          'NIK ${log['nik'] ?? '-'}\n${log['building_name'] ?? '-'}\n${log['scanned_at'] ?? '-'}\nGPS: ${log['gps_latitude'] ?? '-'}, ${log['gps_longitude'] ?? '-'}',
                        ),
                        isThreeLine: true,
                        trailing: (log['gps_latitude'] != null && log['gps_longitude'] != null)
                            ? IconButton(
                                onPressed: () => _openMap(
                                  log['gps_latitude'],
                                  log['gps_longitude'],
                                  log['gps_open_url'] as String?,
                                ),
                                icon: const Icon(Icons.map_outlined),
                                tooltip: 'Buka Peta',
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}
