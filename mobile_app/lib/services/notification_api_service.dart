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
}
