import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'services.dart';

class GuardHomeScreen extends StatefulWidget {
  const GuardHomeScreen({
    super.key,
    required this.authState,
    required this.onLogout,
  });

  final MobileAuthState authState;
  final Future<void> Function() onLogout;

  @override
  State<GuardHomeScreen> createState() => _GuardHomeScreenState();
}

class _GuardHomeScreenState extends State<GuardHomeScreen>
    with SingleTickerProviderStateMixin {
  final apiClient = const PatrolApiClient();
  final storage = const GuardDeviceStorage();
  final locationService = const DeviceLocationService();

  late final AnimationController _pulseController;
  PatrolSessionState? session;
  List<GuardCheckpoint> checkpoints = [];
  List<GuardLogEntry> logs = [];
  String selectedShift = 'Pagi';
  String statusMessage = 'Mulai shift untuk membuka sesi patroli.';
  String? errorMessage;
  bool isLoading = true;
  bool isWorking = false;
  bool isScanOverlayVisible = false;

  int get userId => widget.authState.user.id;

  String? _buildMapOpenUrl(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return null;
    }

    return 'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=18/$latitude/$longitude';
  }

  Future<void> _openMap(GuardLogEntry log) async {
    final target = log.gpsOpenUrl ?? _buildMapOpenUrl(log.gpsLatitude, log.gpsLongitude);
    if (target == null) {
      return;
    }

    final uri = Uri.parse(target);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peta tidak bisa dibuka dari device ini.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _hydrateGuardState();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get hasPendingLogs =>
      logs.any((log) => log.syncStatus == 'pending' || log.syncStatus == 'failed');

  Future<void> _hydrateGuardState() async {
    final restoredSession = await storage.readSession(userId);
    final restoredLogs = await storage.readLogs(userId);
    final cachedCheckpoints = await storage.readCheckpoints();

    setState(() {
      session = restoredSession;
      logs = restoredLogs;
      checkpoints = cachedCheckpoints;
      isLoading = false;
    });

    await _refreshCheckpoints(showMessage: false);

    if (session != null && hasPendingLogs) {
      await _syncPendingLogs(showMessage: false);
    }
  }

  Future<void> _refreshCheckpoints({bool showMessage = true}) async {
    try {
      final remoteCheckpoints = await apiClient.fetchCheckpoints(widget.authState.token);
      await storage.saveCheckpoints(remoteCheckpoints);

      setState(() {
        checkpoints = remoteCheckpoints;
        errorMessage = null;
        if (showMessage) {
          statusMessage = 'Daftar checkpoint berhasil dimuat dari server.';
        }
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _startShift() async {
    setState(() {
      isWorking = true;
      errorMessage = null;
    });

    try {
      final nextSession = await apiClient.startPatrol(
        token: widget.authState.token,
        shift: selectedShift,
      );
      await storage.saveSession(userId, nextSession);

      setState(() {
        session = nextSession;
        statusMessage = 'Shift ${nextSession.shift} aktif dan siap untuk checkpoint.';
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => isWorking = false);
      }
    }
  }

  Future<void> _syncPendingLogs({bool showMessage = true}) async {
    if (session == null) {
      return;
    }

    final pendingLogs =
        logs.where((log) => log.syncStatus == 'pending' || log.syncStatus == 'failed').toList();
    if (pendingLogs.isEmpty) {
      return;
    }

    try {
      final syncedRows = await apiClient.sync(
        token: widget.authState.token,
        patrolSessionId: session!.id,
        logs: pendingLogs,
      );

      final syncMap = {for (final row in syncedRows) row['local_uuid'] as String: row};

      final updatedLogs = logs.map((log) {
        final syncedRow = syncMap[log.localUuid];
        if (syncedRow == null) {
          return log;
        }

        return log.copyWith(
          syncStatus: 'synced',
          syncedAt: syncedRow['synced_at'] as String?,
          message: 'Log offline berhasil dikirim ke server.',
          gpsLatitude: (syncedRow['gps_latitude'] as num?)?.toDouble(),
          gpsLongitude: (syncedRow['gps_longitude'] as num?)?.toDouble(),
          gpsMapUrl: syncedRow['gps_map_url'] as String?,
          gpsOpenUrl: syncedRow['gps_open_url'] as String?,
        );
      }).toList();

      await storage.saveLogs(userId, updatedLogs);

      setState(() {
        logs = updatedLogs;
        errorMessage = null;
        if (showMessage) {
          statusMessage = '${syncedRows.length} log offline berhasil disinkronkan.';
        }
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleScanCheckpoint(
    GuardCheckpoint checkpoint, {
    required String source,
  }) async {
    if (session == null) {
      setState(() {
        errorMessage = 'Mulai shift terlebih dahulu sebelum scan checkpoint.';
      });
      return;
    }

    setState(() {
      isWorking = true;
      errorMessage = null;
    });

    final scannedAt = DateTime.now().toIso8601String();
    final localUuid = 'scan-${DateTime.now().microsecondsSinceEpoch}';
    final location = await locationService.capture();
    final onlineLog = GuardLogEntry(
      localUuid: localUuid,
      checkpointId: checkpoint.id,
      checkpointName: checkpoint.name,
      buildingName: checkpoint.buildingName,
      nfcUid: checkpoint.nfcUid,
      qrCode: checkpoint.qrCode,
      scannedAt: scannedAt,
      syncStatus: 'synced',
      message: 'Checkpoint tervalidasi dan dikirim ke server.',
      source: source,
      gpsLatitude: location?.latitude,
      gpsLongitude: location?.longitude,
      gpsOpenUrl: _buildMapOpenUrl(location?.latitude, location?.longitude),
      syncedAt: scannedAt,
    );

    try {
      final payload = await apiClient.scan(
        token: widget.authState.token,
        patrolSessionId: session!.id,
        checkpointId: checkpoint.id,
        localUuid: localUuid,
        scannedAt: scannedAt,
        source: source,
        location: location,
      );

      final updatedLogs = [
        ...logs,
        onlineLog.copyWith(
          syncedAt: payload['synced_at'] as String?,
          gpsLatitude: (payload['gps_latitude'] as num?)?.toDouble(),
          gpsLongitude: (payload['gps_longitude'] as num?)?.toDouble(),
          gpsMapUrl: payload['gps_map_url'] as String?,
          gpsOpenUrl: payload['gps_open_url'] as String?,
        ),
      ];

      await storage.saveLogs(userId, updatedLogs);

      setState(() {
        logs = updatedLogs;
        statusMessage = 'Checkpoint ${checkpoint.name} berhasil dicatat.';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F7B63),
            content: Text('Checkpoint ${checkpoint.name} berhasil.'),
          ),
        );
      }
    } catch (_) {
      final offlineLog = onlineLog.copyWith(
        syncStatus: 'pending',
        syncedAt: null,
        message: 'Server tidak terjangkau. Log disimpan lokal.',
      );
      final updatedLogs = [...logs, offlineLog];
      await storage.saveLogs(userId, updatedLogs);

      setState(() {
        logs = updatedLogs;
        statusMessage = 'Checkpoint ${checkpoint.name} tersimpan lokal dan masuk antrean sync.';
      });
    } finally {
      if (mounted) {
        setState(() => isWorking = false);
      }
    }
  }

  Future<void> _endPatrol() async {
    if (session == null) {
      return;
    }

    setState(() {
      isWorking = true;
      errorMessage = null;
    });

    try {
      if (hasPendingLogs) {
        await _syncPendingLogs(showMessage: false);
      }

      await apiClient.endPatrol(
        token: widget.authState.token,
        patrolSessionId: session!.id,
      );
      await storage.saveSession(userId, null);

      setState(() {
        session = null;
        statusMessage = 'Sesi patroli ditutup dengan sukses.';
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => isWorking = false);
      }
    }
  }

  Future<void> _startNfcScan() async {
    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      setState(() {
        errorMessage = 'NFC tidak aktif atau belum didukung pada device ini.';
      });
      return;
    }

    _showScanOverlay('Scanning NFC', 'Tempelkan ponsel ke tag checkpoint.');
    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      onDiscovered: (tag) async {
        final androidTag = NfcTagAndroid.from(tag);
        await NfcManager.instance.stopSession();
        _dismissScanOverlay();

        if (!mounted || androidTag == null || androidTag.id.isEmpty) {
          return;
        }

        final uid = normalizeNfcUid(
          androidTag.id.map((value) => value.toRadixString(16).padLeft(2, '0')).join('-'),
        );
        final matchedCheckpoint = checkpoints.cast<GuardCheckpoint?>().firstWhere(
          (entry) => entry != null && normalizeNfcUid(entry.nfcUid) == uid,
          orElse: () => null,
        );

        if (matchedCheckpoint == null) {
          setState(() => errorMessage = 'UID $uid tidak cocok dengan checkpoint mana pun.');
          return;
        }

        await _handleScanCheckpoint(matchedCheckpoint, source: 'nfc-scan');
      },
    );
  }

  Future<void> _startQrScan() async {
    _showScanOverlay('Scanning QR Code', 'Arahkan kamera ke QR code checkpoint.');

    final scannedCode = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final controller = MobileScannerController();
        var handled = false;

        return Dialog(
          backgroundColor: const Color(0xFF0E203A),
          child: SizedBox(
            height: 360,
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (handled) {
                  return;
                }
                final value = capture.barcodes.first.rawValue;
                if (value == null || value.isEmpty) {
                  return;
                }
                handled = true;
                controller.dispose();
                Navigator.of(context).pop(value);
              },
            ),
          ),
        );
      },
    );

    _dismissScanOverlay();

    if (!mounted || scannedCode == null || scannedCode.isEmpty) {
      return;
    }

    final normalizedCode = normalizeQrCode(scannedCode);
    final matchedCheckpoint = checkpoints.cast<GuardCheckpoint?>().firstWhere(
      (entry) => entry != null && normalizeQrCode(entry.qrCode) == normalizedCode,
      orElse: () => null,
    );

    if (matchedCheckpoint == null) {
      setState(() => errorMessage = 'QR code $normalizedCode tidak cocok dengan checkpoint mana pun.');
      return;
    }

    await _handleScanCheckpoint(matchedCheckpoint, source: 'qr-scan');
  }

  void _showScanOverlay(String title, String subtitle) {
    if (isScanOverlayVisible || !mounted) {
      return;
    }
    isScanOverlayVisible = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: const Color(0xFF0E203A),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Transform.scale(
                    scale: 1 + (_pulseController.value * 0.08),
                    child: child,
                  ),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF5B93A).withValues(alpha: 0.16),
                      border: Border.all(color: const Color(0xFFF5B93A), width: 2),
                    ),
                    child: const Icon(Icons.nfc, size: 42, color: Color(0xFFF5B93A)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(subtitle, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismissScanOverlay() {
    if (!isScanOverlayVisible || !mounted) {
      return;
    }

    isScanOverlayVisible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _resetLocalState() async {
    await storage.saveSession(userId, null);
    await storage.saveLogs(userId, []);
    setState(() {
      session = null;
      logs = [];
      statusMessage = 'Data lokal patroli untuk user ini dibersihkan.';
      errorMessage = null;
    });
  }

  bool _wasVisited(int checkpointId) => logs.any((log) => log.checkpointId == checkpointId);

  String _checkpointStatus(int checkpointId) {
    final matchingLog = logs.where((log) => log.checkpointId == checkpointId).toList();
    if (matchingLog.isEmpty) {
      return 'Belum dikunjungi';
    }
    if (matchingLog.any((log) => log.syncStatus == 'pending' || log.syncStatus == 'failed')) {
      return 'Pending sync';
    }
    return 'Synced';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authState.user;
    final visitedCount = checkpoints.where((checkpoint) => _wasVisited(checkpoint.id)).length;
    final pendingCount = logs.where((log) => log.syncStatus != 'synced').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Patrol'),
        actions: [
          IconButton(onPressed: _refreshCheckpoints, icon: const Icon(Icons.cloud_download)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshCheckpoints,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: ListTile(
                  title: Text(user.name),
                  subtitle: Text('NIK ${user.nik} • ${user.email}'),
                  trailing: session == null ? const Chip(label: Text('Idle')) : Chip(label: Text(session!.shift)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _StatusCard(title: 'Session', value: session == null ? 'Idle' : 'Aktif')),
                  const SizedBox(width: 10),
                  Expanded(child: _StatusCard(title: 'Checkpoint', value: '$visitedCount/${checkpoints.length}')),
                  const SizedBox(width: 10),
                  Expanded(child: _StatusCard(title: 'Pending', value: '$pendingCount')),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shift Patrol', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedShift,
                        decoration: const InputDecoration(labelText: 'Pilih shift'),
                        items: const [
                          DropdownMenuItem(value: 'Pagi', child: Text('Pagi')),
                          DropdownMenuItem(value: 'Sore', child: Text('Sore')),
                          DropdownMenuItem(value: 'Malam', child: Text('Malam')),
                        ],
                        onChanged: (value) => setState(() => selectedShift = value ?? selectedShift),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: session != null || isWorking ? null : _startShift,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFFF5B93A),
                          foregroundColor: const Color(0xFF241400),
                        ),
                        child: Text(session == null ? 'Mulai Shift' : 'Shift Sudah Aktif'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Checkpoint Tools', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(onPressed: session == null || isWorking ? null : _startNfcScan, icon: const Icon(Icons.nfc), label: const Text('Scan NFC')),
                          FilledButton.icon(onPressed: session == null || isWorking ? null : _startQrScan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan QR')),
                          OutlinedButton.icon(onPressed: hasPendingLogs && session != null ? _syncPendingLogs : null, icon: const Icon(Icons.sync), label: const Text('Sync Pending')),
                          OutlinedButton.icon(onPressed: session == null || isWorking ? null : _endPatrol, icon: const Icon(Icons.flag_circle), label: const Text('End Patrol')),
                          OutlinedButton.icon(onPressed: _resetLocalState, icon: const Icon(Icons.delete_outline), label: const Text('Reset Local')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(statusMessage),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Checkpoint List', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ...checkpoints.map((checkpoint) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      title: Text(checkpoint.name),
                      subtitle: Text('${checkpoint.buildingName}\nNFC: ${normalizeNfcUid(checkpoint.nfcUid)}\nQR: ${checkpoint.qrCode}\nStatus: ${_checkpointStatus(checkpoint.id)}'),
                      isThreeLine: true,
                    ),
                  ),
                )),
              const SizedBox(height: 16),
              Text('Riwayat Lokal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (logs.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Belum ada log scan di device ini.')))
              else
                ...logs.reversed.map((log) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.checkpointName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('${log.buildingName}\n${log.message}\n${log.scannedAt}\nSource: ${log.source}'),
                          if (log.gpsLatitude != null && log.gpsLongitude != null) ...[
                            const SizedBox(height: 10),
                            Text('GPS: ${log.gpsLatitude}, ${log.gpsLongitude}'),
                          ],
                          if (log.gpsMapUrl != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                log.gpsMapUrl!,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 140,
                                    alignment: Alignment.center,
                                    color: const Color(0xFF132640),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: const Text(
                                      'Preview map tidak tersedia. Gunakan tombol Buka Peta.',
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (log.gpsLatitude != null && log.gpsLongitude != null) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => _openMap(log),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Buka Peta'),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Align(alignment: Alignment.centerRight, child: Chip(label: Text(log.syncStatus))),
                        ],
                      ),
                    ),
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
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
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
