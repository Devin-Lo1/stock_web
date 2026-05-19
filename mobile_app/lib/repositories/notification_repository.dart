import '../models/notification_models.dart';
import '../services/notification_api_service.dart';
import '../services/push_token_service.dart';

class NotificationRepository {
  const NotificationRepository({
    required NotificationApiService apiService,
    required PushTokenService tokenService,
  }) : _apiService = apiService,
       _tokenService = tokenService;

  final NotificationApiService _apiService;
  final PushTokenService _tokenService;

  Future<NotificationRegistrationResult> registerCurrentDevice({
    required bool enabled,
    required bool importantEnabled,
  }) async {
    final registration = await _tokenService.getPushTokenRegistration();
    return _apiService.registerDevice(
      platform: _tokenService.platform,
      pushProvider: registration.provider,
      pushToken: registration.token,
      deviceName: '当前手机',
      appVersion: 'Android MVP 0.1.0',
      enabled: enabled,
      importantEnabled: importantEnabled,
    );
  }

  Future<PushRecord> sendTestNotification(String deviceId) {
    return _apiService.sendTestNotification(
      deviceId: deviceId,
      title: '测试提醒',
      message: '通知设置页已成功连接后端。',
    );
  }
}
