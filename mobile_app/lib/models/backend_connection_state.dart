enum BackendConnectionState { connecting, connected, offline }

extension BackendConnectionStateLabel on BackendConnectionState {
  String get statusLabel {
    return switch (this) {
      BackendConnectionState.connecting => '连接中',
      BackendConnectionState.connected => '已连接',
      BackendConnectionState.offline => '离线',
    };
  }

  String get headerLabel {
    return switch (this) {
      BackendConnectionState.connecting => '正在连接后端',
      BackendConnectionState.connected => '后端已连接',
      BackendConnectionState.offline => '后端连接失败 · 使用本地缓存',
    };
  }
}
