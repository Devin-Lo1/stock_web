import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushTokenService {
  const PushTokenService();

  static const _tokenKey = 'notification.installation_token';

  Future<String> getInstallationToken() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_tokenKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final token =
        'local-${DateTime.now().microsecondsSinceEpoch}-${Object().hashCode}';
    await preferences.setString(_tokenKey, token);
    return token;
  }

  String get platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
  }
}
