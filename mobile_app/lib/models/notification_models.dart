class NotificationDevice {
  const NotificationDevice({
    required this.id,
    required this.platform,
    required this.pushProvider,
    required this.pushToken,
    required this.deviceName,
    required this.appVersion,
    required this.enabled,
    required this.importantEnabled,
    required this.lastSeenAt,
  });

  final String id;
  final String platform;
  final String pushProvider;
  final String pushToken;
  final String deviceName;
  final String appVersion;
  final bool enabled;
  final bool importantEnabled;
  final DateTime lastSeenAt;

  factory NotificationDevice.fromJson(Map<String, dynamic> json) {
    return NotificationDevice(
      id: json['id'] as String? ?? '',
      platform: json['platform'] as String? ?? 'unknown',
      pushProvider: json['push_provider'] as String? ?? 'unknown',
      pushToken: json['push_token'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      appVersion: json['app_version'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      importantEnabled: json['important_enabled'] as bool? ?? true,
      lastSeenAt:
          DateTime.tryParse(json['last_seen_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class NotificationRegistrationResult {
  const NotificationRegistrationResult({
    required this.device,
    required this.latestSignalCount,
  });

  final NotificationDevice device;
  final int latestSignalCount;

  factory NotificationRegistrationResult.fromJson(Map<String, dynamic> json) {
    return NotificationRegistrationResult(
      device: NotificationDevice.fromJson(
        (json['device'] as Map<String, dynamic>?) ?? const {},
      ),
      latestSignalCount: json['latest_signal_count'] as int? ?? 0,
    );
  }
}

class PushRecord {
  const PushRecord({
    required this.id,
    required this.status,
    required this.provider,
    required this.errorMessage,
    required this.createdAt,
  });

  final String id;
  final String status;
  final String provider;
  final String errorMessage;
  final DateTime createdAt;

  factory PushRecord.fromJson(Map<String, dynamic> json) {
    return PushRecord(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      provider: json['provider'] as String? ?? 'unknown',
      errorMessage: json['error_message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
