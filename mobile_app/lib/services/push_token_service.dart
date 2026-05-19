import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:huawei_push/huawei_push.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushTokenRegistration {
  const PushTokenRegistration({required this.provider, required this.token});

  final String provider;
  final String token;
}

class PushTokenService {
  const PushTokenService();

  static const _tokenKey = 'notification.installation_token';
  static const _fcmTokenTimeout = Duration(seconds: 4);
  static const _huaweiTokenTimeout = Duration(seconds: 4);

  Future<String> getInstallationToken() async {
    final registration = await getPushTokenRegistration();
    return registration.token;
  }

  Future<PushTokenRegistration> getPushTokenRegistration() async {
    final huaweiToken = await getHuaweiToken();
    if (huaweiToken != null && huaweiToken.isNotEmpty) {
      return PushTokenRegistration(provider: 'huawei', token: huaweiToken);
    }

    final fcmToken = await getFcmToken();
    if (fcmToken != null && fcmToken.isNotEmpty) {
      return PushTokenRegistration(provider: 'fcm', token: fcmToken);
    }

    final localToken = await _getLocalInstallationToken();
    return PushTokenRegistration(provider: 'unknown', token: localToken);
  }

  Future<String?> getHuaweiToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final appId = await Push.getAppId().timeout(_huaweiTokenTimeout);
      if (appId.isEmpty) return null;

      final tokenFuture = Push.getTokenStream
          .where((token) => token.isNotEmpty)
          .first
          .timeout(_huaweiTokenTimeout);
      Push.getToken('');
      return await tokenFuture;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getFcmToken() async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    try {
      return await FirebaseMessaging.instance
          .requestPermission()
          .then((_) => FirebaseMessaging.instance.getToken())
          .timeout(_fcmTokenTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<String> get pushProvider async {
    final registration = await getPushTokenRegistration();
    return registration.provider;
  }

  String get platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
  }

  Future<String> _getLocalInstallationToken() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_tokenKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final token =
        'local-${DateTime.now().microsecondsSinceEpoch}-${Object().hashCode}';
    await preferences.setString(_tokenKey, token);
    return token;
  }
}
