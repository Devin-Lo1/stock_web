import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/trade_signal.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'trade_signals';
  static const _channelName = '持仓信号';
  static const _channelDescription = '止盈止损和异动提醒';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );
      await _plugin.initialize(settings: settings);
      await requestPermissions();
      _initialized = true;
    } catch (_) {
      // Missing platform plugin support during tests should not block the app.
    }
  }

  Future<void> requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    final macPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showTradeSignal(TradeSignal signal) async {
    if (!_initialized) await initialize();
    if (!_initialized || kIsWeb) return;

    try {
      await _plugin.show(
        id: signal.notificationKey.hashCode & 0x7fffffff,
        title: '${signal.type}：${signal.stock}',
        body: signal.time,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        payload: signal.notificationKey,
      );
    } catch (_) {
      // Notification failures should not interrupt quote refresh or editing.
    }
  }
}
