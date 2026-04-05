class MobileAuthState {
  const MobileAuthState({
    required this.token,
    required this.user,
  });

  final String token;
  final MobileUser user;

  factory MobileAuthState.fromJson(Map<String, dynamic> json) {
    return MobileAuthState(
      token: json['token'] as String,
      user: MobileUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
    };
  }
}

class MobileUser {
  const MobileUser({
    required this.id,
    required this.name,
    required this.nik,
    required this.email,
    required this.role,
  });

  final int id;
  final String name;
  final String nik;
  final String email;
  final String role;

  factory MobileUser.fromJson(Map<String, dynamic> json) {
    return MobileUser(
      id: json['id'] as int,
      name: json['name'] as String,
      nik: (json['nik'] as String?) ?? '-',
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nik': nik,
      'email': email,
      'role': role,
    };
  }
}

class GuardCheckpoint {
  const GuardCheckpoint({
    required this.id,
    required this.name,
    required this.buildingName,
    required this.nfcUid,
    required this.qrCode,
    required this.sortOrder,
    this.logsCount = 0,
  });

  final int id;
  final String name;
  final String buildingName;
  final String nfcUid;
  final String qrCode;
  final int sortOrder;
  final int logsCount;

  factory GuardCheckpoint.fromJson(Map<String, dynamic> json) {
    return GuardCheckpoint(
      id: json['id'] as int,
      name: json['name'] as String,
      buildingName: json['building_name'] as String,
      nfcUid: (json['nfc_uid'] as String?) ?? '',
      qrCode: (json['qr_code'] as String?) ?? '',
      sortOrder: (json['sort_order'] as num).toInt(),
      logsCount: (json['logs_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'building_name': buildingName,
      'nfc_uid': nfcUid,
      'qr_code': qrCode,
      'sort_order': sortOrder,
      'logs_count': logsCount,
    };
  }
}

class PatrolSessionState {
  const PatrolSessionState({
    required this.id,
    required this.uuid,
    required this.shift,
    required this.status,
    required this.startedAt,
    this.endedAt,
  });

  final int id;
  final String uuid;
  final String shift;
  final String status;
  final String startedAt;
  final String? endedAt;

  factory PatrolSessionState.fromJson(Map<String, dynamic> json) {
    return PatrolSessionState(
      id: json['id'] as int,
      uuid: json['uuid'] as String,
      shift: json['shift'] as String,
      status: json['status'] as String,
      startedAt: json['started_at'] as String,
      endedAt: json['ended_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'shift': shift,
      'status': status,
      'started_at': startedAt,
      'ended_at': endedAt,
    };
  }
}

class GuardLogEntry {
  const GuardLogEntry({
    required this.localUuid,
    required this.checkpointId,
    required this.checkpointName,
    required this.buildingName,
    required this.nfcUid,
    required this.qrCode,
    required this.scannedAt,
    required this.syncStatus,
    required this.message,
    required this.source,
    this.gpsLatitude,
    this.gpsLongitude,
    this.gpsMapUrl,
    this.gpsOpenUrl,
    this.syncedAt,
  });

  final String localUuid;
  final int checkpointId;
  final String checkpointName;
  final String buildingName;
  final String nfcUid;
  final String qrCode;
  final String scannedAt;
  final String syncStatus;
  final String message;
  final String source;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final String? gpsMapUrl;
  final String? gpsOpenUrl;
  final String? syncedAt;

  GuardLogEntry copyWith({
    String? syncStatus,
    String? message,
    String? syncedAt,
    double? gpsLatitude,
    double? gpsLongitude,
    String? gpsMapUrl,
    String? gpsOpenUrl,
  }) {
    return GuardLogEntry(
      localUuid: localUuid,
      checkpointId: checkpointId,
      checkpointName: checkpointName,
      buildingName: buildingName,
      nfcUid: nfcUid,
      qrCode: qrCode,
      scannedAt: scannedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      message: message ?? this.message,
      source: source,
      gpsLatitude: gpsLatitude ?? this.gpsLatitude,
      gpsLongitude: gpsLongitude ?? this.gpsLongitude,
      gpsMapUrl: gpsMapUrl ?? this.gpsMapUrl,
      gpsOpenUrl: gpsOpenUrl ?? this.gpsOpenUrl,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  factory GuardLogEntry.fromJson(Map<String, dynamic> json) {
    return GuardLogEntry(
      localUuid: json['local_uuid'] as String,
      checkpointId: json['checkpoint_id'] as int,
      checkpointName: json['checkpoint_name'] as String,
      buildingName: json['building_name'] as String,
      nfcUid: (json['nfc_uid'] as String?) ?? '',
      qrCode: (json['qr_code'] as String?) ?? '',
      scannedAt: json['scanned_at'] as String,
      syncStatus: json['sync_status'] as String,
      message: json['message'] as String,
      source: (json['source'] as String?) ?? 'mobile',
      gpsLatitude: (json['gps_latitude'] as num?)?.toDouble(),
      gpsLongitude: (json['gps_longitude'] as num?)?.toDouble(),
      gpsMapUrl: json['gps_map_url'] as String?,
      gpsOpenUrl: json['gps_open_url'] as String?,
      syncedAt: json['synced_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'local_uuid': localUuid,
      'checkpoint_id': checkpointId,
      'checkpoint_name': checkpointName,
      'building_name': buildingName,
      'nfc_uid': nfcUid,
      'qr_code': qrCode,
      'scanned_at': scannedAt,
      'sync_status': syncStatus,
      'message': message,
      'source': source,
      'gps_latitude': gpsLatitude,
      'gps_longitude': gpsLongitude,
      'gps_map_url': gpsMapUrl,
      'gps_open_url': gpsOpenUrl,
      'synced_at': syncedAt,
    };
  }
}
