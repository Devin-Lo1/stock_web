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
    required this.signalEventId,
    required this.deviceId,
    required this.status,
    required this.provider,
    required this.errorMessage,
    required this.attemptCount,
    required this.sentAt,
    required this.createdAt,
  });

  final String id;
  final String? signalEventId;
  final String deviceId;
  final String status;
  final String provider;
  final String errorMessage;
  final int attemptCount;
  final DateTime? sentAt;
  final DateTime createdAt;

  factory PushRecord.fromJson(Map<String, dynamic> json) {
    return PushRecord(
      id: json['id'] as String? ?? '',
      signalEventId: _nullableString(json['signal_event_id']),
      deviceId: json['device_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      provider: json['provider'] as String? ?? 'unknown',
      errorMessage: json['error_message'] as String? ?? '',
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      sentAt: _readDateTime(json['sent_at']),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PushProviderStatus {
  const PushProviderStatus({
    required this.provider,
    required this.configured,
    required this.validateOnly,
    required this.missingEnv,
    required this.message,
  });

  final String provider;
  final bool configured;
  final bool validateOnly;
  final List<String> missingEnv;
  final String message;

  factory PushProviderStatus.fromJson(Map<String, dynamic> json) {
    return PushProviderStatus(
      provider: json['provider'] as String? ?? 'unknown',
      configured: json['configured'] as bool? ?? false,
      validateOnly: json['validate_only'] as bool? ?? false,
      missingEnv: (json['missing_env'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      message: json['message'] as String? ?? '',
    );
  }
}

DateTime? _readDateTime(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

String? _nullableString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
