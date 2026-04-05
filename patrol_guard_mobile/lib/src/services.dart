import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const apiBaseUrl = 'http://192.168.2.10:8000/api';
const authStorageKey = 'patrol_mobile_auth';
const checkpointStorageKey = 'patrol_mobile_checkpoints';

String normalizeNfcUid(String rawUid) {
  final compact = rawUid
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^0-9A-F]'), '');

  if (compact.isEmpty) {
    return '';
  }

  final parts = <String>[];
  for (var index = 0; index < compact.length; index += 2) {
    final end = (index + 2 < compact.length) ? index + 2 : compact.length;
    parts.add(compact.substring(index, end));
  }

  return parts.join('-');
}

String normalizeQrCode(String rawValue) {
  return rawValue.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '-');
}

String guardSessionStorageKeyForUser(int userId) => 'patrol_mobile_guard_session_$userId';
String guardQueueStorageKeyForUser(int userId) => 'patrol_mobile_guard_queue_$userId';

class DeviceLocationData {
  const DeviceLocationData({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class DeviceLocationService {
  const DeviceLocationService();

  Future<DeviceLocationData?> capture() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return DeviceLocationData(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}

class PatrolApiClient {
  const PatrolApiClient();

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    return _request(
      '/login',
      method: 'POST',
      body: {
        'identifier': identifier,
        'password': password,
      },
    );
  }

  Future<List<GuardCheckpoint>> fetchCheckpoints(String token) async {
    final payload = await _request('/checkpoints', token: token);
    final rows = payload['data'] as List<dynamic>? ?? [];

    return rows
        .map((row) => GuardCheckpoint.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<PatrolSessionState> startPatrol({
    required String token,
    required String shift,
  }) async {
    final payload = await _request(
      '/patrol/start',
      token: token,
      method: 'POST',
      body: {'shift': shift},
    );

    return PatrolSessionState.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> scan({
    required String token,
    required int patrolSessionId,
    required int checkpointId,
    required String localUuid,
    required String scannedAt,
    String source = 'nfc-scan',
    DeviceLocationData? location,
  }) async {
    final payload = await _request(
      '/patrol/scan',
      token: token,
      method: 'POST',
      body: {
        'patrol_session_id': patrolSessionId,
        'checkpoint_id': checkpointId,
        'local_uuid': localUuid,
        'scanned_at': scannedAt,
        'source': source,
        'gps_latitude': location?.latitude,
        'gps_longitude': location?.longitude,
      },
    );

    return payload['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> sync({
    required String token,
    required int patrolSessionId,
    required List<GuardLogEntry> logs,
  }) async {
    final payload = await _request(
      '/patrol/sync',
      token: token,
      method: 'POST',
      body: {
        'patrol_session_id': patrolSessionId,
        'logs': logs
            .map(
              (log) => {
                'checkpoint_id': log.checkpointId,
                'local_uuid': log.localUuid,
                'scanned_at': log.scannedAt,
                'source': log.source,
                'gps_latitude': log.gpsLatitude,
                'gps_longitude': log.gpsLongitude,
              },
            )
            .toList(),
      },
    );

    return (payload['data'] as List<dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  Future<void> endPatrol({
    required String token,
    required int patrolSessionId,
  }) async {
    await _request(
      '/patrol/end',
      token: token,
      method: 'POST',
      body: {
        'patrol_session_id': patrolSessionId,
      },
    );
  }

  Future<Map<String, dynamic>> fetchSupervisorDashboard(String token) async {
    return _request('/supervisor/dashboard', token: token);
  }

  Future<Map<String, dynamic>> fetchSupervisorReport(String token, String period) async {
    return _request('/supervisor/reports?period=$period', token: token);
  }

  Future<Map<String, dynamic>> fetchAdminDashboard(String token) async {
    return _request('/admin/dashboard', token: token);
  }

  Future<Map<String, dynamic>> fetchAdminMasterData(String token) async {
    return _request('/admin/master-data', token: token);
  }

  Future<Map<String, dynamic>> fetchAdminReport(String token, String period) async {
    return _request('/admin/reports?period=$period', token: token);
  }

  Future<List<GuardCheckpoint>> fetchAdminCheckpoints(String token) async {
    final payload = await _request('/admin/checkpoints', token: token);
    final rows = payload['data'] as List<dynamic>? ?? [];

    return rows
        .map((row) => GuardCheckpoint.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<GuardCheckpoint> createAdminCheckpoint(
    String token, {
    required String buildingName,
    required String name,
    required String nfcUid,
    required String qrCode,
    required int sortOrder,
  }) async {
    final payload = await _request(
      '/admin/checkpoints',
      token: token,
      method: 'POST',
      body: {
        'building_name': buildingName,
        'name': name,
        'nfc_uid': nfcUid,
        'qr_code': qrCode.isEmpty ? null : qrCode,
        'sort_order': sortOrder,
      },
    );

    return GuardCheckpoint.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<GuardCheckpoint> updateAdminCheckpoint(
    String token, {
    required int checkpointId,
    required String buildingName,
    required String name,
    required String nfcUid,
    required String qrCode,
    required int sortOrder,
  }) async {
    final payload = await _request(
      '/admin/checkpoints/$checkpointId',
      token: token,
      method: 'PUT',
      body: {
        'building_name': buildingName,
        'name': name,
        'nfc_uid': nfcUid,
        'qr_code': qrCode.isEmpty ? null : qrCode,
        'sort_order': sortOrder,
      },
    );

    return GuardCheckpoint.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<void> deleteAdminCheckpoint(String token, int checkpointId) async {
    await _request(
      '/admin/checkpoints/$checkpointId',
      token: token,
      method: 'DELETE',
    );
  }

  Future<String> exportReportPdf({
    required String token,
    required String scope,
    required String period,
  }) async {
    final request = http.Request(
      'GET',
      Uri.parse('$apiBaseUrl/$scope/reports/export?period=$period'),
    )..headers.addAll({
        'Accept': 'application/pdf',
        'Authorization': 'Bearer $token',
      });

    final response = await request.send();
    final bytes = await response.stream.toBytes();

    if (response.statusCode >= 400) {
      throw Exception('Export PDF gagal. Status ${response.statusCode}.');
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}\\${scope}_${period}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);

    return file.path;
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, Uri.parse('$apiBaseUrl$path'))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

    if (body != null) {
      request.body = jsonEncode(body);
    }

    final response = await request.send();
    final rawBody = await response.stream.bytesToString();
    final trimmedBody = rawBody.trimLeft();
    final isJsonResponse = trimmedBody.startsWith('{') || trimmedBody.startsWith('[');
    final payload = rawBody.isEmpty
        ? <String, dynamic>{}
        : isJsonResponse
            ? jsonDecode(rawBody) as Map<String, dynamic>
            : <String, dynamic>{
                'message': _buildNonJsonMessage(response.statusCode, rawBody),
              };

    if (response.statusCode >= 400) {
      throw Exception(payload['message'] ?? 'Permintaan API gagal.');
    }

    if (!isJsonResponse && rawBody.isNotEmpty) {
      throw Exception(payload['message'] ?? 'Server mengembalikan respons non-JSON.');
    }

    return payload;
  }

  String _buildNonJsonMessage(int statusCode, String body) {
    final preview = body.replaceAll(RegExp(r'\s+'), ' ').trim();

    return 'Server tidak mengembalikan JSON. Status $statusCode. '
        'Pastikan URL API benar dan backend Laravel utama dapat diakses dari perangkat. '
        'Preview: ${preview.substring(0, preview.length > 120 ? 120 : preview.length)}';
  }
}

class GuardDeviceStorage {
  const GuardDeviceStorage();

  Future<MobileAuthState?> readAuthState() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(authStorageKey);

    if (rawValue == null) {
      return null;
    }

    return MobileAuthState.fromJson(jsonDecode(rawValue) as Map<String, dynamic>);
  }

  Future<void> saveAuthState(MobileAuthState? authState) async {
    final preferences = await SharedPreferences.getInstance();

    if (authState == null) {
      await preferences.remove(authStorageKey);
      return;
    }

    await preferences.setString(authStorageKey, jsonEncode(authState.toJson()));
  }

  Future<void> saveSession(int userId, PatrolSessionState? session) async {
    final preferences = await SharedPreferences.getInstance();
    final key = guardSessionStorageKeyForUser(userId);

    if (session == null) {
      await preferences.remove(key);
      return;
    }

    await preferences.setString(key, jsonEncode(session.toJson()));
  }

  Future<PatrolSessionState?> readSession(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(guardSessionStorageKeyForUser(userId));

    if (rawValue == null) {
      return null;
    }

    return PatrolSessionState.fromJson(
      jsonDecode(rawValue) as Map<String, dynamic>,
    );
  }

  Future<void> saveLogs(int userId, List<GuardLogEntry> logs) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      guardQueueStorageKeyForUser(userId),
      jsonEncode(logs.map((log) => log.toJson()).toList()),
    );
  }

  Future<List<GuardLogEntry>> readLogs(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(guardQueueStorageKeyForUser(userId));

    if (rawValue == null) {
      return [];
    }

    final rows = jsonDecode(rawValue) as List<dynamic>;
    return rows
        .map((row) => GuardLogEntry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCheckpoints(List<GuardCheckpoint> checkpoints) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      checkpointStorageKey,
      jsonEncode(checkpoints.map((checkpoint) => checkpoint.toJson()).toList()),
    );
  }

  Future<List<GuardCheckpoint>> readCheckpoints() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(checkpointStorageKey);

    if (rawValue == null) {
      return [];
    }

    final rows = jsonDecode(rawValue) as List<dynamic>;
    return rows
        .map((row) => GuardCheckpoint.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
