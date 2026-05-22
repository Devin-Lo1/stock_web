import '../models/notification_models.dart';
import 'api_client.dart';

class NotificationApiService {
  const NotificationApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<NotificationRegistrationResult> registerDevice({
    required String platform,
    required String pushProvider,
    required String pushToken,
    required String deviceName,
    required String appVersion,
    required bool enabled,
    required bool importantEnabled,
  }) async {
    final json = await _apiClient.post('/api/v1/notifications/devices', {
      'platform': platform,
      'push_provider': pushProvider,
      'push_token': pushToken,
      'device_name': deviceName,
      'app_version': appVersion,
      'enabled': enabled,
      'important_enabled': importantEnabled,
    });
    return NotificationRegistrationResult.fromJson(
      (json as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<PushRecord> sendTestNotification({
    required String deviceId,
    required String title,
    required String message,
  }) async {
    final json = await _apiClient.post('/api/v1/notifications/test', {
      'device_id': deviceId,
      'title': title,
      'message': message,
    });
    return PushRecord.fromJson((json as Map<String, dynamic>?) ?? const {});
  }

  Future<List<PushRecord>> fetchPushRecords({
    String? signalEventId,
    String? deviceId,
    String? code,
    String? status,
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (signalEventId != null && signalEventId.trim().isNotEmpty) {
      query['signal_event_id'] = signalEventId.trim();
    }
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      query['device_id'] = deviceId.trim();
    }
    if (code != null && code.trim().isNotEmpty) {
      query['code'] = code.trim().toUpperCase();
    }
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    final decoded = await _apiClient.get(
      '/api/v1/notifications/push-records',
      query: query,
    );
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PushRecord.fromJson)
        .toList();
  }

  Future<PushRecord> retryPushRecord(String recordId) async {
    final json = await _apiClient.post(
      '/api/v1/notifications/push-records/$recordId/retry',
      const {},
    );
    return PushRecord.fromJson((json as Map<String, dynamic>?) ?? const {});
  }

  Future<void> deletePushRecord(String recordId) {
    return _apiClient.delete('/api/v1/notifications/push-records/$recordId');
  }
}
