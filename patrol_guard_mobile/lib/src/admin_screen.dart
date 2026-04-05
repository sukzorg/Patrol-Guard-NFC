import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import 'models.dart';
import 'services.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.authState,
    required this.onLogout,
  });

  final MobileAuthState authState;
  final Future<void> Function() onLogout;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final apiClient = const PatrolApiClient();
  final buildingController = TextEditingController();
  final nameController = TextEditingController();
  final uidController = TextEditingController();
  final qrController = TextEditingController();
  final sortOrderController = TextEditingController(text: '1');

  late final AnimationController _pulseController;
  Map<String, dynamic>? dashboard;
  Map<String, dynamic>? masterData;
  Map<String, dynamic>? report;
  List<GuardCheckpoint> checkpoints = [];
  bool isLoading = true;
  bool isSubmitting = false;
  bool isExporting = false;
  bool isScanOverlayVisible = false;
  String selectedPeriod = 'daily';
  String? errorMessage;
  String statusMessage = 'Admin mobile siap untuk mengelola checkpoint NFC dan QR.';
  int? editingCheckpointId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _loadAdminData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    buildingController.dispose();
    nameController.dispose();
    uidController.dispose();
    qrController.dispose();
    sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final dashboardPayload = await apiClient.fetchAdminDashboard(widget.authState.token);
      final masterPayload = await apiClient.fetchAdminMasterData(widget.authState.token);
      final reportPayload = await apiClient.fetchAdminReport(widget.authState.token, selectedPeriod);
      final checkpointRows = await apiClient.fetchAdminCheckpoints(widget.authState.token);

      setState(() {
        dashboard = dashboardPayload;
        masterData = masterPayload;
        report = reportPayload;
        checkpoints = checkpointRows;
      });
    } catch (error) {
      setState(() => errorMessage = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _submitCheckpoint() async {
    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    try {
      final sortOrder = int.tryParse(sortOrderController.text.trim()) ?? 1;
      final normalizedUid = normalizeNfcUid(uidController.text);
      final normalizedQr = normalizeQrCode(qrController.text);

      final duplicate = checkpoints.cast<GuardCheckpoint?>().firstWhere(
        (checkpoint) {
          if (checkpoint == null) {
            return false;
          }
          if (editingCheckpointId != null && checkpoint.id == editingCheckpointId) {
            return false;
          }

          final sameNfc = normalizedUid.isNotEmpty && normalizeNfcUid(checkpoint.nfcUid) == normalizedUid;
          final sameQr = normalizedQr.isNotEmpty && normalizeQrCode(checkpoint.qrCode) == normalizedQr;
          final differentIdentity = checkpoint.name != nameController.text.trim() ||
              checkpoint.buildingName != buildingController.text.trim();
          return differentIdentity && (sameNfc || sameQr);
        },
        orElse: () => null,
      );

      if (duplicate != null) {
        final continueSave = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Kode sudah terdaftar'),
                content: Text(
                  'NFC UID atau QR code ini sudah digunakan oleh ${duplicate.name} di area ${duplicate.buildingName}.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Periksa Lagi'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Lanjut'),
                  ),
                ],
              ),
            ) ??
            false;

        if (!continueSave) {
          return;
        }
      }

      if (editingCheckpointId == null) {
        await apiClient.createAdminCheckpoint(
          widget.authState.token,
          buildingName: buildingController.text.trim(),
          name: nameController.text.trim(),
          nfcUid: normalizedUid,
          qrCode: normalizedQr,
          sortOrder: sortOrder,
        );
        statusMessage = 'Checkpoint baru berhasil dibuat.';
      } else {
        await apiClient.updateAdminCheckpoint(
          widget.authState.token,
          checkpointId: editingCheckpointId!,
          buildingName: buildingController.text.trim(),
          name: nameController.text.trim(),
          nfcUid: normalizedUid,
          qrCode: normalizedQr,
          sortOrder: sortOrder,
        );
        statusMessage = 'Checkpoint berhasil diperbarui.';
      }

      _resetForm();
      await _loadAdminData();
    } catch (error) {
      setState(() => errorMessage = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> _deleteCheckpoint(int checkpointId) async {
    try {
      await apiClient.deleteAdminCheckpoint(widget.authState.token, checkpointId);
      statusMessage = 'Checkpoint berhasil dihapus.';
      await _loadAdminData();
    } catch (error) {
      setState(() => errorMessage = error.toString().replaceFirst('Exception: ', ''));
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
        scope: 'admin',
        period: selectedPeriod,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF berhasil dibuat di $path')),
        );
      }
    } catch (error) {
      setState(() => errorMessage = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => isExporting = false);
      }
    }
  }

  Future<void> _showPreviewDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Report Admin'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Periode: ${report?['range_label'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('User baru: ${report?['summary']?['new_users'] ?? 0}'),
              Text('Total scan: ${report?['summary']?['total_scans'] ?? 0}'),
              Text('Security unik: ${report?['summary']?['unique_security'] ?? 0}'),
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

  void _editCheckpoint(GuardCheckpoint checkpoint) {
    setState(() {
      editingCheckpointId = checkpoint.id;
      buildingController.text = checkpoint.buildingName;
      nameController.text = checkpoint.name;
      uidController.text = checkpoint.nfcUid;
      qrController.text = checkpoint.qrCode;
      sortOrderController.text = checkpoint.sortOrder.toString();
      statusMessage = 'Mode edit aktif untuk checkpoint ${checkpoint.name}.';
    });
  }

  void _resetForm() {
    setState(() {
      editingCheckpointId = null;
      buildingController.clear();
      nameController.clear();
      uidController.clear();
      qrController.clear();
      sortOrderController.text = '1';
    });
  }

  Future<void> _scanUidForRegistration() async {
    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      setState(() => errorMessage = 'NFC tidak aktif atau tidak tersedia pada device ini.');
      return;
    }

    _showScanOverlay('Scanning NFC', 'Tempelkan tag NFC untuk mengambil UID.');
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

        setState(() {
          uidController.text = uid;
          statusMessage = 'UID NFC berhasil dibaca dan dimasukkan ke form.';
        });
      },
    );
  }

  Future<void> _scanQrForRegistration() async {
    _showScanOverlay('Scanning QR Code', 'Arahkan kamera ke QR code checkpoint.');
    final scannedCode = await showDialog<String>(
      context: context,
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

    setState(() {
      qrController.text = normalizeQrCode(scannedCode);
      statusMessage = 'QR code berhasil dibaca dan dimasukkan ke form.';
    });
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

  @override
  Widget build(BuildContext context) {
    final stats = dashboard?['stats'] as Map<String, dynamic>? ?? {};
    final roles = masterData?['roles'] as List<dynamic>? ?? [];
    final summary = report?['summary'] as Map<String, dynamic>? ?? {};
    final checkpointBreakdown = report?['checkpoint_breakdown'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Mobile'),
        actions: [
          IconButton(onPressed: _loadAdminData, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(child: _MetricCard(title: 'Users', value: '${stats['total_users'] ?? 0}')),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(title: 'Checkpoint', value: '${stats['total_checkpoints'] ?? 0}')),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(title: 'Logs', value: '${stats['total_logs'] ?? 0}')),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rekap & Export PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                        setState(() => selectedPeriod = value);
                        await _loadAdminData();
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
                    Text('User baru ${summary['new_users'] ?? 0} • Total scan ${summary['total_scans'] ?? 0}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (roles.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Role Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      ...roles.map((role) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('${role['name']} - ${((role['permissions'] as List<dynamic>?) ?? []).length} permission'),
                      )),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (errorMessage != null)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(errorMessage!)))
            else
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(statusMessage))),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editingCheckpointId == null ? 'Daftarkan NFC UID / QR Code' : 'Edit Checkpoint',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: buildingController, decoration: const InputDecoration(labelText: 'Area / Gedung')),
                    const SizedBox(height: 10),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Checkpoint')),
                    const SizedBox(height: 10),
                    TextField(controller: uidController, decoration: const InputDecoration(labelText: 'NFC UID')),
                    const SizedBox(height: 10),
                    TextField(controller: qrController, decoration: const InputDecoration(labelText: 'QR Code')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: sortOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Urutan'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(onPressed: _scanUidForRegistration, icon: const Icon(Icons.nfc), label: const Text('Scan NFC')),
                        FilledButton.icon(onPressed: _scanQrForRegistration, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan QR')),
                        FilledButton(onPressed: isSubmitting ? null : _submitCheckpoint, child: Text(editingCheckpointId == null ? 'Simpan' : 'Update')),
                        OutlinedButton(onPressed: _resetForm, child: const Text('Reset Form')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (checkpointBreakdown.isNotEmpty) ...[
              const Text('Rekap Checkpoint', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...checkpointBreakdown.take(5).map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    title: Text('${row['label'] ?? '-'}'),
                    subtitle: Text('${row['area'] ?? '-'}'),
                    trailing: Chip(label: Text('${row['value'] ?? 0} scan')),
                  ),
                ),
              )),
              const SizedBox(height: 16),
            ],
            const Text('Checkpoint CRUD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ...checkpoints.map((checkpoint) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    title: Text(checkpoint.name),
                    subtitle: Text(
                      '${checkpoint.buildingName}\nNFC: ${checkpoint.nfcUid}\nQR: ${checkpoint.qrCode}\nLogs: ${checkpoint.logsCount}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editCheckpoint(checkpoint);
                        } else if (value == 'delete') {
                          _deleteCheckpoint(checkpoint.id);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                  ),
                ),
              )),
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
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
